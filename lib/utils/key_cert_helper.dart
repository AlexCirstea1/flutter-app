import 'dart:async';

import 'package:basic_utils/basic_utils.dart';
import 'package:x509/x509.dart';

import '../models/certificate_info.dart';
import '../models/distinguished_name.dart';
import '../services/storage_service.dart';

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
    DistinguishedName? distinguishedName,
    int? keySize,
    int? daysValid,
  }) async {
    final storageService = StorageService();
    final username = await storageService.getUsername();
    final dn = distinguishedName ??
        DistinguishedName(
          commonName: "$username@VaultX-SecureID",
          organization: "VaultX Trust Network",
          organizationalUnit: 'Secure Messaging Division',
          locality: 'Cyberspace',
          state: 'Encrypted',
          country: "RO",
        );
    final rsaKeySize = keySize ?? 2048;
    final validityDays = daysValid ?? 365;

    // 1) Generate RSA key pair
    final pair = generateRSAKeyPair(keySize: rsaKeySize);
    final privateKey = pair.privateKey;
    final publicKey = pair.publicKey;

    // 2) Encode the private key as PEM
    final privateKeyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);

    // 3) Encode the public key directly as PEM
    final publicKeyPem = CryptoUtils.encodeRSAPublicKeyToPem(publicKey);

    // 4) Generate a CSR from the key pair
    final csrPem = X509Utils.generateRsaCsrPem(
      dn.toMap(),
      privateKey,
      publicKey,
      signingAlgorithm: 'SHA-256',
    );

    // 5) Create a self-signed certificate from that CSR
    final certificatePem = X509Utils.generateSelfSignedCertificate(
      privateKey,
      csrPem,
      validityDays,
    );

    // Return values directly without trying to extract the public key from the certificate
    return (privateKeyPem, certificatePem, publicKeyPem);
  }

  /// Parses a PEM certificate into a CertificateInfo object
  static CertificateInfo parseCertificate(String pemCertificate) {
    // Parse the PEM certificate and assume the first object is an X509Certificate
    final cert = parsePem(pemCertificate).first as X509Certificate;

    // Map to hold the distinguished name fields.
    final Map<String, String> dnMap = {};

    // Since Name does not expose a structured getter, fallback to parsing its string output.
    final subject = cert.tbsCertificate.subject;
    if (subject != null) {
      final subjectString = subject.toString();
      // Use regex to extract key=value pairs (e.g. "CN=MyCert")
      final regex = RegExp(r'([A-Za-z]+)\s*=\s*([^,]+)');
      final matches = regex.allMatches(subjectString);
      for (final match in matches) {
        if (match.groupCount >= 2) {
          final key = match.group(1)?.trim();
          final value = match.group(2)?.trim();
          if (key != null && value != null) {
            dnMap[key] = value;
          }
        }
      }
    }

    // Extract validity dates
    final issuedOn = cert.tbsCertificate.validity?.notBefore ?? DateTime.now();
    final validUntil = cert.tbsCertificate.validity?.notAfter ?? DateTime.now();

    // Determine key size by extracting the public key from the SubjectPublicKeyInfo
    int keySize = 2048;
    try {
      final publicKeyInfo = cert.tbsCertificate.subjectPublicKeyInfo;
      if (publicKeyInfo != null) {
        final spk = publicKeyInfo.subjectPublicKey;
        // Cast to RsaPublicKey which exposes the modulus getter
        if (spk is RsaPublicKey) {
          keySize = (spk as RsaPublicKey).modulus.bitLength;
        }
      }
    } catch (_) {
      // Use default key size if extraction fails.
    }

    return CertificateInfo(
      distinguishedName: DistinguishedName.fromMap(dnMap),
      keySize: keySize,
      issuedOn: issuedOn,
      validUntil: validUntil,
    );
  }
}
