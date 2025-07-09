import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/auth/domain/models/user_profile.dart';
import '../../config/logger_config.dart';

class StorageService {
  final _secureStorage = const FlutterSecureStorage();

  // Constants for secure storage keys
  final String ACCESS_TOKEN = 'access_token';
  final String REFRESH_TOKEN = 'refresh_token';
  final String USER_PROFILE = 'user_profile';
  static const RECENT_ACCOUNTS = 'recent_accounts';
  final String MY_PRIVATE_KEY = 'MY_PRIVATE_KEY';
  static const BIOMETRIC_KEY = 'biometric_enabled';

  Future<void> saveAuthData(Map<String, dynamic> authResponse) async {
    // Extract tokens
    final accessToken = authResponse['access_token'] as String?;
    final refreshToken = authResponse['refresh_token'] as String?;

    // Extract and convert user data
    final userData = authResponse['user'] as Map<String, dynamic>?;

    if (accessToken == null || refreshToken == null || userData == null) {
      throw Exception('Invalid auth response: Missing required fields');
    }

    // Create user profile from the response
    final userProfile = UserProfile.fromJson(userData);

    // Save tokens
    await _secureStorage.write(key: ACCESS_TOKEN, value: accessToken);
    await _secureStorage.write(key: REFRESH_TOKEN, value: refreshToken);

    // Save complete profile as JSON
    await _secureStorage.write(
        key: USER_PROFILE, value: jsonEncode(userProfile.toJson()));

    // Add to recent accounts
    await addRecentAccount(userProfile.id);
  }

  Future<UserProfile?> getUserProfile() async {
    final profileJson = await _secureStorage.read(key: USER_PROFILE);
    if (profileJson == null) return null;

    try {
      final Map<String, dynamic> data = jsonDecode(profileJson);
      return UserProfile.fromJson(data);
    } catch (e) {
      LoggerService.logError('Error parsing user profile', e);
      return null;
    }
  }

  // Get access token
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: ACCESS_TOKEN);
  }

  // Get refresh token
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: REFRESH_TOKEN);
  }

  // Get username from user profile
  Future<String?> getUsername() async {
    final profile = await getUserProfile();
    return profile?.username;
  }

  // Get email from user profile
  Future<String?> getEmail() async {
    final profile = await getUserProfile();
    return profile?.email;
  }

  // Get user ID from user profile
  Future<String?> getUserId() async {
    final profile = await getUserProfile();
    return profile?.id;
  }

  // Clear all tokens and username
  Future<void> clearLoginDetails() async {
    await _secureStorage.delete(key: ACCESS_TOKEN);
    await _secureStorage.delete(key: REFRESH_TOKEN);
    await _secureStorage.delete(key: USER_PROFILE);
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
    final profile = await getUserProfile();
    if (profile == null) return;

    final updatedProfile = UserProfile(
      id: profile.id,
      username: profile.username,
      email: profile.email,
      hasPin: hasPin,
      blockchainConsent: profile.blockchainConsent,
      additionalData: profile.additionalData,
    );

    await _secureStorage.write(
        key: USER_PROFILE, value: jsonEncode(updatedProfile.toJson()));
  }

  // Check if hasPin is set
  Future<bool> getHasPin() async {
    final profile = await getUserProfile();
    return profile?.hasPin ?? false;
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

  /// Add a userId to the "recent accounts" list in secure storage
  /// We'll store up to 5 most recent IDs, last used at the front
  Future<void> addRecentAccount(String userId) async {
    final existing = await _secureStorage.read(key: RECENT_ACCOUNTS);
    List<String> list = [];

    if (existing != null) {
      list = List<String>.from(jsonDecode(existing));
    }

    list.remove(userId);
    list.insert(0, userId);

    if (list.length > 5) {
      list = list.sublist(0, 5);
    }

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

  /// Remove the list of recent account IDs
  Future<void> removeRecentAccount(String userId) async {
    final existing = await _secureStorage.read(key: RECENT_ACCOUNTS);
    if (existing == null) {
      return;
    }

    try {
      List<String> list = List<String>.from(jsonDecode(existing));
      list.remove(userId);

      await _secureStorage.write(key: RECENT_ACCOUNTS, value: jsonEncode(list));
    } catch (e) {
      LoggerService.logError('Error removing recent account', e);
    }
  }

  Future<void> saveCertificate(String version, String certificatePem,
      [String? userId]) async {
    userId = userId ?? await getUserId();
    if (userId == null) {
      throw Exception('Cannot save certificate: No user ID available');
    }

    // Save the certificate with its version and user ID
    final certificateKey = 'X509_CERTIFICATE_${userId}_$version';
    await _secureStorage.write(key: certificateKey, value: certificatePem);
  }

  Future<String?> getCertificate([String? version, String? userId]) async {
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

    // Get the certificate for the specific version and user
    final certificateKey = 'X509_CERTIFICATE_${userId}_$version';
    return await _secureStorage.read(key: certificateKey);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(BIOMETRIC_KEY, enabled);
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(BIOMETRIC_KEY) ?? false;
  }
}
