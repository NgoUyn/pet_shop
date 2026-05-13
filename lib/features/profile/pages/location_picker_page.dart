import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';

class LocationPickerPage extends StatefulWidget {
  final LatLng position;
  final String address;

  const LocationPickerPage({super.key, required this.position, required this.address});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _mapController = MapController();
  late LatLng _center;
  late String _address;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _center = widget.position;
    _address = widget.address;
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMove || event is MapEventFlingAnimation ||
        event is MapEventMoveEnd) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 600), () {
        final c = _mapController.camera.center;
        if (mounted) setState(() => _center = c);
        _reverseGeocode(c);
      });
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=${pos.latitude}&lon=${pos.longitude}'
        '&accept-language=vi&zoom=16',
      );
      final response = await http.get(uri, headers: {'User-Agent': 'PetShopApp/1.0'});
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final name = data['display_name'] as String?;
      if (name != null && name.isNotEmpty && mounted) {
        setState(() => _address = name);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kéo map để chỉnh vị trí'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, {
              'address': _address,
              'lat': _center.latitude,
              'lng': _center.longitude,
            }),
            child: const Text('Xác nhận', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.position,
              initialZoom: 17,
              onMapEvent: _onMapEvent,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.pet_shop',
              ),
            ],
          ),
          // Fixed center pin
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, size: 48, color: Colors.red),
                SizedBox(height: 150),
              ],
            ),
          ),
          // Address bar
          Positioned(
            left: 0, right: 0, bottom: 0,
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
                      child: Text(_address, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
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
