# DccCachingService

Caching functionality for trustlist, business rules and value sets.

## Usage

To use this library, instantiate `DccCachingService` either with default values or custom URLs for trustlist, business rules and value sets. The default values for all URLs resolve to [https://dgc.a-sit.at/ehn/](https://dgc.a-sit.at/ehn/).

```swift
var cachingService = DccCachingService()
var validationCore = ValidationCore(trustlistService: cachingService.trustlistService)
```

Updates can be triggered manually as shown in the example below.
```swift
cachingService.trustlistService.updateTrustlistIfNecessary() {
    error in
    //handle potential error
}
```

## Demo Application Code

A demo application using this package can be found at [hcert-app-swift](https://github.com/ehn-dcc-development/hcert-app-swift)

## Dependencies

This library depends on protocols defined in the Swift package [https://github.com/ehn-dcc-development/ValidationCore](https://github.com/ehn-dcc-development/ValidationCore).
