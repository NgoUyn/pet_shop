import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

/// Result item from image search
class ImageSearchResult {
  final int id;
  final String name;
  final String imageUrl;
  final double price;
  final String type; // "product" or "pet"
  final String description;
  final String category;
  final double similarity;

  ImageSearchResult({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.type,
    this.description = '',
    this.category = '',
    required this.similarity,
  });

  factory ImageSearchResult.fromJson(Map<String, dynamic> json) {
    return ImageSearchResult(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] as String? ?? 'product',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Service to search products/pets by image using CLIP backend.
class ImageSearchService {
  ImageSearchService._();
  static final ImageSearchService instance = ImageSearchService._();

  // Backend URL - change this to your server address
  // For Android emulator: http://10.0.2.2:3002
  // For iOS simulator: http://localhost:3002
  // For real device: http://<your-ip>:3002
  static const String _baseUrl = 'http://10.0.2.2:3002';

  final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery or camera
  Future<XFile?> pickImage({bool fromCamera = false}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      print('ImageSearchService.pickImage error: $e');
      return null;
    }
  }

  /// Search by uploading an image file
  Future<List<ImageSearchResult>> searchByImageFile(
    XFile imageFile, {
    int topK = 20,
  }) async {
    print('=' * 50);
    print('[ImageSearch] Starting searchByImageFile...');
    print('[ImageSearch] Base URL: $_baseUrl');
    print('[ImageSearch] File: ${imageFile.name}, size: ${await imageFile.length()} bytes');

    try {
      final uri = Uri.parse('$_baseUrl/api/v1/search/image');
      print('[ImageSearch] POST $uri');

      final request = http.MultipartRequest('POST', uri);

      // Attach image file
      final bytes = await imageFile.readAsBytes();
      print('[ImageSearch] Read ${bytes.length} bytes from file');
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: imageFile.name,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      request.fields['top_k'] = topK.toString();

      print('[ImageSearch] Sending request...');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      print('[ImageSearch] Got response status: ${streamedResponse.statusCode}');

      final response = await http.Response.fromStream(streamedResponse);
      print('[ImageSearch] Response body length: ${response.body.length}');
      print('[ImageSearch] Response body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        print('[ImageSearch] SUCCESS! Parsed ${data.length} results');
        return data
            .map((e) => ImageSearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        print('[ImageSearch] ERROR: Status ${response.statusCode}');
        print('[ImageSearch] Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('[ImageSearch] EXCEPTION: $e');
      print('[ImageSearch] Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Search by providing an image URL (e.g., from Cloudinary)
  Future<List<ImageSearchResult>> searchByImageUrl(
    String imageUrl, {
    int topK = 20,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/search/image-url');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'image_url': imageUrl,
              'top_k': topK,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((e) => ImageSearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        print('ImageSearchService.searchByImageUrl error: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e) {
      print('ImageSearchService.searchByImageUrl error: $e');
      return [];
    }
  }

  /// Search by text description (uses CLIP text encoder)
  Future<List<ImageSearchResult>> searchByText(
    String text, {
    int topK = 20,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/search/text');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'top_k': topK,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((e) => ImageSearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        print('ImageSearchService.searchByText error: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e) {
      print('ImageSearchService.searchByText error: $e');
      return [];
    }
  }

  /// Get server stats
  Future<Map<String, dynamic>?> getStats() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/stats');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('ImageSearchService.getStats error: $e');
      return null;
    }
  }
}
