import 'package:intl/intl.dart';

class DateTimeUtils {
  // Convert UTC timestamps from server to local device time
  static DateTime utcToLocal(DateTime utcDateTime) {
    return utcDateTime.toLocal();
  }

  // Convert local time to UTC for sending to server
  static DateTime localToUtc(DateTime localDateTime) {
    return localDateTime.toUtc();
  }

  // Format a timestamp in the local timezone
  static String formatDateTime(DateTime dateTime, {String format = 'yyyy-MM-dd HH:mm'}) {
    final formatter = DateFormat(format);
    return formatter.format(utcToLocal(dateTime));
  }

  // Get current time in local timezone
  static DateTime nowLocal() {
    return DateTime.now();
  }

  // Get current time in UTC for server operations
  static DateTime nowUtc() {
    return DateTime.now().toUtc();
  }
}

extension DateTimeExtensions on DateTime {
  DateTime toLocalTime() {
    return DateTimeUtils.utcToLocal(this);
  }

  String format({String format = 'yyyy-MM-dd HH:mm'}) {
    return DateTimeUtils.formatDateTime(this, format: format);
  }

  String toApiString() {
    return toUtc().toIso8601String();
  }
}