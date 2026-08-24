// Wallet balance and transactions notifier provider
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/firebase_service.dart';
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

// Real-time Firestore transaction stream provider
final walletStreamProvider = StreamProvider<WalletState>((ref) {
  final auth = ref.watch(authProvider);
  final userId = auth.uid ?? 'user_1234';

  if (!FirebaseService.isFirebaseAvailable) {
    // Return empty state for fallback
    return Stream.value(const WalletState(balance: 142.50, transactions: []));
  }

  return FirebaseFirestore.instance
      .collection('transactions')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((snapshot) {
        final txList = snapshot.docs.map((doc) {
          final data = doc.data();
          final typeStr = data['type'] as String? ?? 'credit';
          final type = typeStr == 'credit' ? TransactionType.credit : TransactionType.debit;

          DateTime time = DateTime.now();
          if (data['createdAt'] is Timestamp) {
            time = (data['createdAt'] as Timestamp).toDate();
          } else if (data['createdAt'] is String) {
            time = DateTime.parse(data['createdAt'] as String);
          }

          // Format date string, e.g. "12 Aug 2026, 09:30 AM"
          final day = time.day.toString().padLeft(2, '0');
          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          final month = months[time.month - 1];
          final year = time.year.toString();
          final hourNum = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
          final hour = hourNum.toString().padLeft(2, '0');
          final min = time.minute.toString().padLeft(2, '0');
          final period = time.hour >= 12 ? 'PM' : 'AM';
          final dateStr = "$day $month $year, $hour:$min $period";

          return TransactionModel(
            id: doc.id,
            title: data['title'] as String? ?? 'Transaction',
            date: dateStr,
            amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
            type: type,
          );
        }).toList();

        // Sort in memory to avoid index requirements
        txList.sort((a, b) => b.id.compareTo(a.id));

        // Calculate balance dynamically (Starting from base balance 142.50)
        double balance = 142.50;
        for (var tx in txList) {
          if (tx.type == TransactionType.credit) {
            balance += tx.amount;
          } else {
            balance -= tx.amount;
          }
        }

        return WalletState(balance: balance, transactions: txList);
      });
});

class WalletNotifier extends StateNotifier<WalletState> {
  final Ref _ref;

  WalletNotifier(this._ref)
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
        ) {
    // Listen to real-time walletStreamProvider
    _ref.listen<AsyncValue<WalletState>>(walletStreamProvider, (previous, next) {
      next.whenData((val) {
        state = val;
      });
    });
  }

  Future<void> addFunds(double amount) async {
    final auth = _ref.read(authProvider);
    final userId = auth.uid ?? 'user_1234';

    if (FirebaseService.isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance.collection('transactions').add({
          'userId': userId,
          'title': 'Added Funds (UPI)',
          'amount': amount,
          'type': 'credit',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint("Failed to write addFunds to Firestore: $e");
      }
    } else {
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
}

final walletNotifierProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref);
});
