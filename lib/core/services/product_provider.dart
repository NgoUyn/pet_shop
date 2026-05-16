import 'package:flutter/foundation.dart';
import '../../features/home/services/product_repository.dart';

/// Single Source of Truth for Product data.
/// Uses ChangeNotifier so that any widget can listen and auto-refresh.
class ProductProvider extends ChangeNotifier {
  ProductProvider._();

  static final ProductProvider instance = ProductProvider._();

  List<ProductItem> _products = [];
  bool _isLoading = false;
  String? _error;

  List<ProductItem> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all active products from the repository (local + Firestore merged).
  Future<void> loadProducts({int limit = 200}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await ProductRepository.instance.listActiveProducts(limit: limit);
      _error = null;
    } catch (e) {
      _error = 'Không thể tải danh sách sản phẩm';
      debugPrint('ProductProvider.loadProducts error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get a single product by ID from the local cache, or fetch from repository.
  Future<ProductItem?> getProductById(int productId) async {
    // First check local cache
    final cached = _products.where((p) => p.productId == productId).firstOrNull;
    if (cached != null) return cached;

    // Fallback to repository
    try {
      return await ProductRepository.instance.getProductById(productId);
    } catch (e) {
      debugPrint('ProductProvider.getProductById error: $e');
      return null;
    }
  }

  /// Refresh a single product in the list after an update.
  void refreshProduct(ProductItem updatedProduct) {
    final index = _products.indexWhere((p) => p.productId == updatedProduct.productId);
    if (index != -1) {
      _products[index] = updatedProduct;
    } else {
      _products.add(updatedProduct);
    }
    notifyListeners();
  }

  /// Remove a product from the list (soft delete).
  void removeProduct(int productId) {
    _products.removeWhere((p) => p.productId == productId);
    notifyListeners();
  }

  /// Reload all products from scratch.
  Future<void> reload() => loadProducts();
}
