import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});
  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _country = TextEditingController(text: 'Somalia');
  final _price = TextEditingController();

  String _type = 'HOTEL';
  bool _loading = false;
  bool _uploading = false;
  String? _error;
  Uint8List? _imageBytes;
  String? _imageName;
  String? _uploadedImageUrl;

  static const _hostTypes = ['HOTEL', 'FURNISHED_APARTMENT', 'HOSTEL', 'RESORT', 'GUESTHOUSE', 'BEACH'];
  static const _brokerTypes = ['VILLA', 'VILLA_BACWEYNE', 'APARTMENT'];

  static const _typeLabels = {
    'HOTEL': 'Hotel',
    'FURNISHED_APARTMENT': 'Furnished Apartment',
    'HOSTEL': 'Hostel',
    'RESORT': 'Resort',
    'GUESTHOUSE': 'Guesthouse',
    'BEACH': 'Beach',
    'VILLA': 'Villa',
    'VILLA_BACWEYNE': 'Villa Bacweyne',
    'APARTMENT': 'Apartment',
  };

  List<String> get _availableTypes {
    final role = context.read<AuthProvider>().user?.role ?? '';
    if (role == 'BROKER') return _brokerTypes;
    if (role == 'HOST') return _hostTypes;
    return [..._hostTypes, ..._brokerTypes];
  }

  bool get _isMonthly => ['VILLA', 'VILLA_BACWEYNE', 'APARTMENT'].contains(_type);

  @override
  void initState() {
    super.initState();
    final role = context.read<AuthProvider>().user?.role ?? '';
    _type = role == 'BROKER' ? 'VILLA' : 'HOTEL';
  }

  @override
  void dispose() {
    _name.dispose(); _desc.dispose(); _city.dispose();
    _address.dispose(); _country.dispose(); _price.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageName = file.name;
      _uploadedImageUrl = null;
    });
    await _uploadImage(bytes, file.name);
  }

  Future<void> _uploadImage(Uint8List bytes, String filename) async {
    final userId = context.read<AuthProvider>().user?.id ?? '';
    setState(() => _uploading = true);
    try {
      final url = await ApiService.uploadPropertyImage(userId, bytes, filename);
      setState(() { _uploadedImageUrl = url; _uploading = false; });
    } catch (e) {
      setState(() { _uploading = false; _error = 'Image upload failed: $e'; });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = context.read<AuthProvider>().user?.id ?? '';
    final price = double.tryParse(_price.text.trim());
    if (price == null || price <= 0) {
      setState(() => _error = 'Enter a valid price'); return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'type': _type,
        'city': _city.text.trim(),
        'address': _address.text.trim(),
        'country': _country.text.trim(),
        'basePricePerNight': price,
        'currency': 'USD',
        'lat': 2.0,
        'lng': 45.3,
        'postalCode': '',
        'amenities': [],
        if (_uploadedImageUrl != null) 'imageUrls': [_uploadedImageUrl],
      };
      await ApiService.createProperty(userId, body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property added successfully!'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title: const Text('Add Property', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                  ),
                  child: _imageBytes != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity, height: 180),
                            ),
                            if (_uploading)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                              ),
                            if (!_uploading && _uploadedImageUrl != null)
                              Positioned(
                                top: 8, right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                                ),
                              ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text('Tap to add property photo', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                            Text('(Optional)', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

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

              _section('Property Type'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _availableTypes.map((t) => ChoiceChip(
                  label: Text(_typeLabels[t] ?? t, style: const TextStyle(fontSize: 13)),
                  selected: _type == t,
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(color: _type == t ? Colors.white : const Color(0xFF475569), fontWeight: FontWeight.w500),
                  onSelected: (_) => setState(() { _type = t; }),
                )).toList(),
              ),
              const SizedBox(height: 16),

              _section('Property Details'),
              const SizedBox(height: 8),
              _field('Property Name', Icons.home, _name, required: true),
              const SizedBox(height: 10),
              _field('Description', Icons.description, _desc, maxLines: 3),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field('City', Icons.location_city, _city, required: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Country', Icons.public, _country, required: true)),
                ],
              ),
              const SizedBox(height: 10),
              _field('Address', Icons.place, _address, required: true),
              const SizedBox(height: 16),

              _section(_isMonthly ? 'Monthly Rent (USD)' : 'Price per Night (USD)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _dec(_isMonthly ? 'e.g. 500 per month' : 'e.g. 80 per night', Icons.attach_money),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Price is required';
                  if (double.tryParse(v) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: (_loading || _uploading) ? null : _submit,
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
                    : const Text('Add Property', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String t) => Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)));

  Widget _field(String label, IconData icon, TextEditingController ctrl, {bool required = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: _dec(label, icon),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null : null,
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
    filled: true, fillColor: Colors.white,
  );
}
