import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/optimized_network_image.dart';
import '../../../core/utils/cloudinary_transform.dart';
import '../../../core/utils/cloudinary_helper.dart';
import '../services/chat_repository.dart';
import '../services/sensitive_image_detector.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.participantUid});

  final String? participantUid;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatRepository _chatRepository = ChatRepository.instance;
  final ImagePicker _imagePicker = ImagePicker();

  Future<ChatThreadContext>? _bootstrapFuture;
  ChatThreadContext? _thread;
  bool _hasMarkedRead = false;

  /// Dùng ValueNotifier để chỉ rebuild phần input, không rebuild toàn bộ
  final ValueNotifier<bool> _sendingNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _chatRepository.resolveThreadContext(participantUid: widget.participantUid);
  }

  @override
  void didUpdateWidget(ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participantUid != widget.participantUid) {
      _bootstrapFuture = _chatRepository.resolveThreadContext(participantUid: widget.participantUid);
      _hasMarkedRead = false;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _sendingNotifier.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final thread = _thread;
    final content = _messageController.text.trim();

    if (thread == null || content.isEmpty || _sendingNotifier.value) {
      return;
    }

    _sendingNotifier.value = true;

    try {
      await _chatRepository.sendMessage(thread: thread, content: content);
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    } finally {
      if (mounted) {
        _sendingNotifier.value = false;
      }
    }
  }

  /// Pick an image from gallery, check for sensitive content, then upload and send
  Future<void> _pickAndSendImage() async {
    final thread = _thread;
    if (thread == null || _sendingNotifier.value) return;

    try {
      // Pick image from gallery
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return; // User cancelled

      _sendingNotifier.value = true;

      final imageFile = File(pickedFile.path);

      // Step 1: Upload to Cloudinary first (same approach as review page)
      final imageUrl = await CloudinaryHelper.uploadImage(imageFile.path);

      if (imageUrl == null) {
        if (!mounted) return;
        _sendingNotifier.value = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải ảnh lên. Vui lòng thử lại.')),
        );
        return;
      }

      // Step 2: Check for sensitive content via backend API (same as review page)
      final detectionResult = await SensitiveImageDetector.instance.checkImageUrl(imageUrl);

      if (detectionResult.isSensitive) {
        if (!mounted) return;
        _sendingNotifier.value = false;

        // Show warning dialog
        _showSensitiveImageWarning(detectionResult.label);
        return;
      }

      // Step 3: Send image message
      await _chatRepository.sendImageMessage(
        thread: thread,
        imageUrl: imageUrl,
        content: _messageController.text.trim(),
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print('_pickAndSendImage error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi gửi ảnh: ${e.toString().replaceFirst('StateError: ', '')}')),
      );
    } finally {
      if (mounted) {
        _sendingNotifier.value = false;
      }
    }
  }

  /// Show a dialog warning the user that the image contains sensitive content
  void _showSensitiveImageWarning(String label) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text('Ảnh không hợp lệ')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ảnh bạn chọn đã bị chặn vì: $label.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            const Text(
              'Vui lòng chọn ảnh khác phù hợp với tiêu chuẩn cộng đồng.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Future<void> _markThreadAsRead(ChatThreadContext thread) async {
    if (_hasMarkedRead) return;
    _hasMarkedRead = true;
    try {
      await _chatRepository.markThreadAsRead(thread);
    } catch (e) {
      print('markThreadAsRead error: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _threadTitle(ChatThreadContext thread) {
    return thread.participantUser.fullName.isNotEmpty ? thread.participantUser.fullName : 'Hỗ trợ';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatThreadContext>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chat')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không mở được chat: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final thread = snapshot.data;
        if (thread == null) {
          return const Scaffold(body: SizedBox.shrink());
        }

        _thread = thread;
        _markThreadAsRead(thread);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(_threadTitle(thread)),
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.textDark,
            elevation: 0,
            actions: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _bootstrapFuture = _chatRepository.resolveThreadContext(participantUid: widget.participantUid);
                  });
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _ChatBody(
            thread: thread,
            chatRepository: _chatRepository,
            scrollController: _scrollController,
            messageController: _messageController,
            sendingNotifier: _sendingNotifier,
            onSend: _sendMessage,
            onPickImage: _pickAndSendImage,
          ),
        );
      },
    );
  }
}

/// Widget chứa messages + input, dùng ValueListenableBuilder để chỉ rebuild input khi _sending thay đổi
class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.thread,
    required this.chatRepository,
    required this.scrollController,
    required this.messageController,
    required this.sendingNotifier,
    required this.onSend,
    required this.onPickImage,
  });

  final ChatThreadContext thread;
  final ChatRepository chatRepository;
  final ScrollController scrollController;
  final TextEditingController messageController;
  final ValueNotifier<bool> sendingNotifier;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Messages list
        Expanded(
          child: _ChatMessagesList(
            key: ValueKey(thread.threadId),
            thread: thread,
            chatRepository: chatRepository,
            scrollController: scrollController,
          ),
        ),
        // Input area - chỉ rebuild phần này khi sending thay đổi
        ValueListenableBuilder<bool>(
          valueListenable: sendingNotifier,
          builder: (context, sending, _) {
            return _ChatInputArea(
              controller: messageController,
              sending: sending,
              onSend: onSend,
              onPickImage: onPickImage,
            );
          },
        ),
      ],
    );
  }
}

/// Separate widget for messages list to prevent rebuild when sending state changes
class _ChatMessagesList extends StatelessWidget {
  const _ChatMessagesList({
    super.key,
    required this.thread,
    required this.chatRepository,
    required this.scrollController,
  });

  final ChatThreadContext thread;
  final ChatRepository chatRepository;
  final ScrollController scrollController;

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} ${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatMessageItem>>(
      stream: chatRepository.watchThreadMessages(thread.threadId),
      builder: (context, messageSnapshot) {
        if (messageSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (messageSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không tải được tin nhắn: ${messageSnapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final messages = messageSnapshot.data ?? <ChatMessageItem>[];

        // Filter out deleted messages from display
        final visibleMessages = messages.where((m) => !m.isDeleted).toList();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });

        if (visibleMessages.isEmpty) {
          return ListView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: const [
              SizedBox(height: 120),
              Center(child: Text('Chưa có tin nhắn nào, hãy bắt đầu cuộc trò chuyện')),
            ],
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: visibleMessages.length,
          itemBuilder: (context, index) {
            final message = visibleMessages[index];
            final isMine = message.senderUid == thread.currentUser.uid;
            // Allow delete if: user is the sender OR user is admin
            final canDelete = isMine || thread.isCurrentUserAdmin;
            return GestureDetector(
              onLongPress: canDelete
                  ? () => _showDeleteMessageDialog(context, message, thread)
                  : null,
              child: Align(
                alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine ? AppColors.primary : AppColors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show image if message type is image
                      if (message.isImage && message.imageUrl != null)
                        _buildImageContent(context, message, isMine),
                      // Show text content
                      if (message.content.isNotEmpty && message.content != '[Hình ảnh]')
                        Padding(
                          padding: EdgeInsets.only(top: message.isImage ? 8 : 0),
                          child: Text(
                            message.content,
                            style: TextStyle(
                              color: isMine ? Colors.white : AppColors.textDark,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTimestamp(message.createdAt),
                        style: TextStyle(
                          color: isMine ? Colors.white70 : AppColors.textLight,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImageContent(BuildContext context, ChatMessageItem message, bool isMine) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () => _showImagePreview(context, message.imageUrl!),
        child: OptimizedNetworkImage(
          imageUrl: message.imageUrl!,
          size: CloudinaryImageSize.medium,
          width: 280,
          height: 200,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void _showDeleteMessageDialog(BuildContext context, ChatMessageItem message, ChatThreadContext thread) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá tin nhắn'),
        content: const Text('Bạn có chắc chắn muốn xoá tin nhắn này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await chatRepository.deleteMessage(
                  thread: thread,
                  messageId: message.messageId,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xoá tin nhắn')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: ${e.toString().replaceFirst('StateError: ', '')}')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              child: OptimizedNetworkImage(
                imageUrl: imageUrl,
                size: CloudinaryImageSize.large,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Separate widget for input area to prevent rebuild of messages list
class _ChatInputArea extends StatelessWidget {
  const _ChatInputArea({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onPickImage,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Image picker button
            SizedBox(
              height: 48,
              width: 48,
              child: IconButton(
                onPressed: sending ? null : onPickImage,
                icon: const Icon(Icons.image_outlined),
                color: AppColors.primary,
                tooltip: 'Gửi ảnh',
              ),
            ),
            const SizedBox(width: 4),
            // Text input
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Send button
            SizedBox(
              height: 48,
              width: 48,
              child: ElevatedButton(
                onPressed: sending ? null : onSend,
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: sending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
