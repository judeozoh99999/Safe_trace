import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransactionModel {
  final String id;
  final String title;
  final String type; // credit, debit
  final double amount;
  final String date;

  TransactionModel({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    required this.date,
  });
}

class WalletState {
  final double balance;
  final bool isSubscriptionActive;
  final List<TransactionModel> transactions;

  WalletState({
    this.balance = 0.0,
    this.isSubscriptionActive = false,
    this.transactions = const [],
  });

  WalletState copyWith({
    double? balance,
    bool? isSubscriptionActive,
    List<TransactionModel>? transactions,
  }) {
    return WalletState(
      balance: balance ?? this.balance,
      isSubscriptionActive: isSubscriptionActive ?? this.isSubscriptionActive,
      transactions: transactions ?? this.transactions,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier()
      : super(WalletState(
          balance: 0.0,
          isSubscriptionActive: false,
          transactions: [],
        ));

  void depositFunds(double amount) {
    final creditTx = TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Paystack Wallet Deposit',
      type: 'credit',
      amount: amount,
      date: 'Just now',
    );

    double newBalance = state.balance + amount;
    bool subActive = state.isSubscriptionActive;
    List<TransactionModel> txs = [creditTx, ...state.transactions];

    // Trigger auto-subscription if balance is >= 1000 and subscription was inactive
    if (newBalance >= 1000.0 && !subActive) {
      newBalance -= 1000.0;
      subActive = true;
      final debitTx = TransactionModel(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        title: 'SafeTrace 365-Day Subscription',
        type: 'debit',
        amount: 1000.0,
        date: 'Just now',
      );
      txs = [debitTx, ...txs];
    }

    state = state.copyWith(
      balance: newBalance,
      isSubscriptionActive: subActive,
      transactions: txs,
    );
  }

  void cancelSubscription() {
    state = state.copyWith(isSubscriptionActive: false);
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier();
});
