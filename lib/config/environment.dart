import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

enum Flavor {
  LOCAL,
  TEST,
  PRODUCTION,
}

class Environment {
  // Define base host values for each flavor.
  static const String _localHost = 'localhost:8081';
  static const String _testHost = 'api.vaultx.server-alex.cloud';
  static const String _prodHost = 'api.productionserver.com';

  // Set the app flavor here
  static Flavor appFlavor = Flavor.TEST; // Change as needed

  // Returns the base API URL (with /api appended)
  static String get apiBaseUrl {
    if (kIsWeb) {
      return 'http://$_localHost/api'; // Web environment (assumes local for testing)
    } else {
      switch (appFlavor) {
        case Flavor.TEST:
          return 'https://$_testHost/api';
        case Flavor.PRODUCTION:
          return 'https://$_prodHost/api';
        case Flavor.LOCAL:
          // For local testing, use emulator-specific IPs when needed.
          if (Platform.isAndroid) {
            return 'http://10.0.2.2:8081/api'; // Android emulator
          } else {
            return 'http://$_localHost/api'; // iOS simulator or others
          }
      }
    }
  }

  // Returns the WebSocket URL (with /ws appended)
  static String get webSocketUrl {
    if (kIsWeb) {
      return 'ws://$_localHost/ws'; // Web environment
    } else {
      switch (appFlavor) {
        case Flavor.TEST:
          return 'wss://$_testHost/ws'; // Adjust host if needed
        case Flavor.PRODUCTION:
          return 'wss:/$_prodHost/ws'; // Adjust host if needed
        case Flavor.LOCAL:
          if (Platform.isAndroid) {
            return 'ws://10.0.2.2:8081/ws'; // Android emulator
          } else {
            return 'ws://$_localHost/ws'; // iOS simulator or others
          }
      }
    }
  }
}
