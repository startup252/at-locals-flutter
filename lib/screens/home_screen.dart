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
    _Cat('Hotels',      '🏨', Color(0xFF2563EB), 'HOTEL'),
    _Cat('Villas',      '🏰', Color(0xFF7C3AED), 'VILLA'),
    _Cat('Bacweyne',    '🛖', Color(0xFF059669), 'VILLA_BACWEYNE'),
    _Cat('Apartments',  '🏢', Color(0xFF0EA5E9), 'APARTMENT'),
    _Cat('Resorts',     '🏖️', Color(0xFFD97706), 'RESORT'),
    _Cat('Hostels',     '🛏️', Color(0xFF16A34A), 'HOSTEL'),
    _Cat('Guest House', '🏡', Color(0xFFEA580C), 'GUESTHOUSE'),
    _Cat('Beach',       '🌊', Color(0xFF0891B2), 'BEACH'),
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
      if (mounted) setState(() { _error = 'Failed to load'; _loading = false; });
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
    final featured = _activeType.isEmpty ? _properties.take(5).toList() : <Property>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: RefreshIndicator(
        onRefresh: () => _load(type: _activeType),
        color: const Color(0xFF2563EB),
        child: CustomScrollView(
          slivers: [

            // ── HEADER ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hello, ${user?.name?.split(' ').first ?? 'Guest'} 👋',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text('Find your perfect stay in Somalia',
                                      style: TextStyle(fontSize: 13, color: Colors.white60)),
                                ],
                              ),
                            ),
                            // Notifications
                            GestureDetector(
                              onTap: () => context.push('/notifications'),
                              child: Container(
                                width: 40, height: 40,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                              ),
                            ),
                            // Avatar
                            GestureDetector(
                              onTap: () => context.go('/profile'),
                              child: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white30, width: 2),
                                ),
                                child: ClipOval(
                                  child: user?.avatarUrl != null && (user!.avatarUrl!).isNotEmpty
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
                      ),
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: GestureDetector(
                          onTap: () => context.go('/search'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 6))],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34, height: 34,
                                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 18),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Where are you going?',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                      Text('Hotels · Villas · Apartments',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(9)),
                                  child: const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Wave
                      Container(
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        margin: const EdgeInsets.only(top: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── CATEGORIES ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Explore Categories',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const Spacer(),
                        if (_activeType.isNotEmpty)
                          GestureDetector(
                            onTap: () => _selectType(''),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
                              child: const Row(children: [
                                Icon(Icons.close, size: 12, color: Color(0xFF2563EB)),
                                SizedBox(width: 3),
                                Text('Clear', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 78,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cats.length,
                        itemBuilder: (_, i) => _CategoryChip(
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

            // ── FEATURED ────────────────────────────────────────────────────
            if (!_loading && featured.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Featured Stays',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      GestureDetector(
                        onTap: () => context.go('/search'),
                        child: const Text('See all →',
                            style: TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 230,
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

            // ── ALL PROPERTIES HEADER ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activeType.isEmpty
                              ? 'All Properties'
                              : _cats.firstWhere((c) => c.type == _activeType, orElse: () => _cats[0]).label,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        if (!_loading)
                          Text('${_properties.length} stays available',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── PROPERTY LIST ──────────────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 2.5),
                    SizedBox(height: 16),
                    Text('Finding great stays...', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                  ],
                )),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), shape: BoxShape.circle),
                      child: const Icon(Icons.cloud_off_outlined, size: 40, color: Color(0xFFEF4444)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Connection failed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text('Check your internet and try again', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _load(type: _activeType),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                )),
              )
            else if (_properties.isEmpty)
              SliverFillRemaining(
                child: Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), shape: BoxShape.circle),
                      child: const Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(height: 16),
                    const Text('No properties found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    TextButton(onPressed: () => _selectType(''), child: const Text('Show all categories')),
                  ],
                )),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _PropertyListCard(
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

  Widget _avatarFb(String name) => Container(
    color: const Color(0xFF1D4ED8),
    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'G',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
  );
}

// ── Data ──────────────────────────────────────────────────────────────────────

class _Cat {
  final String label, emoji, type;
  final Color color;
  const _Cat(this.label, this.emoji, this.color, this.type);
}

// ── Category Chip ─────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final _Cat cat;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.cat, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [cat.color, cat.color.withValues(alpha: 0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? cat.color : const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: selected
              ? [BoxShadow(color: cat.color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
              : [const BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(cat.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 6),
            Text(
              cat.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Featured Card ─────────────────────────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final Property property;
  final VoidCallback onTap;
  const _FeaturedCard({required this.property, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final img = property.imageUrls.isNotEmpty ? property.imageUrls.first : null;
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Image
              Positioned.fill(
                child: img != null
                    ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: const Color(0xFFE2E8F0)),
                        errorWidget: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
              // Gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                      stops: const [0.35, 1.0],
                    ),
                  ),
                ),
              ),
              // Type badge top-left
              Positioned(
                top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(property.typeLabel,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                ),
              ),
              // Info bottom
              Positioned(
                bottom: 12, left: 12, right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(property.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, height: 1.2),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on, size: 11, color: Colors.white60),
                      const SizedBox(width: 2),
                      Text(property.city, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ]),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(fmt.format(property.basePricePerNight),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('/${property.priceUnit}',
                              style: const TextStyle(color: Colors.white60, fontSize: 10)),
                        ],
                      ),
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

  Widget _placeholder() => Container(
    color: const Color(0xFFE2E8F0),
    child: const Center(child: Icon(Icons.home_work_outlined, size: 40, color: Color(0xFF94A3B8))),
  );
}

// ── Property List Card (Booking.com style) ────────────────────────────────────

class _PropertyListCard extends StatelessWidget {
  final Property property;
  final VoidCallback onTap;
  const _PropertyListCard({required this.property, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final img = property.imageUrls.isNotEmpty ? property.imageUrls.first : null;
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(
                children: [
                  img != null
                      ? CachedNetworkImage(
                          imageUrl: img,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(height: 180, color: const Color(0xFFE2E8F0)),
                          errorWidget: (_, __, ___) => Container(height: 180, color: const Color(0xFFEFF6FF),
                              child: const Center(child: Icon(Icons.home_work, size: 48, color: Color(0xFF94A3B8)))),
                        )
                      : Container(height: 180, color: const Color(0xFFEFF6FF),
                          child: const Center(child: Icon(Icons.home_work, size: 48, color: Color(0xFF94A3B8)))),
                  // Type badge
                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(property.typeLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  // Monthly badge
                  if (property.isMonthly)
                    Positioned(
                      top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Monthly', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(property.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Text('${property.city}, ${property.country}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fmt.format(property.basePricePerNight),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                            Text('per ${property.priceUnit}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: const Text('View →',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
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
