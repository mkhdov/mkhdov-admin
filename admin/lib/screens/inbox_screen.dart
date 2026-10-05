import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/conversation.dart';
import '../models/message.dart' as model;
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_page_shell.dart';
import '../widgets/empty_state.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _isLoading = true;
  String _filter = 'all'; // all, open, resolved
  String _searchQuery = '';
  
  List<Conversation> _conversations = [];
  List<model.Message> _messages = [];
  Conversation? _selectedConversation;
  
  final _searchController = TextEditingController();
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();
  
  dynamic _conversationsSubscription;
  dynamic _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _subscribeToConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _replyController.dispose();
    _scrollController.dispose();
    if (_conversationsSubscription != null) SupabaseService.removeChannel(_conversationsSubscription!);
    if (_messagesSubscription != null) SupabaseService.removeChannel(_messagesSubscription!);
    super.dispose();
  }

  Future<void> _fetchConversations() async {
    try {
      final response = await SupabaseService.from('conversations')
          .select('*')
          .order('updated_at', ascending: false);
          
      if (mounted) {
        setState(() {
          _conversations = (response as List).map((e) => Conversation.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToConversations() {
    _conversationsSubscription = SupabaseService.channel('admin_conversations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) {
            _fetchConversations();
            
            // Update selected if changed
            if (_selectedConversation != null && payload.eventType == PostgresChangeEvent.update) {
              final updated = payload.newRecord;
              if (updated['id'] == _selectedConversation!.id) {
                if (mounted) {
                  setState(() {
                    _selectedConversation = Conversation.fromJson(updated);
                  });
                }
              }
            } else if (_selectedConversation != null && payload.eventType == PostgresChangeEvent.delete) {
              final deleted = payload.oldRecord;
              if (deleted['id'] == _selectedConversation!.id) {
                if (mounted) {
                  setState(() {
                    _selectedConversation = null;
                    _messages = [];
                  });
                }
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _fetchMessages(String conversationId) async {
    try {
      final response = await SupabaseService.from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);
          
      if (mounted) {
        setState(() {
          _messages = (response as List).map((e) => model.Message.fromJson(e)).toList();
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    }
  }

  void _subscribeToMessages(String conversationId) {
    if (_messagesSubscription != null) {
      SupabaseService.removeChannel(_messagesSubscription!);
    }

    _messagesSubscription = SupabaseService.channel('admin_messages_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: conversationId),
          callback: (payload) {
            if (mounted) {
              setState(() {
                _messages.add(model.Message.fromJson(payload.newRecord));
              });
              _scrollToBottom();
              _markAsRead(conversationId);
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _markAsRead(String conversationId) async {
    try {
      await SupabaseService.from('conversations')
          .update({'unread_count_admin': 0})
          .eq('id', conversationId);
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  void _selectConversation(Conversation conversation) {
    setState(() {
      _selectedConversation = conversation;
      _messages = [];
    });
    _fetchMessages(conversation.id);
    _subscribeToMessages(conversation.id);
    if ((conversation.unreadCountAdmin ?? 0) > 0) {
      _markAsRead(conversation.id);
    }
  }

  Future<void> _sendMessage() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _selectedConversation == null) return;

    _replyController.clear();
    
    // Add locally for instant feedback
    final tempMsg = model.Message(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _selectedConversation!.id,
      senderType: 'admin',
      content: text,
      createdAt: DateTime.now().toIso8601String(),
    );
    
    setState(() {
      _messages.add(tempMsg);
    });
    _scrollToBottom();

    try {
      await SupabaseService.from('messages').insert({
        'conversation_id': _selectedConversation!.id,
        'sender_type': 'admin',
        'content': text,
      });

      await SupabaseService.from('conversations').update({
        'updated_at': DateTime.now().toIso8601String(),
        'status': 'open',
      }).eq('id', _selectedConversation!.id);
      
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        setState(() {
          _messages.remove(tempMsg);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _toggleStatus() async {
    if (_selectedConversation == null) return;
    
    final newStatus = _selectedConversation!.status == 'resolved' ? 'open' : 'resolved';
    
    try {
      await SupabaseService.from('conversations')
          .update({'status': newStatus})
          .eq('id', _selectedConversation!.id);
    } catch (e) {
      debugPrint('Error toggling status: $e');
    }
  }

  Future<void> _deleteConversation() async {
    if (_selectedConversation == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text('Are you sure you want to delete this conversation and all its messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final id = _selectedConversation!.id;
      setState(() {
        _selectedConversation = null;
        _messages = [];
      });
      await SupabaseService.from('conversations').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
  }

  List<Conversation> get _filteredConversations {
    return _conversations.where((c) {
      if (_filter != 'all' && c.status != _filter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = c.guestName?.toLowerCase().contains(q) ?? false;
        final matchEmail = c.guestEmail?.toLowerCase().contains(q) ?? false;
        final matchId = c.visitorId.toLowerCase().contains(q);
        return matchName || matchEmail || matchId;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'Inbox',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;
          
          if (isMobile && _selectedConversation != null) {
            // Mobile Chat View
            return _buildChatArea(isMobile: true);
          }
          
          final listArea = _buildListArea(isMobile);
          
          if (isMobile) {
            return listArea;
          }
          
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 320,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: AppColors.border)),
                ),
                child: listArea,
              ),
              Expanded(
                child: _selectedConversation == null
                    ? const EmptyState(
                        icon: '💬',
                        title: 'Select a conversation',
                        subtitle: 'Choose a conversation from the list to start chatting',
                      )
                    : _buildChatArea(isMobile: false),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListArea(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile) ...[
          Text(
            '${_conversations.length} conversation${_conversations.length != 1 ? 's' : ''}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 16),
        ],
        // Search & Filter
        Padding(
          padding: EdgeInsets.only(right: isMobile ? 0 : 16.0, bottom: 16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildFilterBtn('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterBtn('Open', 'open'),
                  const SizedBox(width: 8),
                  _buildFilterBtn('Resolved', 'resolved'),
                ],
              ),
            ],
          ),
        ),
        
        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : _filteredConversations.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No conversations found', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.only(right: isMobile ? 0 : 16.0),
                      itemCount: _filteredConversations.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final conv = _filteredConversations[index];
                        final isSelected = _selectedConversation?.id == conv.id;
                        final hasUnread = (conv.unreadCountAdmin ?? 0) > 0;
                        final name = conv.guestName?.isNotEmpty == true ? conv.guestName! : 'Visitor ${conv.visitorId.substring(0, 4)}';
                        final initial = name[0].toUpperCase();

                        return InkWell(
                          onTap: () => _selectConversation(conv),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.accent.withValues(alpha: 0.05) : AppColors.surfaceMuted,
                              border: Border.all(
                                color: isSelected ? AppColors.accent : AppColors.border,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            _formatTime(conv.updatedAt),
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: hasUnread ? AppColors.accent : AppColors.textMuted,
                                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: conv.status == 'resolved' ? AppColors.success : AppColors.warning,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            conv.status == 'resolved' ? 'Resolved' : 'Open',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                          if (hasUnread) ...[
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.error,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '${conv.unreadCountAdmin}',
                                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterBtn(String label, String value) {
    final active = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.accentDark : Colors.transparent,
          border: Border.all(color: active ? AppColors.accentDark : AppColors.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: active ? Colors.white : AppColors.textBody,
          ),
        ),
      ),
    );
  }

  Widget _buildChatArea({required bool isMobile}) {
    final conv = _selectedConversation!;
    final name = conv.guestName?.isNotEmpty == true ? conv.guestName! : 'Visitor ${conv.visitorId.substring(0, 4)}';
    
    return Container(
      margin: EdgeInsets.only(left: isMobile ? 0 : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (isMobile) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _selectedConversation = null),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${conv.visitorId}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // Actions
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (val) {
                    if (val == 'toggle') _toggleStatus();
                    if (val == 'delete') _deleteConversation();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(conv.status == 'resolved' ? 'Reopen' : 'Mark Resolved'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Messages
          Expanded(
            child: Container(
              color: AppColors.surfaceMuted,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isAdmin = msg.senderType == 'admin';
                  
                  return Align(
                    alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: isAdmin 
                            ? const LinearGradient(colors: [AppColors.accent, AppColors.accentLight])
                            : null,
                        color: isAdmin ? null : Colors.white,
                        borderRadius: BorderRadius.circular(16).copyWith(
                          bottomRight: isAdmin ? const Radius.circular(4) : null,
                          bottomLeft: !isAdmin ? const Radius.circular(4) : null,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
                        ],
                        border: isAdmin ? null : Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.content,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isAdmin ? Colors.white : AppColors.textHeadingAlt,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(msg.createdAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isAdmin ? Colors.white.withValues(alpha: 0.7) : AppColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                    ),
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _sendMessage,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14),
                  ),
                  child: const Icon(Icons.send, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String isoString) {
    final dt = DateTime.parse(isoString).toLocal();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    return DateFormat('MMM d, HH:mm').format(dt);
  }
}
