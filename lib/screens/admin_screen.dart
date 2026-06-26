import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _stats;
  List<dynamic> _users = [];
  List<dynamic> _pendingUsers = [];
  List<dynamic> _bids = [];

  String _userRoleFilter = '';
  String _userSearch = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().user?.id ?? '';
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.getAdminStats(userId),
        ApiService.getAdminUsers(userId, page: 1),
        ApiService.getAdminUsers(userId, role: 'HOST', page: 1),
        ApiService.getAdminBidApprovals(userId),
      ]);
      final statsData  = results[0] as Map<String, dynamic>;
      final usersData  = results[1] as Map<String, dynamic>;
      final pendData   = results[2] as Map<String, dynamic>;
      final bidsData   = results[3] as List<dynamic>;

      // Combine HOST + BROKER pending from stats
      final allUsers = usersData['users'] as List? ?? [];
      final brokerData = await ApiService.getAdminUsers(userId, role: 'BROKER', page: 1);
      final brokerUsers = brokerData['users'] as List? ?? [];

      setState(() {
        _stats = statsData['stats'] as Map<String, dynamic>?;
        _users = allUsers;
        _pendingUsers = [
          ...(pendData['users'] as List? ?? []).where((u) => u['accountStatus'] == 'PENDING'),
          ...brokerUsers.where((u) => u['accountStatus'] == 'PENDING'),
        ];
        _bids = bidsData;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _approveUser(String userId, String status) async {
    final actorId = context.read<AuthProvider>().user?.id ?? '';
    try {
      await ApiService.approveUser(actorId, userId, accountStatus: status);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _searchUsers() async {
    final userId = context.read<AuthProvider>().user?.id ?? '';
    setState(() => _loading = true);
    try {
      final data = await ApiService.getAdminUsers(
        userId,
        role: _userRoleFilter,
        search: _userSearch,
      );
      setState(() { _users = data['users'] as List? ?? []; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Users'),
            Tab(icon: Icon(Icons.approval_outlined, size: 18), text: 'Pending'),
            Tab(icon: Icon(Icons.handshake_outlined, size: 18), text: 'Bids'),
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
                    _buildUsers(),
                    _buildPending(),
                    _buildBids(),
                  ],
                ),
    );
  }

  Widget _buildOverview() {
    final s = _stats ?? {};
    final fmt = NumberFormat('#,##0');
    final fmtD = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Platform Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
              _statCard('Revenue', fmtD.format((s['totalRevenue'] ?? 0.0)), Icons.attach_money, const Color(0xFF7C3AED)),
            ],
          ),
          const SizedBox(height: 16),
          _infoCard('Pending Approvals', '${s['pendingApprovals'] ?? 0} HOST/BROKER applications waiting', Icons.hourglass_empty, const Color(0xFFF59E0B)),
          const SizedBox(height: 8),
          _infoCard('Active Properties', '${s['activeProperties'] ?? 0} listings currently active', Icons.check_circle_outline, const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildUsers() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, size: 20),
                    onPressed: () { _userSearch = _searchCtrl.text; _searchUsers(); },
                  ),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (v) { _userSearch = v; _searchUsers(); },
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['', 'GUEST', 'HOST', 'BROKER', 'STAFF', 'ADMIN'].map((r) =>
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(r.isEmpty ? 'All' : r, style: const TextStyle(fontSize: 12)),
                        selected: _userRoleFilter == r,
                        selectedColor: const Color(0xFF7C3AED),
                        labelStyle: TextStyle(color: _userRoleFilter == r ? Colors.white : const Color(0xFF475569)),
                        onSelected: (_) { _userRoleFilter = r; _searchUsers(); },
                      ),
                    ),
                  ).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? const Center(child: Text('No users found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _users.length,
                  itemBuilder: (_, i) => _userTile(_users[i]),
                ),
        ),
      ],
    );
  }

  Widget _userTile(dynamic u) {
    final roleColor = _roleColor(u['role'] ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: roleColor.withOpacity(0.15),
            backgroundImage: (u['avatarUrl'] != null && (u['avatarUrl'] as String).isNotEmpty)
                ? NetworkImage(u['avatarUrl'] as String)
                : null,
            child: (u['avatarUrl'] == null || (u['avatarUrl'] as String).isEmpty)
                ? Text((u['name'] ?? u['email'] ?? '?')[0].toUpperCase(),
                    style: TextStyle(color: roleColor, fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u['name'] ?? u['email'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(u['email'] ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(u['role'] ?? '', style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              if (u['accountStatus'] != null)
                Text(u['accountStatus'], style: TextStyle(
                  color: u['accountStatus'] == 'APPROVED' ? Colors.green[600] : Colors.orange[600],
                  fontSize: 11,
                )),
            ],
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
              border: Border.all(color: const Color(0xFFFEF3C7)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFF59E0B).withOpacity(0.15),
                      child: Text((u['name'] ?? u['email'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(u['email'] ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          Text('Applied as: ${u['role']}',
                              style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _approveUser(u['id'], 'REJECTED'),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[600],
                          side: BorderSide(color: Colors.red[300]!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveUser(u['id'], 'APPROVED'),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBids() {
    if (_bids.isEmpty) {
      return const Center(child: Text('No bids yet', style: TextStyle(color: Color(0xFF64748B))));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bids.length,
      itemBuilder: (_, i) {
        final b = _bids[i];
        final prop = b['property'] as Map? ?? {};
        final guest = b['guest'] as Map? ?? {};
        final broker = b['broker'] as Map? ?? {};
        final status = b['status'] as String? ?? '';
        final statusColor = status == 'PENDING'
            ? Colors.orange
            : status == 'ADMIN_APPROVED'
                ? Colors.green
                : Colors.red;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(prop['name'] ?? 'Property',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Guest: ${guest['name'] ?? guest['email'] ?? 'N/A'}',
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
              Text('Broker: ${broker['name'] ?? broker['email'] ?? 'N/A'}',
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
              if (b['bidderPhone'] != null)
                Text('Phone: ${b['bidderPhone']}',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ],
          ),
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

  Widget _infoCard(String title, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(sub, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'SUPER_ADMIN': return const Color(0xFF7C3AED);
      case 'ADMIN': return const Color(0xFF7C3AED);
      case 'STAFF': return const Color(0xFF0EA5E9);
      case 'HOST': return const Color(0xFF2563EB);
      case 'BROKER': return const Color(0xFF4F46E5);
      default: return const Color(0xFF10B981);
    }
  }
}
