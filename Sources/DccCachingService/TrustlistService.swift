//
//  TrustlistService.swift
//
//
//  Created by Dominik Mocher on 26.04.21.
//  Adapted by Dominik Mocher on 26.08.21.
//

import Foundation
import SwiftCBOR
import CocoaLumberjackSwift
import Security
import ValidationCore

class DefaultTrustlistService: SignedDataService<TrustList>, TrustlistService {
    private let TRUSTLIST_FILENAME = "trustlist"
    private let TRUSTLIST_KEY_ALIAS = "trustlist_key"
    private let TRUSTLIST_KEYCHAIN_ALIAS = "trustlist_keychain"
    private let LAST_UPDATE_KEY = "last_trustlist_update"
    
    init(dateService: DateService, trustlistUrl: String, signatureUrl: String, trustAnchor: String, apiKey: String? = nil, storeEncrypted: Bool = false) {
        super.init(dateService: dateService,
                   dataUrl: trustlistUrl,
                   signatureUrl: signatureUrl,
                   trustAnchor: trustAnchor,
                   updateInterval: TimeInterval(24.hour),
                   maximumAge: TimeInterval(72.hour),
                   fileName: TRUSTLIST_FILENAME,
                   keyAlias: TRUSTLIST_KEY_ALIAS,
                   legacyKeychainAlias: TRUSTLIST_KEYCHAIN_ALIAS,
                   lastUpdateKey: LAST_UPDATE_KEY,
                   apiKey: apiKey,
                   useEncryption: storeEncrypted)
    }
    
    public func key(for keyId: Data, keyType: CertType, completionHandler: @escaping (Result<SecKey, ValidationError>) -> Void) {
        key(for: keyId, keyType: keyType, cwt: nil, completionHandler: completionHandler)
    }
    
    public func key(for keyId: Data, cwt: CWT, keyType: CertType, completionHandler: @escaping (Result<SecKey, ValidationError>) -> Void) {
        return key(for: keyId, keyType: keyType, cwt: cwt, completionHandler: completionHandler)
    }
    
    private func key(for keyId: Data, keyType: CertType, cwt: CWT?, completionHandler: @escaping (Result<SecKey, ValidationError>) -> Void) {
        updateDataIfNecessary { _ in
            self.cachedKey(from: keyId, for: keyType, cwt: cwt, completionHandler)
        }
    }
    
    private func cachedKey(from keyId: Data, for keyType: CertType, cwt: CWT?, _ completionHandler: @escaping (Result<SecKey, ValidationError>) -> Void) {
        if dataIsExpired() {
            completionHandler(.failure(.DATA_EXPIRED))
            return
        }
        
        guard let entry = cachedData.entry(for: keyId) else {
            completionHandler(.failure(.KEY_NOT_IN_TRUST_LIST))
            return
        }
        guard entry.isValid(for: dateService) else {
            completionHandler(.failure(.PUBLIC_KEY_EXPIRED))
            return
        }
        guard entry.isSuitable(for: keyType) else {
            completionHandler(.failure(.UNSUITABLE_PUBLIC_KEY_TYPE))
            return
        }
        
        if let cwtIssuedAt = cwt?.issuedAt,
           let cwtExpiresAt = cwt?.expiresAt,
           let certNotBefore = entry.notBefore,
           let certNotAfter = entry.notAfter {
            
            guard certNotAfter.isAfter(dateService.now) else {
                completionHandler(.failure(.PUBLIC_KEY_EXPIRED))
                return
            }
            
            guard certNotBefore.isBefore(dateService.now) else {
                completionHandler(.failure(.PUBLIC_KEY_NOT_YET_VALID))
                return
            }
            
            guard cwtExpiresAt.isAfter(dateService.now) else {
                completionHandler(.failure(.CWT_EXPIRED))
                return
            }
            
            guard cwtIssuedAt.isBefore(dateService.now) else {
                completionHandler(.failure(.CWT_NOT_YET_VALID))
                return
            }
        }
        
        guard let secKey = entry.publicKey else {
            completionHandler(.failure(.KEY_CREATION_ERROR))
            return
        }
        completionHandler(.success(secKey))
    }
    
    func updateTrustlistIfNecessary(completionHandler: @escaping (ValidationError?) -> ()) {
        self.updateDataIfNecessary(force: true, completionHandler: completionHandler)
    }
}
