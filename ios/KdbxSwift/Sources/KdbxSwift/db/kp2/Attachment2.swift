import Foundation
import Logging

public class Attachment2: Attachment {
    public var id: Int

    public convenience override init(name: String, isCompressed: Bool, data: ByteArray) {
        self.init(id: -1, name: name, isCompressed: isCompressed, data: data)
    }

    public init(id: Int, name: String, isCompressed: Bool, data: ByteArray) {
        self.id = id
        super.init(name: name, isCompressed: isCompressed, data: data)
    }
    
    override public func clone() -> Attachment {
        return Attachment2(
            id: self.id,
            name: self.name,
            isCompressed: self.isCompressed,
            data: self.data)
    }
    
    static func load(
        xml: AEXMLElement,
        database: Database2,
        streamCipher: StreamCipher
        ) throws -> Attachment2
    {
        assert(xml.name == Xml2.binary)
        
        Logger.mainLog.trace("Loading XML: entry attachment")
        var name: String?
        var binary: Binary2?
        for tag in xml.children {
            switch tag.name {
            case Xml2.key:
                name = tag.value
            case Xml2.value:
                let refString = tag.attributes[Xml2.ref]
                guard let binaryID = Int(refString) else {
                    Logger.mainLog.error("Cannot parse Entry/Binary/Value/Ref as Int")
                    throw Xml2.ParsingError.malformedValue(
                        tag: "Entry/Binary/Value/Ref",
                        value: refString)
                }

                if let binaryInDatabasePool = database.binaries[binaryID] {
                    binary = binaryInDatabasePool
                } else {
                    binary = Binary2(
                        id: binaryID,
                        data: ByteArray(),
                        isCompressed: false,
                        isProtected: false
                    )
                }
            default:
                Logger.mainLog.error("Unexpected XML tag in Entry/Binary", metadata: ["name": "\(tag.name)"])
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "Entry/Binary/*")
            }
        }
        let _name = name ?? ""
        if _name.isEmpty {
            Logger.mainLog.error("Missing Entry/Binary/Name, ignoring")
        }
        guard let _binary = binary else {
            Logger.mainLog.error("Missing Entry/Binary/Value")
            throw Xml2.ParsingError.malformedValue(tag: "Entry/Binary/Value/Ref", value: nil)
        }
        return Attachment2(
            id: _binary.id,
            name: _name,
            isCompressed: _binary.isCompressed,
            data: _binary.data)
    }
    
    internal func toXml() -> AEXMLElement {
        Logger.mainLog.trace("Generating XML: entry attachment")
        let xmlAtt = AEXMLElement(name: Xml2.binary)
        xmlAtt.addChild(name: Xml2.key, value: self.name)
        xmlAtt.addChild(name: Xml2.value, value: nil, attributes: [Xml2.ref: String(self.id)])
        return xmlAtt
    }
}
