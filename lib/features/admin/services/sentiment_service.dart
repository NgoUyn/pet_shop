import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

/// Service to call the sentiment analysis API
class SentimentService {
  /// Get the correct base URL based on platform
  static String get _baseUrl {
    // Android emulator uses 10.0.2.2 to reach host machine
    // iOS simulator uses localhost
    // Web/Windows uses 127.0.0.1
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:5000';
      }
    } catch (_) {}
    return 'http://127.0.0.1:5000';
  }

  static final SentimentService instance = SentimentService._();
  SentimentService._();

  /// Analyze sentiment of a Vietnamese text
  /// Returns a map with: label, neg, neu, pos
  Future<Map<String, dynamic>> predict(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'label': 'LỖI', 'neg': 0, 'neu': 0, 'pos': 0};
    } catch (e) {
      print('SentimentService.predict error: $e');
      return {'label': 'LỖI', 'neg': 0, 'neu': 0, 'pos': 0};
    }
  }

  /// Analyze multiple texts in batch (sequential calls)
  Future<List<Map<String, dynamic>>> predictBatch(List<String> texts) async {
    final results = <Map<String, dynamic>>[];
    for (final text in texts) {
      if (text.trim().isEmpty) {
        results.add({'label': 'TRUNG TÍNH', 'neg': 0, 'neu': 100, 'pos': 0});
        continue;
      }
      final result = await predict(text);
      results.add(result);
      // Small delay to avoid overwhelming the server
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return results;
  }

  /// Check if the server is running
  Future<bool> isServerAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
