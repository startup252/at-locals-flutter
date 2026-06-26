class Booking {
  final String id;
  final String propertyId;
  final String propertyName;
  final String? propertyImage;
  final String status;
  final String paymentStatus;
  final double totalAmount;
  final String currency;
  final DateTime checkIn;
  final DateTime checkOut;
  final int nights;

  const Booking({
    required this.id,
    required this.propertyId,
    required this.propertyName,
    this.propertyImage,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    required this.currency,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
  });

  bool get isActive => status == 'CONFIRMED' || status == 'PENDING';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';

  factory Booking.fromJson(Map<String, dynamic> j) {
    final prop = j['property'] as Map<String, dynamic>?;
    final images = prop?['imageUrls'];
    return Booking(
      id: j['id'] as String,
      propertyId: j['propertyId'] as String,
      propertyName: prop?['name'] as String? ?? 'Property',
      propertyImage: (images is List && images.isNotEmpty) ? images.first as String? : null,
      status: j['status'] as String? ?? 'PENDING',
      paymentStatus: j['paymentStatus'] as String? ?? 'PENDING',
      totalAmount: _toDouble(j['totalAmount']),
      currency: j['currency'] as String? ?? 'USD',
      checkIn: DateTime.tryParse(j['checkIn'] as String? ?? '') ?? DateTime.now(),
      checkOut: DateTime.tryParse(j['checkOut'] as String? ?? '') ?? DateTime.now(),
      nights: _toInt(j['nights']),
    );
  }
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
