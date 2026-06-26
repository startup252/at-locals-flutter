import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _stats;
  List<dynamic> _pendingUsers = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().user?.id ?? '';
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.getAdminStats(userId),
        ApiService.getAdminUsers(userId, page: 1),
      ]);
      final statsData = results[0] as Map<String, dynamic>;
      final usersData = results[1] as Map<String, dynamic>;
      final allUsers = (usersData['users'] as List?) ?? [];

      setState(() {
        _stats = statsData['stats'] as Map<String, dynamic>?;
        _pendingUsers = allUsers.where((u) => u['accountStatus'] == 'PENDING').toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Staff Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.hourglass_empty, size: 18), text: 'Pending'),
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Users'),
          ],
        ),
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
              : TabBarView(
                  controller: _tab,
                  children: [
                    _buildOverview(),
                    _buildPending(),
                    _buildUsers(),
                  ],
                ),
    );
  }

  Widget _buildOverview() {
    final s = _stats ?? {};
    final fmt = NumberFormat('#,##0');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Platform Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _statCard('Total Users', fmt.format(s['totalUsers'] ?? 0), Icons.people, const Color(0xFF2563EB)),
              _statCard('Properties', fmt.format(s['totalProperties'] ?? 0), Icons.home_work, const Color(0xFF059669)),
              _statCard('Bookings', fmt.format(s['totalBookings'] ?? 0), Icons.calendar_month, const Color(0xFFD97706)),
              _statCard('Pending', fmt.format(s['pendingApprovals'] ?? 0), Icons.hourglass_empty, const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                _actionTile(Icons.approval, 'Review Applications', 'Check pending HOST/BROKER', () => _tab.animateTo(1)),
                const Divider(height: 1),
                _actionTile(Icons.manage_accounts, 'Manage Users', 'View all platform users', () => _tab.animateTo(2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPending() {
    if (_pendingUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 56),
            SizedBox(height: 12),
            Text('No pending applications', style: TextStyle(fontSize: 16, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingUsers.length,
        itemBuilder: (_, i) {
          final u = _pendingUsers[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFF59E0B).withOpacity(0.15),
                  child: Text((u['name'] ?? u['email'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(u['email'] ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      Text('Role: ${u['role']}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('PENDING', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUsers() {
    final userId = context.read<AuthProvider>().user?.id ?? '';
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiService.getAdminUsers(userId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snap.data?['users'] as List? ?? [];
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.1),
                  child: Text((u['name'] ?? u['email'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold)),
                ),
                title: Text(u['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(u['email'] ?? '', style: const TextStyle(fontSize: 12)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(u['role'] ?? '', style: const TextStyle(color: Color(0xFF0EA5E9), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, String sub, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF0EA5E9)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }
}
