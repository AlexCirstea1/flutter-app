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
}
