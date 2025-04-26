class UserProfile {
  final String id;
  final String username;
  final String email;
  final bool hasPin;
  final bool blockchainConsent;
  final Map<String, dynamic> additionalData; // Store any extra fields

  UserProfile({
    required this.id,
    required this.username,
    this.email = '',
    this.hasPin = false,
    this.blockchainConsent = false,
    this.additionalData = const {},
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Extract known fields
    final id = json['id'] as String? ?? '';
    final username = json['username'] as String? ?? '';

    // Create a copy without known fields for additionalData
    final Map<String, dynamic> additionalData = Map.from(json);
    additionalData.removeWhere((key, _) => [
          'id',
          'username',
          'email',
          'hasPin',
          'blockchainConsent'
        ].contains(key));

    return UserProfile(
      id: id,
      username: username,
      email: json['email'] as String? ?? '',
      hasPin: json['hasPin'] as bool? ?? false,
      blockchainConsent: json['blockchainConsent'] as bool? ?? false,
      additionalData: additionalData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'hasPin': hasPin,
      'blockchainConsent': blockchainConsent,
      ...additionalData,
    };
  }
}
