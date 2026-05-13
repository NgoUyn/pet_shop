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
    } else {
      await db.insert('FavoriteProduct', {
        'UserID': userId,
        'ProductID': productId,
        'CreatedAt': DateTime.now().toIso8601String(),
      });
    }

    await refreshCountForCurrentUser();
  }

  Future<List<ProductItem>> listFavoriteProducts() async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) return [];

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

  Future<void> removeProductFavorite(int productId) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) return;

    final db = await AppDatabase.instance;
    await db.delete(
      'FavoriteProduct',
      where: 'UserID = ? AND ProductID = ?',
      whereArgs: [userId, productId],
    );
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
    } else {
      await db.insert('FavoritePet', {
        'UserID': userId,
        'PetID': petId,
        'CreatedAt': DateTime.now().toIso8601String(),
      });
    }

    await refreshCountForCurrentUser();
  }

  Future<List<PetItem>> listFavoritePets() async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) return [];

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

  Future<void> removePetFavorite(int petId) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) return;

    final db = await AppDatabase.instance;
    await db.delete(
      'FavoritePet',
      where: 'UserID = ? AND PetID = ?',
      whereArgs: [userId, petId],
    );
    await refreshCountForCurrentUser();
  }
}
