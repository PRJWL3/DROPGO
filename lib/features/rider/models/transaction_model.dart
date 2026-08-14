// Model representing a single wallet transaction
import 'package:flutter/foundation.dart';

enum TransactionType { credit, debit }

@immutable
class TransactionModel {
  final String id;
  final String title;
  final String date;
  final double amount;
  final TransactionType type;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.type,
  });
}
