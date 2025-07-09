import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../core/config/logger_config.dart';
import '../../../../core/data/services/service_locator.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/data/services/websocket_service.dart';
import '../../../../core/utils/key_cert_helper.dart';
import '../../../features/chat/data/services/chat_service.dart';
import '../../../features/auth/data/services/auth_service.dart';
import '../../../features/profile/data/services/avatar_service.dart';
import '../../../features/blockchain/data/blockchain_api.dart';

class DataPreloadService {
  final ValueNotifier<String> currentOperation = ValueNotifier<String>("Initializing...");
  final ValueNotifier<double> progress = ValueNotifier<double>(0.0);

  final StorageService _storage = serviceLocator<StorageService>();
  final WebSocketService _websocket = WebSocketService();
  final ChatService _chatService = serviceLocator<ChatService>();
  final AuthService _authService = serviceLocator<AuthService>();
  final BlockchainApi _blockchainApi = BlockchainApi();

  String? _userId;
  bool _isPreloadComplete = false;
  bool get isPreloadComplete => _isPreloadComplete;

  Future<bool> preloadAppData() async {
    try {
      // Check authentication first
      _userId = await _storage.getUserId();
      final token = await _storage.getAccessToken();

      if (_userId == null || token == null) {
        LoggerService.logInfo('Not authenticated, skipping preload');
        return false;
      }

      // Setup progress tracking
      int completedTasks = 0;
      const totalTasks = 5; // WebSocket + 4 data areas
      void updateProgress() {
        completedTasks++;
        progress.value = completedTasks / totalTasks;
      }

      // Initialize WebSocket first
      currentOperation.value = "Connecting to server...";
      await _initializeWebSocket();
      updateProgress();

      // Load data in parallel
      await Future.wait([
        _preloadHomeData().then((_) {
          updateProgress();
        }),
        _preloadProfileData().then((_) {
          updateProgress();
        }),
        _preloadBlockchainData().then((_) {
          updateProgress();
        }),
        _preloadActivityData().then((_) {
          updateProgress();
        }),
      ]);

      _isPreloadComplete = true;
      currentOperation.value = "Ready";
      return true;
    } catch (e) {
      LoggerService.logError('Error during data preload', e);
      currentOperation.value = "Error during initialization";
      return false;
    }
  }

  void clearCache() {
    _isPreloadComplete = false;
    currentOperation.value = "Initializing...";
    progress.value = 0.0;
  }

  Future<void> _initializeWebSocket() async {
    try {
      await _websocket.connect();
      LoggerService.logInfo('WebSocket connection established');
    } catch (e) {
      LoggerService.logError('WebSocket initialization failed', e);
      // Allow app to continue even if WebSocket fails
    }
  }

  Future<void> _preloadHomeData() async {
    try {
      currentOperation.value = "Loading conversations...";
      await _chatService.fetchAllChats();

      currentOperation.value = "Loading connection requests...";
      await _chatService.fetchPendingChatRequests();

      LoggerService.logInfo('Home data preloaded successfully');
    } catch (e) {
      LoggerService.logError('Home data preload error', e);
    }
  }

  Future<void> _preloadProfileData() async {
    try {
      currentOperation.value = "Loading profile data...";

      // Load user data
      final token = await _storage.getAccessToken();
      if (token != null) {
        await _authService.getUserData(token);
      }

      // Load avatar
      if (_userId != null) {
        currentOperation.value = "Loading avatar...";
        final avatarService = AvatarService(_storage);
        await avatarService.getAvatar(_userId!);
      }

      // Load certificate info
      currentOperation.value = "Loading certificate...";
      final certificate = await _storage.getCertificate();
      if (certificate != null) {
        KeyCertHelper.parseCertificate(certificate);
      }

      LoggerService.logInfo('Profile data preloaded successfully');
    } catch (e) {
      LoggerService.logError('Profile data preload error', e);
    }
  }

  Future<void> _preloadBlockchainData() async {
    if (_userId == null) return;

    try {
      currentOperation.value = "Loading blockchain events...";
      await _blockchainApi.fetchEvents(userId: _userId!);
      LoggerService.logInfo('Blockchain data preloaded successfully');
    } catch (e) {
      LoggerService.logError('Blockchain data preload error', e);
    }
  }

  Future<void> _preloadActivityData() async {
    if (_userId == null) return;

    try {
      currentOperation.value = "Loading activity data...";
      // Add ActivityService implementation here
      // Example: await serviceLocator<ActivityService>().fetchRecentActivity();

      LoggerService.logInfo('Activity data preloaded successfully');
    } catch (e) {
      LoggerService.logError('Activity data preload error', e);
    }
  }
}