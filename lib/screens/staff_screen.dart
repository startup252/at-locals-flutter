import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';

const _kBlue   = Color(0xFF2563EB);
const _kBlueL  = Color(0xFFEFF6FF);
const _kBlack  = Color(0xFF111827);
const _kGrey   = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kBg     = Color(0xFFF9FAFB);

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
  List<dynamic> _pending  = [];
  List<dynamic> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().user?.id ?? '';
    setState(() { _loading = true; _error = null; });
    try {
      final statsMap = await ApiService.getAdminStats(uid);
      final usersMap = await ApiService.getAdminUsers(uid, page: 1);
      final all = usersMap['users'] as List? ?? [];
      setState(() {
        _stats    = statsMap['stats'] as Map<String, dynamic>?;
        _allUsers = all;
        _pending  = all.where((u) => u['accountStatus'] == 'PENDING').toList();
        _loading  = false;
      });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        // Blue header
        Container(
          color: _kBlue,
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(children: [
                  const Icon(Icons.support_agent_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Staff Dashboard',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  GestureDetector(onTap: _load,
                      child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20)),
                ]),
              ),
              const SizedBox(height: 10),
              TabBar(
                controller: _tab,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                dividerColor: Colors.transparent,
                tabs: [
                  const Tab(text: 'Overview'),
                  Tab(child: _badge('Pending', _pending.length)),
                  Tab(text: 'Users (${_allUsers.length})'),
                ],
              ),
            ]),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kBlue))
              : _error != null
                  ? _errView()
                  : TabBarView(controller: _tab, children: [
                      _overview(), _pendingTab(), _usersTab(),
                    ]),
        ),
      ]),
    );
  }

  Widget _badge(String label, int count) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(label),
    if (count > 0) ...[
      const SizedBox(width: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    ],
  ]);

  Widget _overview() {
    final s   = _stats ?? {};
    final fmt = NumberFormat('#,##0');
    return RefreshIndicator(
      onRefresh: _load, color: _kBlue,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        GridView.count(
          crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
          childAspectRatio: 1.6, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _statCard('Users',      fmt.format(s['totalUsers']      ?? 0)),
            _statCard('Properties', fmt.format(s['totalProperties'] ?? 0)),
            _statCard('Bookings',   fmt.format(s['totalBookings']   ?? 0)),
            _statCard('Pending',    fmt.format(s['pendingApprovals'] ?? 0)),
          ],
        ),
        const SizedBox(height: 14),
        if (_pending.isNotEmpty) ...[
          _infoBanner('${_pending.length} application(s) waiting for review', () => _tab.animateTo(1)),
          const SizedBox(height: 12),
        ],
        const _Sec('QUICK ACTIONS'),
        const SizedBox(height: 8),
        _actionRow(Icons.approval_rounded,      'Review Applications', () => _tab.animateTo(1)),
        const SizedBox(height: 6),
        _actionRow(Icons.manage_accounts_rounded, 'Manage Users',      () => _tab.animateTo(2)),
      ]),
    );
  }

  Widget _pendingTab() {
    if (_pending.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, color: Colors.green, size: 52),
        SizedBox(height: 12),
        Text('No pending applications', style: TextStyle(color: _kGrey, fontSize: 15)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _load, color: _kBlue,
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final u    = _pending[i];
          final role = u['role'] as String? ?? '';
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: _kBlue, width: 4),
                  top: const BorderSide(color: _kBorder),
                  right: const BorderSide(color: _kBorder),
                  bottom: const BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _kBlueL,
                child: Text(
                  (u['name'] ?? u['email'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: _kBlue, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _kBlack)),
                Text(u['email'] ?? '',
                    style: const TextStyle(color: _kGrey, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                _pillBlue(role),
              ])),
              _pillOrange('PENDING'),
            ]),
          );
        },
      ),
    );
  }

  Widget _usersTab() {
    if (_allUsers.isEmpty) {
      return const Center(child: Text('No users found', style: TextStyle(color: _kGrey)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _allUsers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final u    = _allUsers[i];
        final role = u['role'] as String? ?? '';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 17, backgroundColor: _kBlueL,
              child: Text((u['name'] ?? u['email'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: _kBlue, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u['name'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _kBlack),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(u['email'] ?? '',
                  style: const TextStyle(fontSize: 11, color: _kGrey),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            _pillBlue(role),
          ]),
        );
      },
    );
  }

  Widget _errView() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, color: Colors.red, size: 44),
    const SizedBox(height: 10),
    Text(_error!, style: const TextStyle(color: _kGrey, fontSize: 13)),
    const SizedBox(height: 14),
    ElevatedButton(onPressed: _load,
        style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
        child: const Text('Retry')),
  ]));

  Widget _statCard(String label, String value) => Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: _kGrey, fontWeight: FontWeight.w500)),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kBlue)),
    ]),
  );

  Widget _infoBanner(String msg, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kBlueL, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBlue.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: _kBlue, size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: _kBlue, fontWeight: FontWeight.w600, fontSize: 12))),
        const Icon(Icons.arrow_forward_ios_rounded, color: _kBlue, size: 11),
      ]),
    ),
  );

  Widget _actionRow(IconData icon, String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: _kBlueL, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: _kBlue, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _kBlack))),
        const Icon(Icons.chevron_right_rounded, color: _kGrey, size: 18),
      ]),
    ),
  );

  Widget _pillBlue(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: _kBlueL, borderRadius: BorderRadius.circular(5)),
    child: Text(label, style: const TextStyle(color: _kBlue, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  Widget _pillOrange(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
    child: Text(label, style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}

class _Sec extends StatelessWidget {
  final String text;
  const _Sec(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGrey, letterSpacing: 0.5));
}
