import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'session.dart';

class SessionState extends Equatable {
  final bool isLoggedIn;
  final String? role;
  final String? name;
  final int? userId;

  const SessionState({this.isLoggedIn = false, this.role, this.name, this.userId});

  factory SessionState.from(Session s) => SessionState(
        isLoggedIn: s.isLoggedIn,
        role: s.role,
        name: s.name,
        userId: s.userId,
      );

  @override
  List<Object?> get props => [isLoggedIn, role, name, userId];
}

class SessionCubit extends Cubit<SessionState> {
  final Session session;
  SessionCubit(this.session) : super(SessionState.from(session));
  void refresh() => emit(SessionState.from(session));

  Future<void> logout() async {
    await session.clear();
    emit(const SessionState());
  }
}