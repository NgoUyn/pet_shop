import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';

class LocationPickerPage extends StatefulWidget {
  final LatLng? initialPosition;

  const LocationPickerPage({super.key, this.initialPosition});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _mapController = MapController();
  late LatLng _currentPosition;
  String _currentAddress = 'Đang tải địa chỉ...';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition ?? const LatLng(10.762622, 106.660172);
    _reverseGeocode(_currentPosition);
  }

  void _onMapEvent(MapEvent event) {
    if (event is! MapEventMove && event is! MapEventFlingAnimation) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final center = _mapController.camera.center;
      setState(() => _currentPosition = center);
      _reverseGeocode(center);
    });
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse'
          '?format=json'
          '&lat=${pos.latitude}'
          '&lon=${pos.longitude}'
          '&accept-language=vi'
          '&zoom=18';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'PetShopApp/1.0',
      });
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final displayName = data['display_name'] as String?;
      if (displayName != null && displayName.isNotEmpty && mounted) {
        setState(() => _currentAddress = displayName);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chọn vị trí giao hàng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'address': _currentAddress,
                'lat': _currentPosition.latitude,
                'lng': _currentPosition.longitude,
              });
            },
            child: const Text('Xác nhận', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom: 16.0,
              onMapEvent: _onMapEvent,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.pet_shop',
              ),
            ],
          ),
          // Center pin
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, size: 48, color: Colors.red),
                SizedBox(height: 160),
              ],
            ),
          ),
          // Address bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Colors.red, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _currentAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
