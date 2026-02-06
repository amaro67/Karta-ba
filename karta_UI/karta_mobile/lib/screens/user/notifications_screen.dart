import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:karta_shared/karta_shared.dart';
import '../../config/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final auth = context.read<AuthProvider>();
    final token = auth.accessToken;
    if (token == null) return;

    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiClient.get('/Notification?page=1&size=50', token: token);
      final items = (data['items'] as List?) ?? [];
      setState(() {
        _notifications = items.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _markAsRead(String id) async {
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;
    try {
      final response = await ApiClient.put('/Notification/$id/read', {}, token: token);
    } catch (e) {
      // PUT returning 204 will throw, that's OK
    }
    setState(() {
      final index = _notifications.indexWhere((n) => n['id'] == id);
      if (index != -1) _notifications[index]['isRead'] = true;
    });
  }

  Future<void> _markAllAsRead() async {
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;
    try {
      await ApiClient.put('/Notification/read-all', {}, token: token);
    } catch (e) {
      // 204 NoContent expected
    }
    setState(() {
      for (var n in _notifications) { n['isRead'] = true; }
    });
  }

  Future<void> _deleteNotification(String id) async {
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;
    try {
      await ApiClient.delete('/Notification/$id', token: token);
      setState(() => _notifications.removeWhere((n) => n['id'] == id));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikacije'),
        actions: [
          if (_notifications.any((n) => n['isRead'] != true))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Pročitaj sve', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Greška: $_error'),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _loadNotifications, child: const Text('Pokušaj ponovo')),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Nemate notifikacija', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          final isRead = n['isRead'] == true;
                          return Dismissible(
                            key: Key(n['id'] ?? index.toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) => _deleteNotification(n['id']),
                            child: ListTile(
                              leading: Icon(
                                _getIcon(n['type']?.toString() ?? ''),
                                color: isRead ? Colors.grey : AppTheme.primaryColor,
                              ),
                              title: Text(
                                n['title']?.toString() ?? '',
                                style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n['content']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(n['createdAt']?.toString()),
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              tileColor: isRead ? null : Colors.blue.shade50,
                              onTap: () {
                                if (!isRead) _markAsRead(n['id']);
                              },
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'SystemAnnouncement': return Icons.campaign;
      case 'OrderUpdate': return Icons.shopping_cart;
      case 'EventChange': return Icons.event;
      case 'TicketIssued': return Icons.confirmation_number;
      case 'TicketCancelled': return Icons.cancel;
      default: return Icons.notifications;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    return '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
