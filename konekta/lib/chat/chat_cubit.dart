import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/chat.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/discovery_repository.dart';

class ChatRoomState extends Equatable {
  final int? conversationId;
  final String displayName;
  final List<ChatMessage> messages;
  final bool loading;
  final bool sending;
  final String? error;
  final num? otherEngagementRate;
  final String? otherBrandSubtitle;

  const ChatRoomState({
    this.conversationId,
    this.displayName = 'Chat',
    this.messages = const [],
    this.loading = true,
    this.sending = false,
    this.error,
    this.otherEngagementRate,
    this.otherBrandSubtitle,
  });

  bool get hasConversation => conversationId != null;

  ChatRoomState copyWith({
    int? conversationId,
    String? displayName,
    List<ChatMessage>? messages,
    bool? loading,
    bool? sending,
    String? error,
    num? otherEngagementRate,
    String? otherBrandSubtitle,
  }) {
    return ChatRoomState(
      conversationId: conversationId ?? this.conversationId,
      displayName: displayName ?? this.displayName,
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      error: error,
      otherEngagementRate: otherEngagementRate ?? this.otherEngagementRate,
      otherBrandSubtitle: otherBrandSubtitle ?? this.otherBrandSubtitle,
    );
  }

  @override
  List<Object?> get props => [
        conversationId,
        displayName,
        messages,
        loading,
        sending,
        error,
        otherEngagementRate,
        otherBrandSubtitle,
      ];
}

class ChatCubit extends Cubit<ChatRoomState> {
  final ChatRepository chatRepo;
  final DiscoveryRepository discoveryRepo;
  final String role;

  ChatCubit({required this.chatRepo, required this.discoveryRepo, required this.role})
      : super(const ChatRoomState());

  Future<void> init({int? conversationId, int? otherUserId, String? otherUserName}) async {
    emit(state.copyWith(displayName: otherUserName ?? 'Chat'));
    if (otherUserId != null) {
      _maybeLoadOtherPartyContext(otherUserId);
    }

    if (conversationId != null) {
      emit(state.copyWith(conversationId: conversationId));
      await loadMessages();
      return;
    }
    if (otherUserId != null) {
      await _startConversation(otherUserId, otherUserName);
      return;
    }
    emit(state.copyWith(loading: false, error: 'No conversation selected'));
  }

  Future<void> _startConversation(int otherUserId, String? otherUserName) async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final c = await chatRepo.startConversation(otherUserId);
      emit(state.copyWith(
        conversationId: c.id,
        displayName: c.otherUserName ?? otherUserName ?? 'Chat',
        loading: false,
      ));
      await loadMessages();
    } catch (e) {
      emit(state.copyWith(error: 'Failed to start conversation: $e', loading: false));
    }
  }

  Future<void> loadMessages() async {
    final id = state.conversationId;
    if (id == null) return;
    emit(state.copyWith(loading: true, error: null));
    try {
      final list = await chatRepo.getMessages(id);
      emit(state.copyWith(messages: list, loading: false));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to load messages: $e', loading: false));
    }
  }

  Future<void> send(String text) async {
    final id = state.conversationId;
    final trimmed = text.trim();
    if (id == null || trimmed.isEmpty || state.sending) return;
    emit(state.copyWith(sending: true));
    try {
      final msg = await chatRepo.sendMessage(id, trimmed);
      emit(state.copyWith(messages: [...state.messages, msg], sending: false));
    } catch (e) {
      emit(state.copyWith(sending: false));
      rethrow;
    }
  }

  Future<void> _maybeLoadOtherPartyContext(int otherUserId) async {
    try {
      if (role == 'brand') {
        final profile = await discoveryRepo.influencer(otherUserId);
        emit(state.copyWith(otherEngagementRate: profile.engagementRate));
      } else if (role == 'influencer') {
        final brand = await discoveryRepo.brand(otherUserId);
        final parts = <String>[
          if ((brand.industry ?? '').isNotEmpty) brand.industry!,
          if ((brand.location ?? '').isNotEmpty) brand.location!,
        ];
        if (parts.isNotEmpty) emit(state.copyWith(otherBrandSubtitle: parts.join(' • ')));
      }
    } catch (_) {
    }
  }
}