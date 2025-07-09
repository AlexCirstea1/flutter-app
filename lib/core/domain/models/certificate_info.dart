import 'distinguished_name.dart';

class CertificateInfo {
  final DistinguishedName distinguishedName;
  final int keySize;
  final DateTime validUntil;
  final DateTime issuedOn;

  CertificateInfo({
    required this.distinguishedName,
    required this.keySize,
    required this.validUntil,
    required this.issuedOn,
  });

  int get daysRemaining {
    final now = DateTime.now();
    return validUntil.difference(now).inDays;
  }

  bool get isExpired => daysRemaining < 0;

  Map<String, dynamic> toJson() {
    return {
      'distinguishedName': distinguishedName.toJson(),
      'keySize': keySize,
      'isExpired': isExpired,
      'daysRemaining': daysRemaining,
    };
  }
}
