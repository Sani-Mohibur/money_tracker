import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'account_allocation.dart';

/// Represents the type of a financial transaction.
enum TransactionType {
  income,
  expense,
}

/// Model class representing a single income or expense transaction.
class Transaction {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String note;
  final String currency;
  final List<AccountAllocation> allocations;

  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note = '',
    this.currency = 'USD',
    this.allocations = const [],
  });

  /// Check if transaction is income.
  bool get isIncome => type == TransactionType.income;

  /// Check if transaction is expense.
  bool get isExpense => type == TransactionType.expense;

  /// Total amount allocated to accounts in this transaction.
  double get totalAllocated {
    return allocations.fold(0.0, (sum, item) => sum + item.amount);
  }

  /// Unassigned portion of the transaction amount.
  double get unassignedAmount {
    final diff = amount - totalAllocated;
    return diff > 0.000001 ? diff : 0.0;
  }

  /// Whether the transaction has unassigned funds.
  bool get hasUnassigned => unassignedAmount > 0.000001;

  /// Creates a copy of this transaction with optional modified values.
  Transaction copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    String? category,
    DateTime? date,
    String? note,
    String? currency,
    List<AccountAllocation>? allocations,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      currency: currency ?? this.currency,
      allocations: allocations ?? this.allocations,
    );
  }

  /// Converts a [Transaction] instance to a Map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.name,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'currency': currency,
      'allocations': allocations.map((a) => a.toMap()).toList(),
    };
  }

  /// Creates a [Transaction] from a Map.
  /// Backward compatible: existing transactions without currency default safely to 'USD',
  /// and existing transactions without allocations default safely to empty list `const []`.
  factory Transaction.fromMap(Map<String, dynamic> map) {
    List<AccountAllocation> allocations = const [];
    if (map['allocations'] is List) {
      allocations = (map['allocations'] as List<dynamic>)
          .map((item) => AccountAllocation.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return Transaction(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      category: map['category'] as String? ?? 'Other',
      date: map['date'] != null
          ? DateTime.tryParse(map['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      note: map['note'] as String? ?? '',
      currency: (map['currency'] as String?)?.isNotEmpty == true
          ? map['currency'] as String
          : 'USD',
      allocations: allocations,
    );
  }

  /// Serializes transaction to JSON string.
  String toJson() => json.encode(toMap());

  /// Deserializes transaction from JSON string.
  factory Transaction.fromJson(String source) =>
      Transaction.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction &&
        other.id == id &&
        other.title == title &&
        other.amount == amount &&
        other.type == type &&
        other.category == category &&
        other.date == date &&
        other.note == note &&
        other.currency == currency &&
        listEquals(other.allocations, allocations);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        amount.hashCode ^
        type.hashCode ^
        category.hashCode ^
        date.hashCode ^
        note.hashCode ^
        currency.hashCode ^
        allocations.hashCode;
  }
}
