import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'account_allocation.dart';

/// Model representing a repayment towards a borrowed loan.
///
/// Accounting rules:
/// - Deducts total payment (principal + interest) from overall balance.
/// - Reduces loan outstanding principal by principalAmount.
/// - Records only interestAmount as an expense transaction.
/// - Does NOT record principalAmount as an expense or income.
/// - Repayment's total cash outflow equals principal repayment plus interest.
class LoanRepayment {
  final String id;
  final String loanId;
  final double principalAmount;
  final double interestAmount;
  final DateTime date;
  final String note;
  final String currency;
  final List<AccountAllocation> allocations;
  final String? interestTransactionId;
  final DateTime createdAt;

  const LoanRepayment({
    required this.id,
    required this.loanId,
    required this.principalAmount,
    this.interestAmount = 0.0,
    required this.date,
    this.note = '',
    this.currency = 'USD',
    this.allocations = const [],
    this.interestTransactionId,
    required this.createdAt,
  });

  /// Total cash outflow for this repayment (Principal + Interest).
  double get totalPayment => principalAmount + interestAmount;

  /// Total amount allocated across accounts.
  double get totalAllocated {
    return allocations.fold(0.0, (sum, item) => sum + item.amount);
  }

  /// Unassigned portion of the repayment total payment.
  double get unassignedAmount {
    final diff = totalPayment - totalAllocated;
    return diff > 0.000001 ? diff : 0.0;
  }

  /// Whether the repayment has unassigned funds.
  bool get hasUnassigned => unassignedAmount > 0.000001;

  LoanRepayment copyWith({
    String? id,
    String? loanId,
    double? principalAmount,
    double? interestAmount,
    DateTime? date,
    String? note,
    String? currency,
    List<AccountAllocation>? allocations,
    String? interestTransactionId,
    DateTime? createdAt,
  }) {
    return LoanRepayment(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      principalAmount: principalAmount ?? this.principalAmount,
      interestAmount: interestAmount ?? this.interestAmount,
      date: date ?? this.date,
      note: note ?? this.note,
      currency: currency ?? this.currency,
      allocations: allocations ?? this.allocations,
      interestTransactionId:
          interestTransactionId ?? this.interestTransactionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loanId': loanId,
      'principalAmount': principalAmount,
      'interestAmount': interestAmount,
      'date': date.toIso8601String(),
      'note': note,
      'currency': currency,
      'allocations': allocations.map((a) => a.toMap()).toList(),
      'interestTransactionId': interestTransactionId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LoanRepayment.fromMap(Map<String, dynamic> map) {
    List<AccountAllocation> allocations = const [];
    if (map['allocations'] is List) {
      allocations = (map['allocations'] as List<dynamic>)
          .map((item) => AccountAllocation.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return LoanRepayment(
      id: map['id'] as String? ?? '',
      loanId: map['loanId'] as String? ?? '',
      principalAmount: (map['principalAmount'] as num?)?.toDouble() ?? 0.0,
      interestAmount: (map['interestAmount'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] != null
          ? DateTime.tryParse(map['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      note: map['note'] as String? ?? '',
      currency: (map['currency'] as String?)?.isNotEmpty == true
          ? map['currency'] as String
          : 'USD',
      allocations: allocations,
      interestTransactionId: map['interestTransactionId'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory LoanRepayment.fromJson(String source) =>
      LoanRepayment.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoanRepayment &&
        other.id == id &&
        other.loanId == loanId &&
        other.principalAmount == principalAmount &&
        other.interestAmount == interestAmount &&
        other.date == date &&
        other.note == note &&
        other.currency == currency &&
        other.interestTransactionId == interestTransactionId &&
        other.createdAt == createdAt &&
        listEquals(other.allocations, allocations);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        loanId.hashCode ^
        principalAmount.hashCode ^
        interestAmount.hashCode ^
        date.hashCode ^
        note.hashCode ^
        currency.hashCode ^
        interestTransactionId.hashCode ^
        createdAt.hashCode ^
        allocations.hashCode;
  }
}
