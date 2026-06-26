class Review {
  final String id;
  final String guestName;
  final String? guestAvatar;
  final double rating;
  final String? comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.guestName,
    this.guestAvatar,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> j) {
    final guest = j['guest'] as Map<String, dynamic>?;
    return Review(
      id: j['id'] as String,
      guestName: guest?['name'] as String? ?? 'Guest',
      guestAvatar: guest?['avatarUrl'] as String?,
      rating: _d(j['rating']),
      comment: j['comment'] as String?,
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
