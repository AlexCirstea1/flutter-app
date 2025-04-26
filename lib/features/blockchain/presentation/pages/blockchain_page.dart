import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/environment.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/widget/bottom_nav_bar.dart';


class BlockchainPage extends StatefulWidget {
  const BlockchainPage({super.key});

  @override
  State<BlockchainPage> createState() => _BlockchainPageState();
}

class _BlockchainPageState extends State<BlockchainPage> {
  int _selectedIndex = 2; // Position in navbar
  bool _isLoading = true;
  List<BlockchainTransaction> _transactions = [];
  String? _selectedFilter;
  bool _consentEnabled = false;

  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _fetchConsentStatus();
    _fetchTransactions();
  }

  Future<void> _fetchConsentStatus() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) throw Exception('Authentication required');

      final response = await http.get(
        Uri.parse('${Environment.apiBaseUrl}/blockchain/consent'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _consentEnabled = data['enabled'] ?? false;
        });
      }
    } catch (e) {
      _showSnackBar('Failed to load consent status: ${e.toString()}');
    }
  }

  Future<void> _toggleConsent(bool value) async {
    try {
      setState(() => _isLoading = true);

      final token = await _storageService.getAccessToken();
      if (token == null) throw Exception('Authentication required');

      final response = await http.post(
        Uri.parse('${Environment.apiBaseUrl}/user/blockchain-consent'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'enabled': value}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _consentEnabled = value;
          _isLoading = false;
        });
        _showSnackBar('Blockchain consent updated successfully');

        if (value) {
          _fetchTransactions();
        }
      } else {
        throw Exception('Failed to update consent');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  Future<void> _fetchTransactions({String? filterType}) async {
    setState(() => _isLoading = true);

    try {
      final token = await _storageService.getAccessToken();
      if (token == null) throw Exception('Authentication required');

      String url = '${Environment.apiBaseUrl}/blockchain/transactions';
      if (filterType != null) {
        url += '?type=$filterType';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<BlockchainTransaction> transactions = (data as List)
            .map((item) => BlockchainTransaction.fromJson(item))
            .toList();

        setState(() {
          _transactions = transactions;
          _isLoading = false;
          _selectedFilter = filterType;
        });
      } else {
        throw Exception('Failed to load transactions');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _connectService() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) throw Exception('Authentication required');

      final response = await http.post(
        Uri.parse('${Environment.apiBaseUrl}/blockchain/connect'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showSnackBar('Successfully connected to partner service');
      } else {
        throw Exception('Failed to connect service');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: theme.surface,
      appBar: AppBar(
        backgroundColor: theme.primary,
        foregroundColor: theme.onPrimary,
        title: const Text('Blockchain Transactions'),
        automaticallyImplyLeading: false,
        actions: [
          if (_consentEnabled)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              onSelected: (value) {
                if (value == 'All') {
                  _fetchTransactions();
                } else {
                  _fetchTransactions(filterType: value.toLowerCase());
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'All', child: Text('All Transactions')),
                const PopupMenuItem(
                    value: 'Consent', child: Text('Consent Updates')),
                const PopupMenuItem(
                    value: 'Identity', child: Text('Identity Verifications')),
                const PopupMenuItem(
                    value: 'Document', child: Text('Document Signatures')),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Consent Management Section
                  Text(
                    'Consent Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Enable Blockchain Services'),
                    subtitle: const Text(
                        'Your data will be processed securely on blockchain'),
                    value: _consentEnabled,
                    onChanged: _toggleConsent,
                    tileColor: theme.primary.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Transaction History Section
                  Text(
                    'Transaction History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (!_consentEnabled)
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.block,
                              size: 64,
                              color: theme.onSurface.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text(
                            'Enable blockchain services to view transactions',
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.onSurface.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else if (_transactions.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.link_off,
                              size: 64,
                              color: theme.onSurface.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text(
                            'No blockchain transactions found',
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          if (_selectedFilter != null) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => _fetchTransactions(),
                              child: const Text('Show all transactions'),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _transactions[index];
                        return TransactionTile(transaction: transaction);
                      },
                    ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Service Integrations Section
                  Text(
                    'Service Integrations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _consentEnabled ? _connectService : null,
                    icon: const Icon(Icons.link),
                    label: const Text('Connect to Partner Service'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.secondary,
                      foregroundColor: theme.onSecondary,
                      disabledBackgroundColor: theme.secondary.withOpacity(0.3),
                      disabledForegroundColor:
                          theme.onSecondary.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class BlockchainTransaction {
  final String id;
  final String type;
  final String description;
  final DateTime timestamp;
  final String status;
  final String transactionHash;
  final String? details;

  BlockchainTransaction({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
    required this.status,
    required this.transactionHash,
    this.details,
  });

  factory BlockchainTransaction.fromJson(Map<String, dynamic> json) {
    return BlockchainTransaction(
      id: json['id'],
      type: json['type'],
      description: json['description'],
      timestamp: DateTime.parse(json['timestamp']),
      status: json['status'],
      transactionHash: json['transactionHash'],
      details: json['details'],
    );
  }

  IconData get icon {
    switch (type.toLowerCase()) {
      case 'consent':
        return Icons.handshake;
      case 'identity':
        return Icons.verified_user;
      case 'document':
        return Icons.description;
      default:
        return Icons.link;
    }
  }

  Color getColor(BuildContext context) {
    switch (type.toLowerCase()) {
      case 'consent':
        return Colors.green;
      case 'identity':
        return Colors.blue;
      case 'document':
        return Colors.amber;
      default:
        return Colors.teal;
    }
  }
}

class TransactionTile extends StatelessWidget {
  final BlockchainTransaction transaction;

  const TransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: transaction.getColor(context).withOpacity(0.2),
          child: Icon(transaction.icon, color: transaction.getColor(context)),
        ),
        title: Text(transaction.description),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatDate(transaction.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: theme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  transaction.status == 'verified'
                      ? Icons.verified
                      : Icons.pending,
                  size: 14,
                  color: transaction.status == 'verified'
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  transaction.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: transaction.status == 'verified'
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showTransactionDetails(context, transaction),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  void _showTransactionDetails(
      BuildContext context, BlockchainTransaction transaction) {
    final theme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(transaction.icon, color: transaction.getColor(context)),
            const SizedBox(width: 8),
            const Text('Transaction Details'),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Type: ${transaction.type}'),
            const SizedBox(height: 8),
            Text('Description: ${transaction.description}'),
            const SizedBox(height: 8),
            Text('Time: ${transaction.timestamp.toString()}'),
            const SizedBox(height: 8),
            Text('Status: ${transaction.status}'),
            const SizedBox(height: 8),
            const Text('Transaction Hash:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.surface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Text(
                      transaction.transactionHash,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.content_copy, size: 18),
                    onPressed: () {
                      // Copy hash to clipboard would go here
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Transaction hash copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (transaction.details != null) ...[
              const SizedBox(height: 8),
              Text('Details: ${transaction.details}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // This would open a web browser to view the transaction
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening blockchain explorer...')),
              );
            },
            child: const Text('View on Explorer'),
          ),
        ],
      ),
    );
  }
}
