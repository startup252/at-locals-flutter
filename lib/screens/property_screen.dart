import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/property.dart';
import '../models/review.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../config.dart';

class PropertyScreen extends StatefulWidget {
  final String propertyId;
  const PropertyScreen({super.key, required this.propertyId});
  @override
  State<PropertyScreen> createState() => _PropertyScreenState();
}

class _PropertyScreenState extends State<PropertyScreen> {
  Property? _property;
  List<Review> _reviews = [];
  bool _loading = true;
  int _imgIndex = 0;

  // Bid form
  final _phoneCtrl = TextEditingController();
  final _waCtrl    = TextEditingController();
  bool _sending    = false;
  bool _bidDone    = false;
  String? _bidError;

  // Booking form (per-night)
  DateTime? _checkIn;
  DateTime? _checkOut;
  int _guests = 1;
  bool _booking = false;
  bool _bookingDone = false;
  String? _bookingError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final [props, reviews] = await Future.wait([
        ApiService.search(),
        ApiService.getReviews(widget.propertyId),
      ]);
      final match = (props as List<Property>).where((p) => p.id == widget.propertyId).toList();
      if (mounted) {
        setState(() {
          _property = match.isNotEmpty ? match.first : null;
          _reviews = reviews as List<Review>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendBid() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) { context.go('/login'); return; }
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() => _bidError = 'Please enter your phone number.'); return;
    }
    setState(() { _sending = true; _bidError = null; });
    try {
      await ApiService.sendBid(
        propertyId: widget.propertyId,
        bidderId: user.id,
        phone: _phoneCtrl.text.trim(),
        whatsapp: _waCtrl.text.trim(),
      );
      if (mounted) setState(() { _bidDone = true; _sending = false; });
    } catch (e) {
      if (mounted) setState(() { _bidError = e.toString().replaceAll('Exception: ', ''); _sending = false; });
    }
  }

  Future<void> _book() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) { context.go('/login'); return; }
    if (_checkIn == null || _checkOut == null) {
      setState(() => _bookingError = 'Please select check-in and check-out dates.'); return;
    }
    final nights = _checkOut!.difference(_checkIn!).inDays;
    if (nights <= 0) {
      setState(() => _bookingError = 'Check-out must be after check-in.'); return;
    }
    setState(() { _booking = true; _bookingError = null; });
    try {
      final total = _property!.guestPricePerNight * nights;
      await ApiService.createBooking(
        propertyId: widget.propertyId,
        guestId: user.id,
        checkIn: _checkIn!,
        checkOut: _checkOut!,
        guests: _guests,
        totalAmount: total,
      );
      if (mounted) setState(() { _bookingDone = true; _booking = false; });
    } catch (e) {
      if (mounted) setState(() { _bookingError = e.toString().replaceAll('Exception: ', ''); _booking = false; });
    }
  }

  Future<void> _pickDate(bool isCheckIn) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isCheckIn ? (_checkIn ?? now.add(const Duration(days: 1))) : (_checkOut ?? now.add(const Duration(days: 2))),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF2563EB))),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isCheckIn) {
          _checkIn = picked;
          if (_checkOut != null && !_checkOut!.isAfter(picked)) _checkOut = null;
        } else {
          _checkOut = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose(); _waCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))));
    }
    if (_property == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: Text('Property not found')),
      );
    }
    final p = _property!;
    final isMonthly = p.isMonthly;
    final commission = p.guestPricePerNight * 0.10;
    final total = p.guestPricePerNight + commission;
    final avgRating = _reviews.isEmpty ? 0.0 : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          // ── Image gallery ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF1D4ED8),
            leading: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            actions: [
              if (p.imageUrls.length > 1)
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: const BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.all(Radius.circular(20))),
                  child: Text('${_imgIndex + 1}/${p.imageUrls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: p.imageUrls.isEmpty
                  ? Container(
                      color: const Color(0xFF1D4ED8),
                      child: const Icon(Icons.home_rounded, size: 80, color: Colors.white24))
                  : PageView.builder(
                      itemCount: p.imageUrls.length,
                      onPageChanged: (i) => setState(() => _imgIndex = i),
                      itemBuilder: (_, i) {
                        final url = p.imageUrls[i].startsWith('http') ? p.imageUrls[i] : '$kBaseUrl${p.imageUrls[i]}';
                        return Image.network(url, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF1D4ED8),
                                child: const Icon(Icons.image_not_supported, size: 48, color: Colors.white30)));
                      },
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── Info card ──────────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
                          child: Text(p.typeLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        if (_reviews.isNotEmpty) ...[
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                          const SizedBox(width: 3),
                          Text(avgRating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 4),
                          Text('(${_reviews.length})', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ],
                      ]),
                      const SizedBox(height: 10),
                      Text(p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(child: Text('${p.address.isNotEmpty ? '${p.address}, ' : ''}${p.city}, ${p.country}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
                      ]),
                      if (p.roomCount > 0) ...[
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        Row(children: [
                          _stat(Icons.bed_outlined, '${p.roomCount}', 'Rooms'),
                          const SizedBox(width: 24),
                          _stat(Icons.people_outline, p.roomCount > 2 ? '${p.roomCount * 2}' : '2', 'Guests'),
                        ]),
                      ],
                    ],
                  ),
                ),

                // ── Description ────────────────────────────────────────────────
                if (p.description != null && p.description!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text(p.description!, style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.6)),
                      ],
                    ),
                  ),

                // ── Amenities ──────────────────────────────────────────────────
                if (p.amenities.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Amenities (${p.amenities.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: p.amenities.map((a) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF2563EB)),
                              const SizedBox(width: 5),
                              Text(a, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                            ]),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),

                // ── Booking / Bid section ──────────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: isMonthly ? _bidSection(commission, total) : _bookingSection(p),
                ),

                // ── Reviews ────────────────────────────────────────────────────
                if (_reviews.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
                          const SizedBox(width: 6),
                          Text('${avgRating.toStringAsFixed(1)} · ${_reviews.length} Reviews',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 14),
                        ..._reviews.take(5).map(_reviewCard),
                      ],
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bidSection(double commission, double total) {
    final p = _property!;
    if (_bidDone) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(16)),
        child: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Request Sent!', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534), fontSize: 15)),
            SizedBox(height: 2),
            Text('The broker will contact you shortly.', style: TextStyle(color: Color(0xFF166534), fontSize: 13)),
          ])),
        ]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Monthly Pricing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      _priceRow('Monthly Rent', p.guestPricePerNight, p.currency),
      const SizedBox(height: 8),
      _priceRow('Commission (10%)', commission, p.currency, amber: true),
      const Divider(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Total / month', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text('\$${total.toStringAsFixed(0)} ${p.currency}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF2563EB))),
      ]),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
          SizedBox(width: 8),
          Expanded(child: Text('Broker-managed property. Contact broker to arrange viewing and payment.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
        ]),
      ),
      const SizedBox(height: 16),
      const Text('Send Reservation Request', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (_bidError != null) ...[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
          child: Text(_bidError!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
        ),
        const SizedBox(height: 10),
      ],
      _input('Your Phone Number *', Icons.phone_outlined, _phoneCtrl, TextInputType.phone),
      const SizedBox(height: 10),
      _input('WhatsApp (optional)', Icons.chat_outlined, _waCtrl, TextInputType.phone),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _sending ? null : _sendBid,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
          ),
          child: _sending
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Send Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
    ]);
  }

  Widget _bookingSection(Property p) {
    if (_bookingDone) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          const Row(children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Booking Confirmed!', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534), fontSize: 15)),
              SizedBox(height: 2),
              Text('Check your bookings for details.', style: TextStyle(color: Color(0xFF166534), fontSize: 13)),
            ])),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go('/bookings'),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF16A34A), side: const BorderSide(color: Color(0xFF16A34A))),
              child: const Text('View My Bookings'),
            ),
          ),
        ]),
      );
    }

    final nights = (_checkIn != null && _checkOut != null)
        ? _checkOut!.difference(_checkIn!).inDays
        : 0;
    final totalAmount = p.guestPricePerNight * nights;
    final fmt = DateFormat('MMM d');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Book Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Row(children: [
          Text('\$${p.guestPricePerNight.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
          const Text(' / night', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ]),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _dateTile('Check-in', _checkIn != null ? fmt.format(_checkIn!) : 'Select', () => _pickDate(true))),
        const SizedBox(width: 10),
        Expanded(child: _dateTile('Check-out', _checkOut != null ? fmt.format(_checkOut!) : 'Select', () => _pickDate(false))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        const Text('Guests:', style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
        const Spacer(),
        IconButton(
          onPressed: _guests > 1 ? () => setState(() => _guests--) : null,
          icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF2563EB)),
        ),
        Text('$_guests', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        IconButton(
          onPressed: _guests < 10 ? () => setState(() => _guests++) : null,
          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB)),
        ),
      ]),
      if (nights > 0) ...[
        const Divider(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$nights night${nights > 1 ? 's' : ''}', style: const TextStyle(color: Color(0xFF64748B))),
          Text('\$${totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
        ]),
      ],
      if (_bookingError != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
          child: Text(_bookingError!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
        ),
      ],
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _booking ? null : _book,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
          ),
          child: _booking
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
    ]);
  }

  Widget _dateTile(String label, String value, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        ]),
      ]),
    ),
  );

  Widget _reviewCard(Review r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF2563EB),
          child: Text(r.guestName.isNotEmpty ? r.guestName[0].toUpperCase() : 'G',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r.guestName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              Row(children: List.generate(5, (i) => Icon(
                i < r.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 14, color: const Color(0xFFF59E0B),
              ))),
            ]),
            if (r.comment != null && r.comment!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(r.comment!, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5)),
            ],
            const SizedBox(height: 3),
            Text(DateFormat('MMM d, yyyy').format(r.createdAt),
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(IconData icon, String value, String label) => Row(children: [
    Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
    ),
    const SizedBox(width: 8),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
    ]),
  ]);

  Widget _priceRow(String label, double amount, String currency, {bool amber = false}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
        Text('\$${amount.toStringAsFixed(0)} $currency',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: amber ? const Color(0xFFD97706) : const Color(0xFF0F172A))),
      ]);

  Widget _input(String label, IconData icon, TextEditingController ctrl, TextInputType type) =>
      TextField(
        controller: ctrl, keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
          filled: true, fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );
}
