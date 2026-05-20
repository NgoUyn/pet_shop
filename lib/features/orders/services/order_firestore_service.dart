import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  }) async {
    try {
      await _firestore.collection('orders').doc(invoiceId.toString()).set({
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
      }, SetOptions(merge: true));
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
          // Query A: orderStatus == 'Unpaid'
          final qA = base.where('orderStatus', isEqualTo: 'Unpaid').get();
          // Query B: paymentStatus in ['Unpaid','Pending']
          final qB = base.where('paymentStatus', whereIn: ['Unpaid', 'Pending']).get();
          // Query C: shipping COD but not paid yet (orderStatus == 'Shipping' && paymentMethod == 'COD')
          final qC = base.where('orderStatus', isEqualTo: 'Shipping').where('paymentMethod', isEqualTo: 'COD').get();

          final results = await Future.wait([qA, qB, qC]);
          for (final r in results) {
            docs.addAll(r.docs);
          }
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

      final base = _firestore.collection('orders');
      List<DocumentSnapshot> docs = [];

      if (statusFilter != null && statusFilter.isNotEmpty) {
        if (statusFilter == 'Unpaid') {
          // A: orderStatus == 'Unpaid' for this user
          final qA = base.where('customerFirebaseUid', isEqualTo: firebaseUser.uid).where('orderStatus', isEqualTo: 'Unpaid').get();
          // B: paymentStatus in ['Unpaid','Pending'] for this user
          final qB = base.where('customerFirebaseUid', isEqualTo: firebaseUser.uid).where('paymentStatus', whereIn: ['Unpaid', 'Pending']).get();
          // C: shipping & COD for this user
          final qC = base.where('customerFirebaseUid', isEqualTo: firebaseUser.uid).where('orderStatus', isEqualTo: 'Shipping').where('paymentMethod', isEqualTo: 'COD').get();

          final results = await Future.wait([qA, qB, qC]);
          for (final r in results) docs.addAll(r.docs);
        } else {
          final snapshot = await base.where('customerFirebaseUid', isEqualTo: firebaseUser.uid).where('orderStatus', isEqualTo: statusFilter).get();
          docs = snapshot.docs;
        }
      } else {
        final snapshot = await base.where('customerFirebaseUid', isEqualTo: firebaseUser.uid).get();
        docs = snapshot.docs;
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
