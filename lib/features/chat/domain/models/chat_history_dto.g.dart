// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_history_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatHistoryDTO _$ChatHistoryDTOFromJson(Map<String, dynamic> json) =>
    ChatHistoryDTO(
      participant: json['participant'] as String,
      participantUsername: json['participantUsername'] as String,
      messages: (json['messages'] as List<dynamic>)
          .map((e) => MessageDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
      unreadCount: (json['unreadCount'] as num).toInt(),
    );

Map<String, dynamic> _$ChatHistoryDTOToJson(ChatHistoryDTO instance) =>
    <String, dynamic>{
      'participant': instance.participant,
      'participantUsername': instance.participantUsername,
      'messages': instance.messages.map((e) => e.toJson()).toList(),
      'unreadCount': instance.unreadCount,
    };
