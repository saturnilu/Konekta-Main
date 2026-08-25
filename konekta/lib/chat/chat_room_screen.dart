import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/app_scope.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models/chat.dart';
import '../data/repositories/discovery_repository.dart';
import 'chat_cubit.dart';

class ChatRoomScreen extends StatelessWidget {
  const ChatRoomScreen({super.key, this.conversationId, this.otherUserId, this.otherUserName});
  final int? conversationId;
  final int? otherUserId;
  final String? otherUserName;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return BlocProvider(
      create: (_) => ChatCubit(
        chatRepo: scope.chatRepo,
        discoveryRepo: DiscoveryRepository(scope.api),
        role: scope.role,
      )..init(conversationId: conversationId, otherUserId: otherUserId, otherUserName: otherUserName),
      child: const _ChatRoomView(),
    );
  }
}

class _ChatRoomView extends StatefulWidget {
  const _ChatRoomView();

  @override
  State<_ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<_ChatRoomView> {
  final _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      await context.read<ChatCubit>().send(text);
      if (!mounted) return;
      _controller.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatCubit, ChatRoomState>(
      listener: (context, state) => _scrollToBottom(),
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          appBar: AppBar(
            backgroundColor: KonektaColors.surface,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: KonektaColors.textPrimary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.displayName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: KonektaColors.textDark),
                ),
                Text(
                  state.otherEngagementRate != null
                      ? 'Engagement: ${state.otherEngagementRate!.toStringAsFixed(1)}%'
                      : (state.otherBrandSubtitle ?? (state.hasConversation ? 'Conversation' : 'Starting chat…')),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A)),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              if (state.error != null)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFEE2E2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFE5484D), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: const TextStyle(color: Color(0xFFB81F23), fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.read<ChatCubit>().loadMessages(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: state.loading && state.messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : state.messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded,
                                    color: KonektaColors.textMuted.withValues(alpha: 0.5), size: 64),
                                const SizedBox(height: 12),
                                const Text(
                                  'No messages yet — say hi!',
                                  style: TextStyle(color: KonektaColors.textMuted, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => context.read<ChatCubit>().loadMessages(),
                            child: ListView.builder(
                              controller: _scroll,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: state.messages.length,
                              itemBuilder: (context, i) {
                                final m = state.messages[i];
                                return _MessageBubble(
                                  isOutgoing: m.isMine,
                                  text: m.body ?? '',
                                  time: Format.chatTime(m.createdAt),
                                );
                              },
                            ),
                          ),
              ),
              _ChatInputBar(
                controller: _controller,
                onSend: _send,
                sending: state.sending,
                enabled: state.hasConversation,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final bool isOutgoing;
  final String text;
  final String time;

  const _MessageBubble({required this.isOutgoing, required this.text, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isOutgoing ? const Color(0xFFEFF5FF) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isOutgoing ? 18 : 4),
                bottomRight: Radius.circular(isOutgoing ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: TextStyle(fontSize: 14, color: KonektaColors.textDark, height: 1.4)),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(time, style: const TextStyle(fontSize: 10, color: KonektaColors.textMuted)),
                ),
              ],
            ),
          ),
          if (isOutgoing) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final bool enabled;

  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.sending,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file_rounded, color: KonektaColors.textMuted),
              onPressed: null,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: KonektaColors.bg, borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF60A9FF), Color(0xFF246FE0)]),
                shape: BoxShape.circle,
                color: enabled ? null : KonektaColors.textMuted.withValues(alpha: 0.4),
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: enabled ? onSend : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}