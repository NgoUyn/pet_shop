import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class PaymentService {
  static const String _baseUrl = "http://10.0.2.2:3000/api/payment";

  /// Tạo link thanh toán PayOS
  static Future<PaymentLinkResponse> createPaymentLink({
    required double amount,
    String? description,
    String? orderId,
    List<OrderItem>? items,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/create"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "amount": amount,
          "description": description ?? "Thanh toán đơn hàng",
          "orderId": orderId ?? DateTime.now().millisecondsSinceEpoch,
          "items": items?.map((e) => e.toJson()).toList() ?? [],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PaymentLinkResponse.fromJson(data);
      } else {
        throw Exception("Lỗi tạo link thanh toán: ${response.body}");
      }
    } catch (e) {
      throw Exception("Lỗi thanh toán: $e");
    }
  }

  /// Mở link thanh toán PayOS
  static Future<bool> openPaymentLink(String checkoutUrl) async {
    try {
      return await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      throw Exception("Không thể mở link thanh toán: $e");
    }
  }

  /// Kiểm tra trạng thái thanh toán
  static Future<PaymentStatus> getPaymentStatus(dynamic orderId) async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/status/$orderId"),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PaymentStatus.fromJson(data);
      } else {
        throw Exception("Lỗi kiểm tra trạng thái: ${response.body}");
      }
    } catch (e) {
      throw Exception("Lỗi kiểm tra trạng thái: $e");
    }
  }

  /// Hủy link thanh toán
  static Future<void> cancelPayment(dynamic orderId) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/cancel/$orderId"),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode != 200) {
        throw Exception("Lỗi hủy thanh toán: ${response.body}");
      }
    } catch (e) {
      throw Exception("Lỗi hủy thanh toán: $e");
    }
  }
}

class OrderItem {
  final String name;
  final int quantity;
  final double price;

  OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price.toInt(),
    };
  }
}

class PaymentLinkResponse {
  final String checkoutUrl;
  final dynamic orderCode;
  final double amount;
  final String description;
  final String status;

  PaymentLinkResponse({
    required this.checkoutUrl,
    required this.orderCode,
    required this.amount,
    required this.description,
    required this.status,
  });

  factory PaymentLinkResponse.fromJson(Map<String, dynamic> json) {
    return PaymentLinkResponse(
      checkoutUrl: json['checkoutUrl'] ?? '',
      orderCode: json['orderCode'],
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] ?? '',
      status: json['status'] ?? 'PENDING',
    );
  }
}

class PaymentStatus {
  final dynamic orderCode;
  final String status; // PENDING, PAID, CANCELLED, FAILED
  final double amount;
  final String? transactionId;

  PaymentStatus({
    required this.orderCode,
    required this.status,
    required this.amount,
    this.transactionId,
  });

  factory PaymentStatus.fromJson(Map<String, dynamic> json) {
    return PaymentStatus(
      orderCode: json['orderCode'],
      status: json['status'] ?? 'PENDING',
      amount: (json['amount'] as num).toDouble(),
      transactionId: json['transactionId'],
    );
  }

  bool get isPaid => status == 'PAID';
  bool get isCancelled => status == 'CANCELLED';
  bool get isFailed => status == 'FAILED';
  bool get isPending => status == 'PENDING';
}