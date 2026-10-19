import 'package:flutter/material.dart';
import '../models/transaction.dart';

/// Information about a transaction category.
class CategoryItem {
  final String name;
  final IconData icon;
  final Color color;
  final bool isCustom;
  final String iconKey;

  const CategoryItem({
    required this.name,
    required this.icon,
    required this.color,
    this.isCustom = false,
    this.iconKey = 'category',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconKey': iconKey,
      'colorValue': color.toARGB32(),
      'isCustom': isCustom,
    };
  }

  factory CategoryItem.fromMap(Map<String, dynamic> map) {
    final key = map['iconKey'] as String? ?? 'category';
    return CategoryItem(
      name: map['name'] as String? ?? 'Custom',
      icon: getIconByKey(key),
      color: Color(map['colorValue'] as int? ?? 0xFF6B7280),
      isCustom: map['isCustom'] as bool? ?? true,
      iconKey: key,
    );
  }

  static IconData getIconByKey(String key) {
    switch (key) {
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'cafe':
        return Icons.local_cafe_rounded;
      case 'fitness':
        return Icons.fitness_center_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'book':
        return Icons.book_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'payments':
        return Icons.payments_rounded;
      case 'celebration':
        return Icons.celebration_rounded;
      case 'gaming':
        return Icons.sports_esports_rounded;
      case 'car':
        return Icons.car_rental_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}

class AppCategories {
  /// Predefined expense categories.
  static const List<CategoryItem> defaultExpenseCategories = [
    CategoryItem(
      name: 'Food & Dining',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFF97316), // Orange
      iconKey: 'restaurant',
    ),
    CategoryItem(
      name: 'Groceries',
      icon: Icons.shopping_cart_rounded,
      color: Color(0xFF10B981), // Emerald
      iconKey: 'groceries',
    ),
    CategoryItem(
      name: 'Transport',
      icon: Icons.directions_car_rounded,
      color: Color(0xFF3B82F6), // Blue
      iconKey: 'transport',
    ),
    CategoryItem(
      name: 'Bills & Utilities',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFEF4444), // Red
      iconKey: 'bills',
    ),
    CategoryItem(
      name: 'Entertainment',
      icon: Icons.movie_filter_rounded,
      color: Color(0xFF8B5CF6), // Purple
      iconKey: 'entertainment',
    ),
    CategoryItem(
      name: 'Shopping',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFFEC4899), // Pink
      iconKey: 'shopping',
    ),
    CategoryItem(
      name: 'Health & Medical',
      icon: Icons.medical_services_rounded,
      color: Color(0xFF14B8A6), // Teal
      iconKey: 'health',
    ),
    CategoryItem(
      name: 'Education',
      icon: Icons.school_rounded,
      color: Color(0xFF6366F1), // Indigo
      iconKey: 'education',
    ),
    CategoryItem(
      name: 'Travel',
      icon: Icons.flight_takeoff_rounded,
      color: Color(0xFF0EA5E9), // Sky Blue
      iconKey: 'travel',
    ),
    CategoryItem(
      name: 'Other Expense',
      icon: Icons.more_horiz_rounded,
      color: Color(0xFF6B7280), // Gray
      iconKey: 'other_expense',
    ),
  ];

  /// Predefined income categories.
  static const List<CategoryItem> defaultIncomeCategories = [
    CategoryItem(
      name: 'Salary',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF059669), // Green
      iconKey: 'salary',
    ),
    CategoryItem(
      name: 'Freelance & Work',
      icon: Icons.laptop_mac_rounded,
      color: Color(0xFF2563EB), // Royal Blue
      iconKey: 'work',
    ),
    CategoryItem(
      name: 'Investments',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF7C3AED), // Violet
      iconKey: 'investments',
    ),
    CategoryItem(
      name: 'Gifts & Awards',
      icon: Icons.card_giftcard_rounded,
      color: Color(0xFFDB2777), // Pink
      iconKey: 'gifts',
    ),
    CategoryItem(
      name: 'Rental Income',
      icon: Icons.home_work_rounded,
      color: Color(0xFFD97706), // Amber
      iconKey: 'rental',
    ),
    CategoryItem(
      name: 'Other Income',
      icon: Icons.attach_money_rounded,
      color: Color(0xFF4B5563), // Slate
      iconKey: 'other_income',
    ),
  ];

  /// Active list including custom categories.
  static List<CategoryItem> customExpenseCategories = [];
  static List<CategoryItem> customIncomeCategories = [];

  static List<CategoryItem> get expenseCategories => [
        ...defaultExpenseCategories,
        ...customExpenseCategories,
      ];

  static List<CategoryItem> get incomeCategories => [
        ...defaultIncomeCategories,
        ...customIncomeCategories,
      ];

  /// Retrieves list of categories according to transaction type.
  static List<CategoryItem> getCategoriesForType(TransactionType type) {
    return type == TransactionType.income ? incomeCategories : expenseCategories;
  }

  /// Finds category metadata or returns a fallback item.
  static CategoryItem getCategoryItem(String name, TransactionType type) {
    final list = getCategoriesForType(type);
    for (final item in list) {
      if (item.name.toLowerCase() == name.toLowerCase()) {
        return item;
      }
    }
    final otherList =
        type == TransactionType.income ? expenseCategories : incomeCategories;
    for (final item in otherList) {
      if (item.name.toLowerCase() == name.toLowerCase()) {
        return item;
      }
    }
    return CategoryItem(
      name: name,
      icon: type == TransactionType.income
          ? Icons.arrow_downward_rounded
          : Icons.arrow_upward_rounded,
      color: type == TransactionType.income
          ? const Color(0xFF10B981)
          : const Color(0xFFEF4444),
      iconKey: type == TransactionType.income ? 'arrow_down' : 'arrow_up',
    );
  }
}
