import 'package:logger/logger.dart';

class LoggerService {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: Level.warning,
  );

  static void logInfo(String message) {
    _logger.i(message);
  }

  static void logWarning(String message) {
    _logger.w(message);
  }

  static void logError(String message,
      [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  static void logException(Exception exception,
      {String? context, StackTrace? stackTrace}) {
    _logger.e('Exception: ${exception.toString()}',
        error: exception, stackTrace: stackTrace ?? StackTrace.current);
  }

  static void logDebug(String message) {
    _logger.d(message);
  }

  static void logVerbose(String message) {
    _logger.v(message);
  }

  static void logErrorWithContext(
      String className, String methodName, String message,
      [dynamic error, StackTrace? stackTrace]) {
    _logger.e('[$className.$methodName] $message',
        error: error, stackTrace: stackTrace);
  }
}
