import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../models/user.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _name     = TextEditingController();
  final _phone    = TextEditingController();
  final _whatsapp = TextEditingController();
  final _city     = TextEditingController();
  final _country  = TextEditingController();

  bool _loading = false;
  bool _uploading = false;
  String? _error;
  Uint8List? _newAvatarBytes;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    _initFields();
    _loadProfile();
  }

  void _initFields() {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _name.text = user.name ?? '';
      _currentAvatarUrl = user.avatarUrl;
    }
  }

  Future<void> _loadProfile() async {
    final userId = context.read<AuthProvider>().user?.id ?? '';
    try {
      final data = await ApiService.getProfile(userId);
      final u = data['user'] as Map? ?? {};
      setState(() {
        _name.text    = u['name'] as String? ?? _name.text;
        _phone.text   = u['phone'] as String? ?? '';
        _whatsapp.text = u['whatsappNumber'] as String? ?? '';
        _city.text    = u['city'] as String? ?? '';
        _country.text = u['country'] as String? ?? '';
        _currentAvatarUrl = u['avatarUrl'] as String? ?? _currentAvatarUrl;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _whatsapp.dispose();
    _city.dispose(); _country.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() { _newAvatarBytes = bytes; _uploading = true; });
    try {
      final userId = context.read<AuthProvider>().user?.id ?? '';
      final url = await ApiService.uploadAvatar(userId, bytes, file.name, 'image/jpeg');
      setState(() { _currentAvatarUrl = url; _uploading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() { _uploading = false; _error = 'Avatar upload failed: $e'; });
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) { setState(() => _error = 'Name is required'); return; }

    final userId = context.read<AuthProvider>().user?.id ?? '';
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.updateProfile(
        userId,
        name: name,
        phone: _phone.text.trim(),
        whatsapp: _whatsapp.text.trim(),
        city: _city.text.trim(),
        country: _country.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Avatar section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF0EA5E9)],
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: ClipOval(
                          child: _newAvatarBytes != null
                              ? Image.memory(_newAvatarBytes!, fit: BoxFit.cover)
                              : (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty)
                                  ? CachedNetworkImage(
                                      imageUrl: _currentAvatarUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const CircularProgressIndicator(),
                                      errorWidget: (_, __, ___) => _avatarFallback(user),
                                    )
                                  : _avatarFallback(user),
                        ),
                      ),
                      if (_uploading)
                        Container(
                          width: 96, height: 96,
                          decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                          child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                        ),
                      GestureDetector(
                        onTap: _uploading ? null : _pickAvatar,
                        child: Container(
                          width: 30, height: 30,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, size: 17, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(user?.displayName ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(user?.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),

            // Form
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  _section('Personal Info'),
                  const SizedBox(height: 8),
                  _formCard([
                    _field('Full Name', Icons.person_outline, _name),
                    _divider(),
                    _field('Phone Number', Icons.phone_outlined, _phone, type: TextInputType.phone),
                    _divider(),
                    _field('WhatsApp', Icons.chat_outlined, _whatsapp, type: TextInputType.phone),
                  ]),
                  const SizedBox(height: 16),

                  _section('Location'),
                  const SizedBox(height: 8),
                  _formCard([
                    _field('City', Icons.location_city_outlined, _city),
                    _divider(),
                    _field('Country', Icons.public_outlined, _country),
                  ]),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _loading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(AppUser? user) {
    return Container(
      color: const Color(0xFF1D4ED8),
      child: Center(
        child: Text(
          (user?.displayName ?? '?')[0].toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _section(String t) => Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)));

  Widget _formCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 16);

  Widget _field(String label, IconData icon, TextEditingController ctrl, {TextInputType? type}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
