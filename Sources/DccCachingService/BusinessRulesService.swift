//
//  BusinessRulesService.swift
//
//
//  Created by Martin Fitzka-Reichart on 14.07.21.
//  Adapted by Dominik Mocher on 26.08.21.
//

import Foundation
import ValidationCore

public protocol BusinessRulesService {
    func businessRules(completionHandler: @escaping (Swift.Result<[BusinessRule], ValidationError>) -> Void)
    func updateDataIfNecessary(force: Bool, completionHandler: @escaping (ValidationError?) -> Void)
    func updateDateService(_ dateService: DateService)
}

class DefaultBusinessRulesService: SignedDataService<BusinessRulesContainer>, BusinessRulesService {
    private let BUSINESS_RULES_FILENAME = "businessrules"
    private let BUSINESS_RULES_KEY_ALIAS = "businessrules_key"
    private let BUSINESS_RULES_KEYCHAIN_ALIAS = "businessrules_keychain"
    private let LAST_UPDATE_KEY = "last_businessrules_update"

    private var parsedRules: [BusinessRule]?

    init(dateService: DateService, businessRulesUrl: String, signatureUrl: String, trustAnchor: String, apiKey: String? = nil, storeEncrypted: Bool = false) {
        super.init(dateService: dateService,
                   dataUrl: businessRulesUrl,
                   signatureUrl: signatureUrl,
                   trustAnchor: trustAnchor,
                   updateInterval: TimeInterval(24.hour),
                   maximumAge: TimeInterval(72.hour),
                   fileName: BUSINESS_RULES_FILENAME,
                   keyAlias: BUSINESS_RULES_KEY_ALIAS,
                   legacyKeychainAlias: BUSINESS_RULES_KEYCHAIN_ALIAS,
                   lastUpdateKey: LAST_UPDATE_KEY,
                   apiKey: apiKey,
                   useEncryption: storeEncrypted)
    }

    override func didUpdateData() {
        parsedRules = cachedData.rules
    }

    private func parsedBusinessRules() -> [BusinessRule] {
        return parsedRules ?? []
    }

    func businessRules(completionHandler: @escaping (Swift.Result<[BusinessRule], ValidationError>) -> Void) {
        updateDataIfNecessary { [weak self] _ in
            self?.cachedBusinessRules(completionHandler: completionHandler)
        }
    }

    private func cachedBusinessRules(completionHandler: @escaping (Swift.Result<[BusinessRule], ValidationError>) -> Void) {
        if dataIsExpired() {
            completionHandler(.failure(.DATA_EXPIRED))
            return
        }

        completionHandler(.success(parsedBusinessRules()))
    }
}
