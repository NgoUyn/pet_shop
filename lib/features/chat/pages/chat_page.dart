import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../services/chat_repository.dart';

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
  });

  final ChatThreadContext thread;
  final ChatRepository chatRepository;
  final ScrollController scrollController;
  final TextEditingController messageController;
  final ValueNotifier<bool> sendingNotifier;
  final VoidCallback onSend;

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

        final messages = messageSnapshot.data ?? const [];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });

        if (messages.isEmpty) {
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
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMine = message.senderUid == thread.currentUser.uid;
            return Align(
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
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMine ? Colors.white : AppColors.textDark,
                        fontSize: 14,
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
            );
          },
        );
      },
    );
  }
}

/// Separate widget for input area to prevent rebuild of messages list
class _ChatInputArea extends StatelessWidget {
  const _ChatInputArea({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

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
