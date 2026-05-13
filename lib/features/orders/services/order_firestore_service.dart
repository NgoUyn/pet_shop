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
      Query query = _firestore.collection('orders');

      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.where('orderStatus', isEqualTo: statusFilter);
      }

      final snapshot = await query.get();
      final orders = snapshot.docs.map((doc) => OrderInfo.fromFirestore(doc)).toList();

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

      Query query = _firestore
          .collection('orders')
          .where('customerFirebaseUid', isEqualTo: firebaseUser.uid);

      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.where('orderStatus', isEqualTo: statusFilter);
      }

      final snapshot = await query.get();
      final orders = snapshot.docs.map((doc) => OrderInfo.fromFirestore(doc)).toList();

      // Sort client-side to avoid requiring a composite index
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return orders;
    } catch (e) {
      print('OrderFirestoreService.getOrdersForCurrentFirebaseUser error: $e');
      return [];
    }
  }
}
