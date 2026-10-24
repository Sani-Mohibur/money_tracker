import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'account_allocation.dart';

/// Model representing a borrowed loan.
///
/// Accounting rules:
/// - Loan principal is NOT recorded as income.
/// - Loan fee is NOT recorded as an ordinary expense; it is deducted from
///   the principal before the net proceeds enter available balance.
/// - Only net amount received affects the overall balance.
/// - Track original loan principal as a liability.
class Loan {
  final String id;
  final String title;
  final String lender;
  final double principal;
  final double fee;
  final DateTime date;
  final String note;
  final String currency;
  final List<AccountAllocation> allocations;
  final DateTime createdAt;
  final bool isArchived;

  const Loan({
    required this.id,
    required this.title,
    this.lender = '',
    required this.principal,
    this.fee = 0.0,
    required this.date,
    this.note = '',
    this.currency = 'USD',
    this.allocations = const [],
    required this.createdAt,
    this.isArchived = false,
  });

  /// Net proceeds received from the loan (Principal - Fee).
  double get netAmountReceived {
    final net = principal - fee;
    return net > 0 ? net : 0.0;
  }

  /// Total amount allocated across money accounts.
  double get totalAllocated {
    return allocations.fold(0.0, (sum, item) => sum + item.amount);
  }

  /// Unassigned portion of the net proceeds.
  double get unassignedAmount {
    final diff = netAmountReceived - totalAllocated;
    return diff > 0.000001 ? diff : 0.0;
  }

  /// Whether some or all net proceeds remain unassigned.
  bool get hasUnassigned => unassignedAmount > 0.000001;

  Loan copyWith({
    String? id,
    String? title,
    String? lender,
    double? principal,
    double? fee,
    DateTime? date,
    String? note,
    String? currency,
    List<AccountAllocation>? allocations,
    DateTime? createdAt,
    bool? isArchived,
  }) {
    return Loan(
      id: id ?? this.id,
      title: title ?? this.title,
      lender: lender ?? this.lender,
      principal: principal ?? this.principal,
      fee: fee ?? this.fee,
      date: date ?? this.date,
      note: note ?? this.note,
      currency: currency ?? this.currency,
      allocations: allocations ?? this.allocations,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'lender': lender,
      'principal': principal,
      'fee': fee,
      'date': date.toIso8601String(),
      'note': note,
      'currency': currency,
      'allocations': allocations.map((a) => a.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'isArchived': isArchived,
    };
  }

  factory Loan.fromMap(Map<String, dynamic> map) {
    List<AccountAllocation> allocations = const [];
    if (map['allocations'] is List) {
      allocations = (map['allocations'] as List<dynamic>)
          .map((item) => AccountAllocation.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return Loan(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      lender: map['lender'] as String? ?? '',
      principal: (map['principal'] as num?)?.toDouble() ?? 0.0,
      fee: (map['fee'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] != null
          ? DateTime.tryParse(map['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      note: map['note'] as String? ?? '',
      currency: (map['currency'] as String?)?.isNotEmpty == true
          ? map['currency'] as String
          : 'USD',
      allocations: allocations,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isArchived: map['isArchived'] as bool? ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory Loan.fromJson(String source) =>
      Loan.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Loan &&
        other.id == id &&
        other.title == title &&
        other.lender == lender &&
        other.principal == principal &&
        other.fee == fee &&
        other.date == date &&
        other.note == note &&
        other.currency == currency &&
        other.createdAt == createdAt &&
        other.isArchived == isArchived &&
        listEquals(other.allocations, allocations);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        lender.hashCode ^
        principal.hashCode ^
        fee.hashCode ^
        date.hashCode ^
        note.hashCode ^
        currency.hashCode ^
        createdAt.hashCode ^
        isArchived.hashCode ^
        allocations.hashCode;
  }
}
