import 'package:json_annotation/json_annotation.dart';

part 'did_event.g.dart';

@JsonSerializable()
class DIDEvent {
  final String eventId;
  final String userId;
  final String? publicKey;
  @JsonKey(name: 'eventType')
  final String? type;
  final DateTime timestamp;
  final String? payload;
  final int kafkaOffset;
  final String payloadHash;
  final String docType;

  DIDEvent({
    required this.eventId,
    required this.userId,
    this.publicKey,
    this.type,
    required this.timestamp,
    this.payload,
    required this.kafkaOffset,
    required this.payloadHash,
    required this.docType,
  });

  factory DIDEvent.fromJson(Map<String, dynamic> json) =>
      _$DIDEventFromJson(json);

  Map<String, dynamic> toJson() => _$DIDEventToJson(this);
}
