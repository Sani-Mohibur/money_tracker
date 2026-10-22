/// Represents a direct transfer between two Money Accounts.
/// A transfer does not count as income or expense in overall financial balance.
/// Any nonzero transfer fee is recorded as a linked expense transaction.
class AccountTransfer {
  final String id;
  final String fromAccountId;
  final String toAccountId;
  final double amount;
  final double toAmount;
  final double fee;
  final String? feeTransactionId;
  final DateTime date;
  final String note;

  const AccountTransfer({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.toAmount,
    this.fee = 0.0,
    this.feeTransactionId,
    required this.date,
    this.note = '',
  });

  AccountTransfer copyWith({
    String? id,
    String? fromAccountId,
    String? toAccountId,
    double? amount,
    double? toAmount,
    double? fee,
    String? feeTransactionId,
    DateTime? date,
    String? note,
  }) {
    return AccountTransfer(
      id: id ?? this.id,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      amount: amount ?? this.amount,
      toAmount: toAmount ?? this.toAmount,
      fee: fee ?? this.fee,
      feeTransactionId: feeTransactionId ?? this.feeTransactionId,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromAccountId': fromAccountId,
      'toAccountId': toAccountId,
      'amount': amount,
      'toAmount': toAmount,
      'fee': fee,
      'feeTransactionId': feeTransactionId,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory AccountTransfer.fromMap(Map<String, dynamic> map) {
    return AccountTransfer(
      id: map['id'] as String? ?? '',
      fromAccountId: map['fromAccountId'] as String? ?? '',
      toAccountId: map['toAccountId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      toAmount: (map['toAmount'] as num?)?.toDouble() ??
          (map['amount'] as num?)?.toDouble() ??
          0.0,
      fee: (map['fee'] as num?)?.toDouble() ?? 0.0,
      feeTransactionId: map['feeTransactionId'] as String?,
      date: map['date'] != null
          ? DateTime.tryParse(map['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      note: map['note'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountTransfer &&
        other.id == id &&
        other.fromAccountId == fromAccountId &&
        other.toAccountId == toAccountId &&
        other.amount == amount &&
        other.toAmount == toAmount &&
        other.fee == fee &&
        other.feeTransactionId == feeTransactionId &&
        other.date == date &&
        other.note == note;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        fromAccountId.hashCode ^
        toAccountId.hashCode ^
        amount.hashCode ^
        toAmount.hashCode ^
        fee.hashCode ^
        feeTransactionId.hashCode ^
        date.hashCode ^
        note.hashCode;
  }
}
