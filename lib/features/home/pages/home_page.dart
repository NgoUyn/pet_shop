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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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

            GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                return _buildProductCard();
              },
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

  static Widget _buildProductCard() {
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: Image.network(
                CloudinaryHelper.getProductImage(
                  'sample_product',
                ),
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thức ăn mèo cao cấp',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6),
                Text(
                  '250.000đ',
                  style: TextStyle(
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
}