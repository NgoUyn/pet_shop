import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/services/auth_repository.dart';
import '../../../core/widgets/main_wrapper.dart';

class ProfileDetailPage extends StatefulWidget {
  const ProfileDetailPage({super.key});

  @override
  State<ProfileDetailPage> createState() => _ProfileDetailPageState();
}

class _ProfileDetailPageState extends State<ProfileDetailPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;

  final TextEditingController _nameController = TextEditingController(text: 'Username_Petshop');
  final TextEditingController _emailController = TextEditingController(text: 'user@email.com');
  final TextEditingController _receiverController = TextEditingController(text: 'Nguyen Van A');
  final TextEditingController _phoneController = TextEditingController(text: '0901234567');
  final TextEditingController _addressController = TextEditingController(text: '123 Duong ABC, Quan 1, TP.HCM');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _receiverController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Da cap nhat ho so')));
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ho so ca nhan'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isEditing ? _saveProfile : _toggleEdit,
            child: Text(
              _isEditing ? 'Luu' : 'Chinh sua',
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
                _buildSectionTitle('Thong tin ca nhan'),
                _buildTextField(
                  label: 'Ho va ten',
                  controller: _nameController,
                  enabled: _isEditing,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Vui long nhap ten' : null,
                ),
                _buildTextField(
                  label: 'Email',
                  controller: _emailController,
                  enabled: _isEditing,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Vui long nhap email' : null,
                ),
                const SizedBox(height: 16),
                _buildSectionTitle('Thong tin nhan hang'),
                _buildTextField(
                  label: 'Nguoi nhan',
                  controller: _receiverController,
                  enabled: _isEditing,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Vui long nhap nguoi nhan' : null,
                ),
                _buildTextField(
                  label: 'So dien thoai',
                  controller: _phoneController,
                  enabled: _isEditing,
                  keyboardType: TextInputType.phone,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Vui long nhap so dien thoai' : null,
                ),
                _buildTextField(
                  label: 'Dia chi',
                  controller: _addressController,
                  enabled: _isEditing,
                  maxLines: 2,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Vui long nhap dia chi' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Dang xuat', style: TextStyle(color: Colors.red)),
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
