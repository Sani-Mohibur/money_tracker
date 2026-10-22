import 'package:flutter/material.dart';
import '../models/transaction.dart';

/// Information about a transaction category.
class CategoryItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isCustom;
  final String iconKey;
  final bool isArchived;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isCustom = false,
    this.iconKey = 'category',
    this.isArchived = false,
  });

  CategoryItem copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    bool? isCustom,
    String? iconKey,
    bool? isArchived,
  }) {
    return CategoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isCustom: isCustom ?? this.isCustom,
      iconKey: iconKey ?? this.iconKey,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconKey': iconKey,
      'colorValue': color.toARGB32(),
      'isCustom': isCustom,
      'isArchived': isArchived,
    };
  }

  factory CategoryItem.fromMap(Map<String, dynamic> map) {
    final key = map['iconKey'] as String? ?? 'category';
    final name = map['name'] as String? ?? 'Custom';
    final generatedId = map['id'] as String? ??
        name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');

    return CategoryItem(
      id: generatedId,
      name: name,
      icon: getIconByKey(key),
      color: Color(map['colorValue'] as int? ?? 0xFF6B7280),
      isCustom: map['isCustom'] as bool? ?? false,
      iconKey: key,
      isArchived: map['isArchived'] as bool? ?? false,
    );
  }

  static IconData getIconByKey(String key) {
    switch (key) {
      // Default expense icons
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'groceries':
        return Icons.shopping_cart_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'bills':
        return Icons.receipt_long_rounded;
      case 'entertainment':
        return Icons.movie_filter_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'health':
        return Icons.medical_services_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'travel':
        return Icons.flight_takeoff_rounded;
      case 'other_expense':
        return Icons.more_horiz_rounded;
      case 'transfer_fees':
        return Icons.price_change_rounded;

      // Default income icons
      case 'salary':
        return Icons.account_balance_wallet_rounded;
      case 'work':
        return Icons.laptop_mac_rounded;
      case 'investments':
        return Icons.trending_up_rounded;
      case 'gifts':
        return Icons.card_giftcard_rounded;
      case 'rental':
        return Icons.home_work_rounded;
      case 'other_income':
        return Icons.attach_money_rounded;

      // Custom icon keys
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
      case 'swap_horiz':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  static const List<MapEntry<String, IconData>> availableIcons = [
    MapEntry('shopping_bag', Icons.shopping_bag_rounded),
    MapEntry('groceries', Icons.shopping_cart_rounded),
    MapEntry('restaurant', Icons.restaurant_rounded),
    MapEntry('cafe', Icons.local_cafe_rounded),
    MapEntry('bills', Icons.receipt_long_rounded),
    MapEntry('transfer_fees', Icons.price_change_rounded),
    MapEntry('transport', Icons.directions_car_rounded),
    MapEntry('car', Icons.car_rental_rounded),
    MapEntry('travel', Icons.flight_takeoff_rounded),
    MapEntry('entertainment', Icons.movie_filter_rounded),
    MapEntry('health', Icons.medical_services_rounded),
    MapEntry('education', Icons.school_rounded),
    MapEntry('fitness', Icons.fitness_center_rounded),
    MapEntry('pets', Icons.pets_rounded),
    MapEntry('book', Icons.book_rounded),
    MapEntry('gaming', Icons.sports_esports_rounded),
    MapEntry('celebration', Icons.celebration_rounded),
    MapEntry('salary', Icons.account_balance_wallet_rounded),
    MapEntry('work', Icons.laptop_mac_rounded),
    MapEntry('investments', Icons.trending_up_rounded),
    MapEntry('savings', Icons.savings_rounded),
    MapEntry('gifts', Icons.card_giftcard_rounded),
    MapEntry('rental', Icons.home_work_rounded),
    MapEntry('payments', Icons.payments_rounded),
    MapEntry('swap_horiz', Icons.swap_horiz_rounded),
    MapEntry('other_expense', Icons.more_horiz_rounded),
  ];

  static const List<Color> availableColors = [
    Color(0xFFF97316), // Orange
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Blue
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFF6366F1), // Indigo
    Color(0xFF0EA5E9), // Sky Blue
    Color(0xFFD97706), // Amber
    Color(0xFF64748B), // Slate
    Color(0xFF4B5563), // Gray
  ];
}

class AppCategories {
  /// Predefined expense categories with Transfer Fees included.
  static const List<CategoryItem> defaultExpenseCategories = [
    CategoryItem(
      id: 'food_dining',
      name: 'Food & Dining',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFF97316), // Orange
      iconKey: 'restaurant',
    ),
    CategoryItem(
      id: 'groceries',
      name: 'Groceries',
      icon: Icons.shopping_cart_rounded,
      color: Color(0xFF10B981), // Emerald
      iconKey: 'groceries',
    ),
    CategoryItem(
      id: 'transport',
      name: 'Transport',
      icon: Icons.directions_car_rounded,
      color: Color(0xFF3B82F6), // Blue
      iconKey: 'transport',
    ),
    CategoryItem(
      id: 'bills_utilities',
      name: 'Bills & Utilities',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFEF4444), // Red
      iconKey: 'bills',
    ),
    CategoryItem(
      id: 'transfer_fees',
      name: 'Transfer Fees',
      icon: Icons.price_change_rounded,
      color: Color(0xFF64748B), // Slate
      iconKey: 'transfer_fees',
    ),
    CategoryItem(
      id: 'entertainment',
      name: 'Entertainment',
      icon: Icons.movie_filter_rounded,
      color: Color(0xFF8B5CF6), // Purple
      iconKey: 'entertainment',
    ),
    CategoryItem(
      id: 'shopping',
      name: 'Shopping',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFFEC4899), // Pink
      iconKey: 'shopping',
    ),
    CategoryItem(
      id: 'health_medical',
      name: 'Health & Medical',
      icon: Icons.medical_services_rounded,
      color: Color(0xFF14B8A6), // Teal
      iconKey: 'health',
    ),
    CategoryItem(
      id: 'education',
      name: 'Education',
      icon: Icons.school_rounded,
      color: Color(0xFF6366F1), // Indigo
      iconKey: 'education',
    ),
    CategoryItem(
      id: 'travel',
      name: 'Travel',
      icon: Icons.flight_takeoff_rounded,
      color: Color(0xFF0EA5E9), // Sky Blue
      iconKey: 'travel',
    ),
    CategoryItem(
      id: 'other_expense',
      name: 'Other Expense',
      icon: Icons.more_horiz_rounded,
      color: Color(0xFF6B7280), // Gray
      iconKey: 'other_expense',
    ),
  ];

  /// Predefined income categories.
  static const List<CategoryItem> defaultIncomeCategories = [
    CategoryItem(
      id: 'salary',
      name: 'Salary',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF059669), // Green
      iconKey: 'salary',
    ),
    CategoryItem(
      id: 'freelance_work',
      name: 'Freelance & Work',
      icon: Icons.laptop_mac_rounded,
      color: Color(0xFF2563EB), // Royal Blue
      iconKey: 'work',
    ),
    CategoryItem(
      id: 'investments',
      name: 'Investments',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF7C3AED), // Violet
      iconKey: 'investments',
    ),
    CategoryItem(
      id: 'gifts_awards',
      name: 'Gifts & Awards',
      icon: Icons.card_giftcard_rounded,
      color: Color(0xFFDB2777), // Pink
      iconKey: 'gifts',
    ),
    CategoryItem(
      id: 'rental_income',
      name: 'Rental Income',
      icon: Icons.home_work_rounded,
      color: Color(0xFFD97706), // Amber
      iconKey: 'rental',
    ),
    CategoryItem(
      id: 'other_income',
      name: 'Other Income',
      icon: Icons.attach_money_rounded,
      color: Color(0xFF4B5563), // Slate
      iconKey: 'other_income',
    ),
  ];

  /// Active lists holding all user categories.
  static List<CategoryItem> _expenseCategories = List.from(defaultExpenseCategories);
  static List<CategoryItem> _incomeCategories = List.from(defaultIncomeCategories);

  /// Backwards compatible accessors for custom categories
  static List<CategoryItem> customExpenseCategories = [];
  static List<CategoryItem> customIncomeCategories = [];

  static List<CategoryItem> get allExpenseCategories => _expenseCategories;
  static List<CategoryItem> get allIncomeCategories => _incomeCategories;

  /// Returns active (non-archived) expense categories for transaction selection
  static List<CategoryItem> get expenseCategories =>
      _expenseCategories.where((c) => !c.isArchived).toList();

  /// Returns active (non-archived) income categories for transaction selection
  static List<CategoryItem> get incomeCategories =>
      _incomeCategories.where((c) => !c.isArchived).toList();

  /// Sets the active expense categories list
  static void setExpenseCategories(List<CategoryItem> list) {
    _expenseCategories = List.from(list);
  }

  /// Sets the active income categories list
  static void setIncomeCategories(List<CategoryItem> list) {
    _incomeCategories = List.from(list);
  }

  /// Resets categories back to defaults (for tests and teardown)
  static void reset() {
    _expenseCategories = List.from(defaultExpenseCategories);
    _incomeCategories = List.from(defaultIncomeCategories);
    customExpenseCategories = [];
    customIncomeCategories = [];
  }

  /// Retrieves list of active categories according to transaction type.
  static List<CategoryItem> getCategoriesForType(TransactionType type) {
    return type == TransactionType.income ? incomeCategories : expenseCategories;
  }

  /// Retrieves all categories (including archived) according to transaction type.
  static List<CategoryItem> getAllCategoriesForType(TransactionType type) {
    return type == TransactionType.income ? _incomeCategories : _expenseCategories;
  }

  /// Finds category metadata or returns a fallback item.
  static CategoryItem getCategoryItem(String name, TransactionType type) {
    final list = getAllCategoriesForType(type);
    for (final item in list) {
      if (item.name.toLowerCase() == name.toLowerCase()) {
        return item;
      }
    }
    final otherList =
        type == TransactionType.income ? _expenseCategories : _incomeCategories;
    for (final item in otherList) {
      if (item.name.toLowerCase() == name.toLowerCase()) {
        return item;
      }
    }
    return CategoryItem(
      id: name.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
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
