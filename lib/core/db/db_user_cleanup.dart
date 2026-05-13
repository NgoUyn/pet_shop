import 'package:sqflite/sqflite.dart';

Future<void> deleteUserByIdFromDb(Database db, int userId) async {
  await db.transaction((txn) async {
    final userRows = await txn.query(
      'User',
      columns: ['Role'],
      where: 'UserID = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (userRows.isEmpty) {
      throw StateError('Không tìm thấy user để xoá');
    }

    final customerRows = await txn.query(
      'Customer',
      columns: ['CustomerID'],
      where: 'UserID = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (customerRows.isNotEmpty) {
      final customerId = customerRows.first['CustomerID'] as int;

      await txn.delete(
        'CartItem',
        where: 'CartID IN (SELECT CartID FROM Cart WHERE CustomerID = ?)',
        whereArgs: [customerId],
      );

      await txn.delete(
        'Cart',
        where: 'CustomerID = ?',
        whereArgs: [customerId],
      );

      await txn.delete(
        'InvoiceDetail',
        where: 'InvoiceID IN (SELECT InvoiceID FROM Invoice WHERE CustomerID = ?)',
        whereArgs: [customerId],
      );

      await txn.delete(
        'Invoice',
        where: 'CustomerID = ?',
        whereArgs: [customerId],
      );

      await txn.update(
        'Pet',
        {'CustomerID': null},
        where: 'CustomerID = ?',
        whereArgs: [customerId],
      );

      await txn.delete(
        'Customer',
        where: 'CustomerID = ?',
        whereArgs: [customerId],
      );
    }

    await txn.delete(
      'User',
      where: 'UserID = ?',
      whereArgs: [userId],
    );
  });
}
