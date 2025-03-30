import 'dart:async';

import 'package:basic_utils/basic_utils.dart';

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
    // Convert the PEM certificate to a structured X509CertificateData object.
    final data = X509Utils.x509CertificateFromPem(pemCertificate);

    // Create a map for the Distinguished Name fields using standard OIDs.
    final Map<String, String> dnMap = {};

    // The subject is provided as a map with OID keys.
    // Common Name (OID 2.5.4.3)
    if (data.subject.containsKey("2.5.4.3")) {
      dnMap["CN"] = data.subject["2.5.4.3"]!;
    }
    // Organization (OID 2.5.4.10)
    if (data.subject.containsKey("2.5.4.10")) {
      dnMap["O"] = data.subject["2.5.4.10"]!;
    }
    // Organizational Unit (OID 2.5.4.11)
    if (data.subject.containsKey("2.5.4.11")) {
      dnMap["OU"] = data.subject["2.5.4.11"]!;
    }
    // Locality (OID 2.5.4.7)
    if (data.subject.containsKey("2.5.4.7")) {
      dnMap["L"] = data.subject["2.5.4.7"]!;
    }
    // State/Province (OID 2.5.4.8)
    if (data.subject.containsKey("2.5.4.8")) {
      dnMap["ST"] = data.subject["2.5.4.8"]!;
    }
    // Country (OID 2.5.4.6)
    if (data.subject.containsKey("2.5.4.6")) {
      dnMap["C"] = data.subject["2.5.4.6"]!;
    }
    // Email Address (OID 1.2.840.113549.1.9.1)
    if (data.subject.containsKey("1.2.840.113549.1.9.1")) {
      dnMap["EMAIL"] = data.subject["1.2.840.113549.1.9.1"]!;
    }
  
    // Extract the key size from the public key data, if available.
    int keySize = 2048; // default value
    if (data.publicKeyData.length != null) {
      keySize = data.publicKeyData.length!;
    }

    // Extract validity dates if provided; otherwise use current time as placeholders.
    DateTime issuedOn = DateTime.now();
    DateTime validUntil = DateTime.now();
    issuedOn = data.validity.notBefore;
    validUntil = data.validity.notAfter;
  
    return CertificateInfo(
      distinguishedName: DistinguishedName.fromMap(dnMap),
      keySize: keySize,
      issuedOn: issuedOn,
      validUntil: validUntil,
    );
  }

}
