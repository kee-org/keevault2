import Foundation
import os.log

public class TOTPGeneratorFactory {
    
    public static func makeGenerator(for entry: Entry) -> TOTPGenerator? {
        return makeGenerator(from: entry.fields)
    }
    
    private static func find(_ name: String, in fields: [EntryField]) -> EntryField? {
        return fields.first(where: { $0.name == name })
    }
    
    public static func makeGenerator(from fields: [EntryField]) -> TOTPGenerator? {
        if let totpField = find(SingleFieldFormat.fieldName, in: fields) {
            return parseSingleFieldFormat(totpField.value)
        } else {
            guard let seedField = find(SplitFieldFormat.seedFieldName, in: fields) else {
                return nil
            }
            let settingsField = find(SplitFieldFormat.settingsFieldName, in: fields) 
            return SplitFieldFormat.parse(
                seedString: seedField.value,
                settingsString: settingsField?.value)
        }
    }
    
    private static func parseSingleFieldFormat(_ paramString: String) -> TOTPGenerator? {
        let trimmedParamString = paramString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uriComponents = URLComponents(string: trimmedParamString) else {
            Logger.mainLog.warning("Unexpected OTP field format")
            return nil
        }
        
        if GAuthFormat.isMatching(scheme: uriComponents.scheme, host: uriComponents.host) {
            return GAuthFormat.parse(uriComponents)
        }
        if KeeOtpFormat.isMatching(scheme: uriComponents.scheme, host: uriComponents.host) {
            return KeeOtpFormat.parse(paramString)
        }
        Logger.mainLog.warning("Unrecognized OTP field format")
        return nil
    }

    public static func isValid(_ paramString: String) -> Bool {
        return parseSingleFieldFormat(paramString) != nil
    }
}

public extension EntryField {
    static let otpConfig1 = EntryField.otp
    static let otpConfig2Seed = SplitFieldFormat.seedFieldName
    static let otpConfig2Settings = SplitFieldFormat.settingsFieldName
}

fileprivate class SingleFieldFormat {
    static let fieldName = EntryField.otp
}

fileprivate class GAuthFormat: SingleFieldFormat {
    static let scheme = "otpauth"
    static let host = "totp"
    
    static let seedParam = "secret"
    static let timeStepParam = "period"
    static let lengthParam = "digits"
    static let algorithmParam = "algorithm"
    static let issuerParam = "issuer"
    static let encoderParam = "encoder" 
    
    static let defaultTimeStep = 30
    static let defaultLength = 6
    static let defaultAlgorithm = TOTPHashAlgorithm.sha1
    
    static func isMatching(scheme: String?, host: String?) -> Bool {
        return scheme == GAuthFormat.scheme
    }
    
    static func parse(_ uriComponents: URLComponents) -> TOTPGenerator? {
        guard uriComponents.scheme == scheme,
            uriComponents.host == host,
            let queryItems = uriComponents.queryItems else
        {
            Logger.mainLog.warning("OTP URI has unexpected format")
            return nil
        }
        
        let params = queryItems.reduce(into: [String: String]()) { (result, item) in
            result[item.name] = item.value
        }
        
        guard let seedString = params[seedParam],
            let seedData = base32DecodeToData(seedString),
            !seedData.isEmpty else
        {
            Logger.mainLog.warning("OTP parameter cannot be parsed [parameter: \(seedParam)]")
            return nil
        }
        
        guard let timeStep = Int(params[timeStepParam] ?? "\(defaultTimeStep)") else {
            Logger.mainLog.warning("OTP parameter cannot be parsed [parameter: \(timeStepParam)]")
            return nil
        }
        
        let isSteam = uriComponents.path.starts(with: "/Steam:") ||
            (params[issuerParam] == "Steam") ||
            (params[encoderParam] == "steam")
        if isSteam {
            return TOTPGeneratorSteam(seed: ByteArray(data: seedData), timeStep: timeStep)
        }
        
        var algorithm: TOTPHashAlgorithm?
        if let algorithmString = params[algorithmParam] {
            guard let _algorithm = TOTPHashAlgorithm.fromString(algorithmString) else {
                Logger.mainLog.warning("OTP algorithm is not supported [algorithm: \(algorithmString)]")
                return nil
            }
            algorithm = _algorithm
        }
        
        guard let length = Int(params[lengthParam] ?? "\(defaultLength)") else {
            Logger.mainLog.warning("OTP parameter cannot be parsed [parameter: \(lengthParam)]")
            return nil
        }
        
        return TOTPGeneratorRFC6238(
            seed: ByteArray(data: seedData),
            timeStep: timeStep,
            length: length,
            hashAlgorithm: algorithm ?? defaultAlgorithm)
    }
}

fileprivate class KeeOtpFormat: SingleFieldFormat {
    static let seedParam = "key"
    static let timeStepParam = "step"
    static let lengthParam = "size"
    static let typeParam = "type"
    static let algorithmParam = "otpHashMode"
    
    static let defaultTimeStep = 30
    static let defaultLength = 6
    static let defaultAlgorithm = TOTPHashAlgorithm.sha1
    static let supportedType = "totp"
    
    static func isMatching(scheme: String?, host: String?) -> Bool {
        return (scheme == nil) && (host == nil)
    }

    static func parse(_ paramString: String) -> TOTPGenerator? {
        guard let uriComponents = URLComponents(string: "fakeScheme://fakeHost?" + paramString),
            let queryItems = uriComponents.queryItems
            else { return nil }
        let params = queryItems.reduce(into: [String: String]()) { (result, item) in
            result[item.name] = item.value
        }
        
        guard let seedString = params[seedParam],
            let seedData = base32DecodeToData(seedString),
            !seedData.isEmpty else
        {
            Logger.mainLog.warning("OTP parameter cannot be parsed [parameter: \(seedParam)]")
            return nil
        }
        
        if let type = params[typeParam],
            type.caseInsensitiveCompare(supportedType) != .orderedSame
        {
            Logger.mainLog.warning("OTP type is not suppoorted [type: \(type)]")
            return nil
        }
        
        var algorithm: TOTPHashAlgorithm?
        if let algorithmString = params[algorithmParam] {
            guard let _algorithm = TOTPHashAlgorithm.fromString(algorithmString) else {
                Logger.mainLog.warning("OTP algorithm is not supported [algorithm: \(algorithmString)]")
                return nil
            }
            algorithm = _algorithm
        }
        
        guard let timeStep = Int(params[timeStepParam] ?? "\(defaultTimeStep)") else {
            Logger.mainLog.warning("OTP parameter cannot be parsed [parameter: \(timeStepParam)]")
            return nil
        }
        
        guard let length = Int(params[lengthParam] ?? "\(defaultLength)") else {
            Logger.mainLog.warning("OTP parameter cannot be parsed [parameter: \(lengthParam)]")
            return nil
        }
        
        return TOTPGeneratorRFC6238(
            seed: ByteArray(data: seedData),
            timeStep: timeStep,
            length: length,
            hashAlgorithm: algorithm ?? defaultAlgorithm)
    }
}

fileprivate class SplitFieldFormat {
    static let seedFieldName = "TOTP Seed"
    static let settingsFieldName = "TOTP Settings"
    static let defaultSettingsValue = "30;6"
    
    static func parse(seedString: String, settingsString: String?) -> TOTPGenerator? {
        guard let seed = parseSeedString(seedString) else {
            Logger.mainLog.warning("Unrecognized TOTP seed format")
            return nil
        }
        
        let settingsString = settingsString ?? SplitFieldFormat.defaultSettingsValue
        let settings = settingsString.split(separator: ";")
        if settings.count > 2 {
            Logger.mainLog.trace("Found redundant TOTP settings, ignoring [expected: 2, got: \(settings.count)]")
        } else if settings.count < 2 {
            Logger.mainLog.warning("Insufficient TOTP settings number [expected: 2, got: \(settings.count)]")
            return nil
        }
        guard let timeStep = Int(settings[0]) else {
            Logger.mainLog.warning("Failed to parse TOTP time step as Int")
            return nil
        }
        guard timeStep > 0 else {
            Logger.mainLog.warning("Invalid TOTP time step value: \(timeStep)")
            return nil
        }
        
        if let length = Int(settings[1]) {
            return TOTPGeneratorRFC6238(
                seed: seed,
                timeStep: timeStep,
                length: length,
                hashAlgorithm: .sha1
            )
        } else if settings[1] == TOTPGeneratorSteam.typeSymbol {
            return TOTPGeneratorSteam(seed: seed, timeStep: timeStep)
        } else {
            Logger.mainLog.warning("Unexpected TOTP size or type: '\(settings[1])'")
            return nil
        }
    }
    
    static func parseSeedString(_ seedString: String) -> ByteArray? {
        let cleanedSeedString = seedString
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "=", with: "")
        if let seedData = base32DecodeToData(cleanedSeedString) {
            return ByteArray(data: seedData)
        }
        if let seedData = base32HexDecodeToData(cleanedSeedString) {
            return ByteArray(data: seedData)
        }
        if let seedData = Data(base64Encoded: cleanedSeedString) {
            return ByteArray(data: seedData)
        }
        return nil
    }
}
