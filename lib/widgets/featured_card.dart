import 'package:flutter/material.dart';
import '../models/property.dart';
import '../config.dart';

class FeaturedCard extends StatelessWidget {
  final Property property;
  final VoidCallback onTap;

  const FeaturedCard({super.key, required this.property, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = property;
    final imgUrl = p.imageUrls.isNotEmpty
        ? (p.imageUrls.first.startsWith('http') ? p.imageUrls.first : '$kBaseUrl${p.imageUrls.first}')
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Image
              SizedBox(
                height: 200, width: 240,
                child: imgUrl != null
                    ? Image.network(imgUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              // Content
              Positioned(
                left: 14, right: 14, bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(p.typeLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 6),
                    Text(p.name,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.location_on, color: Colors.white70, size: 12),
                      const SizedBox(width: 2),
                      Expanded(child: Text('${p.city}, ${p.country}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('\$${p.guestPricePerNight.toStringAsFixed(0)} / ${p.priceUnit}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                          child: const Text('View', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
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

  Widget _placeholder() => Container(
    color: const Color(0xFF1E3A5F),
    child: const Center(child: Icon(Icons.home_rounded, size: 56, color: Colors.white24)),
  );
}
