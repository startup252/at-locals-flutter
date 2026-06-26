import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../config.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> with SingleTickerProviderStateMixin {
  List<Booking> _bookings = [];
  bool _loading = true;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      final list = await ApiService.getMyBookings(userId);
      if (mounted) setState(() { _bookings = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(Booking b) async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Booking', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Cancel your booking at ${b.propertyName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.cancelBooking(b.id, userId);
      _load();
    } catch (_) {}
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'CONFIRMED': return const Color(0xFF16A34A);
      case 'COMPLETED': return const Color(0xFF2563EB);
      case 'CANCELLED': return const Color(0xFFDC2626);
      default:          return const Color(0xFFD97706);
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'CONFIRMED': return Icons.check_circle_rounded;
      case 'COMPLETED': return Icons.task_alt_rounded;
      case 'CANCELLED': return Icons.cancel_rounded;
      default:          return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _bookings.where((b) => b.isActive).toList();
    final past   = _bookings.where((b) => !b.isActive).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(children: [
                    const Text('My Bookings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
                      child: Text('${_bookings.length} total',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
                TabBar(
                  controller: _tabs,
                  labelColor: const Color(0xFF2563EB),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF2563EB),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: [
                    Tab(text: 'Active (${active.length})'),
                    Tab(text: 'Past (${past.length})'),
                  ],
                ),
              ]),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _list(active, showCancel: true),
                      _list(past),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<Booking> items, {bool showCancel = false}) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), shape: BoxShape.circle),
            child: const Icon(Icons.calendar_today_outlined, size: 32, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 16),
          const Text('No bookings here', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          const Text('Your reservations will appear here', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.go('/search'),
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Explore Properties'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF2563EB),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _bookingCard(items[i], showCancel: showCancel),
      ),
    );
  }

  Widget _bookingCard(Booking b, {bool showCancel = false}) {
    final fmt = DateFormat('MMM d, yyyy');
    final imgUrl = b.propertyImage != null
        ? (b.propertyImage!.startsWith('http') ? b.propertyImage! : '$kBaseUrl${b.propertyImage}')
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Image
        if (imgUrl != null)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.network(imgUrl, height: 140, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    height: 140, color: const Color(0xFFE2E8F0),
                    child: const Icon(Icons.home_rounded, size: 40, color: Color(0xFF94A3B8)))),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(b.propertyName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(b.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_statusIcon(b.status), size: 12, color: _statusColor(b.status)),
                  const SizedBox(width: 4),
                  Text(b.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(b.status))),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _infoBox(Icons.login_rounded, 'Check-in', fmt.format(b.checkIn))),
              const SizedBox(width: 8),
              Expanded(child: _infoBox(Icons.logout_rounded, 'Check-out', fmt.format(b.checkOut))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _chip(Icons.nights_stay_outlined, '${b.nights} nights'),
              const SizedBox(width: 8),
              _chip(Icons.attach_money_rounded, '\$${b.totalAmount.toStringAsFixed(0)} ${b.currency}', blue: true),
            ]),
            if (showCancel && b.status == 'CONFIRMED') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancel(b),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancel Booking'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _infoBox(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(icon, size: 14, color: const Color(0xFF2563EB)),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ])),
    ]),
  );

  Widget _chip(IconData icon, String label, {bool blue = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: blue ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: blue ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: blue ? const Color(0xFF2563EB) : const Color(0xFF475569))),
    ]),
  );
}
