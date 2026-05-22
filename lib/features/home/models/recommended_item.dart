import '../services/product_repository.dart';
import '../services/pet_repository.dart';

/// Loại item được recommend.
enum RecommendedKind { product, pet }

/// Một item trong danh sách gợi ý (có thể là sản phẩm hoặc thú cưng).
class RecommendedItem {
  final RecommendedKind kind;
  final ProductItem? product;
  final PetItem? pet;

  RecommendedItem.product(this.product)
      : kind = RecommendedKind.product,
        pet = null;
  RecommendedItem.pet(this.pet)
      : kind = RecommendedKind.pet,
        product = null;
}
