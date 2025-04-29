// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'did_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DIDEvent _$DIDEventFromJson(Map<String, dynamic> json) => DIDEvent(
      eventId: json['eventId'] as String,
      userId: json['userId'] as String,
      publicKey: json['publicKey'] as String?,
      type: json['eventType'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      payload: json['payload'] as String?,
      kafkaOffset: (json['kafkaOffset'] as num).toInt(),
      payloadHash: json['payloadHash'] as String,
      docType: json['docType'] as String,
    );

Map<String, dynamic> _$DIDEventToJson(DIDEvent instance) => <String, dynamic>{
      'eventId': instance.eventId,
      'userId': instance.userId,
      'publicKey': instance.publicKey,
      'eventType': instance.type,
      'timestamp': instance.timestamp.toIso8601String(),
      'payload': instance.payload,
      'kafkaOffset': instance.kafkaOffset,
      'payloadHash': instance.payloadHash,
      'docType': instance.docType,
    };
