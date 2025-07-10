import 'package:json_annotation/json_annotation.dart';

import 'file_info.dart';

part 'message_dto.g.dart';

@JsonSerializable()
class MessageDTO {
  final String id;
  final String sender;
  final String recipient;

  /// The AES-encrypted ciphertext, base64-encoded.
  final String ciphertext;

  /// The AES IV used for encryption, base64-encoded.
  final String iv;

  /// The RSA-encrypted AES key, base64-encoded, for the **sender** to decrypt.
  final String encryptedKeyForSender;

  /// The RSA-encrypted AES key, base64-encoded, for the **recipient** to decrypt.
  final String encryptedKeyForRecipient;

  /// The key version used for sender-side encryption (e.g., "v1", "v2").
  final String senderKeyVersion;

  /// The key version used for recipient-side encryption.
  final String recipientKeyVersion;

  /// Timestamp of the message.
  final DateTime timestamp;

  bool isRead;
  DateTime? readTimestamp;

  bool isDelivered;
  DateTime? deliveredTimestamp;

  /// Whether this is a one-time/ephemeral message that should be deleted after reading
  bool oneTime;

  /// The temporary client-side ID (for matching ephemeral messages).
  String? clientTempId;

  /// The type of message, e.g. "SENT_MESSAGE" or "INCOMING_MESSAGE".
  String? type;

  /// Optionally, you can keep a decrypted plaintext in memory;
  /// do NOT annotate or store it in toJson / fromJson so it won't persist.
  @JsonKey(ignore: true)
  String? plaintext;

  /// File information if this is a file message
  FileInfo? file;

  MessageDTO({
    required this.id,
    required this.sender,
    required this.recipient,
    required this.ciphertext,
    required this.iv,
    required this.encryptedKeyForSender,
    required this.encryptedKeyForRecipient,
    required this.timestamp,
    required this.senderKeyVersion,
    required this.recipientKeyVersion,
    this.file,
    this.isRead = false,
    this.readTimestamp,
    this.isDelivered = false,
    this.deliveredTimestamp,
    this.oneTime = false,
    this.clientTempId,
    this.type,
    this.plaintext, // Not serialized
  });

  /// JSON factory/fromJson
  factory MessageDTO.fromJson(Map<String, dynamic> json) =>
      _$MessageDTOFromJson(json);

  /// JSON to map
  Map<String, dynamic> toJson() => _$MessageDTOToJson(this);
}
