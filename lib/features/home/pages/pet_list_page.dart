import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../services/pet_repository.dart';
import '../widgets/pet_card.dart';

class PetListPage extends StatefulWidget {
  const PetListPage({super.key});

  @override
  State<PetListPage> createState() => _PetListPageState();
}

class _PetListPageState extends State<PetListPage> {
  late Future<List<PetItem>> _future;

  void _handlePetsChanged() {
    if (!mounted) return;
    setState(() {
      _future = PetRepository.instance.listActivePets();
    });
  }

  @override
  void initState() {
    super.initState();
    _future = PetRepository.instance.listActivePets();
    PetRepository.instance.changeToken.addListener(_handlePetsChanged);
  }

  @override
  void dispose() {
    PetRepository.instance.changeToken.removeListener(_handlePetsChanged);
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = PetRepository.instance.listActivePets();
    });
  }

  String _formatPrice(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceFirst('.0', '')}tr';
    }
    return '${value.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}đ';
  }

  Widget _buildPetCard(PetItem item) {
    return PetCard(
      item: item,
      formatPrice: _formatPrice,
      onTap: () => showPetDetailSheet(context, item, _formatPrice),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mua thú cưng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<PetItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Không thể tải danh sách thú cưng'),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('Chưa có thú cưng nào'),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildPetCard(item);
            },
          );
        },
      ),
    );
  }
}
