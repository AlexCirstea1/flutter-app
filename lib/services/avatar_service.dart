// avatar_service.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../config/logger_config.dart';
import '../services/storage_service.dart';

class AvatarService {
  final StorageService _storageService;

  // Optional in-memory cache
  final Map<String, Uint8List?> _avatarCache = {};

  AvatarService(this._storageService);

  Future<Uint8List?> getAvatar(String userId) async {
    // If we have it cached, return immediately
    if (_avatarCache.containsKey(userId)) {
      return _avatarCache[userId];
    }

    // final accessToken = await _storageService.getAccessToken();
    // if (accessToken == null) {
    //   LoggerService.logError('No access token found for avatar fetch');
    //   return null;
    // }

    // This endpoint returns a base64 string
    final url =
        Uri.parse('${Environment.apiBaseUrl}/user/public/avatar/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final base64String = response.body; // It's text
        // Decode to raw PNG bytes
        final pngBytes = base64Decode(base64String);
        _avatarCache[userId] = pngBytes;
        return pngBytes;
      } else {
        LoggerService.logError(
          'Failed to fetch avatar for user $userId. Status: ${response.statusCode}',
        );
        _avatarCache[userId] = null;
        return null;
      }
    } catch (e) {
      LoggerService.logError('Error fetching avatar for $userId', e);
      _avatarCache[userId] = null;
      return null;
    }
  }
}
