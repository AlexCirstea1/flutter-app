import 'dart:convert';

class EventHistory {
  final String txId;
  final DateTime timestamp;
  final bool isDelete;
  final String value;

  EventHistory({
    required this.txId,
    required this.timestamp,
    required this.isDelete,
    required this.value,
  });

  factory EventHistory.fromJson(Map<String, dynamic> json) {
    // 1) pull out the raw field (note: your API key is "delete", not "isDelete")
    final rawTs = json['timestamp'] as String?;
    final deleteFlag = (json['delete'] as bool?) ?? false;

    DateTime parsedTs;

    if (rawTs != null && rawTs.startsWith('{')) {
      // 2) it's actually the JSON‐inside‐a‐string case, so decode it
      final Map<String, dynamic> obj = jsonDecode(rawTs);
      final seconds = (obj['seconds'] as num).toInt();
      final nanos = (obj['nanos'] as num).toInt();
      // build a UTC DateTime
      parsedTs = DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + (nanos / 1e6).round(),
        isUtc: true,
      ).toLocal();
    } else if (rawTs != null) {
      // 3) otherwise assume it's an ISO 8601 string
      parsedTs = DateTime.parse(rawTs);
    } else {
      // 4) fallback
      parsedTs = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return EventHistory(
      txId: json['txId'] as String,
      timestamp: parsedTs,
      isDelete: deleteFlag,
      value: json['value'] as String? ?? '',
    );
  }
}
