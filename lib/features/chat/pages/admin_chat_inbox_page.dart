import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../services/chat_repository.dart';
import 'chat_page.dart';

class AdminChatInboxPage extends StatefulWidget {
  const AdminChatInboxPage({super.key});

  @override
  State<AdminChatInboxPage> createState() => _AdminChatInboxPageState();
}

class _AdminChatInboxPageState extends State<AdminChatInboxPage> {
  final ChatRepository _chatRepository = ChatRepository.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ChatDateFilter _dateFilter = _ChatDateFilter.all;

  String _normalizeSearchText(String value) {
    const replacements = {
      'á': 'a', 'à': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a', 'ă': 'a', 'ắ': 'a', 'ằ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a', 'â': 'a', 'ấ': 'a', 'ầ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
      'Á': 'a', 'À': 'a', 'Ả': 'a', 'Ã': 'a', 'Ạ': 'a', 'Ă': 'a', 'Ắ': 'a', 'Ằ': 'a', 'Ẳ': 'a', 'Ẵ': 'a', 'Ặ': 'a', 'Â': 'a', 'Ấ': 'a', 'Ầ': 'a', 'Ẩ': 'a', 'Ẫ': 'a', 'Ậ': 'a',
      'é': 'e', 'è': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e', 'ê': 'e', 'ế': 'e', 'ề': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
      'É': 'e', 'È': 'e', 'Ẻ': 'e', 'Ẽ': 'e', 'Ẹ': 'e', 'Ê': 'e', 'Ế': 'e', 'Ề': 'e', 'Ể': 'e', 'Ễ': 'e', 'Ệ': 'e',
      'í': 'i', 'ì': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i', 'Í': 'i', 'Ì': 'i', 'Ỉ': 'i', 'Ĩ': 'i', 'Ị': 'i',
      'ó': 'o', 'ò': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o', 'ô': 'o', 'ố': 'o', 'ồ': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o', 'ơ': 'o', 'ớ': 'o', 'ờ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
      'Ó': 'o', 'Ò': 'o', 'Ỏ': 'o', 'Õ': 'o', 'Ọ': 'o', 'Ô': 'o', 'Ố': 'o', 'Ồ': 'o', 'Ổ': 'o', 'Ỗ': 'o', 'Ộ': 'o', 'Ơ': 'o', 'Ớ': 'o', 'Ờ': 'o', 'Ở': 'o', 'Ỡ': 'o', 'Ợ': 'o',
      'ú': 'u', 'ù': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u', 'ư': 'u', 'ứ': 'u', 'ừ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
      'Ú': 'u', 'Ù': 'u', 'Ủ': 'u', 'Ũ': 'u', 'Ụ': 'u', 'Ư': 'u', 'Ứ': 'u', 'Ừ': 'u', 'Ử': 'u', 'Ữ': 'u', 'Ự': 'u',
      'ý': 'y', 'ỳ': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y', 'Ý': 'y', 'Ỳ': 'y', 'Ỷ': 'y', 'Ỹ': 'y', 'Ỵ': 'y',
      'đ': 'd', 'Đ': 'd',
    };

    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(replacements[char] ?? char);
    }
    return buffer.toString().toLowerCase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChatConversationSummary> _applyFilters(List<ChatConversationSummary> conversations) {
    final query = _normalizeSearchText(_searchQuery.trim());
    final now = DateTime.now();

    return conversations.where((conv) {
      final searchableText = _normalizeSearchText([
        conv.customerUser.fullName,
        conv.customerUser.email,
        conv.lastMessage,
        conv.threadId,
      ].join(' '));

      final matchesSearch = query.isEmpty || searchableText.contains(query);

      if (!matchesSearch) return false;

      final messageTime = conv.lastMessageAt.toLocal();
      final matchesDate = switch (_dateFilter) {
        _ChatDateFilter.all => true,
        _ChatDateFilter.today => _isSameDay(messageTime, now),
        _ChatDateFilter.thisWeek => _isSameWeek(messageTime, now),
        _ChatDateFilter.thisMonth => messageTime.year == now.year && messageTime.month == now.month,
      };

      return matchesDate;
    }).toList();
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month && left.day == right.day;
  }

  bool _isSameWeek(DateTime left, DateTime right) {
    final leftStart = left.subtract(Duration(days: left.weekday - 1));
    final rightStart = right.subtract(Duration(days: right.weekday - 1));
    return _isSameDay(leftStart, rightStart);
  }

  void _setDateFilter(_ChatDateFilter filter) {
    setState(() {
      _dateFilter = _dateFilter == filter ? _ChatDateFilter.all : filter;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hỗ trợ khách hàng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: StreamBuilder<List<ChatConversationSummary>>(
        stream: _chatRepository.watchAdminConversations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không tải được danh sách: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final conversations = _applyFilters(snapshot.data ?? const []);

          if (conversations.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 12),
                  _buildSearchAndFilters(),
                  const SizedBox(height: 80),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text(
                            'Không có cuộc trò chuyện phù hợp',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Thử đổi từ khóa tìm kiếm hoặc bộ lọc thời gian',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSearchAndFilters(),
                const SizedBox(height: 12),
                ...List.generate(conversations.length, (index) {
                  final conv = conversations[index];
                  final hasUnread = conv.adminUnreadCount > 0;

                  return Padding(
                    padding: EdgeInsets.only(bottom: index == conversations.length - 1 ? 0 : 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(participantUid: conv.customerUser.uid),
                          ),
                        );
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: hasUnread
                              ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5)
                              : null,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                  child: Text(
                                    conv.customerUser.fullName.isNotEmpty
                                        ? conv.customerUser.fullName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                if (hasUnread)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          conv.adminUnreadCount > 9
                                              ? '9+'
                                              : conv.adminUnreadCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          conv.customerUser.fullName.isNotEmpty
                                              ? conv.customerUser.fullName
                                              : 'Khách hàng',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                                            color: AppColors.textDark,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatTime(conv.lastMessageAt),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    conv.lastMessage,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textLight,
                                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Tìm theo tên hoặc tin nhắn',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('Tất cả', _dateFilter == _ChatDateFilter.all, () => _setDateFilter(_ChatDateFilter.all)),
              const SizedBox(width: 8),
              _buildFilterChip('Hôm nay', _dateFilter == _ChatDateFilter.today, () => _setDateFilter(_ChatDateFilter.today)),
              const SizedBox(width: 8),
              _buildFilterChip('Tuần này', _dateFilter == _ChatDateFilter.thisWeek, () => _setDateFilter(_ChatDateFilter.thisWeek)),
              const SizedBox(width: 8),
              _buildFilterChip('Tháng này', _dateFilter == _ChatDateFilter.thisMonth, () => _setDateFilter(_ChatDateFilter.thisMonth)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textDark,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(color: selected ? AppColors.primary : Colors.grey.shade300),
      backgroundColor: AppColors.white,
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inDays < 1) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    } else {
      return '${local.day}/${local.month}/${local.year}';
    }
  }
}

enum _ChatDateFilter { all, today, thisWeek, thisMonth }
