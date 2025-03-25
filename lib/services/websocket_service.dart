import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

import '../config/environment.dart';
import '../config/logger_config.dart';
import 'storage_service.dart';

/// A helper class to handle STOMP WebSocket connections, subscriptions, and
/// broadcasting messages to the rest of the app through streams.
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

  // Getters for external listeners
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  bool get isConnected => _stompClient?.connected ?? false;

  Future<void> connect() async {
    final accessToken = await _storageService.getAccessToken();
    if (accessToken == null) {
      LoggerService.logError('Access token not found');
      return;
    }

    // Create and activate a StompClient
    _stompClient = StompClient(
      config: StompConfig(
        url: Environment.webSocketUrl, // e.g. "ws://<host>:<port>/ws"
        onConnect: _onConnect,
        beforeConnect: () async {
          // LoggerService.logInfo('Attempting to connect to WebSocket...');
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
        // Try reconnecting after 5 seconds if the connection drops
        reconnectDelay: const Duration(milliseconds: 5000),
      ),
    );

    _stompClient?.activate();
  }

  void _onConnect(StompFrame frame) {
    // LoggerService.logInfo('WebSocket connected');
    _connectionStatusController.add(true);

    // 1) Incoming private messages for the recipient
    _stompClient?.subscribe(
      destination: '/user/queue/messages',
      callback: (StompFrame frame) {
        _handleIncomingFrame(frame, tag: 'INCOMING_MESSAGE');
      },
    );

    // 2) "Sent" confirmations back to the sender with the real DB ID, timestamps, etc.
    _stompClient?.subscribe(
      destination: '/user/queue/sent',
      callback: (StompFrame frame) {
        _handleIncomingFrame(frame, tag: 'SENT_MESSAGE');
      },
    );

    // 3) Read receipts to the sender when the recipient reads their messages
    _stompClient?.subscribe(
      destination: '/user/queue/read-receipts',
      callback: (StompFrame frame) {
        _handleIncomingFrame(frame, tag: 'READ_RECEIPT');
      },
    );

    // 4) User search results
    _stompClient?.subscribe(
      destination: '/user/queue/userSearchResults',
      callback: (StompFrame frame) {
        _handleIncomingFrame(frame, tag: 'USER_SEARCH_RESULTS');
      },
    );
  }

  void _handleIncomingFrame(StompFrame frame, {required String tag}) {
    if (frame.body == null) return;
    LoggerService.logInfo("Received [$tag]: ${frame.body}");
    try {
      final data = jsonDecode(frame.body!);

      // Instead of forcing data['type'] = tag,
      // we only set it if it's missing. That way your Java code
      // (which sets "INCOMING_MESSAGE" or "SENT_MESSAGE") remains intact:
      data['type'] ??= tag;

      _messageController.add(data);
    } catch (e) {
      LoggerService.logError('Error parsing STOMP frame ($tag)', e);
    }
  }


  /// Send a generic JSON-encodable message to a STOMP destination
  void sendMessage(String destination, Map<String, dynamic> message) {
    if (_stompClient != null && _stompClient!.connected) {
      final String messageJson = jsonEncode(message);
      _stompClient!.send(
        destination: destination,
        body: messageJson,
      );
      LoggerService.logInfo("Sent message to $destination: $message");
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
