import 'package:json_annotation/json_annotation.dart';
part 'chat_request_dto.g.dart';

@JsonSerializable()
class ChatRequestDTO {
  final String id;
  final String requester; // The user who initiated the request
  final String recipient;
  final String ciphertext;
  final String iv;
  final String encryptedKeyForSender;
  final String encryptedKeyForRecipient;
  final String senderKeyVersion;
  final String recipientKeyVersion;
  final DateTime timestamp;
  final String status; // For example "PENDING", "ACCEPTED", "REJECTED"

  ChatRequestDTO({
    required this.id,
    required this.requester,
    required this.recipient,
    required this.ciphertext,
    required this.iv,
    required this.encryptedKeyForSender,
    required this.encryptedKeyForRecipient,
    required this.senderKeyVersion,
    required this.recipientKeyVersion,
    required this.timestamp,
    required this.status,
  });

  factory ChatRequestDTO.fromJson(Map<String, dynamic> json) =>
      _$ChatRequestDTOFromJson(json);
  Map<String, dynamic> toJson() => _$ChatRequestDTOToJson(this);
}
