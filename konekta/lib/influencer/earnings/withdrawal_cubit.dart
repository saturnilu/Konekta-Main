import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/withdrawal_repository.dart';

class WithdrawalState extends Equatable {
  final bool loading;
  final String? error;
  final WithdrawalBalance? balance;
  final List<WithdrawalRequest> history;
  final bool submitting;

  const WithdrawalState({
    this.loading = true,
    this.error,
    this.balance,
    this.history = const [],
    this.submitting = false,
  });

  WithdrawalState copyWith({
    bool? loading,
    String? error,
    WithdrawalBalance? balance,
    List<WithdrawalRequest>? history,
    bool? submitting,
  }) {
    return WithdrawalState(
      loading: loading ?? this.loading,
      error: error,
      balance: balance ?? this.balance,
      history: history ?? this.history,
      submitting: submitting ?? this.submitting,
    );
  }

  @override
  List<Object?> get props => [loading, error, balance, history, submitting];
}

class WithdrawalCubit extends Cubit<WithdrawalState> {
  final WithdrawalRepository repo;
  WithdrawalCubit(this.repo) : super(const WithdrawalState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final results = await Future.wait([repo.balance(), repo.mine()]);
      emit(state.copyWith(
        balance: results[0] as WithdrawalBalance,
        history: results[1] as List<WithdrawalRequest>,
        loading: false,
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: '$e'));
    }
  }

  Future<void> submit({
    required num amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    emit(state.copyWith(submitting: true));
    try {
      await repo.request(
        amount: amount,
        bankName: bankName,
        accountNumber: accountNumber,
        accountName: accountName,
      );
      emit(state.copyWith(submitting: false));
      await load();
    } catch (e) {
      emit(state.copyWith(submitting: false));
      rethrow;
    }
  }
}