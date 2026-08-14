// Wallet balance and transactions notifier provider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';

class WalletState {
  final double balance;
  final List<TransactionModel> transactions;

  const WalletState({
    required this.balance,
    required this.transactions,
  });

  WalletState copyWith({
    double? balance,
    List<TransactionModel>? transactions,
  }) {
    return WalletState(
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier()
      : super(
          const WalletState(
            balance: 142.50,
            transactions: [
              TransactionModel(
                id: 'tx_1',
                title: 'Ride to Airport',
                date: '12 Aug 2026, 09:30 AM',
                amount: 25.00,
                type: TransactionType.debit,
              ),
              TransactionModel(
                id: 'tx_2',
                title: 'Added Funds (Card)',
                date: '11 Aug 2026, 04:15 PM',
                amount: 50.00,
                type: TransactionType.credit,
              ),
              TransactionModel(
                id: 'tx_3',
                title: 'Ride to Market',
                date: '10 Aug 2026, 11:20 AM',
                amount: 10.00,
                type: TransactionType.debit,
              ),
              TransactionModel(
                id: 'tx_4',
                title: 'Referral Bonus',
                date: '08 Aug 2026, 02:00 PM',
                amount: 15.00,
                type: TransactionType.credit,
              ),
            ],
          ),
        );

  void addFunds(double amount) {
    final updatedTx = [
      TransactionModel(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Added Funds (UPI)',
        date: 'Today, Just Now',
        amount: amount,
        type: TransactionType.credit,
      ),
      ...state.transactions,
    ];
    state = state.copyWith(
      balance: state.balance + amount,
      transactions: updatedTx,
    );
  }
}

final walletNotifierProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier();
});
