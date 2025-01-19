import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final _secureStorage = const FlutterSecureStorage();
  final String ACCESS_TOKEN = 'access_token';
  final String REFRESH_TOKEN = 'refresh_token';
  final String USERNAME = 'username';
  final String USER_PIN = 'user_pin';
  final String USER_ID = 'user_id';

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
}
