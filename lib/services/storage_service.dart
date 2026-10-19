import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/categories.dart';
import '../models/transaction.dart';

/// Service responsible for persisting and loading transactions locally.
class StorageService {
  static const String _transactionsKey = 'saved_transactions_v1';
  static const String _firstLaunchKey = 'has_launched_before';
  static const String _customCategoriesExpenseKey = 'custom_categories_expense_v1';
  static const String _customCategoriesIncomeKey = 'custom_categories_income_v1';
  static const String _themeModeKey = 'pref_theme_mode_v1';

  /// Loads all transactions from local persistent storage.
  /// Preserves existing user data.
  Future<List<Transaction>> loadTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final bool hasLaunched = prefs.getBool(_firstLaunchKey) ?? false;
      if (!hasLaunched) {
        final sampleList = _getSampleTransactions();
        try {
          await saveTransactions(sampleList);
          await prefs.setBool(_firstLaunchKey, true);
        } catch (e) {
          debugPrint('Error saving initial first-launch flag: $e');
        }
        return sampleList;
      }

      final String? jsonString = prefs.getString(_transactionsKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> decodedList = json.decode(jsonString) as List<dynamic>;
      final transactions = decodedList
          .map((item) => Transaction.fromMap(item as Map<String, dynamic>))
          .toList();

      // Sort newest first by default
      transactions.sort((a, b) => b.date.compareTo(a.date));
      return transactions;
    } catch (e, stack) {
      debugPrint('Error loading transactions: $e\n$stack');
      return [];
    }
  }

  /// Persists the list of transactions to SharedPreferences as JSON.
  Future<bool> saveTransactions(List<Transaction> transactions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> mapList =
          transactions.map((t) => t.toMap()).toList();
      final String jsonString = json.encode(mapList);
      return await prefs.setString(_transactionsKey, jsonString);
    } catch (e, stack) {
      debugPrint('Error saving transactions: $e\n$stack');
      return false;
    }
  }

  /// Adds a single transaction and saves.
  Future<List<Transaction>> addTransaction(Transaction transaction) async {
    final currentList = await loadTransactions();
    final updatedList = [transaction, ...currentList];
    await saveTransactions(updatedList);
    return updatedList;
  }

  /// Updates an existing transaction by matching id and saves.
  Future<List<Transaction>> updateTransaction(Transaction transaction) async {
    final currentList = await loadTransactions();
    final updatedList = currentList.map((item) {
      return item.id == transaction.id ? transaction : item;
    }).toList();
    // Maintain chronological sort
    updatedList.sort((a, b) => b.date.compareTo(a.date));
    await saveTransactions(updatedList);
    return updatedList;
  }

  /// Deletes a transaction by ID and updates storage.
  Future<List<Transaction>> deleteTransaction(String id) async {
    final currentList = await loadTransactions();
    final updatedList = currentList.where((item) => item.id != id).toList();
    await saveTransactions(updatedList);
    return updatedList;
  }

  /// Clears all transactions from storage.
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_transactionsKey);
    } catch (e) {
      debugPrint('Error clearing transactions: $e');
    }
  }

  /// Re-seeds demo sample transactions.
  Future<List<Transaction>> resetSampleData() async {
    final samples = _getSampleTransactions();
    await saveTransactions(samples);
    return samples;
  }

  /// Loads custom user categories from local storage.
  Future<void> loadCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expenseJson = prefs.getString(_customCategoriesExpenseKey);
      final incomeJson = prefs.getString(_customCategoriesIncomeKey);

      if (expenseJson != null) {
        try {
          final List<dynamic> list = json.decode(expenseJson);
          AppCategories.customExpenseCategories = list
              .map((item) => CategoryItem.fromMap(item as Map<String, dynamic>))
              .toList();
        } catch (e) {
          debugPrint('Error parsing custom expense categories: $e');
        }
      }

      if (incomeJson != null) {
        try {
          final List<dynamic> list = json.decode(incomeJson);
          AppCategories.customIncomeCategories = list
              .map((item) => CategoryItem.fromMap(item as Map<String, dynamic>))
              .toList();
        } catch (e) {
          debugPrint('Error parsing custom income categories: $e');
        }
      }
    } catch (e, stack) {
      debugPrint('Error loading custom categories: $e\n$stack');
    }
  }

  /// Adds a custom category and persists it.
  Future<void> addCustomCategory(CategoryItem item, TransactionType type) async {
    try {
      if (type == TransactionType.income) {
        AppCategories.customIncomeCategories.add(item);
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = json.encode(
          AppCategories.customIncomeCategories.map((c) => c.toMap()).toList(),
        );
        await prefs.setString(_customCategoriesIncomeKey, jsonStr);
      } else {
        AppCategories.customExpenseCategories.add(item);
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = json.encode(
          AppCategories.customExpenseCategories.map((c) => c.toMap()).toList(),
        );
        await prefs.setString(_customCategoriesExpenseKey, jsonStr);
      }
    } catch (e) {
      debugPrint('Error saving custom category: $e');
    }
  }

  /// Deletes a custom category and persists changes.
  Future<void> deleteCustomCategory(String name, TransactionType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (type == TransactionType.income) {
        AppCategories.customIncomeCategories
            .removeWhere((c) => c.name.toLowerCase() == name.toLowerCase());
        final jsonStr = json.encode(
          AppCategories.customIncomeCategories.map((c) => c.toMap()).toList(),
        );
        await prefs.setString(_customCategoriesIncomeKey, jsonStr);
      } else {
        AppCategories.customExpenseCategories
            .removeWhere((c) => c.name.toLowerCase() == name.toLowerCase());
        final jsonStr = json.encode(
          AppCategories.customExpenseCategories.map((c) => c.toMap()).toList(),
        );
        await prefs.setString(_customCategoriesExpenseKey, jsonStr);
      }
    } catch (e) {
      debugPrint('Error deleting custom category: $e');
    }
  }

  /// Loads saved theme mode (light, dark, system).
  Future<ThemeMode> loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_themeModeKey);
      switch (modeStr) {
        case 'dark':
          return ThemeMode.dark;
        case 'light':
          return ThemeMode.light;
        default:
          return ThemeMode.system;
      }
    } catch (e) {
      debugPrint('Error loading theme mode: $e');
      return ThemeMode.system;
    }
  }

  /// Persists theme mode.
  Future<void> saveThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  /// Initial beginner-friendly sample transactions.
  static List<Transaction> _getSampleTransactions() {
    final now = DateTime.now();
    return [
      Transaction(
        id: 'sample-1',
        title: 'Monthly Salary',
        amount: 3500.00,
        type: TransactionType.income,
        category: 'Salary',
        date: now.subtract(const Duration(days: 2)),
        note: 'Tech Corp monthly payroll',
        currency: 'USD',
      ),
      Transaction(
        id: 'sample-2',
        title: 'Grocery Supermarket',
        amount: 142.50,
        type: TransactionType.expense,
        category: 'Groceries',
        date: now.subtract(const Duration(days: 1)),
        note: 'Weekly essentials & fresh veggies',
        currency: 'USD',
      ),
      Transaction(
        id: 'sample-3',
        title: 'Freelance Design',
        amount: 450.00,
        type: TransactionType.income,
        category: 'Freelance & Work',
        date: now.subtract(const Duration(hours: 14)),
        note: 'Logo & brand guideline project',
        currency: 'USD',
      ),
      Transaction(
        id: 'sample-4',
        title: 'Italian Bistro Dinner',
        amount: 68.00,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: now.subtract(const Duration(hours: 5)),
        note: 'Dinner with college friends',
        currency: 'USD',
      ),
      Transaction(
        id: 'sample-5',
        title: 'Electric & Internet Bill',
        amount: 115.00,
        type: TransactionType.expense,
        category: 'Bills & Utilities',
        date: now.subtract(const Duration(hours: 2)),
        note: 'High-speed fiber & electricity',
        currency: 'USD',
      ),
    ];
  }
}
