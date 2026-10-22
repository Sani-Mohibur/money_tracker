/// Represents the allocation of a portion (or all) of a transaction's amount
/// to a specific Money Account.
class AccountAllocation {
  final String accountId;
  final double amount;

  const AccountAllocation({
    required this.accountId,
    required this.amount,
  });

  AccountAllocation copyWith({
    String? accountId,
    double? amount,
  }) {
    return AccountAllocation(
      accountId: accountId ?? this.accountId,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'amount': amount,
    };
  }

  factory AccountAllocation.fromMap(Map<String, dynamic> map) {
    return AccountAllocation(
      accountId: map['accountId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountAllocation &&
        other.accountId == accountId &&
        other.amount == amount;
  }

  @override
  int get hashCode => accountId.hashCode ^ amount.hashCode;
}
