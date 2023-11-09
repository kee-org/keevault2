import Foundation
import Logging

public class Binary2: Eraseable {
    public typealias ID = Int

    private(set) var id: Binary2.ID
    
    private(set) var data: ByteArray
    
    private(set) var isCompressed: Bool
    
    private(set) var isProtected: Bool
    
    public var flags: UInt8 {
        return isProtected ? 1 : 0
    }
    
    init(id: Binary2.ID, data: ByteArray, isCompressed: Bool, isProtected: Bool) {
        self.id = id
        self.data = data.clone()
        self.isCompressed = isCompressed
        self.isProtected = isProtected
    }
    
    deinit {
        erase()
    }
    
    public func erase() {
        id = -1
        isCompressed = false
        isProtected = false
        data.erase()
    }
    
    static func load(xml: AEXMLElement, streamCipher: StreamCipher) throws -> Binary2 {
        assert(xml.name == Xml2.binary)
        Logger.mainLog.trace("Loading XML: binary")
        
        let idString = xml.attributes[Xml2.id]
        guard let id = Int(idString) else {
            Logger.mainLog.error("Cannot parse Meta/Binary/ID as Int")
            throw Xml2.ParsingError.malformedValue(tag: "Meta/Binary/ID", value: idString)
        }
        let isCompressedString = xml.attributes[Xml2.compressed]
        let isProtectedString = xml.attributes[Xml2.protected]
        let isCompressed: Bool = Bool(string: isCompressedString ?? "")
        let isProtected: Bool = Bool(string: isProtectedString ?? "")
        let base64 = xml.value ?? ""
        guard var data = ByteArray(base64Encoded: base64) else {
            Logger.mainLog.error("Cannot parse Meta/Binary/Value as Base64 string")
            throw Xml2.ParsingError.malformedValue(tag: "Meta/Binary/ValueBase64", value: String(base64.prefix(16)))
        }
        
        if isProtected {
            Logger.mainLog.trace("Decrypting binary")
            data = try streamCipher.decrypt(data: data, progress: nil) 
        }
        
        return Binary2(id: id, data: data, isCompressed: isCompressed, isProtected: isProtected)
    }
    
    func toXml(streamCipher: StreamCipher) throws -> AEXMLElement {
        Logger.mainLog.trace("Generating XML: binary")
        var attributes = [
            Xml2.id: String(id),
            Xml2.compressed: isCompressed ? Xml2._true : Xml2._false
        ]
        
        let value: ByteArray
        if isProtected {
            Logger.mainLog.trace("Encrypting binary")
            value = try streamCipher.encrypt(data: data, progress: nil) 
            attributes[Xml2.protected] = Xml2._true
        } else {
            value = data
        }
        return AEXMLElement(
            name: Xml2.binary,
            value: value.base64EncodedString(),
            attributes: attributes)
    }
}
