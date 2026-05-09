import 'package:flutter/foundation.dart';

import '../../../core/db/app_database.dart';

class PetItem {
  PetItem({
    required this.petId,
    required this.petName,
    required this.species,
    required this.isActive,
    required this.createdAt,
    this.description,
    this.price,
    this.age,
    this.personality,
    this.imageUrl,
    this.isDewormed = false,
    this.isVaccinated = false,
  });

  final int petId;
  final String petName;
  final String species;
  final String? description;
  final double? price;
  final int? age;
  final String? personality;
  final String? imageUrl;
  final bool isDewormed;
  final bool isVaccinated;
  final bool isActive;
  final DateTime createdAt;

  static PetItem fromRow(Map<String, Object?> row) {
    final rawPrice = row['Price'] as num?;
    return PetItem(
      petId: row['PetID'] as int,
      petName: (row['PetName'] as String?) ?? '',
      species: (row['Species'] as String?) ?? '',
      description: row['Description'] as String?,
      price: rawPrice?.toDouble(),
      age: row['Age'] as int?,
      personality: row['Personality'] as String?,
      imageUrl: row['ImageURL'] as String?,
      isDewormed: (row['IsDewormed'] as int?) == 1,
      isVaccinated: (row['IsVaccinated'] as int?) == 1,
      isActive: (row['IsActive'] as int?) == 1,
      createdAt: DateTime.parse(row['CreatedAt'] as String),
    );
  }
}

class PetRepository {
  PetRepository._();

  static final PetRepository instance = PetRepository._();
  final ValueNotifier<int> changeToken = ValueNotifier<int>(0);

  void _notifyChanged() {
    changeToken.value = changeToken.value + 1;
  }

  Future<List<PetItem>> listActivePets({int limit = 200}) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'Pet',
      orderBy: 'CreatedAt DESC, PetID DESC',
      limit: limit,
    );

    return rows.map(PetItem.fromRow).toList();
  }

  Future<int> addPet({
    int? customerId,
    required String petName,
    required String species,
    required double price,
    String? description,
    int? age,
    String? personality,
    required bool isDewormed,
    required bool isVaccinated,
    String? imageUrl,
  }) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('Pet', {
      'CustomerID': customerId,
      'PetName': petName,
      'Species': species,
      'Description': description,
      'Price': price,
      'Age': age,
      'Personality': personality,
      'IsDewormed': isDewormed ? 1 : 0,
      'IsVaccinated': isVaccinated ? 1 : 0,
      'ImageURL': imageUrl,
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    });
    _notifyChanged();
    return id;
  }
}
