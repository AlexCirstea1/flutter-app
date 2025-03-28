import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vaultx_app/config/logger_config.dart';

class StorageService {
  final _secureStorage = const FlutterSecureStorage();
  final String ACCESS_TOKEN = 'access_token';
  final String REFRESH_TOKEN = 'refresh_token';
  final String USERNAME = 'username';
  final String USER_PIN = 'user_pin';
  final String USER_ID = 'user_id';
  final String MY_PRIVATE_KEY = 'MY_PRIVATE_KEY';
  static const RECENT_ACCOUNTS = 'recent_accounts';

  // Save tokens and username
  Future<void> saveLoginDetails(String accessToken, String refreshToken,
      String username, String userId) async {
    await _secureStorage.write(key: ACCESS_TOKEN, value: accessToken);
    await _secureStorage.write(key: REFRESH_TOKEN, value: refreshToken);
    await _secureStorage.write(key: USERNAME, value: username);
    await _secureStorage.write(key: USER_ID, value: userId);
  }

  // Get access token
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: ACCESS_TOKEN);
  }

  // Get refresh token
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: REFRESH_TOKEN);
  }

  // Get username
  Future<String?> getUsername() async {
    return await _secureStorage.read(key: USERNAME);
  }

  Future<String?> getUserId() async {
    return await _secureStorage.read(key: USER_ID);
  }

  Future<void> savePrivateKey(String version, String privateKey,
      [String? userId]) async {
    // If userId is not provided, try to get it from storage
    userId = userId ?? await getUserId();
    if (userId == null) {
      throw Exception('Cannot save private key: No user ID available');
    }

    // Save the current key version with user ID
    final versionKey = 'CURRENT_KEY_VERSION_$userId';
    await _secureStorage.write(key: versionKey, value: version);

    // Save the private key with its version and user ID
    final privateKeyName = '${MY_PRIVATE_KEY}_${userId}_$version';
    await _secureStorage.write(key: privateKeyName, value: privateKey);
  }

  Future<String?> getPrivateKey([String? version, String? userId]) async {
    // If userId is not provided, try to get it from storage
    userId = userId ?? await getUserId();
    if (userId == null) {
      return null;
    }

    if (version == null) {
      // Get the current version for this specific user
      final versionKey = 'CURRENT_KEY_VERSION_$userId';
      version = await _secureStorage.read(key: versionKey);

      if (version == null) {
        return null;
      }
    }

    // Get the private key for the specific version and user
    final privateKeyName = '${MY_PRIVATE_KEY}_${userId}_$version';
    final privateKey = await _secureStorage.read(key: privateKeyName);
    if (privateKey != null) {
      LoggerService.logInfo(
          'Successfully retrieved private key for user: $userId, version: $version');
    } else {
      LoggerService.logError(
          'Private key not found with name: $privateKeyName');
    }

    return privateKey;
  }

  // Clear all tokens and username
  Future<void> clearLoginDetails() async {
    await _secureStorage.delete(key: ACCESS_TOKEN);
    await _secureStorage.delete(key: REFRESH_TOKEN);
    await _secureStorage.delete(key: USERNAME);
    await _secureStorage.delete(key: USER_PIN);
  }

  // Generic save
  Future<void> saveInStorage(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  // Generic get
  Future<String?> getFromStorage(String key) async {
    return await _secureStorage.read(key: key);
  }

  // Save hasPin
  Future<void> saveHasPin(bool hasPin) async {
    await _secureStorage.write(key: USER_PIN, value: hasPin.toString());
  }

  // Check if hasPin is set
  Future<bool> getHasPin() async {
    String? hasPin = await _secureStorage.read(key: USER_PIN);
    return hasPin == 'true';
  }

  /// Add a userId to the "recent accounts" list in secure storage
  /// We'll store up to 5 most recent IDs, last used at the front
  Future<void> addRecentAccount(String userId) async {
    final existing = await _secureStorage.read(key: RECENT_ACCOUNTS);
    List<String> list = [];
    if (existing != null) {
      list = List<String>.from(jsonDecode(existing));
    }

    // If userId already exists, remove it so we can re-insert at front
    list.remove(userId);

    // Insert userId at front
    list.insert(0, userId);

    // Limit to 5
    if (list.length > 5) {
      list = list.sublist(0, 5);
    }

    // Save updated list
    await _secureStorage.write(key: RECENT_ACCOUNTS, value: jsonEncode(list));
  }

  /// Get the list of recent account IDs
  Future<List<String>> getRecentAccounts() async {
    final existing = await _secureStorage.read(key: RECENT_ACCOUNTS);

    if (existing == null) {
      return [];
    }

    try {
      final list = List<String>.from(jsonDecode(existing));
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<void> removeRecentAccount(String userId) async {
    final existing = await _secureStorage.read(key: RECENT_ACCOUNTS);

    if (existing == null) {
      return; // Nothing to remove
    }

    try {
      List<String> list = List<String>.from(jsonDecode(existing));

      // Remove the userId if it exists
      list.remove(userId);

      // Save the updated list
      await _secureStorage.write(key: RECENT_ACCOUNTS, value: jsonEncode(list));
      LoggerService.logInfo('Removed account $userId from recent accounts list');
    } catch (e) {
      LoggerService.logError('Error removing recent account', e);
    }
  }
}
