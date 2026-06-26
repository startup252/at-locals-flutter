import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../models/property.dart';

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

  List<Property> _properties = [];
  Map<String, dynamic>? _earnings;
  List<dynamic> _commissions = [];

  // Bids for selected property
  List<dynamic> _bids = [];
  Property? _selectedProp;
  bool _bidsLoading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      if (_tab.index == 2 && _selectedProp != null && _bids.isEmpty) {
        _loadBids(_selectedProp!.id);
      }
    });
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
        ApiService.getBrokerEarnings(userId),
      ]);
      final props = results[0] as List<Property>;
      final earningsData = results[1] as Map<String, dynamic>;

      setState(() {
        _properties = props;
        _earnings = earningsData['totals'] as Map<String, dynamic>?;
        _commissions = earningsData['commissions'] as List? ?? [];
        if (props.isNotEmpty) _selectedProp = props.first;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadBids(String propertyId) async {
    setState(() => _bidsLoading = true);
    try {
      final bids = await ApiService.getPropertyBids(propertyId);
      setState(() { _bids = bids; _bidsLoading = false; });
    } catch (_) {
      setState(() => _bidsLoading = false);
    }
  }

  Future<void> _collectPayment(String bidId) async {
    final userId = context.read<AuthProvider>().user?.id ?? '';
    try {
      await ApiService.updateBidStatus(bidId, userId, 'PAYMENT_COLLECTED');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment collected! Booking created.'), backgroundColor: Colors.green),
      );
      if (_selectedProp != null) _loadBids(_selectedProp!.id);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectBid(String bidId) async {
    final userId = context.read<AuthProvider>().user?.id ?? '';
    try {
      await ApiService.updateBidStatus(bidId, userId, 'REJECTED');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid rejected'), backgroundColor: Colors.orange),
      );
      if (_selectedProp != null) _loadBids(_selectedProp!.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Broker Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            Tab(icon: Icon(Icons.monetization_on_outlined, size: 18), text: 'Earnings'),
            Tab(icon: Icon(Icons.home_outlined, size: 18), text: 'Properties'),
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
                  children: [_buildEarnings(), _buildProperties(), _buildBids()],
                ),
    );
  }

  Widget _buildEarnings() {
    final e = _earnings ?? {};
    final fmtD = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Commission Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          _earningCard('Total Earned', fmtD.format(e['totalEarned'] ?? 0.0), Icons.account_balance_wallet, Colors.green),
          const SizedBox(height: 10),
          _earningCard('Pending to Platform', fmtD.format(e['pendingDebt'] ?? 0.0), Icons.pending_actions, Colors.orange),
          const SizedBox(height: 10),
          _earningCard('Paid to Platform', fmtD.format(e['paidDebt'] ?? 0.0), Icons.check_circle_outline, const Color(0xFF4F46E5)),
          const SizedBox(height: 20),
          if (_commissions.isNotEmpty) ...[
            const Text('Recent Commissions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            ..._commissions.take(10).map((c) => _commissionTile(c)),
          ],
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
            const Text('No properties yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Add your first property to start listing', textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push('/add-property'),
              icon: const Icon(Icons.add),
              label: const Text('Add Property'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
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
        itemBuilder: (_, i) {
          final p = _properties[i];
          final img = p.imageUrls.isNotEmpty ? p.imageUrls.first : null;
          final fmtD = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
          return InkWell(
            onTap: () {
              setState(() => _selectedProp = p);
              _loadBids(p.id);
              _tab.animateTo(2);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                    child: img != null
                        ? CachedNetworkImage(imageUrl: img, width: 90, height: 90, fit: BoxFit.cover)
                        : Container(width: 90, height: 90, color: const Color(0xFFEDE9FE),
                            child: const Icon(Icons.home_work, color: Color(0xFF4F46E5), size: 32)),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${p.city} · ${p.typeLabel}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(fmtD.format(p.basePricePerNight) + '/mo',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), fontSize: 15)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.circle, size: 8, color: p.isActive ? Colors.green : Colors.grey),
                              const SizedBox(width: 4),
                              Text(p.isActive ? 'Available' : 'Rented',
                                  style: TextStyle(fontSize: 11,
                                      color: p.isActive ? Colors.green[700] : Colors.grey[600])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBids() {
    if (_properties.isEmpty) {
      return const Center(child: Text('Add a property first to see bids', style: TextStyle(color: Color(0xFF64748B))));
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: DropdownButtonFormField<String>(
            value: _selectedProp?.id,
            decoration: InputDecoration(
              labelText: 'Select Property',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: _properties.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (id) {
              final prop = _properties.firstWhere((p) => p.id == id);
              setState(() { _selectedProp = prop; _bids = []; });
              _loadBids(id!);
            },
          ),
        ),
        Expanded(
          child: _bidsLoading
              ? const Center(child: CircularProgressIndicator())
              : _bids.isEmpty
                  ? const Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.handshake_outlined, size: 56, color: Color(0xFF94A3B8)),
                        SizedBox(height: 12),
                        Text('No bids for this property', style: TextStyle(color: Color(0xFF64748B))),
                      ],
                    ))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _bids.length,
                      itemBuilder: (_, i) => _bidTile(_bids[i]),
                    ),
        ),
      ],
    );
  }

  Widget _bidTile(dynamic b) {
    final bidder = b['bidder'] as Map? ?? {};
    final status = b['status'] as String? ?? '';
    final statusColor = status == 'PENDING' ? Colors.orange : status == 'ADMIN_APPROVED' ? Colors.green : Colors.red;
    final isPending = status == 'PENDING';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isPending ? Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                backgroundImage: (bidder['avatarUrl'] != null && (bidder['avatarUrl'] as String).isNotEmpty)
                    ? NetworkImage(bidder['avatarUrl'] as String) : null,
                child: (bidder['avatarUrl'] == null || (bidder['avatarUrl'] as String).isEmpty)
                    ? Text((bidder['name'] ?? bidder['email'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bidder['name'] ?? bidder['email'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(bidder['email'] ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (b['bidderPhone'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text('${b['bidderPhone']}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectBid(b['id'] as String),
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
                    onPressed: () => _collectPayment(b['id'] as String),
                    icon: const Icon(Icons.payments, size: 16),
                    label: const Text('Collect Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _earningCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
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
                Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _commissionTile(dynamic c) {
    final fmtD = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['propName'] ?? 'Property', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Commission: ${(((c['commissionRate'] ?? 0.0) as num) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtD.format(c['brokerShare'] ?? 0.0),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), fontSize: 14)),
              Text('Your share', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
