import Foundation
import Security

/// The request/response cipher of 115's `downurl` endpoint: byte shuffling
/// plus textbook RSA under 115's public key. Both directions are the public
/// key operation `x^e mod n`, done here with Security's raw RSA.
enum P115Cipher {
    private static let gKeyL: [UInt8] = [0x78, 0x06, 0xad, 0x4c, 0x33, 0x86, 0x5d, 0x18, 0x4c, 0x01, 0x3f, 0x46]
    private static let rsaKey: [UInt8] = [0x8d, 0xa5, 0xa5, 0x8d]
    private static let gKts: [UInt8] = [
        0xf0, 0xe5, 0x69, 0xae, 0xbf, 0xdc, 0xbf, 0x8a, 0x1a, 0x45, 0xe8, 0xbe, 0x7d, 0xa6, 0x73, 0xb8,
        0xde, 0x8f, 0xe7, 0xc4, 0x45, 0xda, 0x86, 0xc4, 0x9b, 0x64, 0x8b, 0x14, 0x6a, 0xb4, 0xf1, 0xaa,
        0x38, 0x01, 0x35, 0x9e, 0x26, 0x69, 0x2c, 0x86, 0x00, 0x6b, 0x4f, 0xa5, 0x36, 0x34, 0x62, 0xa6,
        0x2a, 0x96, 0x68, 0x18, 0xf2, 0x4a, 0xfd, 0xbd, 0x6b, 0x97, 0x8f, 0x4d, 0x8f, 0x89, 0x13, 0xb7,
        0x6c, 0x8e, 0x93, 0xed, 0x0e, 0x0d, 0x48, 0x3e, 0xd7, 0x2f, 0x88, 0xd8, 0xfe, 0xfe, 0x7e, 0x86,
        0x50, 0x95, 0x4f, 0xd1, 0xeb, 0x83, 0x26, 0x34, 0xdb, 0x66, 0x7b, 0x9c, 0x7e, 0x9d, 0x7a, 0x81,
        0x32, 0xea, 0xb6, 0x33, 0xde, 0x3a, 0xa9, 0x59, 0x34, 0x66, 0x3b, 0xaa, 0xba, 0x81, 0x60, 0x48,
        0xb9, 0xd5, 0x81, 0x9c, 0xf8, 0x6c, 0x84, 0x77, 0xff, 0x54, 0x78, 0x26, 0x5f, 0xbe, 0xe8, 0x1e,
        0x36, 0x9f, 0x34, 0x80, 0x5c, 0x45, 0x2c, 0x9b, 0x76, 0xd5, 0x1b, 0x8f, 0xcc, 0xc3, 0xb8, 0xf5,
    ]
    private static let modulusHex = "8686980c0f5a24c4b9d43020cd2c22703ff3f450756529058b1cf88f09b8602136477198a6e2683149659bd122c33592fdb5ad47944ad1ea4d36c6b172aad6338c3bb6ac6227502d010993ac967d1aef00f0c8e038de2e4d3bc2ec368af2e9f10a6f1eda4f7262f136420c07c331b871bf139f74f3010e3c4fe57df3afb71683"
    private static let blockSize = 128

    static func encrypt(_ json: [String: String]) -> String {
        let payload = [UInt8](try! JSONSerialization.data(withJSONObject: json))
        let shuffled = xor(Array(xor(payload, rsaKey).reversed()), gKeyL)
        let data = [UInt8](repeating: 0, count: 16) + shuffled
        var out = [UInt8]()
        for start in stride(from: 0, to: data.count, by: 117) {
            let chunk = data[start..<min(start + 117, data.count)]
            // PKCS#1-style type 2 block with a fixed 0x02 filler.
            let block = [0] + [UInt8](repeating: 2, count: 126 - chunk.count) + [0] + chunk
            out += publicKeyOperation(block)
        }
        return Data(out).base64EncodedString()
    }

    static func decrypt(_ base64: String) -> String {
        let cipher = [UInt8](Data(base64Encoded: base64)!)
        var data = [UInt8]()
        for start in stride(from: 0, to: cipher.count, by: blockSize) {
            let plain = publicKeyOperation(Array(cipher[start..<min(start + blockSize, cipher.count)]))
            // Drop the padding: leading zeros, then everything through the next zero.
            let minimal = plain.drop { $0 == 0 }
            data += minimal[minimal.firstIndex(of: 0)! + 1..<minimal.endIndex]
        }
        let keyL = genKey(Array(data[0..<16]), length: 12)
        let tmp = Array(xor(Array(data[16...]), keyL).reversed())
        return String(decoding: xor(tmp, rsaKey), as: UTF8.self)
    }

    private static func genKey(_ randKey: [UInt8], length: Int) -> [UInt8] {
        var key = [UInt8](repeating: 0, count: length)
        var tail = length * (length - 1)
        var index = 0
        for i in 0..<length {
            key[i] = gKts[tail] ^ (randKey[i] &+ gKts[index])
            tail -= length
            index += length
        }
        return key
    }

    /// XOR where the first `count % 4` bytes use the key's head, then every
    /// key-sized chunk restarts at the key's first byte.
    private static func xor(_ src: [UInt8], _ key: [UInt8]) -> [UInt8] {
        var out = [UInt8]()
        out.reserveCapacity(src.count)
        let head = src.count & 3
        for i in 0..<head { out.append(src[i] ^ key[i]) }
        var i = head
        while i < src.count {
            let end = min(i + key.count, src.count)
            for j in i..<end { out.append(src[j] ^ key[j - i]) }
            i = end
        }
        return out
    }

    private static func publicKeyOperation(_ block: [UInt8]) -> [UInt8] {
        var error: Unmanaged<CFError>?
        let result = SecKeyCreateEncryptedData(publicKey, .rsaEncryptionRaw, Data(block) as CFData, &error)!
        return [UInt8](result as Data)
    }

    private static var publicKey: SecKey {
        var modulus = [UInt8](repeating: 0, count: modulusHex.count / 2)
        for i in modulus.indices {
            let start = modulusHex.index(modulusHex.startIndex, offsetBy: i * 2)
            modulus[i] = UInt8(modulusHex[start..<modulusHex.index(start, offsetBy: 2)], radix: 16)!
        }
        // DER RSAPublicKey: SEQUENCE { INTEGER n, INTEGER e }.
        func der(_ tag: UInt8, _ content: [UInt8]) -> [UInt8] {
            let length: [UInt8] = content.count < 0x80
                ? [UInt8(content.count)]
                : [0x82, UInt8(content.count >> 8), UInt8(content.count & 0xff)]
            return [tag] + length + content
        }
        let key = der(0x30, der(0x02, [0] + modulus) + der(0x02, [0x01, 0x00, 0x01]))
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 1024,
        ]
        return SecKeyCreateWithData(Data(key) as CFData, attributes as CFDictionary, nil)!
    }
}
