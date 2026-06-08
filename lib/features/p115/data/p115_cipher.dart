import 'dart:convert';
import 'dart:typed_data';

class P115Cipher {
  P115Cipher._();

  static const _gKeyL = <int>[
    0x78,
    0x06,
    0xad,
    0x4c,
    0x33,
    0x86,
    0x5d,
    0x18,
    0x4c,
    0x01,
    0x3f,
    0x46,
  ];
  static const _rsaKey = <int>[0x8d, 0xa5, 0xa5, 0x8d];
  static const _rsaRandKey = <int>[
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ];
  static const _gKts = <int>[
    0xf0,
    0xe5,
    0x69,
    0xae,
    0xbf,
    0xdc,
    0xbf,
    0x8a,
    0x1a,
    0x45,
    0xe8,
    0xbe,
    0x7d,
    0xa6,
    0x73,
    0xb8,
    0xde,
    0x8f,
    0xe7,
    0xc4,
    0x45,
    0xda,
    0x86,
    0xc4,
    0x9b,
    0x64,
    0x8b,
    0x14,
    0x6a,
    0xb4,
    0xf1,
    0xaa,
    0x38,
    0x01,
    0x35,
    0x9e,
    0x26,
    0x69,
    0x2c,
    0x86,
    0x00,
    0x6b,
    0x4f,
    0xa5,
    0x36,
    0x34,
    0x62,
    0xa6,
    0x2a,
    0x96,
    0x68,
    0x18,
    0xf2,
    0x4a,
    0xfd,
    0xbd,
    0x6b,
    0x97,
    0x8f,
    0x4d,
    0x8f,
    0x89,
    0x13,
    0xb7,
    0x6c,
    0x8e,
    0x93,
    0xed,
    0x0e,
    0x0d,
    0x48,
    0x3e,
    0xd7,
    0x2f,
    0x88,
    0xd8,
    0xfe,
    0xfe,
    0x7e,
    0x86,
    0x50,
    0x95,
    0x4f,
    0xd1,
    0xeb,
    0x83,
    0x26,
    0x34,
    0xdb,
    0x66,
    0x7b,
    0x9c,
    0x7e,
    0x9d,
    0x7a,
    0x81,
    0x32,
    0xea,
    0xb6,
    0x33,
    0xde,
    0x3a,
    0xa9,
    0x59,
    0x34,
    0x66,
    0x3b,
    0xaa,
    0xba,
    0x81,
    0x60,
    0x48,
    0xb9,
    0xd5,
    0x81,
    0x9c,
    0xf8,
    0x6c,
    0x84,
    0x77,
    0xff,
    0x54,
    0x78,
    0x26,
    0x5f,
    0xbe,
    0xe8,
    0x1e,
    0x36,
    0x9f,
    0x34,
    0x80,
    0x5c,
    0x45,
    0x2c,
    0x9b,
    0x76,
    0xd5,
    0x1b,
    0x8f,
    0xcc,
    0xc3,
    0xb8,
    0xf5,
  ];

  static final BigInt _modulus = BigInt.parse(
    '8686980c0f5a24c4b9d43020cd2c22703ff3f450756529058b1cf88f09b8602136477198a6e2683149659bd122c33592fdb5ad47944ad1ea4d36c6b172aad6338c3bb6ac6227502d010993ac967d1aef00f0c8e038de2e4d3bc2ec368af2e9f10a6f1eda4f7262f136420c07c331b871bf139f74f3010e3c4fe57df3afb71683',
    radix: 16,
  );
  static final BigInt _exponent = BigInt.from(0x10001);

  static String encryptJson(Map<String, dynamic> payload) {
    return encrypt(utf8.encode(jsonEncode(payload)));
  }

  static String encrypt(List<int> data) {
    final tmp = _xor(data, _rsaKey).reversed.toList();
    final xorData = <int>[..._rsaRandKey, ..._xor(tmp, _gKeyL)];
    return base64Encode(_rsaEncryptWithPubkey(xorData));
  }

  static String decryptToString(String cipherData) {
    final data = _rsaDecryptWithPubkey(base64Decode(cipherData));
    final randKey = data.sublist(0, 16);
    final keyL = _rsaGenKey(randKey, 12);
    final tmp = _xor(data.sublist(16), keyL).reversed.toList();
    return utf8.decode(_xor(tmp, _rsaKey));
  }

  static List<int> _rsaGenKey(List<int> randKey, int skLen) {
    final xorKey = List<int>.filled(skLen, 0);
    var length = skLen * (skLen - 1);
    var index = 0;
    for (var i = 0; i < skLen; i++) {
      final x = (randKey[i] + _gKts[index]) & 0xff;
      xorKey[i] = _gKts[length] ^ x;
      length -= skLen;
      index += skLen;
    }
    return xorKey;
  }

  static List<int> _xor(List<int> src, List<int> key) {
    final secret = <int>[];
    var i = src.length & 3;
    if (i > 0) {
      secret.addAll(_bytesXor(src.sublist(0, i), key.sublist(0, i), i));
    }
    while (i < src.length) {
      final end = i + key.length > src.length ? src.length : i + key.length;
      final size = end - i;
      secret.addAll(_bytesXor(src.sublist(i, end), key.sublist(0, size), size));
      i = end;
    }
    return secret;
  }

  static List<int> _bytesXor(List<int> v1, List<int> v2, int size) {
    final n = _fromBytes(v1) ^ _fromBytes(v2);
    return _toBytes(n, size);
  }

  static List<int> _rsaEncryptWithPubkey(List<int> data) {
    final cipher = <int>[];
    for (var start = 0; start < data.length; start += 117) {
      final end = start + 117 > data.length ? data.length : start + 117;
      final padded = _padPkcs1(data.sublist(start, end));
      final encrypted = padded.modPow(_exponent, _modulus);
      cipher.addAll(_toBytes(encrypted, 128));
    }
    return cipher;
  }

  static List<int> _rsaDecryptWithPubkey(List<int> cipherData) {
    final data = <int>[];
    for (var start = 0; start < cipherData.length; start += 128) {
      final end = start + 128 > cipherData.length
          ? cipherData.length
          : start + 128;
      final p = _fromBytes(
        cipherData.sublist(start, end),
      ).modPow(_exponent, _modulus);
      final bytes = _toMinimalBytes(p);
      data.addAll(bytes.sublist(bytes.indexOf(0) + 1));
    }
    return data;
  }

  static BigInt _padPkcs1(List<int> message) {
    final data = <int>[0, ...List<int>.filled(126 - message.length, 2), 0];
    data.addAll(message);
    return _fromBytes(data);
  }

  static BigInt _fromBytes(List<int> bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  static List<int> _toBytes(BigInt value, int size) {
    final out = Uint8List(size);
    var n = value;
    for (var i = size - 1; i >= 0; i--) {
      out[i] = (n & BigInt.from(0xff)).toInt();
      n >>= 8;
    }
    return out;
  }

  static List<int> _toMinimalBytes(BigInt value) {
    final size = (value.bitLength + 7) >> 3;
    return _toBytes(value, size);
  }
}
