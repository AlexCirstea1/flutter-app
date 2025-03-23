import 'dart:async';

import 'package:basic_utils/basic_utils.dart';

/// A helper class to generate an RSA key pair, produce a self-signed certificate,
/// and optionally extract the public key from the cert for usage.
class KeyCertHelper {
  /// Generates an RSA key pair (public + private).
  /// - [keySize] can be 1024, 2048, 4096, etc.
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateRSAKeyPair({
    int keySize = 2048,
  }) {
    // basic_utils has a convenient method to generate RSA keys.
    final pair = CryptoUtils.generateRSAKeyPair(keySize: keySize);

    // The returned object is typed (PublicKey, PrivateKey),
    // but we cast them to RSAPublicKey and RSAPrivateKey for clarity.
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
      pair.publicKey as RSAPublicKey,
      pair.privateKey as RSAPrivateKey,
    );
  }

  /// Generates a self-signed certificate from the newly generated RSA key pair.
  ///
  /// Returns a tuple of `(privateKeyPem, certificatePem, publicKeyPem)`.
  ///
  /// The [dn] is a `Map<String,String>` describing
  /// the certificate subject (e.g. `{"CN": "MySelfSigned", "O": "MyOrg"}`).
  ///
  /// [daysValid] is how many days the self-signed cert is valid.
  static Future<
          (String privateKeyPem, String certificatePem, String publicKeyPem)>
      generateSelfSignedCert({
    required Map<String, String> dn,
    int keySize = 2048,
    int daysValid = 365,
  }) async {
    // 1) Generate RSA key pair
    final pair = generateRSAKeyPair(keySize: keySize);
    final privateKey = pair.privateKey;
    final publicKey = pair.publicKey;

    // 2) Encode the private key as PEM
    final privateKeyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);

    // 3) Encode the public key directly as PEM
    final publicKeyPem = CryptoUtils.encodeRSAPublicKeyToPem(publicKey);

    // 4) Generate a CSR from the key pair
    final csrPem = X509Utils.generateRsaCsrPem(
      dn, // e.g. {"CN":"MySelfSigned","O":"MyOrg"}
      privateKey,
      publicKey,
      signingAlgorithm: 'SHA-256',
    );

    // 5) Create a self-signed certificate from that CSR
    final certificatePem = X509Utils.generateSelfSignedCertificate(
      privateKey,
      csrPem,
      daysValid,
    );

    // Return values directly without trying to extract the public key from the certificate
    return (privateKeyPem, certificatePem, publicKeyPem);
  }
}
