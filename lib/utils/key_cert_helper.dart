import 'dart:async';
import 'dart:convert';

import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/api.dart'
    show AsymmetricKeyPair, RSAPrivateKey, RSAPublicKey;

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
  /// The [distinguishedName] is a `Map<String,String>` describing
  /// the certificate subject (e.g. `{"CN": "MySelfSigned", "O": "MyOrg"}`).
  ///
  /// [daysValid] is how many days the self-signed cert is valid.
  static Future<
          (String privateKeyPem, String certificatePem, String publicKeyPem)>
      generateSelfSignedCertificate({
    required Map<String, String> distinguishedName,
    int keySize = 2048,
    int daysValid = 365,
  }) async {
    // 1) Generate RSA key pair
    final pair = generateRSAKeyPair(keySize: keySize);
    final privateKey = pair.privateKey;
    final publicKey = pair.publicKey;

    // 2) Encode the private key as PEM
    final privateKeyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);

    // 3) Generate a CSR from the key pair
    final csrPem = X509Utils.generateRsaCsrPem(
      distinguishedName, // e.g. {"CN":"MySelfSigned","O":"MyOrg"}
      privateKey,
      publicKey,
      signingAlgorithm: 'SHA-256',
      // If you want SubjectAltName: e.g. san: ['127.0.0.1', 'localhost']
    );

    // 4) Create a self-signed certificate from that CSR
    final certificatePem = X509Utils.generateSelfSignedCertificate(
      privateKey,
      csrPem,
      daysValid,
      // sans: [...], // optional SANs
    );

    // 5) Extract the RSA public key from the certificate as PEM
    final publicKeyPem = _extractPublicKeyFromCertificate(certificatePem);

    return (privateKeyPem, certificatePem, publicKeyPem);
  }

  /// Extracts the RSA public key from a PEM-encoded X.509 certificate,
  /// returning it as a PEM-encoded public key.
  static String _extractPublicKeyFromCertificate(String certificatePem) {
    // 1) Parse the certificate
    final certData = X509Utils.x509CertificateFromPem(certificatePem);
    final publicKeyData = certData.publicKeyData;
    if (publicKeyData == null || publicKeyData.bytes == null) {
      throw StateError('Certificate does not contain public key data.');
    }

    // 2) Convert the DER bytes to an RSAPublicKey
    //    (basic_utils stores the raw DER in `publicKeyData.bytes` as base64)
    final derBytes = base64Decode(publicKeyData.bytes!);
    final rsaPublicKey = CryptoUtils.rsaPublicKeyFromDERBytes(derBytes);

    // 3) Encode as PEM
    return CryptoUtils.encodeRSAPublicKeyToPem(rsaPublicKey);
  }
}
