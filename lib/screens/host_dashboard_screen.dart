import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../models/property.dart';

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

  List<Property> _properties = [];
  List<dynamic> _bookings = [];
  Map<String, dynamic>? _stats;

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
        ApiService.getHostProperties(userId),
        ApiService.getHostBookings(userId),
      ]);
      final props = results[0] as List<Property>;
      final bookData = results[1] as Map<String, dynamic>;
      setState(() {
        _properties = props;
        _bookings = bookData['bookings'] as List? ?? [];
        _stats = bookData['stats'] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Host Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(user?.displayName ?? '', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => context.push('/add-property')),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.home_outlined, size: 18), text: 'Properties'),
            Tab(icon: Icon(Icons.calendar_today_outlined, size: 18), text: 'Bookings'),
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
                  children: [_buildOverview(), _buildProperties(), _buildBookings()],
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
          const Text('Your Performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _statCard('Properties', '${_properties.length}', Icons.home_work, const Color(0xFF2563EB)),
              _statCard('Total Bookings', fmt.format(s['totalBookings'] ?? 0), Icons.calendar_month, const Color(0xFF059669)),
              _statCard('My Revenue', fmtD.format(s['hostRevenue'] ?? 0.0), Icons.attach_money, const Color(0xFF7C3AED)),
              _statCard('Rooms', '${s['totalRooms'] ?? 0} (${s['bookedRooms'] ?? 0} booked)', Icons.bed, const Color(0xFFD97706)),
            ],
          ),
          const SizedBox(height: 16),
          if (_properties.isNotEmpty) ...[
            const Text('Your Properties', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            ..._properties.take(3).map((p) => _propertyQuickCard(p)),
            if (_properties.length > 3) TextButton(
              onPressed: () => _tab.animateTo(1),
              child: Text('View all ${_properties.length} properties →'),
            ),
          ],
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => context.push('/add-property'),
            icon: const Icon(Icons.add),
            label: const Text('Add New Property'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProperties() {
    if (_properties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_work_outlined, size: 64, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            const Text('No properties yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            const Text('Add your first property to start receiving bookings',
                textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push('/add-property'),
              icon: const Icon(Icons.add),
              label: const Text('Add Property'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _properties.length,
        itemBuilder: (_, i) => _propertyCard(_properties[i]),
      ),
    );
  }

  Widget _buildBookings() {
    if (_bookings.isEmpty) {
      return const Center(child: Text('No bookings yet', style: TextStyle(color: Color(0xFF64748B), fontSize: 16)));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (_, i) {
          final b = _bookings[i];
          final guest = b['guest'] as Map? ?? {};
          final prop = b['property'] as Map? ?? {};
          final status = b['status'] as String? ?? '';
          final statusColor = _bookingStatusColor(status);
          final fmtD = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
          final checkIn = b['checkIn'] != null ? DateTime.tryParse(b['checkIn'].toString()) : null;
          final checkOut = b['checkOut'] != null ? DateTime.tryParse(b['checkOut'].toString()) : null;
          final df = DateFormat('MMM d, yyyy');

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                      child: Text((guest['name'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    Text(guest['name'] ?? guest['email'] ?? 'Guest',
                        style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                  ],
                ),
                if (checkIn != null && checkOut != null) ...[
                  const SizedBox(height: 4),
                  Text('${df.format(checkIn)} → ${df.format(checkOut)}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${b['nights'] ?? 1} nights',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    Text(fmtD.format((b['hostBasePrice'] ?? b['totalAmount'] ?? 0.0)),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 15)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _propertyCard(Property p) {
    final img = p.imageUrls.isNotEmpty ? p.imageUrls.first : null;
    final fmtD = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
      ),
      child: InkWell(
        onTap: () => context.push('/property/${p.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: img != null
                  ? CachedNetworkImage(imageUrl: img, height: 140, width: double.infinity, fit: BoxFit.cover)
                  : Container(height: 140, color: const Color(0xFFE2E8F0),
                      child: const Icon(Icons.home_work, size: 48, color: Color(0xFF94A3B8))),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.isActive ? Colors.green[50] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(p.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(color: p.isActive ? Colors.green[700] : Colors.grey[600], fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${p.city}, ${p.country}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(fmtD.format(p.basePricePerNight),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 15)),
                      Text(p.priceUnit, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _propertyQuickCard(Property p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: p.imageUrls.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(imageUrl: p.imageUrls.first, fit: BoxFit.cover),
                  )
                : const Icon(Icons.home_work, color: Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(p.city, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.circle, size: 8, color: p.isActive ? Colors.green : Colors.grey),
        ],
      ),
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
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        ],
      ),
    );
  }

  Color _bookingStatusColor(String s) {
    switch (s) {
      case 'CONFIRMED': return Colors.green;
      case 'COMPLETED': return const Color(0xFF2563EB);
      case 'CANCELLED': return Colors.red;
      default: return Colors.orange;
    }
  }
}
