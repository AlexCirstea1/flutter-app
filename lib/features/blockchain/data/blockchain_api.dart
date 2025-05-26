import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/environment.dart';
import '../../../core/data/services/storage_service.dart';
import '../domain/models/did_event.dart';
import '../domain/models/event_history.dart';

class BlockchainApi {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<DIDEvent>> fetchEvents({
    required String userId,
    String? type,
    DateTime? from,
    DateTime? to,
  }) async {
    final qs = <String>[
      'userId=$userId',
      if (type != null) 'type=$type',
      if (from != null)
        'from=${Uri.encodeQueryComponent(from.toIso8601String())}',
      if (to != null) 'to=${Uri.encodeQueryComponent(to.toIso8601String())}',
    ].join('&');

    final url = Uri.parse('${Environment.apiBaseUrl}/blockchain/events?$qs');
    final resp = await http.get(url, headers: await _authHeaders());
    if (resp.statusCode != 200) {
      throw Exception('Failed to load events (${resp.statusCode})');
    }
    final List jsonList = json.decode(resp.body) as List;
    return jsonList
        .map((m) => DIDEvent.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<DIDEvent> fetchEventDetail(String eventId) async {
    final url =
        Uri.parse('${Environment.apiBaseUrl}/blockchain/events/$eventId');
    final resp = await http.get(url, headers: await _authHeaders());
    if (resp.statusCode != 200) {
      throw Exception('Failed to load event detail');
    }
    return DIDEvent.fromJson(json.decode(resp.body));
  }

  Future<List<EventHistory>> fetchEventHistory(String eventId) async {
    final url = Uri.parse(
        '${Environment.apiBaseUrl}/blockchain/events/$eventId/history');
    final resp = await http.get(url, headers: await _authHeaders());
    if (resp.statusCode != 200) {
      throw Exception('Failed to load event history');
    }
    final List jsonList = json.decode(resp.body) as List;
    return jsonList
        .map((m) => EventHistory.fromJson(m as Map<String, dynamic>))
        .toList();
  }
}
