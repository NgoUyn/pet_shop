import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/main_wrapper.dart';
import '../../auth/services/auth_repository.dart';
import '../services/profile_repository.dart';
import 'location_picker_page.dart';

class ProfileDetailPage extends StatefulWidget {
  const ProfileDetailPage({super.key});

  @override
  State<ProfileDetailPage> createState() => _ProfileDetailPageState();
}

class _ProfileDetailPageState extends State<ProfileDetailPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _isEditing = false;
  ProfileData? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileRepository.instance.getCurrentProfile();
    if (!mounted) return;

    setState(() {
      _profile = profile;
      _loading = false;
      if (profile != null) {
        _nameController.text = profile.fullName;
        _emailController.text = profile.email;
        _phoneController.text = profile.phone ?? '';
        _addressController.text = profile.address ?? '';
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng bật GPS để lấy địa chỉ')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cần cấp quyền truy cập vị trí')),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quyền truy cập vị trí đã bị từ chối vĩnh viễn')),
          );
        }
        return;
      }

      // Try GPS first, with timeout; fall back to lower accuracy if needed
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {}

      if (position == null) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể lấy vị trí. Hãy ra ngoài trời và bật GPS.')),
          );
        }
        return;
      }

      // Reverse geocode via Nominatim
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json'
        '&lat=${position.latitude}'
        '&lon=${position.longitude}'
        '&accept-language=vi'
        '&zoom=16',
      );
      final response = await http.get(uri, headers: {'User-Agent': 'PetShopApp/1.0'});
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final displayName = data['display_name'] as String?;
      if (displayName == null || displayName.isEmpty) return;

      // Open map to confirm and adjust
      if (!mounted) return;
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => LocationPickerPage(
            position: LatLng(position!.latitude, position!.longitude),
            address: displayName,
          ),
        ),
      );
      if (result != null && mounted) {
        _addressController.text = result['address'] as String? ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lấy địa chỉ: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
    });

    try {
      final changed = await ProfileRepository.instance.updateCurrentProfile(
        fullName: _nameController.text,
        phone: _phoneController.text,
        address: _addressController.text,
      );

      if (!mounted) return;

      if (!changed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa có thay đổi nào')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật hồ sơ')),
      );

      final refreshed = await ProfileRepository.instance.getCurrentProfile();
      if (!mounted) return;

      setState(() {
        _profile = refreshed;
        if (refreshed != null) {
          _nameController.text = refreshed.fullName;
          _emailController.text = refreshed.email;
          _phoneController.text = refreshed.phone ?? '';
          _addressController.text = refreshed.address ?? '';
        }
        _isEditing = false;
      });

      Navigator.of(context).pop(true);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await AuthRepository.instance.signOut();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainWrapper(initialIndex: 0)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Hồ sơ cá nhân'),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.textDark,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Không tìm thấy dữ liệu hồ sơ'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _logout,
                child: const Text('Đăng xuất'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : (_isEditing ? _saveProfile : () => setState(() => _isEditing = true)),
            child: Text(
              _saving ? 'Đang lưu...' : (_isEditing ? 'Lưu' : 'Chỉnh sửa'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Thông tin cá nhân'),
                _buildTextField(
                  label: 'Họ và tên',
                  controller: _nameController,
                  enabled: _isEditing,
                  validator: (value) {
                    final normalized = value?.trim() ?? '';
                    if (normalized.isEmpty) {
                      return 'Vui lòng nhập tên';
                    }
                    if (normalized.length < 2) {
                      return 'Tên phải có ít nhất 2 ký tự';
                    }
                    if (normalized.length > 80) {
                      return 'Tên không được vượt quá 80 ký tự';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  label: 'Email',
                  controller: _emailController,
                  enabled: false,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildSectionTitle('Thông tin nhận hàng'),
                _buildTextField(
                  label: 'Số điện thoại',
                  controller: _phoneController,
                  enabled: _isEditing,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    final normalized = value?.trim() ?? '';
                    if (normalized.isEmpty) {
                      return 'Vui lòng nhập số điện thoại';
                    }

                    if (!RegExp(r'^[0-9]+$').hasMatch(normalized)) {
                      return 'Số điện thoại không được chứa chữ hoặc ký tự đặc biệt';
                    }

                    if (normalized.length < 10 || normalized.length > 10 || !normalized.startsWith('0')) {
                      return 'Số điện thoại phải gồm 10 số và bắt đầu bằng 0';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  label: 'Địa chỉ',
                  controller: _addressController,
                  enabled: _isEditing,
                  maxLines: 2,
                  validator: (value) {
                    final normalized = value?.trim() ?? '';
                    if (normalized.isEmpty) {
                      return null;
                    }
                    if (normalized.length < 3) {
                      return 'Địa chỉ phải có ít nhất 3 ký tự';
                    }
                    if (normalized.length > 120) {
                      return 'Địa chỉ không được vượt quá 120 ký tự';
                    }

                    if (normalized.contains(RegExp(r'[<>{}[\]\\]'))) {
                      return 'Địa chỉ không được chứa ký tự đặc biệt';
                    }

                    return null;
                  },
                ),
                if (_isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton.icon(
                      onPressed: _getCurrentLocation,
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text('Lấy địa chỉ hiện tại'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    ),
                  ),
                const SizedBox(height: 8),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}