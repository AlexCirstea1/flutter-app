import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/did_event.dart';
import '../../domain/models/event_history.dart';
import '../../data/blockchain_api.dart';

class EventDetailPage extends StatefulWidget {
  final String eventId;
  const EventDetailPage({super.key, required this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final _api = BlockchainApi();
  DIDEvent? _event;
  List<EventHistory>? _history;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      _event = await _api.fetchEventDetail(widget.eventId);
      _history = await _api.fetchEventHistory(widget.eventId);
    } catch (e) {
      setState(() => _hasError = true);
      debugPrint('Error fetching event details: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final df = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'EVENT DETAIL',
          style: theme.appBarTheme.titleTextStyle,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.appBarTheme.iconTheme?.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
            ? Center(child: CircularProgressIndicator(color: colorScheme.secondary))
            : _hasError || _event == null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error.withOpacity(0.7),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'EVENT NOT FOUND',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  fontSize: 16,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _fetch,
                child: Text(
                  'RETRY',
                  style: TextStyle(
                    color: colorScheme.primary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        )
            : ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // Header section with type and icon
            _buildHeaderSection(context, colorScheme),

            const SizedBox(height: 24),

            // Event details card
            _buildDetailsCard(context, colorScheme, df),

            const SizedBox(height: 24),

            // Payload section
            _buildSectionHeader(context, 'PAYLOAD', Icons.code, colorScheme),
            _buildPayloadCard(context, colorScheme),

            const SizedBox(height: 24),

            // History section
            _buildSectionHeader(context, 'HISTORY', Icons.history, colorScheme),
            _buildHistoryList(context, colorScheme),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.secondary.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.secondary.withOpacity(0.15),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: _getEventIcon(_event!.type, colorScheme.secondary),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            _event!.type?.replaceAll('_', ' ') ?? 'UNKNOWN EVENT',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.5,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard(BuildContext context, ColorScheme colorScheme, DateFormat df) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailItem(
            context,
            'EVENT ID',
            _event!.eventId,
            monospace: true,
          ),
          const SizedBox(height: 12),
          _buildDetailItem(
            context,
            'TIMESTAMP',
            df.format(_event!.timestamp),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, String label, String value, {bool monospace = false}) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontFamily: monospace ? 'monospace' : null,
            color: theme.textTheme.bodyMedium?.color,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayloadCard(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        _event!.payload ?? '—',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, ColorScheme colorScheme) {
    if (_history == null || _history!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          'NO HISTORY RECORDS FOUND',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return Column(
      children: _history!.map((h) =>
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (h.isDelete ?? false)
                          ? Colors.redAccent.withOpacity(0.1)
                          : Colors.greenAccent.withOpacity(0.1),
                      border: Border.all(
                        color: (h.isDelete ?? false)
                            ? Colors.redAccent.withOpacity(0.5)
                            : Colors.greenAccent.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      (h.isDelete ?? false) ? Icons.delete_outline : Icons.add_circle_outline,
                      size: 16,
                      color: (h.isDelete ?? false)
                          ? Colors.redAccent.withOpacity(0.8)
                          : Colors.greenAccent.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _truncateId(h.txId),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm:ss').format(h.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    (h.isDelete ?? false) ? 'DELETED' : 'CREATED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: (h.isDelete ?? false)
                          ? Colors.redAccent.withOpacity(0.8)
                          : Colors.greenAccent.withOpacity(0.8),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          )
      ).toList(),
    );
  }

  String _truncateId(String id) {
    if (id.length <= 10) return id;
    return '${id.substring(0, 8)}...${id.substring(id.length - 8)}';
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

    return Icon(iconData, color: color, size: 30);
  }
}