import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _notifications = [];
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().user?.id ?? '';
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getNotifications(userId);
      setState(() {
        _notifications = data['notifications'] as List? ?? [];
        _unread = (data['unread'] as int?) ?? 0;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _markAllRead() async {
    final userId = context.read<AuthProvider>().user?.id ?? '';
    try {
      await ApiService.markNotificationRead(userId);
      setState(() {
        _notifications = _notifications.map((n) {
          final m = Map<String, dynamic>.from(n as Map);
          m['isRead'] = true;
          return m;
        }).toList();
        _unread = 0;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _markRead(String id, int index) async {
    final userId = context.read<AuthProvider>().user?.id ?? '';
    try {
      await ApiService.markNotificationRead(userId, notifId: id);
      setState(() {
        final m = Map<String, dynamic>.from(_notifications[index] as Map);
        m['isRead'] = true;
        _notifications[index] = m;
        if (_unread > 0) _unread--;
      });
    } catch (_) {}
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'BOOKING': return Icons.calendar_month;
      case 'USER': return Icons.person;
      case 'PAYMENT': return Icons.payments;
      case 'SYSTEM': return Icons.settings;
      default: return Icons.notifications;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'BOOKING': return const Color(0xFF2563EB);
      case 'USER': return const Color(0xFF7C3AED);
      case 'PAYMENT': return const Color(0xFF059669);
      case 'SYSTEM': return const Color(0xFF64748B);
      default: return const Color(0xFF0EA5E9);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                child: Text('$_unread', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAllRead,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Mark all read', style: TextStyle(fontSize: 13)),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[400], size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Colors.red[400])),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ))
              : _notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 64, color: Color(0xFF94A3B8)),
                          SizedBox(height: 16),
                          Text('No notifications yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          SizedBox(height: 8),
                          Text("You're all caught up!", style: TextStyle(color: Color(0xFF64748B))),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _notifications.length,
                        itemBuilder: (_, i) {
                          final n = _notifications[i] as Map;
                          final isRead = n['isRead'] as bool? ?? false;
                          final type = n['type'] as String? ?? '';
                          final color = _typeColor(type);
                          final icon = _typeIcon(type);
                          final createdAt = n['createdAt'] != null
                              ? DateTime.tryParse(n['createdAt'].toString())
                              : null;
                          final timeStr = createdAt != null
                              ? DateFormat('MMM d · h:mm a').format(createdAt.toLocal())
                              : '';

                          return InkWell(
                            onTap: () {
                              if (!isRead) _markRead(n['id'] as String, i);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isRead ? Colors.white : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(14),
                                border: isRead ? null : Border.all(color: const Color(0xFF93C5FD).withOpacity(0.5)),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(icon, color: color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(n['title'] as String? ?? '',
                                                  style: TextStyle(
                                                    fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                                    fontSize: 14,
                                                    color: const Color(0xFF0F172A),
                                                  )),
                                            ),
                                            if (!isRead)
                                              Container(
                                                width: 8, height: 8,
                                                decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(n['body'] as String? ?? '',
                                            style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                                            maxLines: 3, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text(timeStr,
                                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
