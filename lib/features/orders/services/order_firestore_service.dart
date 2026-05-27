import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/db/app_database.dart';
import '../../auth/services/auth_session.dart';
import 'order_repository.dart';

class OrderFirestoreService {
  OrderFirestoreService._();

  static final OrderFirestoreService instance = OrderFirestoreService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Sync ────────────────────────────────────────────────────────────

  /// Write full order doc to Firestore (merge so items aren't lost on partial updates)
  Future<void> syncOrderToFirestore({
    required int invoiceId,
    required int customerId,
    required String customerName,
    required String customerEmail,
    required String customerFirebaseUid,
    required String paymentStatus,
    required String orderStatus,
    required double totalAmount,
    String? shippingAddress,
    String? paymentMethod,
    required String createdAt,
    String? updatedAt,
    required List<Map<String, dynamic>> items,
    String? payOSOrderId,
    String? promotionCode,
    double promotionDiscount = 0,
  }) async {
    try {
      final data = <String, dynamic>{
        'invoiceId': invoiceId,
        'customerId': customerId,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'customerFirebaseUid': customerFirebaseUid,
        'paymentStatus': paymentStatus,
        'orderStatus': orderStatus,
        'totalAmount': totalAmount,
        'shippingAddress': shippingAddress,
        'paymentMethod': paymentMethod,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'items': items,
      };
      if (payOSOrderId != null) {
        data['payOSOrderId'] = payOSOrderId;
      }
      if (promotionCode != null) {
        data['promotionCode'] = promotionCode;
        data['promotionDiscount'] = promotionDiscount;
      }
      await _firestore.collection('orders').doc(invoiceId.toString()).set(
        data,
        SetOptions(merge: true),
      );
    } catch (e) {
      print('OrderFirestoreService.syncOrderToFirestore error: $e');
    }
  }

  /// Update only status fields (called after admin changes status)
  Future<void> updateOrderStatusInFirestore({
    required int invoiceId,
    required String orderStatus,
    String? paymentStatus,
  }) async {
    try {
      final data = <String, dynamic>{
        'orderStatus': orderStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (paymentStatus != null) {
        data['paymentStatus'] = paymentStatus;
      }
      await _firestore.collection('orders').doc(invoiceId.toString()).set(
            data,
            SetOptions(merge: true),
          );
    } catch (e) {
      print('OrderFirestoreService.updateOrderStatusInFirestore error: $e');
    }
  }

  // ── Queries ──────────────────────────────────────────────────────────

  /// Get a single order document data from Firestore, returns null if not found
  Future<Map<String, dynamic>?> getOrderDoc(int invoiceId) async {
    try {
      final doc = await _firestore
          .collection('orders')
          .doc(invoiceId.toString())
          .get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      print('OrderFirestoreService.getOrderDoc error: $e');
      return null;
    }
  }

  /// Admin: get all orders from Firestore, optionally filtered by status
  Future<List<OrderInfo>> getAllOrdersFromFirestore({String? statusFilter}) async {
    try {
      final base = _firestore.collection('orders');
      List<DocumentSnapshot> docs = [];

      if (statusFilter != null && statusFilter.isNotEmpty) {
        if (statusFilter == 'Unpaid') {
          // Only get orders with orderStatus == 'Unpaid'
          final snapshot = await base.where('orderStatus', isEqualTo: 'Unpaid').get();
          docs = snapshot.docs;
        } else {
          final snapshot = await base.where('orderStatus', isEqualTo: statusFilter).get();
          docs = snapshot.docs;
        }
      } else {
        final snapshot = await base.get();
        docs = snapshot.docs;
      }

      // Deduplicate by invoiceId (doc id or field)
      final seen = <String>{};
      final orders = <OrderInfo>[];
      for (final doc in docs) {
        try {
          final idKey = (doc.data() as Map<String, dynamic>?)?['invoiceId']?.toString() ?? doc.id;
          if (seen.contains(idKey)) continue;
          seen.add(idKey);
          orders.add(OrderInfo.fromFirestore(doc));
        } catch (_) {
          // skip bad doc
        }
      }

      // Sort client-side to avoid requiring a composite index
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return orders;
    } catch (e) {
      print('OrderFirestoreService.getAllOrdersFromFirestore error: $e');
      return [];
    }
  }

  /// Get orders for the currently signed-in user (by Firebase UID)
  Future<List<OrderInfo>> getOrdersForCurrentFirebaseUser({String? statusFilter}) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return [];

      int? localCustomerId;
      try {
        final userId = AuthSession.instance.currentUserId.value;
        if (userId != null) {
          final db = await AppDatabase.instance;
          final rows = await db.query(
            'Customer',
            columns: ['CustomerID'],
            where: 'UserID = ?',
            whereArgs: [userId],
            limit: 1,
          );
          if (rows.isNotEmpty) {
            localCustomerId = rows.first['CustomerID'] as int?;
          }
        }
      } catch (_) {}

      final base = _firestore.collection('orders');
      final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

      if (statusFilter != null && statusFilter.isNotEmpty) {
        if (statusFilter == 'Unpaid') {
          queries.add(base.where('customerFirebaseUid', isEqualTo: firebaseUser.uid).where('orderStatus', isEqualTo: 'Unpaid').get());
          if (localCustomerId != null) {
            queries.add(base.where('customerId', isEqualTo: localCustomerId).where('orderStatus', isEqualTo: 'Unpaid').get());
          }
        } else {
          queries.add(base.where('customerFirebaseUid', isEqualTo: firebaseUser.uid).where('orderStatus', isEqualTo: statusFilter).get());
          if (localCustomerId != null) {
            queries.add(base.where('customerId', isEqualTo: localCustomerId).where('orderStatus', isEqualTo: statusFilter).get());
          }
        }
      } else {
        queries.add(base.where('customerFirebaseUid', isEqualTo: firebaseUser.uid).get());
        if (localCustomerId != null) {
          queries.add(base.where('customerId', isEqualTo: localCustomerId).get());
        }
      }

      final results = await Future.wait(queries);
      final docs = <DocumentSnapshot>[];
      final seenDocIds = <String>{};
      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          if (seenDocIds.add(doc.id)) {
            docs.add(doc);
          }
        }
      }

      final seen = <String>{};
      final orders = <OrderInfo>[];
      for (final doc in docs) {
        try {
          final idKey = (doc.data() as Map<String, dynamic>?)?['invoiceId']?.toString() ?? doc.id;
          if (seen.contains(idKey)) continue;
          seen.add(idKey);
          orders.add(OrderInfo.fromFirestore(doc));
        } catch (_) {}
      }

      // Sort client-side to avoid requiring a composite index
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return orders;
    } catch (e) {
      print('OrderFirestoreService.getOrdersForCurrentFirebaseUser error: $e');
      return [];
    }
  }
}
