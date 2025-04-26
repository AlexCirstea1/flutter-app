import 'dart:async';

import 'package:flutter/material.dart';

import '../data/services/websocket_service.dart';

class LifecycleObserver extends WidgetsBindingObserver {
  Timer? _heartbeatTimer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // The app is now in the foreground
        _startHeartbeat();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        // The app is backgrounded or closed
        _stopHeartbeat();
        break;
      case AppLifecycleState.hidden:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  void _startHeartbeat() {
    // If there's already a timer, cancel it first
    _heartbeatTimer?.cancel();

    // Send a /app/heartbeat message every 30 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final ws = WebSocketService();
      if (ws.isConnected) {
        // The server PresenceController listens at /app/heartbeat
        ws.sendMessage('/app/heartbeat', {});
      }
    });

    // Also send an immediate heartbeat to mark the user online
    final ws = WebSocketService();
    if (ws.isConnected) {
      ws.sendMessage('/app/heartbeat', {});
    }
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    // Optionally, mark user offline immediately (but usually the
    // SessionDisconnectEvent and presence logic in the server
    // will handle it if the socket truly disconnects).
    // But if you want to forcibly tell the server, do:
    // final ws = WebSocketService();
    // ws.disconnect(); // triggers a STOMP disconnect event on server side
  }
}
