import Foundation

public protocol Cloneable {
    associatedtype T
    func clone() -> T
}

public extension Array where Element == UInt8 {
    public func clone() -> Array<UInt8> {
        return self.withUnsafeBufferPointer {
            [UInt8].init($0)
        }
    }
}
