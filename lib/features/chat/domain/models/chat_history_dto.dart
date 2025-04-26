import 'package:json_annotation/json_annotation.dart';

import 'message_dto.dart';

part 'chat_history_dto.g.dart';

@JsonSerializable(explicitToJson: true)
class ChatHistoryDTO {
  final String participant;
  final String participantUsername;
  final List<MessageDTO> messages;
  int unreadCount;

  ChatHistoryDTO({
    required this.participant,
    required this.participantUsername,
    required this.messages,
    required this.unreadCount,
  });

  factory ChatHistoryDTO.fromJson(Map<String, dynamic> json) =>
      _$ChatHistoryDTOFromJson(json);
  Map<String, dynamic> toJson() => _$ChatHistoryDTOToJson(this);
}
