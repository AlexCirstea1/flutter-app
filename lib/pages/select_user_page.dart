import 'dart:async';
import 'package:flutter/material.dart';

import '../pages/chat_page.dart';
import '../services/websocket_service.dart';

class SelectUserPage extends StatefulWidget {
  const SelectUserPage({super.key});

  @override
  State<SelectUserPage> createState() => _SelectUserPageState();
}

class _SelectUserPageState extends State<SelectUserPage> {
  final WebSocketService _webSocketService = WebSocketService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    if (!_webSocketService.isConnected) {
      await _webSocketService.connect();
    }
    // Listen for search results
    _webSocketService.messages.listen((message) {
      if (message['type'] == 'USER_SEARCH_RESULTS') {
        final List<dynamic> users = message['payload'] ?? [];
        setState(() {
          _searchResults = users.map((u) {
            return {
              'id': u['id'] ?? '',
              'username': u['username'] ?? 'Unknown',
            };
          }).toList();
        });
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _sendUserSearch(query);
    });
  }

  void _sendUserSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final msg = {
      'type': 'USER_SEARCH',
      'payload': {'query': query.trim()},
    };
    _webSocketService.sendMessage('/app/userSearch', msg);
  }

  void _createChat(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          chatUserId: user['id'],
          chatUsername: user['username'],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select User'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _searchResults.isEmpty
                  ? const Center(child: Text('No users found.'))
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(user['username']),
                          onTap: () => _createChat(user),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
