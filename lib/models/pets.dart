class Pet {
  final int? id;
  final String name;
  final String species; // Loài: Chó, Mèo...
  final String? breed;   // Giống: Munchkin, Corgi...
  final String gender;  // Chưa xác định, Đực, Cái
  final String age;
  final double price;
  final String? imageUrl;
  final String status;  // Đang bán, Đã bán
  final String? description;

  const Pet({
    this.id,
    required this.name,
    required this.species,
    this.breed,
    required this.gender,
    required this.age,
    required this.price,
    this.imageUrl,
    required this.status,
    this.description,
  });

  Pet copyWith({
    int? id,
    String? name,
    String? species,
    String? breed,
    String? gender,
    String? age,
    double? price,
    String? imageUrl,
    String? status,
    String? description,
  }) {
    return Pet(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      description: description ?? this.description,
    );
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'] as int?,
      name: json['name'] as String,
      species: json['species'] as String,
      breed: json['breed'] as String?,
      gender: json['gender'] as String,
      age: json['age'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String?,
      status: json['status'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'breed': breed,
      'gender': gender,
      'age': age,
      'price': price,
      'imageUrl': imageUrl,
      'status': status,
      'description': description,
    };
  }
}