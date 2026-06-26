import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/property.dart';
import '../services/api_service.dart';
import '../widgets/property_card.dart';

class SearchScreen extends StatefulWidget {
  final String? initialType;
  const SearchScreen({super.key, this.initialType});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  List<Property> _results = [];
  bool _loading = false;
  String? _selectedType;

  static const _types = [
    {'label': 'All',          'value': '',              'icon': '🔍'},
    {'label': 'Hotel',        'value': 'HOTEL',         'icon': '🏨'},
    {'label': 'Apartment',    'value': 'APARTMENT',     'icon': '🏢'},
    {'label': 'Villa',        'value': 'VILLA',         'icon': '🏰'},
    {'label': 'Bacweyne',     'value': 'VILLA_BACWEYNE','icon': '🛖'},
    {'label': 'Resort',       'value': 'RESORT',        'icon': '🏖'},
    {'label': 'Hostel',       'value': 'HOSTEL',        'icon': '🛏'},
    {'label': 'Guest House',  'value': 'GUESTHOUSE',    'icon': '🏡'},
    {'label': 'Beach',        'value': 'BEACH',         'icon': '🌊'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? '';
    _search();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final results = await ApiService.search(
        q: _searchCtrl.text.trim(),
        type: _selectedType?.isEmpty == true ? null : _selectedType,
      );
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // ── Search header ──────────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.go('/'),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: Color(0xFF0F172A)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            autofocus: widget.initialType == null,
                            onSubmitted: (_) => _search(),
                            decoration: InputDecoration(
                              hintText: 'Search properties, cities...',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                              prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                                      onPressed: () { _searchCtrl.clear(); _search(); })
                                  : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
                              filled: true, fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _search,
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.search, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Type filter chips
                  SizedBox(
                    height: 42,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _types.length,
                      itemBuilder: (ctx, i) {
                        final t = _types[i];
                        final selected = _selectedType == t['value'];
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedType = t['value'] as String);
                            _search();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFF2563EB) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              '${t['icon']} ${t['label']}',
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Results ────────────────────────────────────────────────────────
          if (!_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${_results.length} properties found',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _results.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.search_off_rounded, size: 56, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 14),
                          const Text('No properties found', style: TextStyle(fontSize: 16, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          const Text('Try a different search or filter', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                        ]),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                        itemCount: _results.length,
                        itemBuilder: (ctx, i) => PropertyCard(
                          property: _results[i],
                          onTap: () => context.go('/property/${_results[i].id}'),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
