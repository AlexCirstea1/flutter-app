// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'read_receipt_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReadReceiptNotification _$ReadReceiptNotificationFromJson(
        Map<String, dynamic> json) =>
    ReadReceiptNotification(
      readerId: json['readerId'] as String,
      messageIds: (json['messageIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      readTimestamp: json['readTimestamp'] as String,
    );

Map<String, dynamic> _$ReadReceiptNotificationToJson(
        ReadReceiptNotification instance) =>
    <String, dynamic>{
      'readerId': instance.readerId,
      'messageIds': instance.messageIds,
      'readTimestamp': instance.readTimestamp,
    };
