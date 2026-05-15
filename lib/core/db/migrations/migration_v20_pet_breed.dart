import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV20PetBreed {
  static Future<void> up(Database db) async {
    // Add Breed column to Pet table
    try {
      await db.execute('ALTER TABLE Pet ADD COLUMN Breed TEXT;');
    } catch (e) {
      print('MigrationV20PetBreed: $e');
    }

    // Parse existing Species data to split into Species + Breed
    // Current format: "Chó Poodle", "Mèo Anh lông ngắn", etc.
    final rows = await db.query('Pet');
    for (final row in rows) {
      final species = (row['Species'] as String?) ?? '';
      final petId = row['PetID'] as int;
      final breed = row['Breed'] as String?;

      // Only process if Breed is empty and Species contains data
      if ((breed == null || breed.isEmpty) && species.isNotEmpty) {
        final parsed = _parseSpecies(species);
        if (parsed != null) {
          await db.update(
            'Pet',
            {
              'Species': parsed.$1,
              'Breed': parsed.$2,
            },
            where: 'PetID = ?',
            whereArgs: [petId],
          );
        }
      }
    }

    // Sync updated data to Firestore
    await _syncToFirestore(db);
  }

  /// Parses "Chó Poodle" → ('Chó', 'Poodle'), "Mèo Anh lông ngắn" → ('Mèo', 'Anh lông ngắn')
  static (String, String)? _parseSpecies(String species) {
    final trimmed = species.trim();
    if (trimmed.startsWith('Chó ')) {
      return ('Chó', trimmed.substring(4).trim());
    } else if (trimmed.startsWith('Mèo ')) {
      return ('Mèo', trimmed.substring(4).trim());
    }
    // If it doesn't start with Chó/Mèo, keep species as-is
    return null;
  }

  static Future<void> _syncToFirestore(Database db) async {
    try {
      final rows = await db.query('Pet');
      for (final row in rows) {
        final petId = row['PetID'] as int;
        final rawPrice = row['Price'] as num?;
        await FirebaseFirestore.instance
            .collection('pets')
            .doc(petId.toString())
            .set({
          'petId': petId,
          'petName': (row['PetName'] as String?) ?? '',
          'species': (row['Species'] as String?) ?? '',
          'breed': row['Breed'] as String?,
          'gender': row['Gender'] as String?,
          'description': row['Description'] as String?,
          'price': rawPrice?.toDouble(),
          'age': row['Age'] as int?,
          'personality': row['Personality'] as String?,
          'imageUrl': row['ImageURL'] as String?,
          'isDewormed': (row['IsDewormed'] as int?) == 1,
          'isVaccinated': (row['IsVaccinated'] as int?) == 1,
          'isActive': (row['IsActive'] as int?) == 1,
          'createdAt': (row['CreatedAt'] as String?) ?? DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('MigrationV20PetBreed._syncToFirestore error: $e');
    }
  }
}
