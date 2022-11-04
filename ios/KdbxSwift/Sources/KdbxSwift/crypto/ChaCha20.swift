import Foundation

public final class ChaCha20: StreamCipher {

    public static let nonceSize = 12 
    private let blockSize = 64
    private var key: ByteArray
    private var iv: ByteArray
    private var counter: UInt32
    private var block: [UInt8]
    private var posInBlock: Int
    
    init(key: ByteArray, iv: ByteArray) {
        precondition(key.count == 32, "ChaCha20 expects 32-byte key")
        precondition(iv.count == ChaCha20.nonceSize, "ChaCha20 expects \(ChaCha20.nonceSize)-byte IV")
        
        self.key = key
        self.iv = iv
        block = [UInt8](repeating: 0, count: blockSize)
        counter = 0
        posInBlock = blockSize
    }
    deinit {
        erase()
    }
    
    public func erase() {
        key.erase()
        iv.erase()
        block.erase()
        block = [UInt8](repeating: 0, count: blockSize) 
        counter = 0
    }
    
    
    /// https://tools.ietf.org/html/rfc7539#section-2.3.
    fileprivate func core(block: inout Array<UInt8>, counter: Array<UInt8>, key: Array<UInt8>, iv: Array<UInt8>) {
      precondition(block.count == blockSize)
        precondition(counter.count == 4)
        precondition(iv.count == 12)
      precondition(key.count == 32)

      let j0: UInt32 = 0x61707865
      let j1: UInt32 = 0x3320646e // 0x3620646e sigma/tau
      let j2: UInt32 = 0x79622d32
      let j3: UInt32 = 0x6b206574
      let j4: UInt32 = UInt32(bytes: key[0..<4]).bigEndian
      let j5: UInt32 = UInt32(bytes: key[4..<8]).bigEndian
      let j6: UInt32 = UInt32(bytes: key[8..<12]).bigEndian
      let j7: UInt32 = UInt32(bytes: key[12..<16]).bigEndian
      let j8: UInt32 = UInt32(bytes: key[16..<20]).bigEndian
      let j9: UInt32 = UInt32(bytes: key[20..<24]).bigEndian
      let j10: UInt32 = UInt32(bytes: key[24..<28]).bigEndian
      let j11: UInt32 = UInt32(bytes: key[28..<32]).bigEndian
      let j12: UInt32 = UInt32(bytes: counter[0..<4]).bigEndian
      let j13: UInt32 = UInt32(bytes: iv[0..<4]).bigEndian
      let j14: UInt32 = UInt32(bytes: iv[4..<8]).bigEndian
      let j15: UInt32 = UInt32(bytes: iv[8..<12]).bigEndian

      var (x0, x1, x2, x3, x4, x5, x6, x7) = (j0, j1, j2, j3, j4, j5, j6, j7)
      var (x8, x9, x10, x11, x12, x13, x14, x15) = (j8, j9, j10, j11, j12, j13, j14, j15)

      for _ in 0..<10 { // 20 rounds
        x0 = x0 &+ x4
        x12 ^= x0
        x12 = (x12 << 16) | (x12 >> 16)
        x8 = x8 &+ x12
        x4 ^= x8
        x4 = (x4 << 12) | (x4 >> 20)
        x0 = x0 &+ x4
        x12 ^= x0
        x12 = (x12 << 8) | (x12 >> 24)
        x8 = x8 &+ x12
        x4 ^= x8
        x4 = (x4 << 7) | (x4 >> 25)
        x1 = x1 &+ x5
        x13 ^= x1
        x13 = (x13 << 16) | (x13 >> 16)
        x9 = x9 &+ x13
        x5 ^= x9
        x5 = (x5 << 12) | (x5 >> 20)
        x1 = x1 &+ x5
        x13 ^= x1
        x13 = (x13 << 8) | (x13 >> 24)
        x9 = x9 &+ x13
        x5 ^= x9
        x5 = (x5 << 7) | (x5 >> 25)
        x2 = x2 &+ x6
        x14 ^= x2
        x14 = (x14 << 16) | (x14 >> 16)
        x10 = x10 &+ x14
        x6 ^= x10
        x6 = (x6 << 12) | (x6 >> 20)
        x2 = x2 &+ x6
        x14 ^= x2
        x14 = (x14 << 8) | (x14 >> 24)
        x10 = x10 &+ x14
        x6 ^= x10
        x6 = (x6 << 7) | (x6 >> 25)
        x3 = x3 &+ x7
        x15 ^= x3
        x15 = (x15 << 16) | (x15 >> 16)
        x11 = x11 &+ x15
        x7 ^= x11
        x7 = (x7 << 12) | (x7 >> 20)
        x3 = x3 &+ x7
        x15 ^= x3
        x15 = (x15 << 8) | (x15 >> 24)
        x11 = x11 &+ x15
        x7 ^= x11
        x7 = (x7 << 7) | (x7 >> 25)
        x0 = x0 &+ x5
        x15 ^= x0
        x15 = (x15 << 16) | (x15 >> 16)
        x10 = x10 &+ x15
        x5 ^= x10
        x5 = (x5 << 12) | (x5 >> 20)
        x0 = x0 &+ x5
        x15 ^= x0
        x15 = (x15 << 8) | (x15 >> 24)
        x10 = x10 &+ x15
        x5 ^= x10
        x5 = (x5 << 7) | (x5 >> 25)
        x1 = x1 &+ x6
        x12 ^= x1
        x12 = (x12 << 16) | (x12 >> 16)
        x11 = x11 &+ x12
        x6 ^= x11
        x6 = (x6 << 12) | (x6 >> 20)
        x1 = x1 &+ x6
        x12 ^= x1
        x12 = (x12 << 8) | (x12 >> 24)
        x11 = x11 &+ x12
        x6 ^= x11
        x6 = (x6 << 7) | (x6 >> 25)
        x2 = x2 &+ x7
        x13 ^= x2
        x13 = (x13 << 16) | (x13 >> 16)
        x8 = x8 &+ x13
        x7 ^= x8
        x7 = (x7 << 12) | (x7 >> 20)
        x2 = x2 &+ x7
        x13 ^= x2
        x13 = (x13 << 8) | (x13 >> 24)
        x8 = x8 &+ x13
        x7 ^= x8
        x7 = (x7 << 7) | (x7 >> 25)
        x3 = x3 &+ x4
        x14 ^= x3
        x14 = (x14 << 16) | (x14 >> 16)
        x9 = x9 &+ x14
        x4 ^= x9
        x4 = (x4 << 12) | (x4 >> 20)
        x3 = x3 &+ x4
        x14 ^= x3
        x14 = (x14 << 8) | (x14 >> 24)
        x9 = x9 &+ x14
        x4 ^= x9
        x4 = (x4 << 7) | (x4 >> 25)
      }

      x0 = x0 &+ j0
      x1 = x1 &+ j1
      x2 = x2 &+ j2
      x3 = x3 &+ j3
      x4 = x4 &+ j4
      x5 = x5 &+ j5
      x6 = x6 &+ j6
      x7 = x7 &+ j7
      x8 = x8 &+ j8
      x9 = x9 &+ j9
      x10 = x10 &+ j10
      x11 = x11 &+ j11
      x12 = x12 &+ j12
      x13 = x13 &+ j13
      x14 = x14 &+ j14
      x15 = x15 &+ j15

      block.replaceSubrange(0..<4, with: x0.bigEndian.bytes())
      block.replaceSubrange(4..<8, with: x1.bigEndian.bytes())
      block.replaceSubrange(8..<12, with: x2.bigEndian.bytes())
      block.replaceSubrange(12..<16, with: x3.bigEndian.bytes())
      block.replaceSubrange(16..<20, with: x4.bigEndian.bytes())
      block.replaceSubrange(20..<24, with: x5.bigEndian.bytes())
      block.replaceSubrange(24..<28, with: x6.bigEndian.bytes())
      block.replaceSubrange(28..<32, with: x7.bigEndian.bytes())
      block.replaceSubrange(32..<36, with: x8.bigEndian.bytes())
      block.replaceSubrange(36..<40, with: x9.bigEndian.bytes())
      block.replaceSubrange(40..<44, with: x10.bigEndian.bytes())
      block.replaceSubrange(44..<48, with: x11.bigEndian.bytes())
      block.replaceSubrange(48..<52, with: x12.bigEndian.bytes())
      block.replaceSubrange(52..<56, with: x13.bigEndian.bytes())
      block.replaceSubrange(56..<60, with: x14.bigEndian.bytes())
      block.replaceSubrange(60..<64, with: x15.bigEndian.bytes())
    }
    
    func xor(bytes: inout [UInt8]) throws {

        key.withBytes { keyBytes in
            iv.withBytes { ivBytes in
                for i in 0..<bytes.count {
                    if posInBlock == blockSize {
                        let counterBytes = counter.bytes
                        core(block: &block, counter: counterBytes, key: keyBytes, iv: ivBytes)
                        counter += 1
                        posInBlock = 0
                    }
                    bytes[i] ^= block[posInBlock]
                    posInBlock += 1
                }
            }
        }

    }
    
    func encrypt(data: ByteArray, progress: ProgressEx?=nil) throws -> ByteArray {
        var outBytes = data.bytesCopy()
        try xor(bytes: &outBytes)
        return ByteArray(bytes: outBytes)
    }
    
    func decrypt(data: ByteArray, progress: ProgressEx?=nil) throws -> ByteArray {
        return try encrypt(data: data, progress: progress) 
    }
}

//
//  CryptoSwift
//
//  Copyright (C) 2014-2022 Marcin Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(ucrt)
import ucrt
#endif

protocol _UInt32Type {}
extension UInt32: _UInt32Type {}

/** array of bytes */
extension UInt32 {
  @_specialize(where T == ArraySlice<UInt8>)
  init<T: Collection>(bytes: T) where T.Element == UInt8, T.Index == Int {
    self = UInt32(bytes: bytes, fromIndex: bytes.startIndex)
  }

  @_specialize(where T == ArraySlice<UInt8>)
  @inlinable
  init<T: Collection>(bytes: T, fromIndex index: T.Index) where T.Element == UInt8, T.Index == Int {
    if bytes.isEmpty {
      self = 0
      return
    }

    let count = bytes.count

    let val0 = count > 0 ? UInt32(bytes[index.advanced(by: 0)]) << 24 : 0
    let val1 = count > 1 ? UInt32(bytes[index.advanced(by: 1)]) << 16 : 0
    let val2 = count > 2 ? UInt32(bytes[index.advanced(by: 2)]) << 8 : 0
    let val3 = count > 3 ? UInt32(bytes[index.advanced(by: 3)]) : 0

    self = val0 | val1 | val2 | val3
  }
}

extension FixedWidthInteger {
  @inlinable
  func bytes(totalBytes: Int = MemoryLayout<Self>.size) -> Array<UInt8> {
    arrayOfBytes(value: self.littleEndian, length: totalBytes)
    // TODO: adjust bytes order
    // var value = self.littleEndian
    // return withUnsafeBytes(of: &value, Array.init).reversed()
  }
}


/// Array of bytes. Caution: don't use directly because generic is slow.
///
/// - parameter value: integer value
/// - parameter length: length of output array. By default size of value type
///
/// - returns: Array of bytes
@_specialize(where T == Int)
@_specialize(where T == UInt)
@_specialize(where T == UInt8)
@_specialize(where T == UInt16)
@_specialize(where T == UInt32)
@_specialize(where T == UInt64)
@inlinable
func arrayOfBytes<T: FixedWidthInteger>(value: T, length totalBytes: Int = MemoryLayout<T>.size) -> Array<UInt8> {
  let valuePointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
  valuePointer.pointee = value

  let bytesPointer = UnsafeMutablePointer<UInt8>(OpaquePointer(valuePointer))
  var bytes = Array<UInt8>(repeating: 0, count: totalBytes)
  for j in 0..<min(MemoryLayout<T>.size, totalBytes) {
    bytes[totalBytes - 1 - j] = (bytesPointer + j).pointee
  }

  valuePointer.deinitialize(count: 1)
  valuePointer.deallocate()

  return bytes
}
