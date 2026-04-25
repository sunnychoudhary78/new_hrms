import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class CryptoHelper {
  static const String SECRET_KEY = 'your_api_secret';

  static Map<String, dynamic>? encryptPayload(dynamic data) {
    if (data == null) return data;

    try {
      final jsonStr = jsonEncode(data);

      final salt = _randomBytes(8);

      final keyIv = _evpKDF(utf8.encode(SECRET_KEY), salt);

      final key = Uint8List.fromList(keyIv.sublist(0, 32));
      final iv = Uint8List.fromList(keyIv.sublist(32, 48));

      final cipher = PaddedBlockCipherImpl(
        PKCS7Padding(),
        CBCBlockCipher(AESEngine()),
      );

      cipher.init(
        true,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), iv),
          null,
        ),
      );

      final encryptedBytes = cipher.process(
        Uint8List.fromList(utf8.encode(jsonStr)),
      );

      final result = Uint8List.fromList(
        utf8.encode("Salted__") + salt + encryptedBytes,
      );

      return {"payload": base64Encode(result)};
    } catch (e) {
      print("Encryption failed: $e");
      return data;
    }
  }

  static dynamic decryptPayload(dynamic response) {
    if (response == null || response['payload'] == null) {
      return response;
    }

    try {
      final encrypted = base64Decode(response['payload']);

      final salt = encrypted.sublist(8, 16);
      final ciphertext = encrypted.sublist(16);

      final keyIv = _evpKDF(utf8.encode(SECRET_KEY), salt);

      final key = Uint8List.fromList(keyIv.sublist(0, 32));
      final iv = Uint8List.fromList(keyIv.sublist(32, 48));

      final cipher = PaddedBlockCipherImpl(
        PKCS7Padding(),
        CBCBlockCipher(AESEngine()),
      );

      cipher.init(
        false,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), iv),
          null,
        ),
      );

      final decryptedBytes = cipher.process(ciphertext);

      return jsonDecode(utf8.decode(decryptedBytes));
    } catch (e) {
      print("Decryption failed: $e");
      return response;
    }
  }

  static List<int> _evpKDF(List<int> password, List<int> salt) {
    List<int> derived = [];
    List<int> block = [];

    while (derived.length < 48) {
      final data = Uint8List.fromList(block + password + salt);
      block = md5.convert(data).bytes;
      derived += block;
    }

    return derived;
  }

  static List<int> _randomBytes(int length) {
    final rand = Random.secure();
    return List.generate(length, (_) => rand.nextInt(256));
  }
}
