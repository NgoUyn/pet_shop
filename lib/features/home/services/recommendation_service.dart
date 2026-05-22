import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service gọi API recommendation server để lấy gợi ý sản phẩm/thú cưng.
class RecommendationService {
  RecommendationService._();
  static final RecommendationService instance = RecommendationService._();

  // Địa chỉ server recommendation (chạy trên Docker)
  static const String _baseUrl = 'http://localhost:8000';

  /// Gọi API lấy danh sách product_id và pet_id được recommend cho user.
  ///
  /// [userId] - ID của user (từ SQLite), có thể null nếu chưa đăng nhập.
  /// [limit] - Số lượng recommend tối đa (mặc định 10).
  ///
  /// Trả về [RecommendationResult] chứa danh sách product_id và pet_id.
  Future<RecommendationResult> getRecommendations({
    int? userId,
    int limit = 10,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/recommendations').replace(
        queryParameters: {
          if (userId != null) 'user_id': userId.toString(),
          'limit': limit.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {'accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final products = (data['products'] as List<dynamic>?)
                ?.map((e) => (e as Map<String, dynamic>)['id'] as int)
                .toList() ??
            [];
        final pets = (data['pets'] as List<dynamic>?)
                ?.map((e) => (e as Map<String, dynamic>)['id'] as int)
                .toList() ??
            [];
        return RecommendationResult(
          productIds: products,
          petIds: pets,
        );
      }
    } catch (_) {
      // Nếu server không chạy hoặc lỗi, trả về empty
    }
    return const RecommendationResult();
  }
}

/// Kết quả recommend từ server.
class RecommendationResult {
  final List<int> productIds;
  final List<int> petIds;

  const RecommendationResult({
    this.productIds = const [],
    this.petIds = const [],
  });
}
