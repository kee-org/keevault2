import Foundation

public protocol Eraseable {
    func erase()
}

public protocol EraseableStruct {
    mutating func erase()
}

extension Array where Element: EraseableStruct {
    mutating func erase() {
        for i in 0..<count {
            self[i].erase()
        }
        removeAll()
    }
}

extension Array where Element: Eraseable {
    mutating func erase() {
        for i in 0..<count {
            self[i].erase()
        }
        removeAll()
    }
}

public extension Array where Element == UInt8 {
    mutating func erase() {
        // Hypothesis:
        // erasing a native Array messes up Swift somehow. Maybe some compiler optimisations that happen
        // only in Release mode will point all instances of array literals ([], [0], [1], etc.) to the
        // same memory address and the unsafe mutations then screw everything up from that point onwards
        withUnsafeBufferPointer {
            let mutatablePointer = UnsafeMutableRawPointer(mutating: $0.baseAddress!)
            memset_s(mutatablePointer, $0.count, 0, $0.count)
        }
        removeAll()
    }
}

extension Data: EraseableStruct {
    mutating public func erase() {
        resetBytes(in: 0..<count)
        removeAll()
    }
}

extension Dictionary where Key: Eraseable, Value: Eraseable {
    mutating func erase() {
        forEach({ (key, value) in
            key.erase()
            value.erase()
        })
        removeAll()
    }
}
extension Dictionary where Value: Eraseable {
    mutating func erase() {
        forEach({ (key, value) in
            value.erase()
        })
        removeAll()
    }
}
