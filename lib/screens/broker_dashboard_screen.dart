import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';

// Blue · White · Black
const _kBlue   = Color(0xFF2563EB);
const _kBlueL  = Color(0xFFEFF6FF);
const _kBlack  = Color(0xFF111827);
const _kGrey   = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kBg     = Color(0xFFF9FAFB);

class BrokerDashboardScreen extends StatefulWidget {
  const BrokerDashboardScreen({super.key});
  @override
  State<BrokerDashboardScreen> createState() => _BrokerDashboardScreenState();
}

class _BrokerDashboardScreenState extends State<BrokerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _earnings = {};
  List<dynamic> _properties      = [];
  List<dynamic> _bids            = [];
  String? _selectedPropId;

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
      final r = await Future.wait([
        ApiService.getBrokerEarnings(uid),
        ApiService.getHostProperties(uid),
      ]);
      setState(() {
        _earnings   = r[0] as Map<String, dynamic>;
        _properties = r[1] as List<dynamic>;
        _loading    = false;
      });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _loadBids(String propId) async {
    setState(() { _selectedPropId = propId; _bids = []; });
    try {
      final bids = await ApiService.getPropertyBids(propId);
      setState(() => _bids = bids);
    } catch (_) {}
  }

  Future<void> _updateBid(String bidId, String status) async {
    final uid = context.read<AuthProvider>().user?.id ?? '';
    try {
      await ApiService.updateBidStatus(bidId, uid, status);
      _snack(status == 'PAYMENT_COLLECTED' ? 'Payment collected' : 'Bid rejected',
          status == 'PAYMENT_COLLECTED' ? Colors.green : Colors.red);
      if (_selectedPropId != null) _loadBids(_selectedPropId!);
    } catch (e) { _snack('Error: $e', Colors.red); }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  int get _pendingBidCount =>
      _bids.where((b) => (b['status'] as String? ?? '') == 'PENDING').length;

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
                  const Icon(Icons.business_center_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Broker Dashboard',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  GestureDetector(
                    onTap: _load,
                    child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                  ),
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
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                dividerColor: Colors.transparent,
                tabs: [
                  const Tab(text: 'Earnings'),
                  Tab(text: 'Properties (${_properties.length})'),
                  Tab(child: _tabBadge('Bids', _pendingBidCount)),
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
                      _earningsTab(), _propertiesTab(), _bidsTab(),
                    ]),
        ),
      ]),
    );
  }

  Widget _tabBadge(String label, int count) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label),
      if (count > 0) ...[
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
          child: Text('$count',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ],
    ],
  );

  // ─── Earnings ─────────────────────────────────────────────────────────
  Widget _earningsTab() {
    final fmt   = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final fmt2  = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final total   = (_earnings['totalEarned']  as num?)?.toDouble() ?? 0.0;
    final pending = (_earnings['pendingDebt']  as num?)?.toDouble() ?? 0.0;
    final paid    = (_earnings['paidDebt']     as num?)?.toDouble() ?? 0.0;
    final history = _earnings['commissionHistory'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      color: _kBlue,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        // Earnings summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Total Earned', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Text(fmt.format(total),
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 0),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _earningMini('Pending', fmt2.format(pending), Colors.orange)),
              Container(width: 1, height: 36, color: Colors.white24),
              Expanded(child: _earningMini('Paid Out', fmt2.format(paid), Colors.greenAccent)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),

        // Summary row
        Row(children: [
          Expanded(child: _miniCard('Properties', '${_properties.length}')),
          const SizedBox(width: 10),
          Expanded(child: _miniCard('Transactions', '${history.length}')),
        ]),
        const SizedBox(height: 18),

        // History list
        if (history.isNotEmpty) ...[
          const _Sec('COMMISSION HISTORY'),
          const SizedBox(height: 8),
          ...history.map((h) {
            final amount   = (h['commissionTotal'] as num?)?.toDouble() ?? 0.0;
            final status   = h['status']                as String? ?? '';
            final propName = h['property']?['name']     as String? ?? 'Property';
            final date     = h['createdAt']             as String? ?? '';
            final isPaid   = status == 'PAID';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPaid ? Icons.check_circle_outline : Icons.schedule_rounded,
                    color: isPaid ? Colors.green : Colors.orange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(propName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _kBlack),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (date.isNotEmpty)
                    Text(_fmtDate(date), style: const TextStyle(fontSize: 11, color: _kGrey)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fmt2.format(amount),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: _kBlue, fontSize: 13)),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(status,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                            color: isPaid ? Colors.green : Colors.orange)),
                  ),
                ]),
              ]),
            );
          }),
        ] else
          const _Empty('No commission history yet'),
      ]),
    );
  }

  // ─── Properties ───────────────────────────────────────────────────────
  Widget _propertiesTab() {
    if (_properties.isEmpty) {
      return const _EmptyPage(icon: Icons.home_work_outlined,
          title: 'No Properties', sub: 'Properties assigned to you appear here');
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: _kBlue,
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _properties.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final p    = _properties[i];
          final imgs = p['imageUrls'] as List? ?? [];
          final url  = imgs.isNotEmpty ? imgs[0] as String : null;
          final isMonthly = ['VILLA', 'VILLA_BACWEYNE', 'APARTMENT'].contains(p['type'] as String? ?? '');
          final price = (p['basePricePerNight'] as num?)?.toDouble() ?? 0.0;
          final fmt   = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

          return GestureDetector(
            onTap: () { _tab.animateTo(2); _loadBids(p['id'] as String); },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: Row(children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                  child: SizedBox(
                    width: 80, height: 80,
                    child: url != null
                        ? Image.network(url, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgBox())
                        : _imgBox(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['name'] as String? ?? 'Property',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _kBlack),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text('${p['city'] ?? ''}, ${p['country'] ?? ''}',
                        style: const TextStyle(fontSize: 11, color: _kGrey)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text('${fmt.format(price)}/${isMonthly ? 'mo' : 'night'}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: _kBlue, fontSize: 13)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: _kBlueL, borderRadius: BorderRadius.circular(5)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('View Bids', style: TextStyle(color: _kBlue, fontSize: 10, fontWeight: FontWeight.w600)),
                          SizedBox(width: 2),
                          Icon(Icons.arrow_forward_ios_rounded, size: 9, color: _kBlue),
                        ]),
                      ),
                    ]),
                  ]),
                )),
                const SizedBox(width: 10),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ─── Bids ─────────────────────────────────────────────────────────────
  Widget _bidsTab() {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return Column(children: [
      // Property selector
      if (_properties.isNotEmpty)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedPropId,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Select a property to view bids',
              hintStyle: const TextStyle(color: _kGrey, fontSize: 13),
              prefixIcon: const Icon(Icons.home_work_outlined, color: _kBlue, size: 18),
              filled: true, fillColor: _kBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
              isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: _properties.map((p) => DropdownMenuItem<String>(
              value: p['id'] as String,
              child: Text(p['name'] as String? ?? 'Property',
                  style: const TextStyle(fontSize: 13, color: _kBlack),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: (v) { if (v != null) _loadBids(v); },
          ),
        ),

      Expanded(
        child: _selectedPropId == null
            ? const _EmptyPage(
                icon: Icons.handshake_outlined,
                title: 'Select a Property',
                sub: 'Choose a property above to see its bids')
            : _bids.isEmpty
                ? const _Empty('No bids for this property yet')
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _bids.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final b      = _bids[i];
                      final status = b['status'] as String? ?? '';
                      final guest  = b['guest']  as Map? ?? {};
                      final isPending = status == 'PENDING';

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border(
                            left: BorderSide(color: _bidColor(status), width: 4),
                            top:    const BorderSide(color: _kBorder),
                            right:  const BorderSide(color: _kBorder),
                            bottom: const BorderSide(color: _kBorder),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: _kBlueL,
                                child: Text(
                                  (guest['name'] ?? guest['email'] ?? '?')[0].toString().toUpperCase(),
                                  style: const TextStyle(color: _kBlue, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(guest['name'] as String? ?? 'Guest',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _kBlack)),
                                if (b['bidderPhone'] != null)
                                  Text(b['bidderPhone'] as String,
                                      style: const TextStyle(fontSize: 11, color: _kGrey)),
                              ])),
                              _statusPill(status),
                            ]),
                            const SizedBox(height: 8),
                            const Divider(height: 0, color: _kBorder),
                            const SizedBox(height: 8),
                            Row(children: [
                              _infoItem('Check-in',
                                  b['checkIn'] != null ? _fmtDate(b['checkIn'] as String) : 'N/A'),
                              _infoItem('Check-out',
                                  b['checkOut'] != null ? _fmtDate(b['checkOut'] as String) : 'N/A'),
                              if (b['totalAmount'] != null)
                                _infoItem('Amount',
                                    fmt.format((b['totalAmount'] as num).toDouble())),
                            ]),
                            if (isPending) ...[
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _dlg('Reject Bid',
                                        'Reject bid from ${guest['name'] ?? 'guest'}?',
                                        'Reject', Colors.red, () => _updateBid(b['id'] as String, 'REJECTED')),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _dlg('Collect Payment',
                                        'Confirm payment from ${guest['name'] ?? 'guest'}?',
                                        'Collect', _kBlue, () => _updateBid(b['id'] as String, 'PAYMENT_COLLECTED')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _kBlue, foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 9), elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Collect Payment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ),
                                ),
                              ]),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }

  Future<void> _dlg(String title, String body, String action, Color color, VoidCallback onOk) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: _kBlack)),
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

  Widget _earningMini(String label, String value, Color color) => Column(children: [
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
  ]);

  Widget _miniCard(String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
    child: Row(children: [
      const Icon(Icons.circle, color: _kBlue, size: 8),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: _kGrey))),
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kBlue)),
    ]),
  );

  Widget _infoItem(String label, String value) => Expanded(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: _kGrey)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kBlack),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ],
  ));

  Widget _statusPill(String status) {
    Color color;
    switch (status) {
      case 'PENDING':           color = Colors.orange; break;
      case 'PAYMENT_COLLECTED': color = Colors.green; break;
      case 'REJECTED':          color = Colors.red; break;
      default:                  color = _kGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Color _bidColor(String s) {
    switch (s) {
      case 'PENDING':           return Colors.orange;
      case 'PAYMENT_COLLECTED': return Colors.green;
      case 'REJECTED':          return Colors.red;
      default:                  return _kBorder;
    }
  }

  Widget _imgBox() => Container(color: _kBg,
      child: const Icon(Icons.home_work_outlined, color: _kBorder, size: 26));

  String _fmtDate(String iso) {
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(iso)); } catch (_) { return iso; }
  }
}

// ─── Shared small widgets ───────────────────────────────────────────────────
class _Sec extends StatelessWidget {
  final String text;
  const _Sec(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGrey, letterSpacing: 0.5));
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Center(child: Text(text, style: const TextStyle(color: _kGrey)));
}

class _EmptyPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _EmptyPage({required this.icon, required this.title, required this.sub});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: _kBlueL, shape: BoxShape.circle),
      child: Icon(icon, size: 40, color: _kBlue),
    ),
    const SizedBox(height: 14),
    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kBlack)),
    const SizedBox(height: 6),
    Text(sub, style: const TextStyle(fontSize: 12, color: _kGrey), textAlign: TextAlign.center),
  ]));
}
