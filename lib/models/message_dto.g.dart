// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessageDTO _$MessageDTOFromJson(Map<String, dynamic> json) => MessageDTO(
      id: json['id'] as String,
      sender: json['sender'] as String,
      recipient: json['recipient'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      readTimestamp: json['readTimestamp'] == null
          ? null
          : DateTime.parse(json['readTimestamp'] as String),
      isDelivered: json['isDelivered'] as bool? ?? false,
      deliveredTimestamp: json['deliveredTimestamp'] == null
          ? null
          : DateTime.parse(json['deliveredTimestamp'] as String),
    );

Map<String, dynamic> _$MessageDTOToJson(MessageDTO instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sender': instance.sender,
      'recipient': instance.recipient,
      'content': instance.content,
      'timestamp': instance.timestamp.toIso8601String(),
      'isRead': instance.isRead,
      'readTimestamp': instance.readTimestamp?.toIso8601String(),
      'isDelivered': instance.isDelivered,
      'deliveredTimestamp': instance.deliveredTimestamp?.toIso8601String(),
    };
