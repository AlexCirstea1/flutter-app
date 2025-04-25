enum ChatRequestStatus {
  PENDING,
  ACCEPTED,
  REJECTED,
  CANCELLED,
  EXPIRED,
  BLOCKED,
}

ChatRequestStatus _statusFromString(String raw) =>
    ChatRequestStatus.values.firstWhere((e) => e.name == raw.toUpperCase(),
        orElse: () => ChatRequestStatus.PENDING);

class ChatRequestDTO {
  final String id;
  final String requester;
  final String recipient;
  final DateTime timestamp;
  final ChatRequestStatus status;

  // encryption fields
  final String ciphertext;
  final String iv;
  final String encryptedKeyForSender;
  final String encryptedKeyForRecipient;
  final String senderKeyVersion;
  final String recipientKeyVersion;

  ChatRequestDTO({
    required this.id,
    required this.requester,
    required this.recipient,
    required this.timestamp,
    required this.status,
    required this.ciphertext,
    required this.iv,
    required this.encryptedKeyForSender,
    required this.encryptedKeyForRecipient,
    required this.senderKeyVersion,
    required this.recipientKeyVersion,
  });

  factory ChatRequestDTO.fromJson(Map<String, dynamic> json) => ChatRequestDTO(
        id: json['id'] ?? '',
        requester: json['requester'] ?? '',
        recipient: json['recipient'] ?? '',
        timestamp: DateTime.parse(
            json['timestamp'] ?? DateTime.now().toIso8601String()),
        status: _statusFromString(json['status'] ?? 'PENDING'),
        ciphertext: json['ciphertext'] ?? '',
        iv: json['iv'] ?? '',
        encryptedKeyForSender: json['encryptedKeyForSender'] ?? '',
        encryptedKeyForRecipient: json['encryptedKeyForRecipient'] ?? '',
        senderKeyVersion: json['senderKeyVersion'] ?? '',
        recipientKeyVersion: json['recipientKeyVersion'] ?? '',
      );
}
