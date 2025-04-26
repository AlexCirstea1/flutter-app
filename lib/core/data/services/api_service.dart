import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vaultx_app/core/data/services/storage_service.dart';

import '../../config/environment.dart';

class ApiService {
  final StorageService _storageService = StorageService();
  final GlobalKey<NavigatorState> navigatorKey;

  ApiService({required this.navigatorKey});

  // GET request with auth handling
  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    return _handleRequest(() async {
      final token = await _storageService.getAccessToken();
      final requestHeaders = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        ...?headers,
      };

      final response = await http.get(
        Uri.parse('${Environment.apiBaseUrl}$endpoint'),
        headers: requestHeaders,
      );

      return _handleResponse(response);
    });
  }

  // POST request with auth handling
  Future<dynamic> post(String endpoint, dynamic body,
      {Map<String, String>? headers}) async {
    return _handleRequest(() async {
      final token = await _storageService.getAccessToken();
      final requestHeaders = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        ...?headers,
      };

      final response = await http.post(
        Uri.parse('${Environment.apiBaseUrl}$endpoint'),
        headers: requestHeaders,
        body: json.encode(body),
      );

      return _handleResponse(response);
    });
  }

  // Add other methods (put, delete, etc.) as needed

  // Common response handler
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      // Token is invalid or expired
      _handleAuthError();
      throw Exception('Unauthorized');
    } else {
      throw Exception('Request failed with status: ${response.statusCode}');
    }
  }

  // Common request wrapper that handles network errors
  Future<dynamic> _handleRequest(Future<dynamic> Function() requestFunc) async {
    try {
      return await requestFunc();
    } catch (error) {
      if (error.toString().contains('Failed host lookup') ||
          error.toString().contains('Connection refused') ||
          error.toString().contains('Connection reset') ||
          error.toString().contains('Socket operation')) {
        // Network error
        _handleNetworkError();
      } else if (error.toString().contains('Unauthorized')) {
        // Auth error already handled in _handleResponse
      }
      rethrow;
    }
  }

  // Handle authentication errors (401)
  void _handleAuthError() async {
    await _logOut();
    _navigateToLogin();
  }

  // Handle network errors
  void _handleNetworkError() async {
    // Log out the user and navigate to login screen
    await _logOut();
    _navigateToLogin();

    // Still show a notification about the network issue
    ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
      const SnackBar(
          content: Text('Network error. Please check your connection.')),
    );
  }

  // Log out the user
  Future<void> _logOut() async {
    await _storageService.clearLoginDetails();
  }

  // Navigate to login screen
  void _navigateToLogin() {
    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
