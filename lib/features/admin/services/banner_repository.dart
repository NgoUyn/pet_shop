import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/cloudinary_helper.dart';

class BannerItem {
  BannerItem({
    required this.bannerId,
    required this.imageUrl,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    this.title = '',
  });

  final String bannerId;
  final String imageUrl;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final String title;

  factory BannerItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BannerItem(
      bannerId: doc.id,
      imageUrl: (data['imageUrl'] as String?) ?? '',
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      title: (data['title'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'imageUrl': imageUrl,
        'sortOrder': sortOrder,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
        'title': title,
      };

  BannerItem copyWith({
    String? imageUrl,
    int? sortOrder,
    bool? isActive,
    String? title,
  }) {
    return BannerItem(
      bannerId: bannerId,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      title: title ?? this.title,
    );
  }
}

class BannerRepository {
  BannerRepository._();
  static final BannerRepository instance = BannerRepository._();

  static const _collection = 'banners';
  final _firestore = FirebaseFirestore.instance;

  final ValueNotifier<int> changeToken = ValueNotifier<int>(0);

  void _notify() => changeToken.value++;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(_collection);

  /// Real-time stream of active banners sorted by sortOrder
  Stream<List<BannerItem>> watchActiveBanners() {
    return _col
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs.map(BannerItem.fromFirestore).toList());
  }

  /// Real-time stream of ALL banners for admin (sorted by sortOrder)
  Stream<List<BannerItem>> watchAllBanners() {
    return _col
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs.map(BannerItem.fromFirestore).toList());
  }

  /// One-time fetch for the admin list
  Future<List<BannerItem>> listAll() async {
    try {
      final snap = await _col.orderBy('sortOrder').get();
      return snap.docs.map(BannerItem.fromFirestore).toList();
    } catch (e) {
      print('BannerRepository.listAll error: $e');
      return [];
    }
  }

  /// Add a new banner — uploads image to Cloudinary first
  Future<BannerItem?> addBanner({
    required String localFilePath,
    String title = '',
  }) async {
    final imageUrl = await CloudinaryHelper.uploadImage(localFilePath);
    if (imageUrl == null) return null;

    final existing = await listAll();
    final nextOrder = existing.isEmpty
        ? 0
        : existing.map((b) => b.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    final now = DateTime.now();
    final docRef = _col.doc();
    final item = BannerItem(
      bannerId: docRef.id,
      imageUrl: imageUrl,
      sortOrder: nextOrder,
      isActive: true,
      createdAt: now,
      title: title,
    );
    await docRef.set(item.toFirestore());
    _notify();
    return item;
  }

  /// Delete a banner by ID
  Future<void> deleteBanner(String bannerId) async {
    await _col.doc(bannerId).delete();
    _notify();
  }

  /// Toggle isActive
  Future<void> toggleActive(String bannerId, {required bool isActive}) async {
    await _col.doc(bannerId).update({'isActive': isActive});
    _notify();
  }

  /// Update sortOrder for a list of banners (after reorder)
  Future<void> updateSortOrders(List<BannerItem> banners) async {
    final batch = _firestore.batch();
    for (var i = 0; i < banners.length; i++) {
      batch.update(_col.doc(banners[i].bannerId), {'sortOrder': i});
    }
    await batch.commit();
    _notify();
  }

  /// Update title
  Future<void> updateTitle(String bannerId, String title) async {
    await _col.doc(bannerId).update({'title': title});
    _notify();
  }
}
