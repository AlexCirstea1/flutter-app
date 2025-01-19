// lib/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

import '../config/environment.dart';
import '../config/logger_config.dart';
import 'storage_service.dart';

class WebSocketService {
  // Singleton pattern
  WebSocketService._privateConstructor();
  static final WebSocketService _instance =
      WebSocketService._privateConstructor();
  factory WebSocketService() => _instance;

  StompClient? _stompClient;
  final StorageService _storageService = StorageService();

  // StreamControllers for broadcasting messages and connection status
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();
  final StreamController<bool> _connectionStatusController =
      StreamController.broadcast();

  // Getters for streams
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  // Getter to check connection status
  bool get isConnected => _stompClient?.connected ?? false;

  Future<void> connect() async {
    final accessToken = await _storageService.getAccessToken();
    if (accessToken == null) {
      LoggerService.logError('Access token not found');
      return;
    }

    _stompClient = StompClient(
      config: StompConfig(
        url: Environment.webSocketUrl,
        onConnect: _onConnect,
        beforeConnect: () async {
          LoggerService.logInfo('Attempting to connect to WebSocket...');
          await Future.delayed(const Duration(milliseconds: 200));
        },
        stompConnectHeaders: {
          'Authorization': 'Bearer $accessToken',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $accessToken',
        },
        onWebSocketError: (dynamic error) {
          LoggerService.logError('WebSocket error', error);
          _connectionStatusController.add(false);
        },
        onStompError: (StompFrame frame) {
          LoggerService.logError('STOMP error', frame.body);
          _connectionStatusController.add(false);
        },
        reconnectDelay:
            const Duration(milliseconds: 5000), // Reconnect after 5 seconds
      ),
    );

    _stompClient?.activate();
  }

  void _onConnect(StompFrame frame) {
    LoggerService.logInfo('WebSocket connected');
    _connectionStatusController.add(true);

    // Example subscription: Private messages
    _stompClient?.subscribe(
      destination: '/user/queue/messages',
      callback: _onMessageReceived,
    );

    // Example subscription: User search results
    _stompClient?.subscribe(
      destination: '/user/queue/userSearchResults',
      callback: _onUserSearchResultsReceived,
    );

    // Add more subscriptions as needed
  }

  void _onMessageReceived(StompFrame frame) {
    LoggerService.logInfo("Received Message: ${frame.body}");
    if (frame.body != null) {
      try {
        final Map<String, dynamic> messageData = jsonDecode(frame.body!);
        _messageController.add(messageData);
      } catch (e) {
        LoggerService.logError('Error parsing message data', e);
      }
    }
  }

  void _onUserSearchResultsReceived(StompFrame frame) {
    LoggerService.logInfo("Received User Search Results: ${frame.body}");
    if (frame.body != null) {
      try {
        final Map<String, dynamic> response = jsonDecode(frame.body!);
        if (response['type'] == 'USER_SEARCH_RESULTS') {
          final List<dynamic> users = response['payload'] ?? [];
          _messageController.add({
            'type': 'USER_SEARCH_RESULTS',
            'payload': users,
          });
        }
      } catch (e) {
        LoggerService.logError('Error parsing user search results', e);
      }
    }
  }

  void sendMessage(String destination, Map<String, dynamic> message) {
    if (_stompClient != null && _stompClient!.connected) {
      final String messageJson = jsonEncode(message);
      _stompClient!.send(
        destination: destination,
        body: messageJson,
      );
      LoggerService.logInfo("Sent Message: $message");
    } else {
      LoggerService.logError(
          'Cannot send message. WebSocket is not connected.');
    }
  }

  void disconnect() {
    _stompClient?.deactivate();
    _connectionStatusController.add(false);
    LoggerService.logInfo('WebSocket disconnected');
  }

  void dispose() {
    _stompClient?.deactivate();
    _messageController.close();
    _connectionStatusController.close();
    LoggerService.logInfo('WebSocketService disposed');
  }
}
