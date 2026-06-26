const List<String> kMonthlyTypes = ['VILLA', 'VILLA_BACWEYNE', 'APARTMENT'];

class Property {
  final String id;
  final String name;
  final String type;
  final String city;
  final String country;
  final String address;
  final double basePricePerNight;
  final double guestPricePerNight;
  final String currency;
  final List<String> imageUrls;
  final List<String> amenities;
  final String? description;
  final int roomCount;
  final bool isActive;

  const Property({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    required this.country,
    required this.address,
    required this.basePricePerNight,
    required this.guestPricePerNight,
    required this.currency,
    required this.imageUrls,
    required this.amenities,
    this.description,
    required this.roomCount,
    this.isActive = true,
  });

  bool get isMonthly => kMonthlyTypes.contains(type);

  String get priceUnit => isMonthly ? 'month' : 'night';

  String get typeLabel {
    const labels = {
      'HOTEL': 'Hotel',
      'HOSTEL': 'Hostel',
      'RESORT': 'Resort',
      'GUESTHOUSE': 'Guest House',
      'FURNISHED_APARTMENT': 'Furnished Apt',
      'APARTMENT': 'Apartment',
      'VILLA': 'Villa',
      'VILLA_BACWEYNE': 'Bacweyne',
      'BEACH': 'Beach',
    };
    return labels[type] ?? type;
  }

  factory Property.fromJson(Map<String, dynamic> j) => Property(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
        city: j['city'] as String,
        country: j['country'] as String,
        address: j['address'] as String? ?? '',
        basePricePerNight: _toDouble(j['basePricePerNight']),
        guestPricePerNight: _toDouble(j['guestPricePerNight'] ?? j['basePricePerNight']),
        currency: j['currency'] as String? ?? 'USD',
        imageUrls: _toStringList(j['imageUrls']),
        amenities: _toStringList(j['amenities']),
        description: j['description'] as String?,
        roomCount: _toInt(j['_count']?['rooms'] ?? j['roomCount'] ?? 0),
        isActive: j['isActive'] as bool? ?? true,
      );
}

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? 0;
}

List<String> _toStringList(dynamic v) {
  if (v == null) return [];
  if (v is List) return v.map((e) => e.toString()).toList();
  return [];
}
