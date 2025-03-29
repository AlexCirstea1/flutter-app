// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_request_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatRequestDTO _$ChatRequestDTOFromJson(Map<String, dynamic> json) =>
    ChatRequestDTO(
      id: json['id'] as String,
      requester: json['requester'] as String,
      recipient: json['recipient'] as String,
      ciphertext: json['ciphertext'] as String,
      iv: json['iv'] as String,
      encryptedKeyForSender: json['encryptedKeyForSender'] as String,
      encryptedKeyForRecipient: json['encryptedKeyForRecipient'] as String,
      senderKeyVersion: json['senderKeyVersion'] as String,
      recipientKeyVersion: json['recipientKeyVersion'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: json['status'] as String,
    );

Map<String, dynamic> _$ChatRequestDTOToJson(ChatRequestDTO instance) =>
    <String, dynamic>{
      'id': instance.id,
      'requester': instance.requester,
      'recipient': instance.recipient,
      'ciphertext': instance.ciphertext,
      'iv': instance.iv,
      'encryptedKeyForSender': instance.encryptedKeyForSender,
      'encryptedKeyForRecipient': instance.encryptedKeyForRecipient,
      'senderKeyVersion': instance.senderKeyVersion,
      'recipientKeyVersion': instance.recipientKeyVersion,
      'timestamp': instance.timestamp.toIso8601String(),
      'status': instance.status,
    };
