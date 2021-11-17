//
//  SignedDataService.swift
//
//
//  Created by Martin Fitzka-Reichart on 14.07.21.
//  Adapted by Dominik Mocher on 26.08.21.
//
import ValidationCore
import CocoaLumberjackSwift
import Foundation
import Security
import SwiftCBOR

class SignedDataService<T: SignedData> {
    let dataUrl: String
    private let signatureUrl: String
    private let apiKey: String?
    private let trustAnchor: String
    var dateService: DateService
    private let fileStorage: FileStorage
    var cachedData: T
    private let updateInterval: TimeInterval
    private let maximumAge: TimeInterval
    var lastUpdate: Date {
        get {
            if let isoDate = UserDefaults().string(forKey: lastUpdateKey),
               let date = ISO8601DateFormatter().date(from: isoDate) {
                return date
            }
            return Date(timeIntervalSince1970: 0)
        }
        set {
            let isoDate = ISO8601DateFormatter().string(from: newValue)
            UserDefaults().set(isoDate, forKey: lastUpdateKey)
        }
    }
    
    private let fileName: String
    private let keyAlias: String
    private let legacyKeychainAlias: String
    private let lastUpdateKey: String
    private let useEncryption : Bool
    
    init(dateService: DateService,
         dataUrl: String,
         signatureUrl: String,
         trustAnchor: String,
         updateInterval: TimeInterval,
         maximumAge: TimeInterval,
         fileName: String,
         keyAlias: String,
         legacyKeychainAlias: String,
         lastUpdateKey: String,
         apiKey: String? = nil,
         useEncryption: Bool = true) {
        self.dataUrl = dataUrl
        self.signatureUrl = signatureUrl
        self.trustAnchor = trustAnchor
        fileStorage = FileStorage()
        self.dateService = dateService
        self.updateInterval = updateInterval
        self.maximumAge = maximumAge
        self.fileName = fileName
        self.keyAlias = keyAlias
        self.legacyKeychainAlias = legacyKeychainAlias
        self.lastUpdateKey = lastUpdateKey
        self.apiKey = apiKey
        self.useEncryption = useEncryption
        cachedData = T()
        loadCachedData()
        if cachedData.isEmpty {
            lastUpdate = Date(timeIntervalSince1970: 0)
        }
        updateSignatureAndDataIfNecessary { _ in }
        removeLegacyKeychainData()
    }
    
    func updateDateService(_ dateService: DateService) {
        self.dateService = dateService
    }
    
    public func updateDataIfNecessary(force: Bool = false, completionHandler: @escaping (ValidationError?) -> Void) {
        if dateService.isNowBefore(lastUpdate.addingTimeInterval(updateInterval)) && !cachedData.isEmpty && !force {
            DDLogDebug("Skipping data update...")
            completionHandler(nil)
            return
        }
        
        updateSignatureAndDataIfNecessary { error in
            if let error = error {
                DDLogError("Cannot refresh data: \(error)")
            }
            
            completionHandler(error)
        }
    }
    
    private func updateSignatureAndDataIfNecessary(completionHandler: @escaping (ValidationError?) -> Void) {
        updateDetachedSignature { result in
            switch result {
            case let .success(hash):
                if hash != self.cachedData.hash {
                    self.updateData(for: hash, completionHandler)
                    return
                } else {
                    self.lastUpdate = self.dateService.now
                }
                completionHandler(nil)
            case let .failure(error):
                completionHandler(error)
            }
        }
    }
    
    private func updateData(for hash: Data, _ completionHandler: @escaping (ValidationError?) -> Void) {
        guard let request = defaultRequest(to: dataUrl) else {
            completionHandler(.TRUST_SERVICE_ERROR)
            return
        }
        
        URLSession.shared.dataTask(with: request) { body, response, error in
            guard self.isResponseValid(response, error), let body = body else {
                DDLogError("Cannot query signed data service")
                completionHandler(.TRUST_SERVICE_ERROR)
                return
            }
            guard self.refreshData(from: body, for: hash) else {
                completionHandler(.TRUST_SERVICE_ERROR)
                return
            }
            self.lastUpdate = self.dateService.now
            completionHandler(nil)
        }.resume()
    }
    
    private func updateDetachedSignature(completionHandler: @escaping (Result<Data, ValidationError>) -> Void) {
        guard let request = defaultRequest(to: signatureUrl) else {
            completionHandler(.failure(.TRUST_SERVICE_ERROR))
            return
        }
        
        URLSession.shared.dataTask(with: request) { body, response, error in
            guard self.isResponseValid(response, error), let body = body else {
                completionHandler(.failure(.TRUST_SERVICE_ERROR))
                return
            }
            do {
                let decoded = try DataDecoder().decode(signatureCose: body, trustAnchor: self.trustAnchor, dateService: self.dateService)
                let trustlistHash = decoded.content
                completionHandler(.success(trustlistHash))
            } catch let error {
                completionHandler(.failure(error as? ValidationError ?? .TRUST_SERVICE_ERROR))
                return
            }
        }.resume()
    }
    
    private func refreshData(from data: Data, for hash: Data) -> Bool {
        guard let cbor = try? CBORDecoder(input: data.bytes).decodeItem(),
              var decodedData = try? CodableCBORDecoder().decode(T.self, from: cbor.asData()) else {
            return false
        }
        
        decodedData.hash = hash
        cachedData = decodedData
        storeData()
        didUpdateData()
        return true
    }
    
    func didUpdateData() {}
    
    private func defaultRequest(to url: String) -> URLRequest? {
        guard let url = URL(string: url) else {
            return nil
        }
        var request = URLRequest(url: url)
        request.addValue("application/octet-stream", forHTTPHeaderField: "Accept")
        if let apiToken = apiKey {
            request.addValue(apiToken, forHTTPHeaderField: "X-Token")
        }
        return request
    }
    
    private func isResponseValid(_ response: URLResponse?, _ error: Error?) -> Bool {
        guard error == nil,
              let status = (response as? HTTPURLResponse)?.statusCode,
              status == 200 else {
            return false
        }
        return true
    }
    
    private func trustAnchorKey() -> SecKey? {
        guard let certData = Data(base64Encoded: trustAnchor),
              let certificate = SecCertificateCreateWithData(nil, certData as CFData),
              let secKey = SecCertificateCopyKey(certificate) else {
            return nil
        }
        return secKey
    }
    
    func dataIsExpired() -> Bool {
        if dateService.isNowBefore(expirationDate) {
            return false
        }
        return true
    }
    
    public var expirationDate : Date {
        get {
            return lastUpdate.addingTimeInterval(maximumAge)
        }
    }
}

extension SignedDataService {
    // MARK: Cached Data Storage and Retrieval
    private func storeData() {
        guard let encodedData = try? JSONEncoder().encode(cachedData) else {
            DDLogError("Cannot encode data for storing")
            return
        }
        if !useEncryption {
            storeUnencrypted(data: encodedData)
            return
        }
        if #available(iOS 13.0, *) {
            storeEncrypted(data: encodedData)
        } else {
            storeLegacyData(encodedData: encodedData)
        }
    }
    
    func loadCachedData() {
        if !useEncryption {
            loadUnencryptedCachedData()
            return
        }
        if #available(iOS 13.0, *) {
            loadEncryptedCachedData()
        } else {
            loadCachedLegacyData()
        }
        didUpdateData()
    }
    
    @available(iOS 13, *)
    func storeEncrypted(data: Data){
        CryptoService.createKeyAndEncrypt(data: data, with: self.keyAlias, completionHandler: { result in
            switch result {
            case let .success(encryptedData):
                if !self.fileStorage.writeProtectedFileToDisk(fileData: encryptedData, with: self.fileName) {
                    DDLogError("Cannot write data to disk")
                }
            case let .failure(error): DDLogError(error)
            }
        })
    }
    
    @available(iOS 13, *)
    func loadEncryptedCachedData(){
        if let encodedData = fileStorage.loadProtectedFileFromDisk(with: self.fileName) {
            CryptoService.decrypt(ciphertext: encodedData, with: self.keyAlias) { result in
                switch result {
                case let .success(plaintext):
                    if let data = try? JSONDecoder().decode(T.self, from: plaintext) {
                        self.cachedData = data
                    }
                case let .failure(error): DDLogError("Cannot load cached trust list: \(error)")
                }
            }
        }
    }
    
    func storeUnencrypted(data: Data) {
        if !fileStorage.writeProtectedFileToDisk(fileData: data, with: fileName) {
            DDLogError("Cannot write unencrypted data to disk")
        }
    }
    
    func loadUnencryptedCachedData(){
        guard let fileData = fileStorage.loadProtectedFileFromDisk(with: fileName),
              let decoded = try? JSONDecoder().decode(T.self, from: fileData) else {
            DDLogError("Cannot load unencrypted cached data")
            return
        }
        cachedData = decoded
        didUpdateData()
    }
}

extension SignedDataService {
    // MARK: iOS 12 support for missing CryptoKit
    func removeLegacyKeychainData() {
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrLabel: legacyKeychainAlias] as [String: Any]
        SecItemDelete(query as CFDictionary)
    }
    
    private func storeLegacyData(encodedData: Data) {
        guard let accessFlags = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            [],
            nil
        ) else {
            DDLogError(ValidationError.KEYSTORE_ERROR)
            return
        }
        let updateQuery = [kSecClass: kSecClassGenericPassword,
                           kSecAttrLabel: legacyKeychainAlias,
                           kSecAttrAccessControl: accessFlags] as [String: Any]
        
        let updateAttributes = [kSecValueData: encodedData] as [String: Any]
        
        let status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        if status == errSecItemNotFound {
            let addQuery = [kSecClass: kSecClassGenericPassword,
                            kSecAttrLabel: legacyKeychainAlias,
                            kSecAttrAccessControl: accessFlags,
                            kSecValueData: encodedData] as [String: Any]
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                DDLogError(ValidationError.KEYSTORE_ERROR)
            }
        } else if status != errSecSuccess {
            DDLogError(ValidationError.KEYSTORE_ERROR)
        }
    }
    
    private func loadCachedLegacyData() {
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrLabel: legacyKeychainAlias,
                     kSecReturnData: true] as [String: Any]
        
        var item: CFTypeRef?
        switch SecItemCopyMatching(query as CFDictionary, &item) {
        case errSecSuccess:
            if let plaintext = item as? Data {
                if let data = try? JSONDecoder().decode(T.self, from: plaintext) {
                    cachedData = data
                }
            }
            
        default: DDLogError(ValidationError.KEYSTORE_ERROR)
        }
    }
}
