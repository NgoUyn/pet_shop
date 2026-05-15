import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/db/app_database.dart';

class PetItem {
  PetItem({
    required this.petId,
    required this.petName,
    required this.species,
    required this.gender,
    required this.isActive,
    required this.createdAt,
    this.description,
    this.price,
    this.age,
    this.personality,
    this.imageUrl,
    this.isDewormed = false,
    this.isVaccinated = false,
    this.breed,
  });

  final int petId;
  final String petName;
  final String species;
  final String? breed;
  final String? gender;
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
      breed: row['Breed'] as String?,
      gender: row['Gender'] as String?,
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
    final results = await Future.wait([
      _listLocalActivePets(limit),
      _listFirestoreActivePets(limit),
    ]);

    final localItems = results[0] as List<PetItem>;
    final firestoreItems = results[1] as List<PetItem>;

    // Dedup by petId (Firestore takes precedence for same ID)
    final map = <int, PetItem>{};
    for (final item in localItems) {
      map[item.petId] = item;
    }
    for (final item in firestoreItems) {
      map[item.petId] = item;
    }

    var merged = map.values.toList();
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (limit < merged.length) {
      return merged.sublist(0, limit);
    }
    return merged;
  }

  Future<List<PetItem>> _listLocalActivePets(int limit) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'Pet',
      where: 'IsActive = 1',
      orderBy: 'CreatedAt DESC, PetID DESC',
      limit: limit,
    );
    return rows.map(PetItem.fromRow).toList();
  }

  Future<List<PetItem>> _listFirestoreActivePets(int limit) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pets')
          .where('isActive', isEqualTo: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PetItem(
          petId: (data['petId'] as num).toInt(),
          petName: (data['petName'] as String?) ?? '',
          species: (data['species'] as String?) ?? '',
          breed: data['breed'] as String?,
          gender: data['gender'] as String?,
          description: data['description'] as String?,
          price: (data['price'] as num?)?.toDouble(),
          age: (data['age'] as num?)?.toInt(),
          personality: data['personality'] as String?,
          imageUrl: data['imageUrl'] as String?,
          isDewormed: data['isDewormed'] as bool? ?? false,
          isVaccinated: data['isVaccinated'] as bool? ?? false,
          isActive: data['isActive'] as bool? ?? true,
          createdAt: DateTime.parse((data['createdAt'] as String)),
        );
      }).toList();
    } catch (e) {
      print('PetRepository._listFirestoreActivePets error: $e');
      return [];
    }
  }

  Future<PetItem?> getPetById(int petId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'Pet',
      where: 'PetID = ?',
      whereArgs: [petId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return PetItem.fromRow(rows.first);
    }

    // Fallback to Firestore (may have been created on another device)
    try {
      final doc = await FirebaseFirestore.instance
          .collection('pets')
          .doc(petId.toString())
          .get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return PetItem(
        petId: petId,
        petName: (data['petName'] as String?) ?? '',
        species: (data['species'] as String?) ?? '',
        breed: data['breed'] as String?,
        gender: data['gender'] as String?,
        description: data['description'] as String?,
        price: (data['price'] as num?)?.toDouble(),
        age: (data['age'] as num?)?.toInt(),
        personality: data['personality'] as String?,
        imageUrl: data['imageUrl'] as String?,
        isDewormed: data['isDewormed'] as bool? ?? false,
        isVaccinated: data['isVaccinated'] as bool? ?? false,
        isActive: data['isActive'] as bool? ?? true,
        createdAt: DateTime.parse((data['createdAt'] as String)),
      );
    } catch (e) {
      print('PetRepository.getPetById Firestore fallback error: $e');
      return null;
    }
  }

  Future<int> addPet({
    int? customerId,
    required String petName,
    required String species,
    required String gender,
    required double price,
    String? description,
    int? age,
    String? personality,
    required bool isDewormed,
    required bool isVaccinated,
    String? imageUrl,
    String? breed,
  }) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('Pet', {
      'CustomerID': customerId,
      'PetName': petName,
      'Species': species,
      'Breed': breed,
      'Gender': gender,
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
    _syncPetToFirestore(PetItem(
      petId: id,
      petName: petName,
      species: species,
      breed: breed,
      gender: gender,
      description: description,
      price: price,
      age: age,
      personality: personality,
      imageUrl: imageUrl,
      isDewormed: isDewormed,
      isVaccinated: isVaccinated,
      isActive: true,
      createdAt: DateTime.parse(now),
    ));
    _notifyChanged();
    return id;
  }

  Future<PetItem> updatePet({
    required int petId,
    int? customerId,
    required String petName,
    required String species,
    required String gender,
    required double price,
    String? description,
    int? age,
    String? personality,
    required bool isDewormed,
    required bool isVaccinated,
    String? imageUrl,
    bool? isActive,
    String? breed,
  }) async {
    final db = await AppDatabase.instance;
    final affected = await db.update(
      'Pet',
      {
        'CustomerID': customerId,
        'PetName': petName,
        'Species': species,
        'Breed': breed,
        'Gender': gender,
        'Description': description,
        'Price': price,
        'Age': age,
        'Personality': personality,
        'IsDewormed': isDewormed ? 1 : 0,
        'IsVaccinated': isVaccinated ? 1 : 0,
        'ImageURL': imageUrl,
        'IsActive': (isActive ?? true) ? 1 : 0,
        'UpdatedAt': DateTime.now().toIso8601String(),
      },
      where: 'PetID = ?',
      whereArgs: [petId],
    );

    if (affected == 0) {
      throw StateError('Không tìm thấy thú cưng để cập nhật');
    }

    _notifyChanged();

    final updated = await getPetById(petId);
    if (updated == null) {
      throw StateError('Không thể tải lại dữ liệu thú cưng');
    }

    _syncPetToFirestore(updated);
    return updated;
  }

  Future<void> deletePet(int petId) async {
    final db = await AppDatabase.instance;
    final affected = await db.update(
      'Pet',
      {
        'IsActive': 0,
        'UpdatedAt': DateTime.now().toIso8601String(),
      },
      where: 'PetID = ?',
      whereArgs: [petId],
    );

    if (affected == 0) {
      throw StateError('Không tìm thấy thú cưng để xóa');
    }

    _syncPetDeletionToFirestore(petId);
    _notifyChanged();
  }

  // ── Firestore sync ──────────────────────────────────────────────────

  void _syncPetToFirestore(PetItem pet) {
    _doSyncPetToFirestore(pet);
  }

  Future<void> _doSyncPetToFirestore(PetItem pet) async {
    try {
      await FirebaseFirestore.instance
          .collection('pets')
          .doc(pet.petId.toString())
          .set({
        'petId': pet.petId,
        'petName': pet.petName,
        'species': pet.species,
        'breed': pet.breed,
        'gender': pet.gender,
        'description': pet.description,
        'price': pet.price,
        'age': pet.age,
        'personality': pet.personality,
        'imageUrl': pet.imageUrl,
        'isDewormed': pet.isDewormed,
        'isVaccinated': pet.isVaccinated,
        'isActive': pet.isActive,
        'createdAt': pet.createdAt.toIso8601String(),
      });
    } catch (e) {
      print('PetRepository._doSyncPetToFirestore error: $e');
    }
  }

  Future<void> _syncPetDeletionToFirestore(int petId) async {
    try {
      await FirebaseFirestore.instance
          .collection('pets')
          .doc(petId.toString())
          .update({'isActive': false});
    } catch (e) {
      print('PetRepository._syncPetDeletionToFirestore error: $e');
    }
  }
}
