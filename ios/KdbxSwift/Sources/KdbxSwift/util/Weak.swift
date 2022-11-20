import Foundation

public class Weak<T: AnyObject> {
    public weak var value: T?
    public init(_ value: T) {
        self.value = value
    }
    
    public static func wrapped(_ array: [T]) -> [Weak<T>] {
        return array.map { Weak($0) }
    }
    
    public static func unwrapped(_ array: [Weak<T>]) -> [T] {
        var result = [T]()
        array.forEach {
            if let value = $0.value {
                result.append(value)
            }
        }
        return result
    }
}
