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
  });

  final int petId;
  final String petName;
  final String species;
  final String? description;
  final double? price;
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
      isActive: (row['IsActive'] as int?) == 1,
      createdAt: DateTime.parse(row['CreatedAt'] as String),
    );
  }
}

class PetRepository {
  PetRepository._();

  static final PetRepository instance = PetRepository._();

  Future<List<PetItem>> listActivePets({int limit = 200}) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'Pet',
      orderBy: 'CreatedAt DESC, PetID DESC',
      limit: limit,
    );

    return rows.map(PetItem.fromRow).toList();
  }
}
