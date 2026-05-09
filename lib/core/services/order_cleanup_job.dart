import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';

/// Background job that periodically checks for unpaid orders
/// and cancels those that have been unpaid for more than 24 hours.
class OrderCleanupJob {
  OrderCleanupJob._();

  static final OrderCleanupJob instance = OrderCleanupJob._();

  Timer? _timer;
  bool _isRunning = false;

  /// Start the background job. Checks every 5 minutes.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    print('OrderCleanupJob: started');

    // Run immediately on start
    _runCleanup();

    // Then run every 5 minutes
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      _runCleanup();
    });
  }

  /// Stop the background job
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    print('OrderCleanupJob: stopped');
  }

  Future<void> _runCleanup() async {
    try {
      final db = await AppDatabase.instance;
      await _cancelUnpaidOrdersOlderThan24h(db);
    } catch (e) {
      print('OrderCleanupJob: error during cleanup: $e');
    }
  }

  /// Cancel all orders with PaymentStatus = 'Unpaid' that were created
  /// more than 24 hours ago.
  Future<void> _cancelUnpaidOrdersOlderThan24h(Database db) async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final cutoffStr = cutoff.toIso8601String();

    print('OrderCleanupJob: checking for unpaid orders older than $cutoffStr');

    // Find unpaid orders older than 24h
    final unpaidOrders = await db.query(
      'Invoice',
      columns: ['InvoiceID', 'CustomerID', 'CreatedAt'],
      where: 'PaymentStatus = ? AND CreatedAt < ?',
      whereArgs: ['Unpaid', cutoffStr],
    );

    if (unpaidOrders.isEmpty) {
      print('OrderCleanupJob: no unpaid orders to cancel');
      return;
    }

    print('OrderCleanupJob: found ${unpaidOrders.length} unpaid order(s) to cancel');

    for (final order in unpaidOrders) {
      final invoiceId = order['InvoiceID'] as int;
      final now = DateTime.now().toIso8601String();

      try {
        await db.transaction((txn) async {
          // Update invoice status to Cancelled
          await txn.update(
            'Invoice',
            {
              'PaymentStatus': 'Cancelled',
              'UpdatedAt': now,
            },
            where: 'InvoiceID = ?',
            whereArgs: [invoiceId],
          );

          // Update payment record status
          await txn.update(
            'Payment',
            {
              'Status': 'Cancelled',
            },
            where: 'InvoiceID = ?',
            whereArgs: [invoiceId],
          );

          // Restore stock for each product in the invoice
          final details = await txn.query(
            'InvoiceDetail',
            columns: ['ProductID', 'Quantity'],
            where: 'InvoiceID = ?',
            whereArgs: [invoiceId],
          );

          for (final detail in details) {
            final productId = detail['ProductID'] as int?;
            final quantity = (detail['Quantity'] as int?) ?? 0;

            if (productId != null && quantity > 0) {
              await txn.rawUpdate(
                'UPDATE Product SET StockQuantity = StockQuantity + ? WHERE ProductID = ?',
                [quantity, productId],
              );
            }
          }
        });

        print('OrderCleanupJob: cancelled order #$invoiceId');
      } catch (e) {
        print('OrderCleanupJob: failed to cancel order #$invoiceId: $e');
      }
    }
  }
}
