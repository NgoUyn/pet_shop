import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/db/app_database.dart';
import '../../auth/services/auth_session.dart';
import '../../profile/services/profile_repository.dart';

class ChatUser {
  ChatUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    this.localUserId,
  });

  final String uid;
  final String fullName;
  final String email;
  final String role;
  final int? localUserId;

  bool get isAdmin => role.toLowerCase() == 'admin';
}

class ChatThreadContext {
  ChatThreadContext({
    required this.threadId,
    required this.currentUser,
    required this.participantUser,
    required this.customerUser,
    required this.adminUser,
  });

  final String threadId;
  final ChatUser currentUser;
  final ChatUser participantUser;
  final ChatUser customerUser;
  final ChatUser adminUser;

  bool get isCurrentUserAdmin => currentUser.isAdmin;
}

class ChatMessageItem {
  ChatMessageItem({
    required this.messageId,
    required this.senderUid,
    required this.receiverUid,
    required this.content,
    required this.createdAt,
    this.imageUrl,
    this.messageType = 'text',
    this.deletedAt,
  });

  final String messageId;
  final String senderUid;
  final String receiverUid;
  final String content;
  final DateTime createdAt;
  final String? imageUrl;
  final String messageType; // 'text' or 'image'
  final DateTime? deletedAt;

  bool get isImage => messageType == 'image';
  bool get isDeleted => deletedAt != null;

  static ChatMessageItem fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return ChatMessageItem(
      messageId: doc.id,
      senderUid: (data['senderUid'] as String?) ?? '',
      receiverUid: (data['receiverUid'] as String?) ?? '',
      content: (data['content'] as String?) ?? '',
      createdAt: _timestampToDateTime(data['createdAt']),
      imageUrl: data['imageUrl'] as String?,
      messageType: (data['messageType'] as String?) ?? 'text',
      deletedAt: data['deletedAt'] != null ? _timestampToDateTime(data['deletedAt']) : null,
    );
  }
}

class ChatConversationSummary {
  ChatConversationSummary({
    required this.threadId,
    required this.customerUser,
    required this.adminUser,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.customerUnreadCount,
    required this.adminUnreadCount,
  });

  final String threadId;
  final ChatUser customerUser;
  final ChatUser adminUser;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int customerUnreadCount;
  final int adminUnreadCount;

  int unreadFor(ChatUser user) => user.isAdmin ? adminUnreadCount : customerUnreadCount;
}

DateTime _timestampToDateTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate().toLocal();
  }
  return DateTime.now();
}

class ChatRepository {
  ChatRepository._();

  static final ChatRepository instance = ChatRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<ProfileData?> getCurrentProfile() async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) {
      return null;
    }

    return ProfileRepository.instance.getProfileByUserId(userId);
  }

  Future<ChatUser> ensureCurrentUserSynced() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      throw StateError('Vui lòng đăng nhập để sử dụng chat');
    }

    final profile = await getCurrentProfile();
    final fullName = (profile?.fullName.trim().isNotEmpty == true
            ? profile!.fullName.trim()
            : firebaseUser.displayName?.trim().isNotEmpty == true
                ? firebaseUser.displayName!.trim()
                : firebaseUser.email?.split('@').first ?? 'Người dùng')
        .trim();
    final email = (profile?.email.trim().isNotEmpty == true
            ? profile!.email.trim()
            : firebaseUser.email?.trim() ?? '')
        .toLowerCase();
    final role = (profile?.role.trim().isNotEmpty == true ? profile!.role.trim() : 'customer').toLowerCase();

    // Try to sync user to Firestore (best-effort, ignore permission errors)
    try {
      final userDoc = _firestore.collection('users').doc(firebaseUser.uid);
      final existing = await userDoc.get();
      final now = Timestamp.now();

      await userDoc.set(
        {
          'uid': firebaseUser.uid,
          'localUserId': profile?.userId,
          'fullName': fullName,
          'email': email,
          'role': role,
          'updatedAt': now,
          if (!existing.exists) 'createdAt': now,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('ensureCurrentUserSynced: error syncing user to Firestore (non-fatal): $e');
    }

    return ChatUser(
      uid: firebaseUser.uid,
      fullName: fullName,
      email: email,
      role: role,
      localUserId: profile?.userId,
    );
  }

  Future<ChatUser?> getAdminUser() async {
    await ensureCurrentUserSynced();

    // First try to find admin in Firestore
    try {
      final snapshot = await _firestore.collection('users').where('role', isEqualTo: 'admin').limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        return _userFromDoc(snapshot.docs.first);
      }
    } catch (e) {
      print('getAdminUser: error querying Firestore for admin: $e');
    }

    // If no admin in Firestore, look up from local SQLite
    // Priority: find admin with email huynhmai2755@gmail.com first
    String? adminName;
    String? adminEmail;
    int? localUserId;
    String? existingFirebaseUid;

    try {
      final db = await AppDatabase.instance;

      // Try to find the specific admin email first
      final specificRows = await db.rawQuery(
        "SELECT UserID, FullName, Email, FirebaseUID FROM User WHERE Role = 'admin' AND lower(Email) = ? LIMIT 1",
        ['huynhmai2755@gmail.com'],
      );

      if (specificRows.isNotEmpty) {
        final row = specificRows.first;
        adminName = (row['FullName'] as String?) ?? 'Admin Shop';
        adminEmail = (row['Email'] as String?) ?? 'huynhmai2755@gmail.com';
        localUserId = row['UserID'] as int?;
        existingFirebaseUid = row['FirebaseUID'] as String?;
      } else {
        // Fallback to any admin
        final rows = await db.rawQuery(
          "SELECT UserID, FullName, Email, FirebaseUID FROM User WHERE Role = 'admin' LIMIT 1",
        );

        if (rows.isNotEmpty) {
          final row = rows.first;
          adminName = (row['FullName'] as String?) ?? 'Admin Shop';
          adminEmail = (row['Email'] as String?) ?? '';
          localUserId = row['UserID'] as int?;
          existingFirebaseUid = row['FirebaseUID'] as String?;
        }
      }
    } catch (e) {
      print('getAdminUser: error reading admin from local DB: $e');
    }

    // If no admin found in SQLite, create a synthetic admin
    final resolvedAdminName = adminName ?? 'Admin Shop';
    final resolvedAdminEmail = adminEmail ?? 'huynhmai2755@gmail.com';

    // Use existing FirebaseUID if available, otherwise generate synthetic one
    final resolvedUid = (existingFirebaseUid != null && existingFirebaseUid.isNotEmpty)
        ? existingFirebaseUid
        : 'admin_synthetic_${localUserId ?? 0}';

    // Try to sync admin user to Firestore (best-effort, ignore errors)
    try {
      final adminDoc = _firestore.collection('users').doc(resolvedUid);
      final adminExisting = await adminDoc.get();
      final now = Timestamp.now();

      await adminDoc.set(
        {
          'uid': resolvedUid,
          'localUserId': localUserId,
          'fullName': resolvedAdminName,
          'email': resolvedAdminEmail,
          'role': 'admin',
          'updatedAt': now,
          if (!adminExisting.exists) 'createdAt': now,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('getAdminUser: error syncing admin to Firestore (non-fatal): $e');
    }

    return ChatUser(
      uid: resolvedUid,
      fullName: resolvedAdminName,
      email: resolvedAdminEmail,
      role: 'admin',
      localUserId: localUserId,
    );
  }

  Future<bool> isCurrentUserAdmin() async {
    return (await ensureCurrentUserSynced()).isAdmin;
  }

  Future<ChatUser?> getUserByUid(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      return null;
    }
    return _userFromDoc(doc);
  }

  ChatUser _userFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ChatUser(
      uid: doc.id,
      fullName: (data['fullName'] as String?) ?? 'Người dùng',
      email: (data['email'] as String?) ?? '',
      role: (data['role'] as String?) ?? 'customer',
      localUserId: data['localUserId'] as int?,
    );
  }

  String _threadId(String customerUid, String adminUid) => 'support_${customerUid}_$adminUid';

  Future<ChatThreadContext> resolveThreadContext({String? participantUid}) async {
    final currentUser = await ensureCurrentUserSynced();
    if (currentUser.isAdmin) {
      if (participantUid == null) {
        throw StateError('Vui lòng chọn khách hàng để chat');
      }

      final customerUser = await getUserByUid(participantUid);
      if (customerUser == null) {
        throw StateError('Không tìm thấy khách hàng trên Firestore');
      }

      final adminUser = currentUser;
      final threadId = _threadId(customerUser.uid, adminUser.uid);
      await _ensureThreadDocument(
        threadId: threadId,
        customerUser: customerUser,
        adminUser: adminUser,
      );

      return ChatThreadContext(
        threadId: threadId,
        currentUser: currentUser,
        participantUser: customerUser,
        customerUser: customerUser,
        adminUser: adminUser,
      );
    }

    final adminUser = await getAdminUser();
    if (adminUser == null) {
      throw StateError('Chưa có tài khoản admin trên Firestore');
    }

    final customerUser = currentUser;
    final threadId = _threadId(customerUser.uid, adminUser.uid);
    await _ensureThreadDocument(
      threadId: threadId,
      customerUser: customerUser,
      adminUser: adminUser,
    );

    return ChatThreadContext(
      threadId: threadId,
      currentUser: currentUser,
      participantUser: adminUser,
      customerUser: customerUser,
      adminUser: adminUser,
    );
  }

  Future<void> _ensureThreadDocument({
    required String threadId,
    required ChatUser customerUser,
    required ChatUser adminUser,
  }) async {
    final threadRef = _firestore.collection('chats').doc(threadId);
    final existing = await threadRef.get();
    final now = Timestamp.now();

    await threadRef.set(
      {
        'threadId': threadId,
        'customerUid': customerUser.uid,
        'customerName': customerUser.fullName,
        'customerEmail': customerUser.email,
        'adminUid': adminUser.uid,
        'adminName': adminUser.fullName,
        'adminEmail': adminUser.email,
        'lastMessage': (existing.data()?['lastMessage'] as String?) ?? '',
        'lastMessageAt': existing.data()?['lastMessageAt'] ?? now,
        'customerUnreadCount': (existing.data()?['customerUnreadCount'] as num?)?.toInt() ?? 0,
        'adminUnreadCount': (existing.data()?['adminUnreadCount'] as num?)?.toInt() ?? 0,
        'createdAt': existing.data()?['createdAt'] ?? now,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );
  }

  Stream<int> watchUnreadCountForCurrentUser() async* {
    final currentUser = await ensureCurrentUserSynced();

    if (currentUser.isAdmin) {
      // For admin: query ALL chats and sum adminUnreadCount
      // (because adminUid may be synthetic and not match Firebase UID)
      yield* _firestore.collection('chats').snapshots().map((snapshot) {
        var total = 0;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final customerUid = (data['customerUid'] as String?) ?? '';
          // Skip if customer is admin (admin-to-admin chat)
          if (customerUid == currentUser.uid) continue;
          total += (data['adminUnreadCount'] as num?)?.toInt() ?? 0;
        }
        return total;
      });
    } else {
      yield* _firestore
          .collection('chats')
          .where('customerUid', isEqualTo: currentUser.uid)
          .snapshots()
          .map((snapshot) {
        var total = 0;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          total += (data['customerUnreadCount'] as num?)?.toInt() ?? 0;
        }
        return total;
      });
    }
  }

  Future<int> unreadCountForCurrentUser() async {
    try {
      final currentUser = await ensureCurrentUserSynced();

      if (currentUser.isAdmin) {
        // For admin: query ALL chats and sum adminUnreadCount
        // (because adminUid may be synthetic and not match Firebase UID)
        final snapshot = await _firestore.collection('chats').get();
        var total = 0;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final customerUid = (data['customerUid'] as String?) ?? '';
          // Skip if customer is admin (admin-to-admin chat)
          if (customerUid == currentUser.uid) continue;
          total += (data['adminUnreadCount'] as num?)?.toInt() ?? 0;
        }
        return total;
      } else {
        final snapshot = await _firestore
            .collection('chats')
            .where('customerUid', isEqualTo: currentUser.uid)
            .get();
        var total = 0;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          total += (data['customerUnreadCount'] as num?)?.toInt() ?? 0;
        }
        return total;
      }
    } catch (e) {
      print('unreadCountForCurrentUser error: $e');
      return 0;
    }
  }

  Stream<List<ChatConversationSummary>> watchAdminConversations() async* {
    ChatUser? currentUser;
    try {
      currentUser = await ensureCurrentUserSynced();
    } catch (e) {
      print('watchAdminConversations: ensureCurrentUserSynced error: $e');
      yield const [];
      return;
    }

    final user = currentUser;
    if (!user.isAdmin) {
      yield const [];
      return;
    }

    // Query ALL chats (not filtered by adminUid) because the adminUid in Firestore
    // may be a synthetic UID (e.g. 'admin_synthetic_1') that doesn't match the
    // current Firebase Auth UID. We'll filter out admin-to-admin conversations later.
    yield* _firestore.collection('chats').snapshots().map((snapshot) {
      final items = <ChatConversationSummary>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final customerUid = (data['customerUid'] as String?) ?? '';

        // Skip if customerUid is empty
        if (customerUid.isEmpty) continue;

        // Skip if the customerUid matches the current user (admin chatting with themselves)
        if (customerUid == user.uid) continue;

        items.add(
          ChatConversationSummary(
            threadId: doc.id,
            customerUser: ChatUser(
              uid: customerUid,
              fullName: (data['customerName'] as String?) ?? 'Khách hàng',
              email: (data['customerEmail'] as String?) ?? '',
              role: 'customer',
            ),
            adminUser: ChatUser(
              uid: user.uid,
              fullName: user.fullName,
              email: user.email,
              role: user.role,
            ),
            lastMessage: (data['lastMessage'] as String?) ?? '',
            lastMessageAt: _timestampToDateTime(data['lastMessageAt']),
            customerUnreadCount: (data['customerUnreadCount'] as num?)?.toInt() ?? 0,
            adminUnreadCount: (data['adminUnreadCount'] as num?)?.toInt() ?? 0,
          ),
        );
      }

      items.sort((left, right) => right.lastMessageAt.compareTo(left.lastMessageAt));
      return items;
    });
  }

  Stream<List<ChatMessageItem>> watchThreadMessages(String threadId) {
    return _firestore
        .collection('chats')
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatMessageItem.fromDoc).toList());
  }

  Future<void> markThreadAsRead(ChatThreadContext thread) async {
    final currentUser = await ensureCurrentUserSynced();
    final threadRef = _firestore.collection('chats').doc(thread.threadId);
    final now = Timestamp.now();

    await threadRef.set(
      {
        'updatedAt': now,
        if (currentUser.isAdmin)
          'adminUnreadCount': 0
        else
          'customerUnreadCount': 0,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> sendMessage({
    required ChatThreadContext thread,
    required String content,
  }) async {
    final currentUser = await ensureCurrentUserSynced();
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      throw StateError('Nội dung tin nhắn không được để trống');
    }

    final threadRef = _firestore.collection('chats').doc(thread.threadId);
    final messageRef = threadRef.collection('messages').doc();
    final now = Timestamp.now();

    await _firestore.runTransaction((transaction) async {
      final threadSnapshot = await transaction.get(threadRef);
      final existingData = threadSnapshot.data() ?? <String, dynamic>{};
      var customerUnread = (existingData['customerUnreadCount'] as num?)?.toInt() ?? 0;
      var adminUnread = (existingData['adminUnreadCount'] as num?)?.toInt() ?? 0;

      if (currentUser.isAdmin) {
        customerUnread += 1;
        adminUnread = 0;
      } else {
        adminUnread += 1;
        customerUnread = 0;
      }

      transaction.set(messageRef, {
        'messageId': messageRef.id,
        'senderUid': currentUser.uid,
        'receiverUid': currentUser.isAdmin ? thread.customerUser.uid : thread.adminUser.uid,
        'content': normalizedContent,
        'createdAt': now,
      });

      transaction.set(
        threadRef,
        {
          'threadId': thread.threadId,
          'customerUid': thread.customerUser.uid,
          'adminUid': thread.adminUser.uid,
          'lastMessage': normalizedContent,
          'lastMessageAt': now,
          'customerUnreadCount': customerUnread,
          'adminUnreadCount': adminUnread,
          'updatedAt': now,
          'createdAt': existingData['createdAt'] ?? now,
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Delete a message (soft delete). Sets [deletedAt] timestamp on the message document.
  /// Both the sender and admin can delete messages.
  Future<void> deleteMessage({
    required ChatThreadContext thread,
    required String messageId,
  }) async {
    final currentUser = await ensureCurrentUserSynced();
    final messageRef = _firestore
        .collection('chats')
        .doc(thread.threadId)
        .collection('messages')
        .doc(messageId);

    // Verify the message exists and user has permission
    final messageDoc = await messageRef.get();
    if (!messageDoc.exists) {
      throw StateError('Tin nhắn không tồn tại');
    }

    final messageData = messageDoc.data()!;
    final senderUid = messageData['senderUid'] as String? ?? '';

    // Allow delete if: user is the sender OR user is admin
    if (currentUser.uid != senderUid && !currentUser.isAdmin) {
      throw StateError('Bạn không có quyền xoá tin nhắn này');
    }

    await messageRef.update({
      'deletedAt': Timestamp.now(),
    });
  }

  /// Send an image message. The [imageUrl] should be the uploaded Cloudinary URL.
  /// The [content] is an optional caption/description for the image.
  Future<void> sendImageMessage({
    required ChatThreadContext thread,
    required String imageUrl,
    String content = '',
  }) async {
    final currentUser = await ensureCurrentUserSynced();

    final threadRef = _firestore.collection('chats').doc(thread.threadId);
    final messageRef = threadRef.collection('messages').doc();
    final now = Timestamp.now();
    final displayContent = content.trim().isNotEmpty ? content.trim() : '[Hình ảnh]';

    await _firestore.runTransaction((transaction) async {
      final threadSnapshot = await transaction.get(threadRef);
      final existingData = threadSnapshot.data() ?? <String, dynamic>{};
      var customerUnread = (existingData['customerUnreadCount'] as num?)?.toInt() ?? 0;
      var adminUnread = (existingData['adminUnreadCount'] as num?)?.toInt() ?? 0;

      if (currentUser.isAdmin) {
        customerUnread += 1;
        adminUnread = 0;
      } else {
        adminUnread += 1;
        customerUnread = 0;
      }

      transaction.set(messageRef, {
        'messageId': messageRef.id,
        'senderUid': currentUser.uid,
        'receiverUid': currentUser.isAdmin ? thread.customerUser.uid : thread.adminUser.uid,
        'content': displayContent,
        'imageUrl': imageUrl,
        'messageType': 'image',
        'createdAt': now,
      });

      transaction.set(
        threadRef,
        {
          'threadId': thread.threadId,
          'customerUid': thread.customerUser.uid,
          'adminUid': thread.adminUser.uid,
          'lastMessage': displayContent,
          'lastMessageAt': now,
          'customerUnreadCount': customerUnread,
          'adminUnreadCount': adminUnread,
          'updatedAt': now,
          'createdAt': existingData['createdAt'] ?? now,
        },
        SetOptions(merge: true),
      );
    });
  }
}
