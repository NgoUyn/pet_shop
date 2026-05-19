import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/db/app_database.dart';

// ── Models ────────────────────────────────────────────────────────────────

class PetBreed {
  PetBreed({
    required this.breedId,
    required this.species,
    required this.breedName,
    this.description,
    this.isActive = true,
  });

  final int breedId;
  final String species;
  final String breedName;
  final String? description;
  final bool isActive;

  factory PetBreed.fromRow(Map<String, dynamic> row) => PetBreed(
        breedId: row['BreedID'] as int,
        species: (row['Species'] as String?) ?? '',
        breedName: (row['BreedName'] as String?) ?? '',
        description: row['Description'] as String?,
        isActive: (row['IsActive'] as int?) == 1,
      );

  Map<String, dynamic> toFirestore() => {
        'breedId': breedId,
        'species': species,
        'breedName': breedName,
        'description': description,
        'isActive': isActive,
      };
}

class ProductSubCategory {
  ProductSubCategory({
    required this.subCategoryId,
    required this.subCategoryName,
    this.description,
    this.isActive = true,
  });

  final int subCategoryId;
  final String subCategoryName;
  final String? description;
  final bool isActive;

  factory ProductSubCategory.fromRow(Map<String, dynamic> row) =>
      ProductSubCategory(
        subCategoryId: row['SubCategoryID'] as int,
        subCategoryName: (row['SubCategoryName'] as String?) ?? '',
        description: row['Description'] as String?,
        isActive: (row['IsActive'] as int?) == 1,
      );

  Map<String, dynamic> toFirestore() => {
        'subCategoryId': subCategoryId,
        'subCategoryName': subCategoryName,
        'description': description,
        'isActive': isActive,
      };
}

// ── Repository ────────────────────────────────────────────────────────────

class CategoryRepository {
  CategoryRepository._();
  static final CategoryRepository instance = CategoryRepository._();

  final ValueNotifier<int> changeToken = ValueNotifier<int>(0);

  void _notify() => changeToken.value++;

  // ── Firestore collection refs ─────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> get _breedCol =>
      FirebaseFirestore.instance.collection('petBreedCategories');

  static CollectionReference<Map<String, dynamic>> get _subCatCol =>
      FirebaseFirestore.instance.collection('productSubCategories');

  // ════════════════════════════════════════════════════════════════════════
  // PetBreed CRUD
  // ════════════════════════════════════════════════════════════════════════

  Stream<List<PetBreed>> watchBreeds({String? species}) {
    Query<Map<String, dynamic>> q =
        _breedCol.where('isActive', isEqualTo: true);
    if (species != null) q = q.where('species', isEqualTo: species);
    return q.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PetBreed(
                breedId: (d.data()['breedId'] as num).toInt(),
                species: (d.data()['species'] as String?) ?? '',
                breedName: (d.data()['breedName'] as String?) ?? '',
                description: d.data()['description'] as String?,
                isActive: d.data()['isActive'] as bool? ?? true,
              ))
          .toList();
      list.sort((a, b) => a.breedName.compareTo(b.breedName));
      return list;
    });
  }

  Stream<List<PetBreed>> watchAllBreeds() {
    return _breedCol.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PetBreed(
                breedId: (d.data()['breedId'] as num).toInt(),
                species: (d.data()['species'] as String?) ?? '',
                breedName: (d.data()['breedName'] as String?) ?? '',
                description: d.data()['description'] as String?,
                isActive: d.data()['isActive'] as bool? ?? true,
              ))
          .toList();
      list.sort((a, b) {
        final sc = a.species.compareTo(b.species);
        return sc != 0 ? sc : a.breedName.compareTo(b.breedName);
      });
      return list;
    });
  }

  Future<List<PetBreed>> listBreeds({String? species}) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'PetBreedCategory',
      where: species != null ? 'IsActive = 1 AND Species = ?' : 'IsActive = 1',
      whereArgs: species != null ? [species] : null,
      orderBy: 'Species ASC, BreedName ASC',
    );
    return rows.map(PetBreed.fromRow).toList();
  }

  Future<PetBreed> addBreed({
    required String species,
    required String breedName,
    String? description,
  }) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('PetBreedCategory', {
      'Species': species,
      'BreedName': breedName,
      'Description': description,
      'IsActive': 1,
      'CreatedAt': now,
    });
    final breed = PetBreed(
      breedId: id,
      species: species,
      breedName: breedName,
      description: description,
    );
    _syncBreedToFirestore(breed);
    _notify();
    return breed;
  }

  Future<void> updateBreed({
    required int breedId,
    required String species,
    required String breedName,
    String? description,
  }) async {
    final db = await AppDatabase.instance;
    await db.update(
      'PetBreedCategory',
      {'Species': species, 'BreedName': breedName, 'Description': description},
      where: 'BreedID = ?',
      whereArgs: [breedId],
    );
    _syncBreedToFirestore(PetBreed(
      breedId: breedId,
      species: species,
      breedName: breedName,
      description: description,
    ));
    _notify();
  }

  Future<void> deleteBreed(int breedId) async {
    final db = await AppDatabase.instance;
    await db.update(
      'PetBreedCategory',
      {'IsActive': 0},
      where: 'BreedID = ?',
      whereArgs: [breedId],
    );
    _breedCol.doc(breedId.toString()).update({'isActive': false}).catchError(
        (e) => print('deleteBreed Firestore: $e'));
    _notify();
  }

  void _syncBreedToFirestore(PetBreed breed) {
    _breedCol
        .doc(breed.breedId.toString())
        .set(breed.toFirestore())
        .catchError((e) => print('syncBreed error: $e'));
  }

  // ════════════════════════════════════════════════════════════════════════
  // ProductSubCategory CRUD
  // ════════════════════════════════════════════════════════════════════════

  Stream<List<ProductSubCategory>> watchSubCategories() {
    return _subCatCol
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => ProductSubCategory(
                subCategoryId: (d.data()['subCategoryId'] as num).toInt(),
                subCategoryName:
                    (d.data()['subCategoryName'] as String?) ?? '',
                description: d.data()['description'] as String?,
                isActive: d.data()['isActive'] as bool? ?? true,
              ))
          .toList();
      list.sort((a, b) => a.subCategoryName.compareTo(b.subCategoryName));
      return list;
    });
  }

  Stream<List<ProductSubCategory>> watchAllSubCategories() {
    return _subCatCol.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => ProductSubCategory(
                subCategoryId: (d.data()['subCategoryId'] as num).toInt(),
                subCategoryName:
                    (d.data()['subCategoryName'] as String?) ?? '',
                description: d.data()['description'] as String?,
                isActive: d.data()['isActive'] as bool? ?? true,
              ))
          .toList();
      list.sort((a, b) => a.subCategoryName.compareTo(b.subCategoryName));
      return list;
    });
  }

  Future<List<ProductSubCategory>> listSubCategories() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'ProductSubCategory',
      where: 'IsActive = 1',
      orderBy: 'SubCategoryName ASC',
    );
    return rows.map(ProductSubCategory.fromRow).toList();
  }

  Future<ProductSubCategory> addSubCategory({
    required String subCategoryName,
    String? description,
  }) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('ProductSubCategory', {
      'SubCategoryName': subCategoryName,
      'Description': description,
      'IsActive': 1,
      'CreatedAt': now,
    });
    final sub = ProductSubCategory(
      subCategoryId: id,
      subCategoryName: subCategoryName,
      description: description,
    );
    _syncSubCatToFirestore(sub);
    _notify();
    return sub;
  }

  Future<void> updateSubCategory({
    required int subCategoryId,
    required String subCategoryName,
    String? description,
  }) async {
    final db = await AppDatabase.instance;
    await db.update(
      'ProductSubCategory',
      {'SubCategoryName': subCategoryName, 'Description': description},
      where: 'SubCategoryID = ?',
      whereArgs: [subCategoryId],
    );
    _syncSubCatToFirestore(ProductSubCategory(
      subCategoryId: subCategoryId,
      subCategoryName: subCategoryName,
      description: description,
    ));
    _notify();
  }

  Future<void> deleteSubCategory(int subCategoryId) async {
    final db = await AppDatabase.instance;
    await db.update(
      'ProductSubCategory',
      {'IsActive': 0},
      where: 'SubCategoryID = ?',
      whereArgs: [subCategoryId],
    );
    _subCatCol
        .doc(subCategoryId.toString())
        .update({'isActive': false}).catchError(
            (e) => print('deleteSubCategory Firestore: $e'));
    _notify();
  }

  void _syncSubCatToFirestore(ProductSubCategory sub) {
    _subCatCol
        .doc(sub.subCategoryId.toString())
        .set(sub.toFirestore())
        .catchError((e) => print('syncSubCat error: $e'));
  }
}
