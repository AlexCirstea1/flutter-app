import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

enum Flavor {
  LOCAL,
  TEST,
  PRODUCTION,
}

class Environment {
  // Set the flavor here
  static Flavor appFlavor = Flavor.LOCAL; // Change as needed

  // API Base URL
  static String get apiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8081/api'; // Web environment
    } else {
      switch (appFlavor) {
        case Flavor.TEST:
          return 'https://api.testserver.com';
        case Flavor.PRODUCTION:
          return 'https://api.productionserver.com';
        case Flavor.LOCAL:
        default:
          if (Platform.isAndroid) {
            return 'http://10.0.2.2:8081/api'; // Android emulator
          } else {
            return 'http://localhost:8081/api'; // iOS simulator or others
          }
      }
    }
  }

  // WebSocket URL
  static String get webSocketUrl {
    if (kIsWeb) {
      return 'ws://localhost:8081/ws'; // Web environment
    } else {
      switch (appFlavor) {
        case Flavor.TEST:
          return 'wss://ws.test-server.com/ws';
        case Flavor.PRODUCTION:
          return 'wss://ws.production server.com/ws';
        case Flavor.LOCAL:
        default:
          if (Platform.isAndroid) {
            return 'ws://10.0.2.2:8081/ws'; // Android emulator
          } else {
            return 'ws://localhost:8081/ws'; // iOS simulator or others
          }
      }
    }
  }
}
