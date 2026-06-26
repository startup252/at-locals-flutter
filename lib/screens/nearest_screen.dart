import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../config.dart';

// ── Nearby property model (has distanceKm) ───────────────────────────────────
class NearbyProperty {
  final String id;
  final String name;
  final String type;
  final String city;
  final String country;
  final double guestPricePerNight;
  final String currency;
  final List<String> imageUrls;
  final double distanceKm;

  const NearbyProperty({
    required this.id, required this.name, required this.type,
    required this.city, required this.country,
    required this.guestPricePerNight, required this.currency,
    required this.imageUrls, required this.distanceKm,
  });

  factory NearbyProperty.fromJson(Map<String, dynamic> j) => NearbyProperty(
    id: j['id'] as String,
    name: j['name'] as String,
    type: j['type'] as String? ?? '',
    city: j['city'] as String? ?? '',
    country: j['country'] as String? ?? '',
    guestPricePerNight: _d(j['guestPricePerNight'] ?? j['basePricePerNight']),
    currency: j['currency'] as String? ?? 'USD',
    imageUrls: _sl(j['imageUrls']),
    distanceKm: _d(j['distanceKm']),
  );

  String get typeLabel {
    const m = {
      'HOTEL': 'Hotel', 'HOSTEL': 'Hostel', 'RESORT': 'Resort',
      'GUESTHOUSE': 'Guest House', 'FURNISHED_APARTMENT': 'Furnished Apt',
      'APARTMENT': 'Apartment', 'VILLA': 'Villa', 'VILLA_BACWEYNE': 'Bacweyne', 'BEACH': 'Beach',
    };
    return m[type] ?? type;
  }

  bool get isMonthly => ['VILLA', 'VILLA_BACWEYNE', 'APARTMENT'].contains(type);
  String get priceUnit => isMonthly ? 'mo' : 'night';
}

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

List<String> _sl(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return [];
}

// ── Screen ────────────────────────────────────────────────────────────────────
class NearestScreen extends StatefulWidget {
  const NearestScreen({super.key});
  @override
  State<NearestScreen> createState() => _NearestScreenState();
}

class _NearestScreenState extends State<NearestScreen> {
  List<NearbyProperty> _properties = [];
  String _status = 'idle'; // idle, locating, loading, done, error
  String _errorMsg = '';
  double _userLat = 0, _userLng = 0;
  int _radius = 25;
  String? _typeFilter;

  static const _radii = [5, 10, 25, 50];
  static const _types = [
    {'label': 'All',       'value': ''},
    {'label': '🏨 Hotel',  'value': 'HOTEL'},
    {'label': '🏢 Apt',    'value': 'APARTMENT'},
    {'label': '🏰 Villa',  'value': 'VILLA'},
    {'label': '🛖 Bacweyne','value':'VILLA_BACWEYNE'},
    {'label': '🏖 Resort', 'value': 'RESORT'},
    {'label': '🛏 Hostel', 'value': 'HOSTEL'},
  ];

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    setState(() { _status = 'locating'; _errorMsg = ''; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() { _status = 'error'; _errorMsg = 'Location services are disabled. Please enable GPS.'; });
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        setState(() { _status = 'error'; _errorMsg = 'Location permission denied. Please allow location access in browser settings.'; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
      );
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      await _fetchNearby();
    } catch (e) {
      setState(() { _status = 'error'; _errorMsg = 'Could not get your location. ${e.toString().replaceAll('Exception: ', '')}'; });
    }
  }

  Future<void> _fetchNearby() async {
    setState(() => _status = 'loading');
    try {
      final uri = Uri.parse('$kBaseUrl/api/properties/nearby')
          .replace(queryParameters: {'lat': '$_userLat', 'lng': '$_userLng', 'radius': '$_radius'});
      final res = await http.get(uri, headers: {'Content-Type': 'application/json'});
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = data['properties'] as List? ?? [];
      if (mounted) setState(() {
        _properties = list.map((e) => NearbyProperty.fromJson(e as Map<String, dynamic>)).toList();
        _status = 'done';
      });
    } catch (e) {
      if (mounted) setState(() { _status = 'error'; _errorMsg = 'Failed to load nearby properties.'; });
    }
  }

  List<NearbyProperty> get _filtered => _typeFilter == null || _typeFilter!.isEmpty
      ? _properties
      : _properties.where((p) => p.type == _typeFilter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF0EA5E9)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.near_me_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text('Near Me', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      _status == 'done'
                          ? '${_filtered.length} properties within $_radius km'
                          : 'Finding properties near your location',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                    // Radius selector
                    Row(
                      children: _radii.map((r) {
                        final sel = r == _radius;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _radius = r);
                            if (_userLat != 0) _fetchNearby();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: sel ? Colors.white : Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${r}km',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                    color: sel ? const Color(0xFF2563EB) : Colors.white)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    // Type filter
                    SizedBox(
                      height: 34,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _types.length,
                        itemBuilder: (ctx, i) {
                          final t = _types[i];
                          final sel = (_typeFilter ?? '') == t['value'];
                          return GestureDetector(
                            onTap: () => setState(() => _typeFilter = t['value']),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel ? Colors.white : Colors.white24,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(t['label']!,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                      color: sel ? const Color(0xFF2563EB) : Colors.white)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_status == 'locating') return _centeredMsg(Icons.location_searching_rounded, 'Getting your location…', loading: true);
    if (_status == 'loading') return _centeredMsg(Icons.search, 'Finding nearby properties…', loading: true);
    if (_status == 'error') return _errorState();
    if (_status == 'done' && _filtered.isEmpty) return _emptyState();
    if (_status != 'done') return _centeredMsg(Icons.near_me_rounded, 'Tap to find properties near you');

    return RefreshIndicator(
      onRefresh: _locate,
      color: const Color(0xFF2563EB),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        itemCount: _filtered.length,
        itemBuilder: (ctx, i) => _propertyCard(_filtered[i], i + 1),
      ),
    );
  }

  Widget _propertyCard(NearbyProperty p, int rank) {
    final imgUrl = p.imageUrls.isNotEmpty
        ? (p.imageUrls.first.startsWith('http') ? p.imageUrls.first : '$kBaseUrl${p.imageUrls.first}')
        : null;

    return GestureDetector(
      onTap: () => context.go('/property/${p.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
        ),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 32,
              height: 100,
              decoration: BoxDecoration(
                color: rank == 1 ? const Color(0xFF2563EB) : rank == 2 ? const Color(0xFF0EA5E9) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              ),
              child: Center(child: Text('$rank',
                  style: TextStyle(color: rank <= 2 ? Colors.white : const Color(0xFF64748B),
                      fontWeight: FontWeight.bold, fontSize: 15))),
            ),
            // Image
            ClipRRect(
              child: SizedBox(
                width: 90, height: 100,
                child: imgUrl != null
                    ? Image.network(imgUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.home_rounded, color: Color(0xFF94A3B8), size: 30)))
                    : Container(color: const Color(0xFFE2E8F0),
                        child: const Icon(Icons.home_rounded, color: Color(0xFF94A3B8), size: 30)),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
                      child: Text(p.typeLabel, style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    const Icon(Icons.near_me_rounded, size: 12, color: Color(0xFF2563EB)),
                    const SizedBox(width: 3),
                    Text('${p.distanceKm} km',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ]),
                  const SizedBox(height: 6),
                  Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Expanded(child: Text('${p.city}, ${p.country}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('\$${p.guestPricePerNight.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    Text(' / ${p.priceUnit}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ]),
                ]),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centeredMsg(IconData icon, String msg, {bool loading = false}) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (loading)
        const CircularProgressIndicator(color: Color(0xFF2563EB))
      else
        Icon(icon, size: 56, color: const Color(0xFF94A3B8)),
      const SizedBox(height: 16),
      Text(msg, style: const TextStyle(fontSize: 15, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
    ]),
  );

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), shape: BoxShape.circle),
          child: const Icon(Icons.location_off_outlined, size: 32, color: Color(0xFFDC2626)),
        ),
        const SizedBox(height: 16),
        const Text('Location Error', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        Text(_errorMsg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _locate,
          icon: const Icon(Icons.my_location, size: 18),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ]),
    ),
  );

  Widget _emptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.location_searching_rounded, size: 56, color: Color(0xFF94A3B8)),
      const SizedBox(height: 14),
      const Text('No properties found nearby', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      const SizedBox(height: 6),
      Text('within $_radius km of your location', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: () { setState(() => _radius = 50); _fetchNearby(); },
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('Expand to 50 km'),
      ),
    ]),
  );
}
