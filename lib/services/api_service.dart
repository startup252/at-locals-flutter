import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/user.dart';
import '../models/property.dart';
import '../models/booking.dart';
import '../models/review.dart';

class ApiService {
  static final _client = http.Client();

  static Future<Map<String, dynamic>> _get(String path, {Map<String, String>? params}) async {
    final uri = Uri.parse('$kBaseUrl$path').replace(queryParameters: params);
    final res = await _client.get(uri, headers: {'Content-Type': 'application/json'});
    if (res.statusCode >= 500) throw Exception('Server error');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$kBaseUrl$path');
    final res = await _client.post(uri,
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) throw Exception(data['error'] ?? 'Request failed');
    return data;
  }

  static Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$kBaseUrl$path');
    final res = await _client.patch(uri,
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) throw Exception(data['error'] ?? 'Request failed');
    return data;
  }

  // ── Auth ─────────────────────────────────────────────────────────────────────

  static Future<AppUser> login(String email, String password) async {
    final data = await _post('/api/auth/login', {'email': email, 'password': password});
    if (data['user'] != null) return AppUser.fromJson(data['user'] as Map<String, dynamic>);
    throw Exception(data['error'] ?? 'Login failed');
  }

  static Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _post('/api/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'role': 'GUEST',
    });
    if (data['user'] != null) return AppUser.fromJson(data['user'] as Map<String, dynamic>);
    throw Exception(data['error'] ?? 'Registration failed');
  }

  // ── Properties ───────────────────────────────────────────────────────────────

  static Future<List<Property>> getFeatured({int limit = 10}) async {
    final data = await _get('/api/search', params: {'page': '1', 'limit': '$limit'});
    final list = data['results'] as List? ?? [];
    return list.map((e) => Property.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<Property>> search({
    String? q,
    String? type,
    String? city,
    int page = 1,
  }) async {
    final params = <String, String>{'page': '$page'};
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (city != null && city.isNotEmpty) params['city'] = city;
    final data = await _get('/api/search', params: params);
    final list = data['results'] as List? ?? [];
    return list.map((e) => Property.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> createProperty(String userId, Map<String, dynamic> data) async {
    return await _post('/api/properties', {...data, 'ownerId': userId});
  }

  // ── Reviews ──────────────────────────────────────────────────────────────────

  static Future<List<Review>> getReviews(String propertyId) async {
    try {
      final data = await _get('/api/reviews', params: {'propertyId': propertyId, 'limit': '10'});
      final list = data['reviews'] as List? ?? data['data'] as List? ?? [];
      return list.map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Bookings ─────────────────────────────────────────────────────────────────

  static Future<List<Booking>> getMyBookings(String userId) async {
    final data = await _get('/api/bookings', params: {'guestId': userId, 'actorId': userId});
    final list = data['bookings'] as List? ?? data['data'] as List? ?? [];
    return list.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Booking> createBooking({
    required String propertyId,
    required String guestId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    required double totalAmount,
  }) async {
    final data = await _post('/api/bookings', {
      'propertyId': propertyId,
      'guestId': guestId,
      'actorId': guestId,
      'checkIn': checkIn.toIso8601String(),
      'checkOut': checkOut.toIso8601String(),
      'guests': guests,
      'totalAmount': totalAmount,
    });
    final b = data['booking'] as Map<String, dynamic>?;
    if (b != null) return Booking.fromJson(b);
    throw Exception('Booking failed');
  }

  static Future<bool> cancelBooking(String bookingId, String userId) async {
    final data = await _post('/api/bookings/$bookingId/cancel', {'actorId': userId});
    return data['success'] == true || data['booking'] != null;
  }

  // ── Bids ─────────────────────────────────────────────────────────────────────

  static Future<void> sendBid({
    required String propertyId,
    required String bidderId,
    required String phone,
    String? whatsapp,
  }) async {
    await _post('/api/bids', {
      'propertyId': propertyId,
      'bidderId': bidderId,
      'bidderPhone': phone,
      if (whatsapp != null && whatsapp.isNotEmpty) 'bidderWhatsapp': whatsapp,
    });
  }

  static Future<List<dynamic>> getPropertyBids(String propertyId) async {
    final data = await _get('/api/bids', params: {'propertyId': propertyId});
    return data['bids'] as List? ?? [];
  }

  static Future<void> updateBidStatus(String bidId, String actorId, String status) async {
    await _patch('/api/bids/$bidId', {'actorId': actorId, 'status': status});
  }

  // ── Admin ────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAdminStats(String actorId) async {
    return await _get('/api/admin/stats', params: {'actorId': actorId});
  }

  static Future<Map<String, dynamic>> getAdminUsers(
    String actorId, {
    String? role,
    String? search,
    int page = 1,
  }) async {
    final params = <String, String>{'actorId': actorId, 'page': '$page', 'pageSize': '20'};
    if (role != null && role.isNotEmpty) params['role'] = role;
    if (search != null && search.isNotEmpty) params['search'] = search;
    return await _get('/api/admin/users', params: params);
  }

  static Future<void> approveUser(
    String actorId,
    String userId, {
    String? accountStatus,
    String? role,
  }) async {
    await _patch('/api/admin/users/$userId', {
      'actorId': actorId,
      if (accountStatus != null) 'accountStatus': accountStatus,
      if (role != null) 'role': role,
    });
  }

  static Future<List<dynamic>> getAdminBidApprovals(String actorId) async {
    final data = await _get('/api/admin/bid-approvals', params: {'actorId': actorId});
    return data['bids'] as List? ?? [];
  }

  // ── Host ─────────────────────────────────────────────────────────────────────

  static Future<List<Property>> getHostProperties(String userId) async {
    final data = await _get('/api/host/properties', params: {'userId': userId});
    final list = data['properties'] as List? ?? [];
    return list.map((e) => Property.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> getHostBookings(String userId) async {
    return await _get('/api/host/bookings', params: {'userId': userId});
  }

  // ── Broker ───────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getBrokerEarnings(String brokerId) async {
    return await _get('/api/broker/earnings', params: {'brokerId': brokerId});
  }

  // ── Notifications ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getNotifications(String userId) async {
    return await _get('/api/notifications', params: {'userId': userId});
  }

  static Future<void> markNotificationRead(String userId, {String? notifId}) async {
    final body = <String, dynamic>{'userId': userId};
    if (notifId != null) body['id'] = notifId;
    await _patch('/api/notifications', body);
  }

  // ── Profile ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getProfile(String userId) async {
    return await _get('/api/profile/$userId');
  }

  static Future<void> updateProfile(
    String userId, {
    String? name,
    String? phone,
    String? whatsapp,
    String? city,
    String? country,
  }) async {
    await _patch('/api/profile/$userId', {
      'actorId': userId,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (whatsapp != null) 'whatsappNumber': whatsapp,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
    });
  }

  static Future<String> uploadAvatar(
    String userId,
    Uint8List bytes,
    String filename,
    String mimeType,
  ) async {
    final uri = Uri.parse('$kBaseUrl/api/upload/avatar');
    final req = http.MultipartRequest('POST', uri)
      ..fields['userId'] = userId
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: filename));
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    if (streamed.statusCode >= 400) throw Exception(data['error'] ?? 'Upload failed');
    return data['avatarUrl'] as String;
  }

  static Future<String> uploadPropertyImage(
    String userId,
    Uint8List bytes,
    String filename,
  ) async {
    final uri = Uri.parse('$kBaseUrl/api/upload/property-image');
    final req = http.MultipartRequest('POST', uri)
      ..fields['userId'] = userId
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    if (streamed.statusCode >= 400) throw Exception(data['error'] ?? 'Upload failed');
    return (data['url'] ?? data['imageUrl'] ?? data['path']) as String;
  }
}
