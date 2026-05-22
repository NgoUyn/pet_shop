import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

/// Service gọi API toxic moderation để kiểm tra nội dung đánh giá.
class ToxicModerationService {
  ToxicModerationService._();
  static final ToxicModerationService instance = ToxicModerationService._();

  // Địa chỉ server toxic moderation
  static String get _baseUrl {
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    } catch (_) {}
    return 'http://localhost:8080';
  }
  static const String _modelName = 'ban3_baseline_lr';

  /// Kiểm tra một danh sách texts có chứa nội dung toxic không.
  ///
  /// Trả về list kết quả tương ứng với từng text.
  /// Mỗi kết quả có: label (0/1), probability, threshold.
  Future<List<ToxicResult>> checkTexts(List<String> texts) async {
    if (texts.isEmpty) return [];

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/models/$_modelName/predict_batch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'texts': texts}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = (data['results'] as List<dynamic>)
            .map((r) => ToxicResult.fromJson(r as Map<String, dynamic>))
            .toList();
        return results;
      }
    } catch (e) {
      print('ToxicModerationService.checkTexts error: $e');
    }

    // Nếu lỗi, coi như không toxic để không chặn user
    return texts.map((_) => const ToxicResult(label: 0, probability: 0, threshold: 0)).toList();
  }

  /// Kiểm tra một text duy nhất có toxic không.
  Future<ToxicResult> checkText(String text) async {
    final results = await checkTexts([text]);
    return results.isNotEmpty ? results.first : const ToxicResult(label: 0, probability: 0, threshold: 0);
  }
}

/// Kết quả kiểm tra toxic từ API.
class ToxicResult {
  final int label; // 0 = không toxic, 1 = toxic
  final double probability;
  final double threshold;

  const ToxicResult({
    required this.label,
    required this.probability,
    required this.threshold,
  });

  bool get isToxic => label == 1;

  factory ToxicResult.fromJson(Map<String, dynamic> json) {
    return ToxicResult(
      label: (json['label'] as num).toInt(),
      probability: (json['probability'] as num).toDouble(),
      threshold: (json['threshold'] as num).toDouble(),
    );
  }
}
