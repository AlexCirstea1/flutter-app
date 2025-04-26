// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessageDTO _$MessageDTOFromJson(Map<String, dynamic> json) => MessageDTO(
      id: json['id'] as String,
      sender: json['sender'] as String,
      recipient: json['recipient'] as String,
      ciphertext: json['ciphertext'] as String,
      iv: json['iv'] as String,
      encryptedKeyForSender: json['encryptedKeyForSender'] as String,
      encryptedKeyForRecipient: json['encryptedKeyForRecipient'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      senderKeyVersion: json['senderKeyVersion'] as String,
      recipientKeyVersion: json['recipientKeyVersion'] as String,
      isRead: json['isRead'] as bool? ?? false,
      readTimestamp: json['readTimestamp'] == null
          ? null
          : DateTime.parse(json['readTimestamp'] as String),
      isDelivered: json['isDelivered'] as bool? ?? false,
      deliveredTimestamp: json['deliveredTimestamp'] == null
          ? null
          : DateTime.parse(json['deliveredTimestamp'] as String),
      oneTime: json['oneTime'] as bool? ?? false,
      clientTempId: json['clientTempId'] as String?,
      type: json['type'] as String?,
    );

Map<String, dynamic> _$MessageDTOToJson(MessageDTO instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sender': instance.sender,
      'recipient': instance.recipient,
      'ciphertext': instance.ciphertext,
      'iv': instance.iv,
      'encryptedKeyForSender': instance.encryptedKeyForSender,
      'encryptedKeyForRecipient': instance.encryptedKeyForRecipient,
      'senderKeyVersion': instance.senderKeyVersion,
      'recipientKeyVersion': instance.recipientKeyVersion,
      'timestamp': instance.timestamp.toIso8601String(),
      'isRead': instance.isRead,
      'readTimestamp': instance.readTimestamp?.toIso8601String(),
      'isDelivered': instance.isDelivered,
      'deliveredTimestamp': instance.deliveredTimestamp?.toIso8601String(),
      'oneTime': instance.oneTime,
      'clientTempId': instance.clientTempId,
      'type': instance.type,
    };
