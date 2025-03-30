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
  static Flavor appFlavor = Flavor.LOCAL; // Change as needed

  // Returns the base API URL (with /api appended)
  static String get apiBaseUrl {
    if (kIsWeb) {
      // On web, you cannot use dart:io's Platform
      switch (appFlavor) {
        case Flavor.TEST:
          return 'https://$_testHost/api';
        case Flavor.PRODUCTION:
          return 'https://$_prodHost/api';
        case Flavor.LOCAL:
        // For web development, you might use localhost (or a tunneling service)
          return 'http://$_localHost/api';
      }
    } else {
      // On mobile, you can use Platform checks if needed.
      // (For example, on Android emulator use 10.0.2.2, on iOS use localhost)
      // Note: If you need to import 'dart:io', make sure you conditionally import it.
      // For simplicity, here’s a sample using a simple check (you might need to refine this):
      // import 'dart:io' show Platform;  <-- This import must be conditionally loaded for non-web platforms.
      // if (Platform.isAndroid) { ... } else { ... }
      // For our example, we assume mobile uses the same endpoints as web.
      switch (appFlavor) {
        case Flavor.TEST:
          return 'https://$_testHost/api';
        case Flavor.PRODUCTION:
          return 'https://$_prodHost/api';
        case Flavor.LOCAL:
        // On mobile, if you’re testing locally, adjust accordingly:
        // For Android emulator, use 10.0.2.2, for iOS use localhost.
        // You could also use kIsWeb here if you set up conditional imports.
          return 'http://$_localHost/api';
      }
    }
    // Fallback in case none of the above match:
    return 'https://$_testHost/api';
  }

  // Returns the WebSocket URL (with /ws appended)
  static String get webSocketUrl {
    if (kIsWeb) {
      switch (appFlavor) {
        case Flavor.TEST:
          return 'wss://$_testHost/ws';
        case Flavor.PRODUCTION:
          return 'wss://$_prodHost/ws';
        case Flavor.LOCAL:
          return 'ws://$_localHost/ws';
      }
    } else {
      // On mobile, similar to apiBaseUrl adjustments might be necessary.
      switch (appFlavor) {
        case Flavor.TEST:
          return 'wss://$_testHost/ws';
        case Flavor.PRODUCTION:
          return 'wss://$_prodHost/ws';
        case Flavor.LOCAL:
          return 'ws://$_localHost/ws';
      }
    }
    return 'wss://$_testHost/ws';
  }
}
