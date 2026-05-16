class Product {
  final int? productId;
  final int categoryId;
  final String productName;
  final double price;
  final int stockQuantity;
  final String? description;
  final String? imageUrl;
  final bool isActive; // SQLite lưu int (0,1), nhưng Dart nên dùng bool
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Product({
    this.productId,
    required this.categoryId,
    required this.productName,
    required this.price,
    required this.stockQuantity,
    this.description,
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  // Tạo bản sao với các thay đổi (Dùng khi cập nhật ảnh hoặc giá)
  Product copyWith({
    int? productId,
    int? categoryId,
    String? productName,
    double? price,
    int? stockQuantity,
    String? description,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      productId: productId ?? this.productId,
      categoryId: categoryId ?? this.categoryId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Chuyển từ Map (Database/API) sang Object
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productId: json['ProductID'] as int?,
      categoryId: json['CategoryID'] as int,
      productName: json['ProductName'] as String,
      price: (json['Price'] as num).toDouble(),
      stockQuantity: json['StockQuantity'] as int,
      description: json['Description'] as String?,
      imageUrl: json['ImageURL'] as String?,
      isActive: (json['IsActive'] as int) == 1,
      createdAt: DateTime.parse(json['CreatedAt'] as String),
      updatedAt: json['UpdatedAt'] != null
          ? DateTime.parse(json['UpdatedAt'] as String)
          : null,
    );
  }

  // Chuyển từ Object sang Map để lưu vào Database/API
  Map<String, dynamic> toJson() {
    return {
      if (productId != null) 'ProductID': productId,
      'CategoryID': categoryId,
      'ProductName': productName,
      'Price': price,
      'StockQuantity': stockQuantity,
      'Description': description,
      'ImageURL': imageUrl,
      'IsActive': isActive ? 1 : 0,
      'CreatedAt': createdAt.toIso8601String(),
      'UpdatedAt': updatedAt?.toIso8601String(),
    };
  }
}