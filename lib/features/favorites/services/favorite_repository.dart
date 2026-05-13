import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/db/app_database.dart';
import '../../auth/services/auth_session.dart';
import '../../home/services/product_repository.dart';
import '../../home/services/pet_repository.dart';

class FavoriteRepository {
  FavoriteRepository._();

  static final FavoriteRepository instance = FavoriteRepository._();

  final ValueNotifier<int> favoriteCount = ValueNotifier<int>(0);

  Future<void> refreshCountForCurrentUser() async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) {
      favoriteCount.value = 0;
      return;
    }

    final db = await AppDatabase.instance;
    final productCount = await db.rawQuery(
      'SELECT COUNT(*) AS Cnt FROM FavoriteProduct WHERE UserID = ?',
      [userId],
    );
    final petCount = await db.rawQuery(
      'SELECT COUNT(*) AS Cnt FROM FavoritePet WHERE UserID = ?',
      [userId],
    );
    final total = ((productCount.first['Cnt'] as int?) ?? 0) +
        ((petCount.first['Cnt'] as int?) ?? 0);
    favoriteCount.value = total;
  }

  // ---- Product Favorites ----

  Future<bool> isProductFavorited(int productId) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) return false;

    final db = await AppDatabase.instance;
    final rows = await db.query(
      'FavoriteProduct',
      where: 'UserID = ? AND ProductID = ?',
      whereArgs: [userId, productId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> toggleProductFavorite(int productId) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) throw StateError('Vui lòng đăng nhập');

    final db = await AppDatabase.instance;
    final existing = await db.query(
      'FavoriteProduct',
      where: 'UserID = ? AND ProductID = ?',
      whereArgs: [userId, productId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.delete(
        'FavoriteProduct',
        where: 'UserID = ? AND ProductID = ?',
        whereArgs: [userId, productId],
      );
      _unsyncFavoriteProductFromFirestore(productId);
    } else {
      await db.insert('FavoriteProduct', {
        'UserID': userId,
        'ProductID': productId,
        'CreatedAt': DateTime.now().toIso8601String(),
      });
      // Fetch product info and sync to Firestore (fire-and-forget)
      _syncFavoriteProductToFirestore(productId);
    }

    await refreshCountForCurrentUser();
  }

  Future<List<ProductItem>> listFavoriteProducts() async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) return [];

    final results = await Future.wait([
      _listLocalFavoriteProducts(userId),
      _listFirestoreFavoriteProducts(),
    ]);

    final localItems = results[0] as List<ProductItem>;
    final firestoreItems = results[1] as List<ProductItem>;

    // Dedup by productId
    final seen = <int>{};
    final merged = <ProductItem>[];
    for (final item in [...localItems, ...firestoreItems]) {
      if (seen.add(item.productId)) {
        merged.add(item);
      }
    }
    return merged;
  }

  Future<List<ProductItem>> _listLocalFavoriteProducts(int userId) async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery(
      '''
      SELECT p.* FROM Product p
      JOIN FavoriteProduct f ON p.ProductID = f.ProductID
      WHERE f.UserID = ?
      ORDER BY f.CreatedAt DESC
      ''',
      [userId],
    );
    return rows.map(ProductItem.fromRow).toList();
  }

  Future<List<ProductItem>> _listFirestoreFavoriteProducts() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return [];

      final snapshot = await FirebaseFirestore.instance
          .collection('favoriteProducts')
          .where('firebaseUid', isEqualTo: firebaseUser.uid)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ProductItem(
          productId: (data['productId'] as num).toInt(),
          categoryId: (data['categoryId'] as num?)?.toInt() ?? 0,
          productName: (data['productName'] as String?) ?? '',
          price: (data['price'] as num).toDouble(),
          stockQuantity: (data['stockQuantity'] as num?)?.toInt() ?? 0,
          description: data['description'] as String?,
          imageUrl: data['imageUrl'] as String?,
          isActive: data['isActive'] as bool? ?? true,
          createdAt: DateTime.parse((data['createdAt'] as String)),
        );
      }).toList();
    } catch (e) {
      print('FavoriteRepository._listFirestoreFavoriteProducts error: $e');
      return [];
    }
  }

  Future<void> removeProductFavorite(int productId) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) return;

    final db = await AppDatabase.instance;
    await db.delete(
      'FavoriteProduct',
      where: 'UserID = ? AND ProductID = ?',
      whereArgs: [userId, productId],
    );
    _unsyncFavoriteProductFromFirestore(productId);
    await refreshCountForCurrentUser();
  }

  // ---- Pet Favorites ----

  Future<bool> isPetFavorited(int petId) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) return false;

    final db = await AppDatabase.instance;
    final rows = await db.query(
      'FavoritePet',
      where: 'UserID = ? AND PetID = ?',
      whereArgs: [userId, petId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> togglePetFavorite(int petId) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) throw StateError('Vui lòng đăng nhập');

    final db = await AppDatabase.instance;
    final existing = await db.query(
      'FavoritePet',
      where: 'UserID = ? AND PetID = ?',
      whereArgs: [userId, petId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.delete(
        'FavoritePet',
        where: 'UserID = ? AND PetID = ?',
        whereArgs: [userId, petId],
      );
      _unsyncFavoritePetFromFirestore(petId);
    } else {
      await db.insert('FavoritePet', {
        'UserID': userId,
        'PetID': petId,
        'CreatedAt': DateTime.now().toIso8601String(),
      });
      _syncFavoritePetToFirestore(petId);
    }

    await refreshCountForCurrentUser();
  }

  Future<List<PetItem>> listFavoritePets() async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) return [];

    final results = await Future.wait([
      _listLocalFavoritePets(userId),
      _listFirestoreFavoritePets(),
    ]);

    final localItems = results[0] as List<PetItem>;
    final firestoreItems = results[1] as List<PetItem>;

    final seen = <int>{};
    final merged = <PetItem>[];
    for (final item in [...localItems, ...firestoreItems]) {
      if (seen.add(item.petId)) {
        merged.add(item);
      }
    }
    return merged;
  }

  Future<List<PetItem>> _listLocalFavoritePets(int userId) async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery(
      '''
      SELECT p.* FROM Pet p
      JOIN FavoritePet f ON p.PetID = f.PetID
      WHERE f.UserID = ?
      ORDER BY f.CreatedAt DESC
      ''',
      [userId],
    );
    return rows.map(PetItem.fromRow).toList();
  }

  Future<List<PetItem>> _listFirestoreFavoritePets() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return [];

      final snapshot = await FirebaseFirestore.instance
          .collection('favoritePets')
          .where('firebaseUid', isEqualTo: firebaseUser.uid)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PetItem(
          petId: (data['petId'] as num).toInt(),
          petName: (data['petName'] as String?) ?? '',
          species: (data['species'] as String?) ?? '',
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
      print('FavoriteRepository._listFirestoreFavoritePets error: $e');
      return [];
    }
  }

  Future<void> removePetFavorite(int petId) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) return;

    final db = await AppDatabase.instance;
    await db.delete(
      'FavoritePet',
      where: 'UserID = ? AND PetID = ?',
      whereArgs: [userId, petId],
    );
    _unsyncFavoritePetFromFirestore(petId);
    await refreshCountForCurrentUser();
  }

  // ── Firestore sync ──────────────────────────────────────────────────

  Future<void> _syncFavoriteProductToFirestore(int productId) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;

      final db = await AppDatabase.instance;
      final productRows = await db.query('Product',
        where: 'ProductID = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (productRows.isEmpty) return;
      final p = ProductItem.fromRow(productRows.first);

      await FirebaseFirestore.instance.collection('favoriteProducts').add({
        'firebaseUid': firebaseUser.uid,
        'productId': p.productId,
        'categoryId': p.categoryId,
        'productName': p.productName,
        'price': p.price,
        'stockQuantity': p.stockQuantity,
        'description': p.description,
        'imageUrl': p.imageUrl,
        'isActive': p.isActive,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('FavoriteRepository._syncFavoriteProductToFirestore error: $e');
    }
  }

  Future<void> _unsyncFavoriteProductFromFirestore(int productId) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;
      final snapshot = await FirebaseFirestore.instance
          .collection('favoriteProducts')
          .where('firebaseUid', isEqualTo: firebaseUser.uid)
          .where('productId', isEqualTo: productId)
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('FavoriteRepository._unsyncFavoriteProductFromFirestore error: $e');
    }
  }

  Future<void> _syncFavoritePetToFirestore(int petId) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;

      final db = await AppDatabase.instance;
      final petRows = await db.query('Pet',
        where: 'PetID = ?',
        whereArgs: [petId],
        limit: 1,
      );
      if (petRows.isEmpty) return;
      final p = PetItem.fromRow(petRows.first);

      await FirebaseFirestore.instance.collection('favoritePets').add({
        'firebaseUid': firebaseUser.uid,
        'petId': p.petId,
        'petName': p.petName,
        'species': p.species,
        'gender': p.gender,
        'description': p.description,
        'price': p.price,
        'age': p.age,
        'personality': p.personality,
        'imageUrl': p.imageUrl,
        'isDewormed': p.isDewormed,
        'isVaccinated': p.isVaccinated,
        'isActive': p.isActive,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('FavoriteRepository._syncFavoritePetToFirestore error: $e');
    }
  }

  Future<void> _unsyncFavoritePetFromFirestore(int petId) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;
      final snapshot = await FirebaseFirestore.instance
          .collection('favoritePets')
          .where('firebaseUid', isEqualTo: firebaseUser.uid)
          .where('petId', isEqualTo: petId)
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('FavoriteRepository._unsyncFavoritePetFromFirestore error: $e');
    }
  }
}
