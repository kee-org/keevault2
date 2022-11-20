import Foundation

public class Attachment: Eraseable {
    public var name: String
    public internal(set) var isCompressed: Bool
    public internal(set) var data: ByteArray {
        didSet {
            uncompressedSize = -1
        }
    }
    public internal(set) var uncompressedSize: Int

    public var size: Int {
        if uncompressedSize < 0 {
            if isCompressed {
                let uncompressedData = try? data.gunzipped() 
                uncompressedSize = uncompressedData?.count ?? 0
            } else {
                uncompressedSize = data.count
            }
        }
        return uncompressedSize
    }
    
    public init(name: String, isCompressed: Bool, data: ByteArray) {
        self.name = name
        self.isCompressed = isCompressed
        self.data = data.clone()
        self.uncompressedSize = -1
    }
    deinit {
        erase()
    }
    
    public func clone() -> Attachment {
        return Attachment(
            name: self.name,
            isCompressed: self.isCompressed,
            data: self.data
        )
    }
    
    public func erase() {
        name.erase()
        isCompressed = false
        data.erase()
        uncompressedSize = -1
    }
}
