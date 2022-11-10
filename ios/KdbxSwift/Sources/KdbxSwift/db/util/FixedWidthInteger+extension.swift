import Foundation

public func sizeof<T: FixedWidthInteger>(_ value: T) -> Int {
    return MemoryLayout.size(ofValue: value)
}

extension FixedWidthInteger {
    init?(data: ByteArray?) {
        guard let data = data else { return nil }
        guard data.count == MemoryLayout<Self>.size else { return nil }
        
        self = data.withBytes { bytes in
            return bytes.withUnsafeBytes{ ptr in
                return ptr.load(as: Self.self)
            }
        }
    }
    
    init?(_ value: String?) {
        guard let value = value else {
            return nil
        }
        self.init(value)
    }
    
    var data: ByteArray {
        return ByteArray(bytes: self.bytes)
    }
    
    var bytes: [UInt8] {
        return withUnsafeBytes(of: self) { Array($0) }
    }
    var asHexString: String {
        let size = MemoryLayout<Self>.size
        return String(format: "%0\(size*2)x", arguments: [self as! CVarArg])
    }
    var byteWidth: Int {
        return bitWidth / UInt8.bitWidth
    }
}
