import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/property.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../widgets/property_card.dart';
import '../widgets/featured_card.dart';
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

  static const _cats = [
    {'label': 'Hotels',     'icon': '🏨', 'type': 'HOTEL'},
    {'label': 'Apartments', 'icon': '🏢', 'type': 'APARTMENT'},
    {'label': 'Villas',     'icon': '🏰', 'type': 'VILLA'},
    {'label': 'Bacweyne',   'icon': '🛖', 'type': 'VILLA_BACWEYNE'},
    {'label': 'Resorts',    'icon': '🏖', 'type': 'RESORT'},
    {'label': 'Hostels',    'icon': '🛏', 'type': 'HOSTEL'},
    {'label': 'Guest House','icon': '🏡', 'type': 'GUESTHOUSE'},
    {'label': 'Beach',      'icon': '🌊', 'type': 'BEACH'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final props = await ApiService.getFeatured(limit: 30);
      if (mounted) setState(() { _properties = props; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load properties'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final featured = _properties.take(6).toList();
    final all      = _properties;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF2563EB),
        child: CustomScrollView(
          slivers: [
            // ── Gradient Header ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF0EA5E9)],
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Greeting row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Hello, ${user?.displayName.split(' ').first ?? 'Guest'} 👋',
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 2),
                                  const Text('Where do you want to stay?',
                                      style: TextStyle(fontSize: 13, color: Colors.white70)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.go('/profile'),
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white38, width: 2),
                                ),
                                child: ClipOval(
                                  child: user?.avatarUrl != null
                                      ? Image.network(
                                          user!.avatarUrl!.startsWith('http') ? user.avatarUrl! : '$kBaseUrl${user.avatarUrl}',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _avatarFallback(user.displayName),
                                        )
                                      : _avatarFallback(user?.displayName ?? 'G'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Search bar
                        GestureDetector(
                          onTap: () => context.go('/search'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)],
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.search, color: Color(0xFF64748B), size: 22),
                                SizedBox(width: 12),
                                Text('Search hotels, villas, apartments...',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Categories ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Browse by Type', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 82,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cats.length,
                        itemBuilder: (ctx, i) {
                          final c = _cats[i];
                          return GestureDetector(
                            onTap: () => context.go('/search?type=${c['type']}'),
                            child: Container(
                              width: 72,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(c['icon']!, style: const TextStyle(fontSize: 26)),
                                  const SizedBox(height: 4),
                                  Text(c['label']!,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                      textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Featured ────────────────────────────────────────────────────
            if (!_loading && featured.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Featured', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            GestureDetector(
                              onTap: () => context.go('/search'),
                              child: const Text('See all', style: TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 205,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(left: 20),
                          itemCount: featured.length,
                          itemBuilder: (ctx, i) => FeaturedCard(
                            property: featured[i],
                            onTap: () => context.go('/property/${featured[i].id}'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── All Properties ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('All Properties', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    if (!_loading)
                      Text('${all.length} available',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ),

            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Color(0xFF64748B))),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                ),
              )
            else if (all.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('No properties available', style: TextStyle(color: Color(0xFF64748B)))),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => PropertyCard(
                      property: all[i],
                      onTap: () => context.go('/property/${all[i].id}'),
                    ),
                    childCount: all.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(String name) => Container(
    color: const Color(0xFF1D4ED8),
    child: Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'G',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    ),
  );
}
