import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final _secureStorage = const FlutterSecureStorage();
  final String ACCESS_TOKEN = 'access_token';
  final String REFRESH_TOKEN = 'refresh_token';
  final String USERNAME = 'username';
  final String USER_PIN = 'user_pin';
  final String USER_ID = 'user_id';
  final String MY_PRIVATE_KEY = 'MY_PRIVATE_KEY';

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

  // In StorageService class
  Future<void> savePrivateKey(String version, String privateKey) async {
    // Save the current key version
    await _secureStorage.write(key: 'CURRENT_KEY_VERSION', value: version);

    // Save the private key with its version
    await _secureStorage.write(key: '${MY_PRIVATE_KEY}_$version', value: privateKey);
  }

  Future<String?> getPrivateKey([String? version]) async {
    if (version == null) {
      // Get the current version
      version = await _secureStorage.read(key: 'CURRENT_KEY_VERSION');
      if (version == null) return null;
    }

    // Get the private key for the specific version
    return await _secureStorage.read(key: '${MY_PRIVATE_KEY}_$version');
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
