import ValidationCore

public class DccCachingService {
    private static let DEFAULT_TRUSTLIST_URL = "https://dgc.a-sit.at/ehn/cert/listv2"
    private static let DEFAULT_SIGNATURE_URL = "https://dgc.a-sit.at/ehn/cert/sigv2"
    private static let DEFAULT_TRUSTLIST_TRUSTANCHOR = """
        MIIBJTCBy6ADAgECAgUAwvEVkzAKBggqhkjOPQQDAjAQMQ4wDAYDVQQDDAVFQy1N
        ZTAeFw0yMTA0MjMxMTI3NDhaFw0yMTA1MjMxMTI3NDhaMBAxDjAMBgNVBAMMBUVD
        LU1lMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE/OV5UfYrtE140ztF9jOgnux1
        oyNO8Bss4377E/kDhp9EzFZdsgaztfT+wvA29b7rSb2EsHJrr8aQdn3/1ynte6MS
        MBAwDgYDVR0PAQH/BAQDAgWgMAoGCCqGSM49BAMCA0kAMEYCIQC51XwstjIBH10S
        N701EnxWGK3gIgPaUgBN+ljZAs76zQIhAODq4TJ2qAPpFc1FIUOvvlycGJ6QVxNX
        EkhRcgdlVfUb
        """.normalizeCertificate()
    
    private static let DEFAULT_BUSINESS_RULES_URL = "https://dgc.a-sit.at/ehn/rules/v1/bin"
    private static let DEFAULT_BUSINESS_RULES_SIGNATURE_URL = "https://dgc.a-sit.at/ehn/rules/v1/sig"
    private static let DEFAULT_BUSINESS_RULES_TRUSTANCHOR = DEFAULT_TRUSTLIST_TRUSTANCHOR.normalizeCertificate()
    
    private static let DEFAULT_VALUE_SET_URL = "https://dgc.a-sit.at/ehn/values/v1/bin"
    private static let DEFAULT_VALUE_SET_SIGNATURE_URL = "https://dgc.a-sit.at/ehn/values/v1/sig"
    private static let DEFAULT_VALUE_SET_TRUSTANCHOR = DEFAULT_TRUSTLIST_TRUSTANCHOR.normalizeCertificate()
    
    public var trustlistService : TrustlistService
    public var valueSetService : ValueSetsService
    public var businessRulesService : BusinessRulesService
    
    public init(dateService: DateService? = nil, trustlistUrl : String? = nil, trustlistSignatureUrl: String? = nil, trustlistTrustAnchor: String? = nil, trustlistApiKey: String? = nil,
                businessRulesUrl: String? = nil, businessRulesSignatureUrl: String? = nil, businessRulesTrustAnchor : String? = nil, businessRulesApiKey: String? = nil,
                valueSetUrl: String? = nil, valueSetSignatureUrl: String? = nil, valueSetTrustAnchor: String? = nil, valueSetApiKey: String? = nil){
        self.trustlistService = DefaultTrustlistService(dateService: dateService ?? DefaultDateService(),
                                                        trustlistUrl: trustlistUrl ?? DccCachingService.DEFAULT_TRUSTLIST_URL,
                                                        signatureUrl: trustlistSignatureUrl ?? DccCachingService.DEFAULT_SIGNATURE_URL,
                                                        trustAnchor: trustlistTrustAnchor ?? DccCachingService.DEFAULT_TRUSTLIST_TRUSTANCHOR,
                                                        apiKey: trustlistApiKey)
        
        self.businessRulesService = DefaultBusinessRulesService(dateService: dateService ?? DefaultDateService(),
                                                                businessRulesUrl: businessRulesUrl ?? DccCachingService.DEFAULT_BUSINESS_RULES_URL,
                                                                signatureUrl: businessRulesSignatureUrl ?? DccCachingService.DEFAULT_BUSINESS_RULES_SIGNATURE_URL,
                                                                trustAnchor: businessRulesTrustAnchor ?? DccCachingService.DEFAULT_BUSINESS_RULES_TRUSTANCHOR,
                                                                apiKey: businessRulesApiKey)
        
        self.valueSetService = DefaultValueSetsService(dateService: dateService ?? DefaultDateService(),
                                                       valueSetsUrl: valueSetUrl ?? DccCachingService.DEFAULT_VALUE_SET_URL,
                                                       signatureUrl: valueSetSignatureUrl ?? DccCachingService.DEFAULT_VALUE_SET_SIGNATURE_URL,
                                                       trustAnchor: valueSetTrustAnchor ?? DccCachingService.DEFAULT_VALUE_SET_TRUSTANCHOR,
                                                       apiKey: valueSetApiKey)
    }
    
    public func initTrustlistService(trustlistUrl : String? = nil, signatureUrl: String? = nil, trustAnchor: String? = nil, apiKey: String? = nil, dateService: DateService? = nil) {
        self.trustlistService = DefaultTrustlistService(dateService: dateService ?? DefaultDateService(),
                                                        trustlistUrl: trustlistUrl ?? DccCachingService.DEFAULT_TRUSTLIST_URL,
                                                        signatureUrl: signatureUrl ?? DccCachingService.DEFAULT_SIGNATURE_URL,
                                                        trustAnchor: trustAnchor ?? DccCachingService.DEFAULT_TRUSTLIST_TRUSTANCHOR,
                                                        apiKey: apiKey)
    }
    
    public func initBusinessRuleService(businessRulesUrl: String? = nil, signatureUrl: String? = nil, trustAnchor: String? = nil, apiKey: String? = nil, dateService: DateService? = nil) {
        self.businessRulesService = DefaultBusinessRulesService(dateService: dateService ?? DefaultDateService(),
                                                                businessRulesUrl: businessRulesUrl ?? DccCachingService.DEFAULT_BUSINESS_RULES_URL,
                                                                signatureUrl: signatureUrl ?? DccCachingService.DEFAULT_BUSINESS_RULES_SIGNATURE_URL,
                                                                trustAnchor: trustAnchor ?? DccCachingService.DEFAULT_BUSINESS_RULES_TRUSTANCHOR,
                                                                apiKey: apiKey)
    }
    
    public func initValueSetService(valueSetUrl: String? = nil, signatureUrl: String? = nil, trustAnchor: String? = nil, apiKey: String? = nil, dateService: DateService? = nil) {
        self.valueSetService = DefaultValueSetsService(dateService: dateService ?? DefaultDateService(),
                                                       valueSetsUrl: valueSetUrl ?? DccCachingService.DEFAULT_VALUE_SET_URL,
                                                       signatureUrl: signatureUrl ?? DccCachingService.DEFAULT_VALUE_SET_SIGNATURE_URL,
                                                       trustAnchor: trustAnchor ?? DccCachingService.DEFAULT_VALUE_SET_TRUSTANCHOR,
                                                       apiKey: apiKey)
    }
}
