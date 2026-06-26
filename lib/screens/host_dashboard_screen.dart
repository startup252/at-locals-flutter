import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../models/property.dart';
import '../config.dart';

const _kBlue   = Color(0xFF2563EB);
const _kBlueL  = Color(0xFFEFF6FF);
const _kBlack  = Color(0xFF111827);
const _kGrey   = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kBg     = Color(0xFFF9FAFB);

class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key});
  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = true;
  String? _error;

  List<Property> _props    = [];
  List<dynamic>  _bookings = [];

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
        ApiService.getHostProperties(uid),
        ApiService.getHostBookings(uid),
      ]);
      final props = r[0] as List<dynamic>;
      final bData = r[1] as Map<String, dynamic>;
      setState(() {
        _props    = props.map((p) => Property.fromJson(p as Map<String, dynamic>)).toList();
        _bookings = bData['bookings'] as List? ?? [];
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
                  const Icon(Icons.home_work_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Host Dashboard',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/add-property'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add, color: _kBlue, size: 14),
                        SizedBox(width: 4),
                        Text('Add', style: TextStyle(color: _kBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                  Tab(text: 'Properties (${_props.length})'),
                  Tab(text: 'Bookings (${_bookings.length})'),
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
                      _overview(), _propertiesTab(), _bookingsTab(),
                    ]),
        ),
      ]),
    );
  }

  // ─── Overview ─────────────────────────────────────────────────────────
  Widget _overview() {
    final fmt  = NumberFormat('#,##0');
    final fmtD = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final totalRevenue = _bookings.fold<double>(0, (sum, b) {
      final s = b['status'] as String? ?? '';
      if (s == 'CONFIRMED' || s == 'COMPLETED') {
        return sum + ((b['totalAmount'] as num?)?.toDouble() ?? 0.0);
      }
      return sum;
    });
    final totalRooms = _props.fold<int>(0, (sum, p) => sum + p.roomCount);

    return RefreshIndicator(
      onRefresh: _load, color: _kBlue,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        GridView.count(
          crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
          childAspectRatio: 1.6, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _statCard('Properties', fmt.format(_props.length)),
            _statCard('Bookings',   fmt.format(_bookings.length)),
            _statCard('Revenue',    fmtD.format(totalRevenue)),
            _statCard('Rooms',      fmt.format(totalRooms)),
          ],
        ),
        const SizedBox(height: 14),
        const _Sec('QUICK ACTIONS'),
        const SizedBox(height: 8),
        _actionRow(Icons.add_home_rounded,       'Add New Property', () => context.push('/add-property')),
        const SizedBox(height: 6),
        _actionRow(Icons.home_work_rounded,      'My Properties',    () => _tab.animateTo(1)),
        const SizedBox(height: 6),
        _actionRow(Icons.calendar_month_rounded, 'My Bookings',      () => _tab.animateTo(2)),
        if (_props.isNotEmpty) ...[
          const SizedBox(height: 18),
          const _Sec('MY PROPERTIES'),
          const SizedBox(height: 8),
          ..._props.take(3).map((p) => _miniPropRow(p)),
          if (_props.length > 3) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _tab.animateTo(1),
              child: const Center(child: Text('View all →',
                  style: TextStyle(color: _kBlue, fontWeight: FontWeight.w600, fontSize: 12))),
            ),
          ],
        ],
      ]),
    );
  }

  Widget _miniPropRow(Property p) {
    final img = p.imageUrls.isNotEmpty ? p.imageUrls[0] : null;
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 44, height: 44,
            child: img != null
                ? Image.network(_fullUrl(img), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imgBox())
                : _imgBox(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _kBlack),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(p.city, style: const TextStyle(fontSize: 11, color: _kGrey)),
        ])),
        Text('${fmt.format(p.basePricePerNight)}/${p.priceUnit}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: _kBlue, fontSize: 12)),
      ]),
    );
  }

  // ─── Properties ───────────────────────────────────────────────────────
  Widget _propertiesTab() {
    if (_props.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: _kBlueL, shape: BoxShape.circle),
          child: const Icon(Icons.home_work_outlined, size: 40, color: _kBlue),
        ),
        const SizedBox(height: 14),
        const Text('No properties yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kBlack)),
        const SizedBox(height: 6),
        const Text('Add your first property to get started', style: TextStyle(color: _kGrey, fontSize: 12)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => context.push('/add-property'),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Property'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kBlue, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _load, color: _kBlue,
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _props.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final p   = _props[i];
          final img = p.imageUrls.isNotEmpty ? p.imageUrls[0] : null;
          final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
          return Container(
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                child: SizedBox(
                  width: 90, height: 90,
                  child: img != null
                      ? Image.network(_fullUrl(img), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imgBox())
                      : _imgBox(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _kBlack),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(p.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold,
                              color: p.isActive ? Colors.green : _kGrey)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text('${p.city}, ${p.country}', style: const TextStyle(fontSize: 11, color: _kGrey)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text('${fmt.format(p.basePricePerNight)}/${p.priceUnit}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: _kBlue, fontSize: 13)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push('/host/properties/${p.id}/edit'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _kBlueL, borderRadius: BorderRadius.circular(6)),
                        child: const Text('Edit', style: TextStyle(color: _kBlue, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ]),
              )),
              const SizedBox(width: 10),
            ]),
          );
        },
      ),
    );
  }

  // ─── Bookings ─────────────────────────────────────────────────────────
  Widget _bookingsTab() {
    if (_bookings.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.calendar_month_outlined, color: _kBorder, size: 52),
        SizedBox(height: 12),
        Text('No bookings yet', style: TextStyle(color: _kGrey, fontSize: 15)),
      ]));
    }
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return RefreshIndicator(
      onRefresh: _load, color: _kBlue,
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final b      = _bookings[i];
          final guest  = b['guest'] as Map? ?? {};
          final prop   = b['property'] as Map? ?? {};
          final status = b['status'] as String? ?? '';
          final amount = (b['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final checkIn  = b['checkIn']  as String? ?? '';
          final checkOut = b['checkOut'] as String? ?? '';

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                  radius: 16, backgroundColor: _kBlueL,
                  child: Text(
                    (guest['name'] ?? guest['email'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: _kBlue, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(guest['name'] ?? 'Guest',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _kBlack),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(prop['name'] as String? ?? 'Property',
                      style: const TextStyle(fontSize: 11, color: _kGrey),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                _statusPill(status),
              ]),
              const SizedBox(height: 8),
              const Divider(height: 0, color: _kBorder),
              const SizedBox(height: 8),
              Row(children: [
                _info('Check-in',  checkIn.isNotEmpty  ? _fmtDate(checkIn)  : 'N/A'),
                _info('Check-out', checkOut.isNotEmpty ? _fmtDate(checkOut) : 'N/A'),
                _info('Amount',    fmt.format(amount)),
              ]),
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
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: _kGrey, fontWeight: FontWeight.w500)),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kBlue)),
    ]),
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

  Widget _info(String label, String value) => Expanded(child: Column(
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
      case 'CONFIRMED':  color = Colors.green; break;
      case 'PENDING':    color = Colors.orange; break;
      case 'CANCELLED':  color = Colors.red; break;
      case 'COMPLETED':  color = _kBlue; break;
      default:           color = _kGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _imgBox() => Container(color: _kBg, child: const Icon(Icons.home_work_outlined, color: _kBorder, size: 26));

  String _fullUrl(String url) =>
      url.startsWith('http') ? url : '$kBaseUrl$url';

  String _fmtDate(String iso) {
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(iso)); } catch (_) { return iso; }
  }
}

class _Sec extends StatelessWidget {
  final String text;
  const _Sec(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGrey, letterSpacing: 0.5));
}
