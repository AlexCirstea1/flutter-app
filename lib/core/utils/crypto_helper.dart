import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:encrypt/encrypt.dart' show RSAKeyParser;
import 'package:pointycastle/asymmetric/api.dart';

/// A helper class for RSA encryption/decryption using the `encrypt` package.
class CryptoHelper {
  /// Encrypt plaintext with an RSA public key in PEM format
  static String rsaEncrypt(String plaintext, String publicKeyPem) {
    final parser = RSAKeyParser();
    final RSAPublicKey publicKey = parser.parse(publicKeyPem) as RSAPublicKey;

    // Using PKCS#1 v1.5 here; for OAEP, you'd do:
    // RSA( publicKey: publicKey, encoding: RSAEncoding.OAEP )
    final encrypter = encrypt.Encrypter(
      encrypt.RSA(
        publicKey: publicKey,
        encoding: encrypt.RSAEncoding.PKCS1,
      ),
    );

    final encrypted = encrypter.encrypt(plaintext);
    return encrypted.base64;
  }

  /// Decrypt a base64 ciphertext with an RSA private key in PEM format
  static String rsaDecrypt(String base64Cipher, String privateKeyPem) {
    final parser = RSAKeyParser();
    final RSAPrivateKey privateKey =
        parser.parse(privateKeyPem) as RSAPrivateKey;

    final encrypter = encrypt.Encrypter(
      encrypt.RSA(
        privateKey: privateKey,
        encoding: encrypt.RSAEncoding.PKCS1,
      ),
    );

    final decrypted = encrypter.decrypt64(base64Cipher);
    return decrypted;
  }
}
