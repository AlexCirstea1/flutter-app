import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/widget/bottom_nav_bar.dart';
import '../../domain/models/did_event.dart';
import '../../data/blockchain_api.dart';
import 'event_detail_page.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  int _selectedIndex = 2;
  final _api = BlockchainApi();
  final _storage = StorageService();

  List<DIDEvent> _events = [];
  bool _loading = true;
  String? _filterType;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _init() async {
    // 1) Load the userId from secure storage
    final id = await _storage.getUserId();
    if (id == null) {
      // handle missing user ID, maybe navigate back to login
      return;
    }
    setState(() => _userId = id);
    // 2) Then load events
    _load();
  }

  Future<void> _load() async {
    if (_userId == null) return;
    setState(() => _loading = true);
    try {
      _events = await _api.fetchEvents(
        userId: _userId!,
        type: _filterType,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading events: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final df = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'BLOCKCHAIN EVENTS',
          style: theme.appBarTheme.titleTextStyle,
        ),
        actions: [
          PopupMenuButton<String?>(
            initialValue: _filterType,
            onSelected: (t) {
              setState(() => _filterType = t);
              _load();
            },
            icon: Icon(Icons.filter_list, color: colorScheme.primary),
            color: colorScheme.surfaceContainerHighest,
            position: PopupMenuPosition.under,
            itemBuilder: (_) => <PopupMenuEntry<String?>>[
              PopupMenuItem(
                value: null,
                child: Text('ALL TYPES',
                    style: TextStyle(color: colorScheme.onSurface)),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'USER_REGISTERED',
                child: Text('REGISTERED',
                    style: TextStyle(color: colorScheme.onSurface)),
              ),
              PopupMenuItem(
                value: 'USER_KEY_ROTATED',
                child: Text('KEY ROTATED',
                    style: TextStyle(color: colorScheme.onSurface)),
              ),
              PopupMenuItem(
                value: 'USER_ROLE_CHANGED',
                child: Text('ROLE CHANGED',
                    style: TextStyle(color: colorScheme.onSurface)),
              ),
              PopupMenuItem(
                value: 'CHAT_CREATED',
                child: Text('CHAT CREATED',
                    style: TextStyle(color: colorScheme.onSurface)),
              ),
            ],
          )
        ],
      ),
      body: Container(
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
        child: _loading
            ? Center(
                child: CircularProgressIndicator(color: colorScheme.secondary))
            : _events.isEmpty
                ? Center(
                    child: Text(
                      'NO EVENTS FOUND',
                      style: TextStyle(
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                        fontSize: 16,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _events.length,
                    itemBuilder: (_, i) {
                      final ev = _events[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.05),
                              blurRadius: 10,
                              spreadRadius: -5,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EventDetailPage(eventId: ev.eventId),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Event icon or indicator
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colorScheme.secondary
                                            .withOpacity(0.5),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colorScheme.secondary
                                              .withOpacity(0.1),
                                          blurRadius: 8,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: _getEventIcon(
                                          ev.type, colorScheme.secondary),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Event info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ev.type?.replaceAll('_', ' ') ?? '—',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: ${_truncateId(ev.eventId)}',
                                          style: TextStyle(
                                            color: theme
                                                .textTheme.bodyMedium?.color
                                                ?.withOpacity(0.7),
                                            fontSize: 12,
                                            fontFamily: 'monospace',
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          df.format(ev.timestamp),
                                          style: TextStyle(
                                            color: theme
                                                .textTheme.bodyMedium?.color
                                                ?.withOpacity(0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Arrow
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color:
                                        colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  String _truncateId(String id) {
    if (id.length <= 10) return id;
    return '${id.substring(0, 6)}...${id.substring(id.length - 4)}';
  }

  Widget _getEventIcon(String? type, Color color) {
    IconData iconData;

    switch (type) {
      case 'USER_REGISTERED':
        iconData = Icons.person_add_outlined;
        break;
      case 'USER_KEY_ROTATED':
        iconData = Icons.key;
        break;
      case 'USER_ROLE_CHANGED':
        iconData = Icons.admin_panel_settings_outlined;
        break;
      case 'CHAT_CREATED':
        iconData = Icons.chat_outlined;
        break;
      default:
        iconData = Icons.data_object;
    }

    return Icon(iconData, color: color, size: 22);
  }
}
