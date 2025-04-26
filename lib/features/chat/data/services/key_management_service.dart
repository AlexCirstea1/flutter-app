import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/environment.dart';
import '../../../../core/config/logger_config.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/domain/models/public_key_data.dart';

class KeyManagementService {
  final StorageService storageService;

  KeyManagementService({required this.storageService});

  Future<PublicKeyData?> getOrFetchPublicKeyAndVersion(String userId) async {
    // Try to get from cache first
    final cachedKey = await storageService.getFromStorage('publicKey_$userId');
    final cachedVersion =
        await storageService.getFromStorage('publicKeyVersion_$userId');

    if (cachedKey != null &&
        cachedKey.isNotEmpty &&
        cachedVersion != null &&
        cachedVersion.isNotEmpty) {
      return PublicKeyData(publicKey: cachedKey, keyVersion: cachedVersion);
    }

    // Fetch from API
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) return null;

    final url = Uri.parse('${Environment.apiBaseUrl}/user/publicKey/$userId');
    try {
      final resp = await http
          .get(url, headers: {'Authorization': 'Bearer $accessToken'});

      if (resp.statusCode == 200) {
        final jsonResp = jsonDecode(resp.body);
        final pubKey = jsonResp['publicKey'] as String? ?? '';
        final keyVer = jsonResp['version'] as String? ?? '';

        if (pubKey.isNotEmpty && keyVer.isNotEmpty) {
          await storageService.saveInStorage('publicKey_$userId', pubKey);
          await storageService.saveInStorage(
              'publicKeyVersion_$userId', keyVer);
          return PublicKeyData(publicKey: pubKey, keyVersion: keyVer);
        }
      } else {
        LoggerService.logError(
            "Failed to fetch pubkey for $userId. code=${resp.statusCode}");
      }
    } catch (e) {
      LoggerService.logError("Exception fetching pubkey for $userId: $e");
    }
    return null;
  }
}
