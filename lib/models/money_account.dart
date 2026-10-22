import 'package:flutter/material.dart';

/// Represents a financial account (e.g., Bank Account, Digital Wallet, Cash, Crypto, etc.).
class MoneyAccount {
  final String id;
  final String name;
  final String description;
  final String currency;
  final String iconKey;
  final int colorValue;
  final bool isArchived;
  final DateTime createdAt;

  const MoneyAccount({
    required this.id,
    required this.name,
    this.description = '',
    required this.currency,
    this.iconKey = 'wallet',
    this.colorValue = 0xFF0F172A,
    this.isArchived = false,
    required this.createdAt,
  });

  Color get color => Color(colorValue);

  IconData get icon => getIconByKey(iconKey);

  MoneyAccount copyWith({
    String? id,
    String? name,
    String? description,
    String? currency,
    String? iconKey,
    int? colorValue,
    bool? isArchived,
    DateTime? createdAt,
  }) {
    return MoneyAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      currency: currency ?? this.currency,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'currency': currency,
      'iconKey': iconKey,
      'colorValue': colorValue,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MoneyAccount.fromMap(Map<String, dynamic> map) {
    return MoneyAccount(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      currency: (map['currency'] as String?)?.isNotEmpty == true
          ? map['currency'] as String
          : 'USD',
      iconKey: map['iconKey'] as String? ?? 'wallet',
      colorValue: map['colorValue'] as int? ?? 0xFF0F172A,
      isArchived: map['isArchived'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static IconData getIconByKey(String key) {
    switch (key) {
      case 'bank':
        return Icons.account_balance_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'cash':
        return Icons.payments_rounded;
      case 'credit_card':
        return Icons.credit_card_rounded;
      case 'crypto':
        return Icons.currency_bitcoin_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'paypal':
        return Icons.payment_rounded;
      case 'wise':
        return Icons.swap_horiz_rounded;
      case 'investment':
        return Icons.trending_up_rounded;
      case 'vault':
        return Icons.lock_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  static const List<MapEntry<String, IconData>> availableIcons = [
    MapEntry('bank', Icons.account_balance_rounded),
    MapEntry('wallet', Icons.account_balance_wallet_rounded),
    MapEntry('cash', Icons.payments_rounded),
    MapEntry('credit_card', Icons.credit_card_rounded),
    MapEntry('crypto', Icons.currency_bitcoin_rounded),
    MapEntry('savings', Icons.savings_rounded),
    MapEntry('paypal', Icons.payment_rounded),
    MapEntry('wise', Icons.swap_horiz_rounded),
    MapEntry('investment', Icons.trending_up_rounded),
    MapEntry('vault', Icons.lock_rounded),
  ];

  static const List<Color> availableColors = [
    Color(0xFF0F172A), // Slate 900
    Color(0xFF2563EB), // Blue
    Color(0xFF059669), // Emerald
    Color(0xFF7C3AED), // Violet
    Color(0xFFD97706), // Amber
    Color(0xFFDC2626), // Red
    Color(0xFF0891B2), // Cyan
    Color(0xFFDB2777), // Pink
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoneyAccount &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.currency == currency &&
        other.iconKey == iconKey &&
        other.colorValue == colorValue &&
        other.isArchived == isArchived &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        description.hashCode ^
        currency.hashCode ^
        iconKey.hashCode ^
        colorValue.hashCode ^
        isArchived.hashCode ^
        createdAt.hashCode;
  }
}
