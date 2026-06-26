import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/property.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Property> _properties = [];
  bool _loading = true;
  String? _error;
  String _activeType = '';

  static const _cats = [
    _Cat('Hotels',      Icons.hotel_rounded,       Color(0xFFFF6B6B), Color(0xFFFF8E8E), 'HOTEL'),
    _Cat('Villas',      Icons.villa_rounded,        Color(0xFF845EC2), Color(0xFFA178E0), 'VILLA'),
    _Cat('Bacweyne',    Icons.holiday_village,      Color(0xFF00C9A7), Color(0xFF00E5BF), 'VILLA_BACWEYNE'),
    _Cat('Apartments',  Icons.apartment_rounded,    Color(0xFF0089CF), Color(0xFF00A8F5), 'APARTMENT'),
    _Cat('Resorts',     Icons.beach_access_rounded, Color(0xFFF9C74F), Color(0xFFFFDA6A), 'RESORT'),
    _Cat('Hostels',     Icons.bed_rounded,          Color(0xFF4CAF50), Color(0xFF66BB6A), 'HOSTEL'),
    _Cat('Guest House', Icons.home_rounded,         Color(0xFFFF9A3C), Color(0xFFFFB05C), 'GUESTHOUSE'),
    _Cat('Beach',       Icons.waves_rounded,        Color(0xFF00BCD4), Color(0xFF26D4E8), 'BEACH'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String type = ''}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final props = await ApiService.search(type: type.isEmpty ? null : type);
      if (mounted) setState(() { _properties = props; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load properties'; _loading = false; });
    }
  }

  void _selectType(String type) {
    final next = _activeType == type ? '' : type;
    setState(() => _activeType = next);
    _load(type: next);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final featured = _activeType.isEmpty ? _properties.take(6).toList() : <Property>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: RefreshIndicator(
        onRefresh: () => _load(type: _activeType),
        color: const Color(0xFF2563EB),
        child: CustomScrollView(
          slivers: [

            // ── Gradient Header ────────────────────────────────────────────
            SliverToBoxAdapter(child: _Header(user: user)),

            // ── Airbnb-style Category Pills ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Text('Explore', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const Spacer(),
                          if (_activeType.isNotEmpty)
                            GestureDetector(
                              onTap: () => _selectType(''),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.close, size: 12, color: Color(0xFF2563EB)),
                                    SizedBox(width: 3),
                                    Text('Clear', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 96,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 20),
                        itemCount: _cats.length,
                        itemBuilder: (_, i) => _CategoryPill(
                          cat: _cats[i],
                          selected: _activeType == _cats[i].type,
                          onTap: () => _selectType(_cats[i].type),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Featured ────────────────────────────────────────────────────
            if (!_loading && featured.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Featured Stays', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      GestureDetector(
                        onTap: () => context.go('/search'),
                        child: const Text('See all →', style: TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    itemCount: featured.length,
                    itemBuilder: (_, i) => _FeaturedCard(
                      property: featured[i],
                      onTap: () => context.go('/property/${featured[i].id}'),
                    ),
                  ),
                ),
              ),
            ],

            // ── Section title ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _activeType.isEmpty ? 'All Properties' : _cats.firstWhere((c) => c.type == _activeType, orElse: () => _cats[0]).label,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    if (!_loading)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                        child: Text('${_properties.length} available',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            ),

            // ── Properties Grid/List ─────────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2563EB)),
                    SizedBox(height: 16),
                    Text('Finding great stays...', style: TextStyle(color: Color(0xFF64748B))),
                  ],
                )),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 56, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Color(0xFF64748B))),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () => _load(type: _activeType), child: const Text('Retry')),
                  ],
                )),
              )
            else if (_properties.isEmpty)
              SliverFillRemaining(
                child: Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off_outlined, size: 56, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    const Text('No properties in this category', style: TextStyle(color: Color(0xFF64748B))),
                    const SizedBox(height: 16),
                    TextButton(onPressed: () => _selectType(''), child: const Text('Show all')),
                  ],
                )),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _PropertyGridCard(
                      property: _properties[i],
                      onTap: () => context.go('/property/${_properties[i].id}'),
                    ),
                    childCount: _properties.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Category data class ────────────────────────────────────────────────────────

class _Cat {
  final String label;
  final IconData icon;
  final Color color;
  final Color colorLight;
  final String type;
  const _Cat(this.label, this.icon, this.color, this.colorLight, this.type);
}

// ── Airbnb-style category pill ─────────────────────────────────────────────────

class _CategoryPill extends StatelessWidget {
  final _Cat cat;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryPill({required this.cat, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: selected ? cat.color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? cat.color : const Color(0xFFE8EDF5),
            width: selected ? 0 : 1.5,
          ),
          boxShadow: selected
              ? [BoxShadow(color: cat.color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))]
              : [const BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.2) : cat.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(cat.icon, color: selected ? Colors.white : cat.color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              cat.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF374151),
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gradient header ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final dynamic user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E40AF), Color(0xFF2563EB), Color(0xFF0EA5E9)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${user?.name?.split(' ').first ?? 'Guest'} 👋',
                          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        const Text('Where do you want to stay?',
                            style: TextStyle(fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                  ),
                  // Avatar + notification
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/notifications'),
                        child: Container(
                          width: 38, height: 38,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/profile'),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white38, width: 2),
                          ),
                          child: ClipOval(
                            child: user?.avatarUrl != null
                                ? Image.network(
                                    user.avatarUrl!.startsWith('http') ? user.avatarUrl! : '$kBaseUrl${user.avatarUrl}',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _avatarFb(user.name ?? 'G'),
                                  )
                                : _avatarFb(user?.name ?? 'G'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Search bar
              GestureDetector(
                onTap: () => context.go('/search'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('Search hotels, villas, apartments...',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                      ),
                      Icon(Icons.tune_rounded, color: Color(0xFF94A3B8), size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFb(String name) => Container(
    color: const Color(0xFF1D4ED8),
    child: Center(
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'G',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    ),
  );
}

// ── Featured card (horizontal scroll) ──────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final Property property;
  final VoidCallback onTap;
  const _FeaturedCard({required this.property, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final img = property.imageUrls.isNotEmpty ? property.imageUrls.first : null;
    final fmtD = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 190,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Image
              img != null
                  ? CachedNetworkImage(
                      imageUrl: img,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: const Color(0xFFE2E8F0)),
                      errorWidget: (_, __, ___) => Container(color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.home_work, size: 40, color: Color(0xFF94A3B8))),
                    )
                  : Container(height: 220, color: const Color(0xFFE2E8F0),
                      child: const Icon(Icons.home_work, size: 40, color: Color(0xFF94A3B8))),

              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // Type badge
              Positioned(
                top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(property.typeLabel,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                ),
              ),

              // Info
              Positioned(
                bottom: 12, left: 12, right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(property.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 11, color: Colors.white60),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(property.city,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(fmtD.format(property.basePricePerNight),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('/${property.priceUnit}',
                            style: const TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Property grid card ──────────────────────────────────────────────────────────

class _PropertyGridCard extends StatelessWidget {
  final Property property;
  final VoidCallback onTap;
  const _PropertyGridCard({required this.property, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final img = property.imageUrls.isNotEmpty ? property.imageUrls.first : null;
    final fmtD = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Stack(
                  children: [
                    img != null
                        ? CachedNetworkImage(
                            imageUrl: img,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: const Color(0xFFE2E8F0)),
                            errorWidget: (_, __, ___) => Container(color: const Color(0xFFEFF6FF),
                                child: const Icon(Icons.home_work, size: 32, color: Color(0xFF94A3B8))),
                          )
                        : Container(color: const Color(0xFFEFF6FF),
                            child: const Icon(Icons.home_work, size: 32, color: Color(0xFF94A3B8))),
                    // Type badge
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(property.typeLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    // Monthly badge
                    if (property.isMonthly)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFF845EC2), borderRadius: BorderRadius.circular(8)),
                          child: const Text('Monthly', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(property.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(property.city,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(fmtD.format(property.basePricePerNight),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      Text('/${property.priceUnit}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
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
}
