/// Represents a Distinguished Name (DN) for X.509 certificates.
class DistinguishedName {
  /// Common Name (CN) - typically the name of the entity or user
  final String commonName;

  /// Organization (O)
  final String? organization;

  /// Organizational Unit (OU)
  final String? organizationalUnit;

  /// Locality/City (L)
  final String? locality;

  /// State/Province (ST)
  final String? state;

  /// Country (C) - typically a two-letter country code
  final String? country;

  /// Email Address
  final String? emailAddress;

  /// Creates a Distinguished Name with standard X.509 attributes
  const DistinguishedName({
    required this.commonName,
    this.organization,
    this.organizationalUnit,
    this.locality,
    this.state,
    this.country,
    this.emailAddress,
  });

  /// Creates a basic Distinguished Name with just the Common Name set to the username
  factory DistinguishedName.fromUsername(String username) {
    return DistinguishedName(commonName: username);
  }

  /// Creates a Distinguished Name from a standard Map representation
  factory DistinguishedName.fromMap(Map<String, String> map) {
    return DistinguishedName(
      commonName: map['CN'] ?? 'User',
      organization: map['O'],
      organizationalUnit: map['OU'],
      locality: map['L'],
      state: map['ST'],
      country: map['C'],
      emailAddress: map['EMAIL'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'commonName': commonName,
      'organization': organization,
      'organizationalUnit': organizationalUnit,
      'state': state,
    };
  }

  /// Converts this Distinguished Name to a Map representation required by X509 utilities
  Map<String, String> toMap() {
    final map = <String, String>{'CN': commonName};

    if (organization != null) map['O'] = organization!;
    if (organizationalUnit != null) map['OU'] = organizationalUnit!;
    if (locality != null) map['L'] = locality!;
    if (state != null) map['ST'] = state!;
    if (country != null) map['C'] = country!;
    if (emailAddress != null) map['EMAIL'] = emailAddress!;

    return map;
  }

}
