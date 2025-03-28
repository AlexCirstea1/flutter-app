import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vaultx_app/config/logger_config.dart';
import 'package:vaultx_app/services/storage_service.dart';

import '../config/environment.dart';

class AuthService {
  // Login user
  Future<Map<String, dynamic>?> loginUser(
      String username, String password) async {
    final url = Uri.parse('${Environment.apiBaseUrl}/auth/login');
    try {
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data; // Return the entire response as is
      } else {
        // Log non-200 responses for debugging
        LoggerService.logError(
            'Login failed with status: ${response.statusCode}', response.body);
      }
    } catch (error, stackTrace) {
      LoggerService.logError('Login error: $error', error, stackTrace);
    }
    return null;
  }

  // Register user
  Future<bool> registerUser(
      String username, String email, String password) async {
    final url = Uri.parse('${Environment.apiBaseUrl}/auth/register');
    try {
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'username': username,
          'email': email,
          'password': password,
        }),
      );
      return response.statusCode == 200;
    } catch (error) {
      LoggerService.logError('Register error: $error');
    }
    return false;
  }

  Future<Map<String, dynamic>?> registerDummyUser(String password) async {
    final url = Uri.parse('${Environment.apiBaseUrl}/auth/register/default');
    try {
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: password,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        LoggerService.logError(
            'Register error: status code ${response.statusCode}');
      }
    } catch (error) {
      LoggerService.logError('Register error: $error');
    }
    return null;
  }

  // Verify token
  Future<bool> verifyToken(String accessToken) async {
    final url = Uri.parse('${Environment.apiBaseUrl}/auth/verify');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return response.statusCode == 200;
    } catch (error) {
      LoggerService.logError('Token verification error: $error');
    }
    return false;
  }

  // Refresh token
  Future<String?> refreshToken(String refreshToken) async {
    final url = Uri.parse('${Environment.apiBaseUrl}/auth/refresh');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $refreshToken',
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['access_token'];
      }
    } catch (error) {
      LoggerService.logError('Token refresh error: $error');
    }
    return null;
  }

  // Logout
  Future<bool> logout(String accessToken) async {
    final url = Uri.parse('${Environment.apiBaseUrl}/auth/logout');
    try {
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return response.statusCode == 200;
    } catch (error) {
      LoggerService.logError('Logout error: $error');
    }
    return false;
  }

  // Save PIN
  Future<bool> savePin(String pin, String accessToken) async {
    print("Pin for resetting is: $pin");
    final String apiUrl = '${Environment.apiBaseUrl}/auth/pin/save?pin=$pin';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );
      return response.statusCode == 200;
    } catch (error) {
      LoggerService.logError('PIN saving error: $error');
    }
    return false;
  }

  // Validate PIN
  Future<bool> validatePin(String pin, String accessToken) async {
    final String apiUrl = '${Environment.apiBaseUrl}/auth/pin/verify?pin=$pin';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );
      return response.statusCode == 200; // True if pin is correct
    } catch (error) {
      LoggerService.logError('PIN validation error: $error');
    }
    return false;
  }

  // Fetch user data from /user endpoint
  Future<Map<String, dynamic>?> getUserData(String accessToken) async {
    final url = Uri.parse('${Environment.apiBaseUrl}/user');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        LoggerService.logError(
            'Failed to fetch user data. Status: ${response.statusCode}');
      }
    } catch (error) {
      LoggerService.logError('Error fetching user data: $error');
    }
    return null;
  }

  Future<bool> deleteAccount(String accessToken) async {
    final url = Uri.parse('${Environment.apiBaseUrl}/user');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        LoggerService.logError(
            'Failed to delete account. Status: ${response.statusCode}');
      }
    } catch (error) {
      LoggerService.logError('Error deleting account: $error');
    }
    return false;
  }

  // Save user data after successful authentication
  Future<bool> saveUserData(
      Map<String, dynamic> response, StorageService storageService) async {
    try {
      await storageService.saveAuthData(response);
      return true;
    } catch (error, stackTrace) {
      LoggerService.logError(
          'Error saving user data: $error', error, stackTrace);
      return false;
    }
  }
}
