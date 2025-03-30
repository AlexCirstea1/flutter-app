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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SELECT USER',
          style: theme.appBarTheme.titleTextStyle,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surface,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: colorScheme.primary.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'SEARCH SECURE CONTACTS',
                    hintStyle: TextStyle(
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                    prefixIcon: Icon(Icons.search,
                        color: colorScheme.primary, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: _searchController.text.isNotEmpty
                    ? Row(
                        children: [
                          Icon(Icons.security,
                              size: 14, color: colorScheme.secondary),
                          const SizedBox(width: 8),
                          Text(
                            'SEARCH RESULTS',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(Icons.lock,
                              size: 14,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.6)),
                          const SizedBox(width: 8),
                          Text(
                            'SECURE DIRECTORY',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
              ),
              Divider(color: colorScheme.primary.withOpacity(0.1), height: 1),
              const SizedBox(height: 10),
              Expanded(
                child: _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _searchController.text.isEmpty
                                  ? Icons.search
                                  : Icons.person_off,
                              size: 50,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'ENTER USERNAME TO SEARCH'
                                  : 'NO USERS FOUND',
                              style: TextStyle(
                                fontSize: 14,
                                letterSpacing: 1.5,
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Start typing to find secure contacts'
                                  : 'Try a different search term',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.transparent),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.shadow.withOpacity(0.2),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color:
                                          colorScheme.primary.withOpacity(0.2),
                                      width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          colorScheme.primary.withOpacity(0.05),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  backgroundColor:
                                      colorScheme.surface.withOpacity(0.5),
                                  child: Icon(Icons.person,
                                      color: colorScheme.secondary, size: 20),
                                ),
                              ),
                              title: Text(
                                user['username']?.toUpperCase() ?? 'UNKNOWN',
                                style: TextStyle(
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w500,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              subtitle: Text(
                                'SECURE ID: ${user['id'].substring(0, 8)}...',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.7),
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              onTap: () => _createChat(user),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
