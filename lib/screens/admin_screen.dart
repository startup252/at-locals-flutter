import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';

// ─── Brand palette: Blue · White · Black ───────────────────────────────────
const _kBlue   = Color(0xFF2563EB);
const _kBlueL  = Color(0xFFEFF6FF);   // light blue tint
const _kBlack  = Color(0xFF111827);
const _kGrey   = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kBg     = Color(0xFFF9FAFB);

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _stats = {};
  List<dynamic> _users        = [];
  List<dynamic> _pending      = [];
  List<dynamic> _bids         = [];
  int _totalUsers             = 0;
  String _roleFilter          = '';
  final _searchCtrl           = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() { _tab.dispose(); _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final id = context.read<AuthProvider>().user?.id ?? '';
    setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([
        ApiService.getAdminStats(id),
        ApiService.getAdminUsers(id, page: 1),
        ApiService.getAdminUsers(id, role: 'HOST',   page: 1),
        ApiService.getAdminUsers(id, role: 'BROKER', page: 1),
        ApiService.getAdminBidApprovals(id),
      ]);
      final statsData  = r[0] as Map<String, dynamic>;
      final allData    = r[1] as Map<String, dynamic>;
      final hostData   = r[2] as Map<String, dynamic>;
      final brokerData = r[3] as Map<String, dynamic>;
      final bidsData   = r[4] as List<dynamic>;

      final allUsers    = allData['users']    as List? ?? [];
      final hostUsers   = hostData['users']   as List? ?? [];
      final brokerUsers = brokerData['users'] as List? ?? [];
      setState(() {
        _stats      = statsData['stats'] as Map<String, dynamic>? ?? {};
        _users      = allUsers;
        _totalUsers = allData['total'] as int? ?? allUsers.length;
        _pending    = [
          ...hostUsers.where((u)   => u['accountStatus'] == 'PENDING'),
          ...brokerUsers.where((u) => u['accountStatus'] == 'PENDING'),
        ];
        _bids    = bidsData;
        _loading = false;
      });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _filterUsers() async {
    final id = context.read<AuthProvider>().user?.id ?? '';
    setState(() => _loading = true);
    try {
      final data = await ApiService.getAdminUsers(id,
          role: _roleFilter, search: _searchCtrl.text.trim());
      setState(() {
        _users      = data['users'] as List? ?? [];
        _totalUsers = data['total'] as int? ?? _users.length;
        _loading    = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _approve(String userId, String status) async {
    final id = context.read<AuthProvider>().user?.id ?? '';
    try {
      await ApiService.approveUser(id, userId, accountStatus: status);
      _snack(status == 'APPROVED' ? 'Approved' : 'Rejected',
          status == 'APPROVED' ? Colors.green : Colors.red);
      _load();
    } catch (e) { _snack('Error: $e', Colors.red); }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────
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
              // Title row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(children: [
                  const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Admin Dashboard',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  GestureDetector(
                    onTap: _load,
                    child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              // Tabs on blue
              TabBar(
                controller: _tab,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                dividerColor: Colors.transparent,
                tabs: [
                  const Tab(text: 'Overview'),
                  Tab(text: 'Users ($_totalUsers)'),
                  Tab(child: _tabBadge('Approvals', _pending.length, Colors.orange)),
                  Tab(child: _tabBadge('Bids', _bids.length, Colors.white70)),
                ],
              ),
            ]),
          ),
        ),

        // Body
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kBlue))
              : _error != null
                  ? _errView()
                  : TabBarView(controller: _tab, children: [
                      _overview(), _usersTab(), _approvalsTab(), _bidsTab(),
                    ]),
        ),
      ]),
    );
  }

  Widget _tabBadge(String label, int count, Color badgeColor) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label),
      if (count > 0) ...[
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10)),
          child: Text('$count',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ],
    ],
  );

  // ─── Overview ─────────────────────────────────────────────────────────
  Widget _overview() {
    final fmt  = NumberFormat('#,##0');
    final fmtD = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return RefreshIndicator(
      onRefresh: _load,
      color: _kBlue,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        // Stat cards
        GridView.count(
          crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
          childAspectRatio: 1.6, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _statCard('Users',      fmt.format(_stats['totalUsers']      ?? 0)),
            _statCard('Properties', fmt.format(_stats['totalProperties'] ?? 0)),
            _statCard('Bookings',   fmt.format(_stats['totalBookings']   ?? 0)),
            _statCard('Revenue',    fmtD.format(_stats['totalRevenue']   ?? 0.0)),
          ],
        ),
        const SizedBox(height: 14),

        // Pending banner
        if ((_stats['pendingApprovals'] ?? 0) > 0) ...[
          _banner('${_stats['pendingApprovals']} pending application(s) — tap to review',
              () => _tab.animateTo(2)),
          const SizedBox(height: 12),
        ],

        // Quick actions
        const _Sec('QUICK ACTIONS'),
        const SizedBox(height: 8),
        _action(Icons.approval_rounded,  'Review Approvals', () => _tab.animateTo(2)),
        const SizedBox(height: 6),
        _action(Icons.people_rounded,    'All Users',        () => _tab.animateTo(1)),
        const SizedBox(height: 6),
        _action(Icons.handshake_rounded, 'Bid History',      () => _tab.animateTo(3)),
      ]),
    );
  }

  // ─── Users ────────────────────────────────────────────────────────────
  Widget _usersTab() => Column(children: [
    Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(children: [
        // Search
        TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 13, color: _kBlack),
          decoration: InputDecoration(
            hintText: 'Search name or email...',
            hintStyle: const TextStyle(color: _kGrey, fontSize: 13),
            prefixIcon: const Icon(Icons.search, size: 18, color: _kGrey),
            suffixIcon: GestureDetector(
              onTap: _filterUsers,
              child: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(6)),
                child: const Text('Search',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
            filled: true, fillColor: _kBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
            isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onSubmitted: (_) => _filterUsers(),
        ),
        const SizedBox(height: 8),
        // Role filter chips
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [for (final r in ['', 'GUEST', 'HOST', 'BROKER', 'STAFF', 'ADMIN'])
              _roleChip(r)],
          ),
        ),
      ]),
    ),
    Container(
      color: _kBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        Text('$_totalUsers user${_totalUsers != 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 12, color: _kGrey)),
      ]),
    ),
    Expanded(
      child: _users.isEmpty
          ? const Center(child: Text('No users found', style: TextStyle(color: _kGrey)))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) => _userRow(_users[i]),
            ),
    ),
  ]);

  Widget _roleChip(String role) {
    final selected = _roleFilter == role;
    final label    = role.isEmpty ? 'All' : role;
    return GestureDetector(
      onTap: () { setState(() => _roleFilter = role); _filterUsers(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _kBlue : _kBorder),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : _kGrey,
        )),
      ),
    );
  }

  Widget _userRow(dynamic u) {
    final role   = u['role']          as String? ?? '';
    final status = u['accountStatus'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: _kBlueL,
          child: Text(
            (u['name'] ?? u['email'] ?? '?')[0].toUpperCase(),
            style: const TextStyle(color: _kBlue, fontWeight: FontWeight.bold, fontSize: 15),
          ),
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
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _pill(role, _kBlue),
          if (status == 'PENDING') ...[
            const SizedBox(height: 3), _pill('PENDING', Colors.orange),
          ] else if (status == 'APPROVED') ...[
            const SizedBox(height: 3), _pill('ACTIVE', Colors.green),
          ],
        ]),
      ]),
    );
  }

  // ─── Approvals ────────────────────────────────────────────────────────
  Widget _approvalsTab() {
    if (_pending.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, color: Colors.green, size: 52),
        SizedBox(height: 12),
        Text('No pending applications', style: TextStyle(color: _kGrey, fontSize: 15)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: _kBlue,
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final u    = _pending[i];
          final role = u['role'] as String? ?? '';
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: _kBlue, width: 4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _kBlack)),
                    Text(u['email'] ?? '',
                        style: const TextStyle(color: _kGrey, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  _pill(role, _kBlue),
                ]),
                if (u['phone'] != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.phone_outlined, size: 13, color: _kGrey),
                    const SizedBox(width: 4),
                    Text(u['phone'] as String, style: const TextStyle(fontSize: 12, color: _kGrey)),
                  ]),
                ],
                const SizedBox(height: 12),
                const Divider(height: 0, color: _kBorder),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _dlg(
                        'Reject',
                        'Reject ${u['name'] ?? 'this user'}\'s application?',
                        'Reject', Colors.red, () => _approve(u['id'] as String, 'REJECTED'),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _dlg(
                        'Approve',
                        'Approve ${u['name'] ?? 'this user'} as ${role == 'HOST' ? 'a Host' : 'a Broker'}?',
                        'Approve', _kBlue, () => _approve(u['id'] as String, 'APPROVED'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10), elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _dlg(String title, String body, String action, Color color, VoidCallback onOk) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kBlack)),
        content: Text(body, style: const TextStyle(color: _kGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: _kGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(action),
          ),
        ],
      ),
    );
    if (ok == true) onOk();
  }

  // ─── Bids ─────────────────────────────────────────────────────────────
  Widget _bidsTab() {
    if (_bids.isEmpty) {
      return const Center(child: Text('No bids yet', style: TextStyle(color: _kGrey)));
    }
    final fmtD = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return RefreshIndicator(
      onRefresh: _load,
      color: _kBlue,
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _bids.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final b      = _bids[i];
          final prop   = b['property'] as Map? ?? {};
          final guest  = b['guest']   as Map? ?? {};
          final broker = b['broker']  as Map? ?? {};
          final status = b['status']  as String? ?? '';
          final imgs   = prop['imageUrls'] as List? ?? [];
          final imgUrl = imgs.isNotEmpty ? imgs[0] as String : null;
          final price  = (prop['basePricePerNight'] as num?)?.toDouble() ?? 0.0;

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Property image
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 60, height: 60,
                  child: imgUrl != null
                      ? Image.network(imgUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imgBox())
                      : _imgBox(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(prop['name'] as String? ?? 'Property',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _kBlack),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  _statusPill(status),
                ]),
                const SizedBox(height: 2),
                Text(prop['city'] as String? ?? '',
                    style: const TextStyle(fontSize: 11, color: _kGrey)),
                Text('Guest: ${guest['name'] ?? guest['email'] ?? 'N/A'}  ·  Broker: ${broker['name'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 11, color: _kGrey),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  if (b['bidderPhone'] != null) ...[
                    const Icon(Icons.phone_outlined, size: 11, color: _kGrey),
                    const SizedBox(width: 3),
                    Text(b['bidderPhone'] as String,
                        style: const TextStyle(fontSize: 11, color: _kGrey)),
                  ],
                  const Spacer(),
                  if (price > 0)
                    Text(fmtD.format(price),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: _kBlue, fontSize: 13)),
                ]),
              ])),
            ]),
          );
        },
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────
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
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _kBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: _kGrey, fontWeight: FontWeight.w500)),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kBlue)),
    ]),
  );

  Widget _banner(String msg, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kBlueL,
        borderRadius: BorderRadius.circular(8),
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

  Widget _action(IconData icon, String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: _kBlueL, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: _kBlue, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _kBlack))),
        const Icon(Icons.chevron_right_rounded, color: _kGrey, size: 18),
      ]),
    ),
  );

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  Widget _statusPill(String status) {
    Color color;
    switch (status) {
      case 'PENDING':        color = Colors.orange; break;
      case 'RENTED':
      case 'ADMIN_APPROVED': color = Colors.green; break;
      case 'REJECTED':       color = Colors.red; break;
      default:               color = _kGrey;
    }
    return _pill(status, color);
  }

  Widget _imgBox() => Container(
    color: _kBg,
    child: const Icon(Icons.home_work_outlined, color: _kBorder, size: 26),
  );
}

class _Sec extends StatelessWidget {
  final String text;
  const _Sec(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: _kGrey, letterSpacing: 0.5));
}
