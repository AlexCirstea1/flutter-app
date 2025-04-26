import 'package:json_annotation/json_annotation.dart';

part 'read_receipt_notification.g.dart';

@JsonSerializable()
class ReadReceiptNotification {
  final String readerId;
  final List<String> messageIds;
  final String readTimestamp;

  ReadReceiptNotification({
    required this.readerId,
    required this.messageIds,
    required this.readTimestamp,
  });

  factory ReadReceiptNotification.fromJson(Map<String, dynamic> json) =>
      _$ReadReceiptNotificationFromJson(json);
  Map<String, dynamic> toJson() => _$ReadReceiptNotificationToJson(this);
}
