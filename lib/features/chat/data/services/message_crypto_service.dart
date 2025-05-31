import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/api.dart';
import 'package:pointycastle/random/fortuna_random.dart';

import '../../../../core/domain/models/public_key_data.dart';
import '../../../../core/utils/crypto_helper.dart';

class MessageCryptoService {
  /// Encrypts a message using ephemeral key encryption
  Future<Map<String, String>> encryptMessage({
    required String content,
    required PublicKeyData senderKey,
    required PublicKeyData recipientKey,
  }) async {
    final aesKeyBytes = _makeFortunaRandom().nextBytes(32);
    final aesKey = encrypt.Key(aesKeyBytes);
    final ivBytes = _makeFortunaRandom().nextBytes(16);
    final ivObj = encrypt.IV(ivBytes);

    final encrypter =
        encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));

    final cipher = encrypter.encrypt(content, iv: ivObj);
    final ciphertextB64 = base64.encode(cipher.bytes);
    final ivB64 = base64.encode(ivBytes);
    final aesKeyB64 = base64.encode(aesKeyBytes);

    final encForSender =
        CryptoHelper.rsaEncrypt(aesKeyB64, senderKey.publicKey);
    final encForRecipient =
        CryptoHelper.rsaEncrypt(aesKeyB64, recipientKey.publicKey);

    return {
      'ciphertext': ciphertextB64,
      'iv': ivB64,
      'encryptedKeyForSender': encForSender,
      'encryptedKeyForRecipient': encForRecipient,
      'senderKeyVersion': senderKey.keyVersion,
      'recipientKeyVersion': recipientKey.keyVersion,
    };
  }

  /// Decrypts a message using the provided private key
  String? decryptMessage({
    required String ciphertext,
    required String iv,
    required String encryptedKey,
    required String privateKey,
  }) {
    try {
      final aesKeyB64 = CryptoHelper.rsaDecrypt(encryptedKey, privateKey);
      final aesKeyBytes = base64.decode(aesKeyB64);
      final ivBytes = base64.decode(iv);
      final cipherBytes = base64.decode(ciphertext);

      final keyObj = encrypt.Key(aesKeyBytes);
      final ivObj = encrypt.IV(ivBytes);
      final encrypter =
          encrypt.Encrypter(encrypt.AES(keyObj, mode: encrypt.AESMode.cbc));

      return encrypter.decrypt(encrypt.Encrypted(cipherBytes), iv: ivObj);
    } catch (e) {
      return null;
    }
  }

  SecureRandom _makeFortunaRandom() {
    final fr = FortunaRandom();
    final rng = Random.secure();
    final seeds = List<int>.generate(32, (_) => rng.nextInt(256));
    fr.seed(KeyParameter(Uint8List.fromList(seeds)));
    return fr;
  }

  /// Same idea as encryptMessage but returns raw-byte cipher.
  Future<EncryptedDataBundle> encryptData({
    required Uint8List plaintextBytes,
    required PublicKeyData senderKey,
    required PublicKeyData recipientKey,
  }) async {
    final aesKeyBytes = _makeFortunaRandom().nextBytes(32);
    final aesKey = encrypt.Key(aesKeyBytes);
    final ivBytes = _makeFortunaRandom().nextBytes(16);
    final ivObj = encrypt.IV(ivBytes);

    final encrypter =
        encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));

    final cipherBytes = encrypter.encryptBytes(plaintextBytes, iv: ivObj).bytes;
    final aesKeyB64 = base64.encode(aesKeyBytes);

    return EncryptedDataBundle(
      cipherBytes: cipherBytes,
      iv: base64.encode(ivBytes),
      keySender: CryptoHelper.rsaEncrypt(aesKeyB64, senderKey.publicKey),
      keyRecipient: CryptoHelper.rsaEncrypt(aesKeyB64, recipientKey.publicKey),
      senderVer: senderKey.keyVersion,
      recipientVer: recipientKey.keyVersion,
    );
  }

  /// Decrypts file data using the provided private key and encrypted AES key
  Future<Uint8List> decryptData({
    required List<int> cipherBytes,
    required String iv,
    required String encryptedKey,
    required String privateKey,
  }) async {
    try {
      // Decrypt the AES key using RSA private key
      final aesKeyB64 = CryptoHelper.rsaDecrypt(encryptedKey, privateKey);
      final aesKeyBytes = base64.decode(aesKeyB64);
      final ivBytes = base64.decode(iv);

      // Create AES cipher for decryption
      final keyObj = encrypt.Key(Uint8List.fromList(aesKeyBytes));
      final ivObj = encrypt.IV(Uint8List.fromList(ivBytes));
      final encrypter =
      encrypt.Encrypter(encrypt.AES(keyObj, mode: encrypt.AESMode.cbc));

      // Decrypt the file content
      final decryptedBytes = encrypter.decryptBytes(
          encrypt.Encrypted(Uint8List.fromList(cipherBytes)),
          iv: ivObj);

      return Uint8List.fromList(decryptedBytes);
    } catch (e) {
      throw Exception('Failed to decrypt file data: $e');
    }
  }
}

class EncryptedDataBundle {
  final List<int> cipherBytes;
  final String iv, keySender, keyRecipient, senderVer, recipientVer;
  EncryptedDataBundle({
    required this.cipherBytes,
    required this.iv,
    required this.keySender,
    required this.keyRecipient,
    required this.senderVer,
    required this.recipientVer,
  });
}
