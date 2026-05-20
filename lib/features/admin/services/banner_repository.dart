import '../../../core/db/app_database.dart';

class BannerItem {
  final int id;
  final String? name;
  final String imageUrl;
  final bool isActive;
  final int sortOrder;
  final String createdAt;

  BannerItem({required this.id, this.name, required this.imageUrl, required this.isActive, required this.sortOrder, required this.createdAt});

  static BannerItem fromRow(Map<String, Object?> row) {
    return BannerItem(
      id: row['BannerID'] as int,
      name: row['Name'] as String?,
      imageUrl: (row['ImageURL'] as String?) ?? '',
      isActive: ((row['IsActive'] as int?) ?? 1) == 1,
      sortOrder: (row['SortOrder'] as int?) ?? 0,
      createdAt: (row['CreatedAt'] as String?) ?? '',
    );
  }
}

class BannerRepository {
  BannerRepository._();
  static final BannerRepository instance = BannerRepository._();

  Future<List<BannerItem>> listAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('Banner', orderBy: 'SortOrder ASC, BannerID DESC');
    return rows.map((r) => BannerItem.fromRow(r)).toList();
  }

  Future<int> create({String? name, required String imageUrl, int sortOrder = 0, bool isActive = true}) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();
    return await db.insert('Banner', {
      'Name': name,
      'ImageURL': imageUrl,
      'IsActive': isActive ? 1 : 0,
      'SortOrder': sortOrder,
      'CreatedAt': now,
      'UpdatedAt': null,
    });
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance;
    await db.delete('Banner', where: 'BannerID = ?', whereArgs: [id]);
  }
}
