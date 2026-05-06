// import 'package:flutter/material.dart';
// import '../../../core/constants/app_colors.dart';
// import '../../../core/utils/cloudinary_helper.dart';
// import '../../../core/widgets/app_header.dart';
//
// class HomePage extends StatelessWidget {
//   const HomePage({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//
//       // Thay AppBar cũ bằng AppHeader
//       appBar: const PreferredSize(
//         preferredSize: Size.fromHeight(70),
//         child: AppHeader(),
//       ),
//
//       body: SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Banner từ Cloudinary
//             Container(
//               margin: const EdgeInsets.all(16),
//               height: 180,
//               width: double.infinity,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(15),
//                 image: DecorationImage(
//                   image: NetworkImage(
//                     CloudinaryHelper.getBannerImage('banner1'),
//                   ),
//                   fit: BoxFit.cover,
//                 ),
//               ),
//             ),
//
//             // Categories Section
//             const Padding(
//               padding: EdgeInsets.symmetric(horizontal: 16),
//               child: Text(
//                 'Danh mục nổi bật',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//
//             const SizedBox(height: 10),
//
//             SizedBox(
//               height: 100,
//               child: ListView(
//                 scrollDirection: Axis.horizontal,
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 children: [
//                   _buildCategoryItem('Chó', 'dog_icon'),
//                   _buildCategoryItem('Mèo', 'cat_icon'),
//                 ],
//               ),
//             ),
//
//             // Recommended Section
//             Padding(
//               padding: const EdgeInsets.all(16),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     'Gợi ý cho bạn',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   TextButton(
//                     onPressed: () {},
//                     child: const Text('Xem tất cả'),
//                   ),
//                 ],
//               ),
//             ),
//
//             GridView.builder(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               gridDelegate:
//               const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 2,
//                 childAspectRatio: 0.75,
//                 crossAxisSpacing: 10,
//                 mainAxisSpacing: 10,
//               ),
//               itemCount: 4,
//               itemBuilder: (context, index) {
//                 return _buildProductCard();
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   static Widget _buildCategoryItem(String name, String publicId) {
//     return Padding(
//       padding: const EdgeInsets.only(right: 20),
//       child: Column(
//         children: [
//           CircleAvatar(
//             radius: 30,
//             backgroundColor: AppColors.white,
//             backgroundImage: NetworkImage(
//               CloudinaryHelper.getThumbnail(publicId),
//             ),
//           ),
//           const SizedBox(height: 5),
//           Text(
//             name,
//             style: const TextStyle(fontSize: 12),
//           ),
//         ],
//       ),
//     );
//   }
//
//   static Widget _buildProductCard() {
//     return Container(
//       decoration: BoxDecoration(
//         color: AppColors.white,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Expanded(
//             child: ClipRRect(
//               borderRadius: const BorderRadius.vertical(
//                 top: Radius.circular(12),
//               ),
//               child: Image.network(
//                 CloudinaryHelper.getProductImage('sample_product'),
//                 fit: BoxFit.cover,
//                 width: double.infinity,
//               ),
//             ),
//           ),
//           const Padding(
//             padding: EdgeInsets.all(8.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Thức ăn mèo cao cấp',
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 SizedBox(height: 5),
//                 Text(
//                   '250.000đ',
//                   style: TextStyle(
//                     color: AppColors.secondary,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/cloudinary_helper.dart';
import '../services/pet_repository.dart';
import '../services/product_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<_RecommendedItem>> _recommendedFuture;

  @override
  void initState() {
    super.initState();
    _recommendedFuture = _loadRecommended();
  }

  Future<List<_RecommendedItem>> _loadRecommended() async {
    final results = await Future.wait([
      ProductRepository.instance.listActiveProducts(limit: 200),
      PetRepository.instance.listActivePets(limit: 200),
    ]);

    final products = results[0] as List<ProductItem>;
    final pets = results[1] as List<PetItem>;

    return [
      ...products.map(_RecommendedItem.product),
      ...pets.map(_RecommendedItem.pet),
    ];
  }

  String _formatPrice(double value) {
    final formatted = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < formatted.length; i++) {
      final fromEnd = formatted.length - i;
      buffer.write(formatted[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) {
        buffer.write('.');
      }
    }
    return '$bufferđ';
  }

  Widget _buildImage(String? url, {IconData fallbackIcon = Icons.image_outlined}) {
    final normalized = (url ?? '').trim();
    if (normalized.isEmpty) {
      return Container(
        color: AppColors.background,
        alignment: Alignment.center,
        child: Icon(fallbackIcon, color: AppColors.textLight, size: 44),
      );
    }

    return Image.network(
      normalized,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.background,
          alignment: Alignment.center,
          child: Icon(Icons.broken_image_outlined, color: AppColors.textLight, size: 44),
        );
      },
    );
  }

  Widget _buildCard(_RecommendedItem item) {
    if (item.kind == _RecommendedKind.product) {
      final product = item.product!;
      return Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: _buildImage(product.imageUrl),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textDark),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatPrice(product.price),
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final pet = item.pet!;
    final price = pet.price;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: _buildImage(null, fallbackIcon: Icons.pets),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.petName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  pet.species,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  price == null ? '-' : _formatPrice(price),
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Banner
            Container(
              margin: const EdgeInsets.all(16),
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: NetworkImage(
                    CloudinaryHelper.getBannerImage('banner1'),
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            /// Danh mục nổi bật
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Danh mục nổi bật',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 95,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildCategoryItem('Chó', 'dog_icon'),
                  _buildCategoryItem('Mèo', 'cat_icon'),
                ],
              ),
            ),

            /// Gợi ý cho bạn
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gợi ý cho bạn',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Xem tất cả'),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FutureBuilder<List<_RecommendedItem>>(
                future: _recommendedFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(child: Text('Không thể tải dữ liệu'));
                  }

                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Center(child: Text('Chưa có dữ liệu'));
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {},
                        child: _buildCard(item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildCategoryItem(
      String name,
      String publicId,
      ) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.white,
            backgroundImage: NetworkImage(
              CloudinaryHelper.getThumbnail(publicId),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

}

enum _RecommendedKind { product, pet }

class _RecommendedItem {
  _RecommendedItem._(this.kind, {this.product, this.pet});

  final _RecommendedKind kind;
  final ProductItem? product;
  final PetItem? pet;

  factory _RecommendedItem.product(ProductItem product) => _RecommendedItem._(
        _RecommendedKind.product,
        product: product,
      );

  factory _RecommendedItem.pet(PetItem pet) => _RecommendedItem._(
        _RecommendedKind.pet,
        pet: pet,
      );
}