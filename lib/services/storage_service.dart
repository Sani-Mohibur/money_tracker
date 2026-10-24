import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/categories.dart';
import '../models/account_transfer.dart';
import '../models/loan.dart';
import '../models/loan_repayment.dart';
import '../models/money_account.dart';
import '../models/transaction.dart';

/// Service responsible for persisting and loading transactions, accounts,
/// transfers, categories, and user preferences locally using SharedPreferences.
class StorageService {
  static const String _transactionsKey = 'saved_transactions_v1';
  static const String _firstLaunchKey = 'has_launched_before';
  static const String _customCategoriesExpenseKey = 'custom_categories_expense_v1';
  static const String _customCategoriesIncomeKey = 'custom_categories_income_v1';
  static const String _categoriesExpenseKey = 'categories_expense_v3';
  static const String _categoriesIncomeKey = 'categories_income_v3';
  static const String _themeModeKey = 'pref_theme_mode_v1';
  static const String _moneyAccountsEnabledKey = 'pref_money_accounts_enabled';
  static const String _accountsKey = 'saved_accounts_v1';
  static const String _accountTransfersKey = 'saved_account_transfers_v1';
  static const String _loansKey = 'saved_loans_v1';
  static const String _loanRepaymentsKey = 'saved_loan_repayments_v1';

  /// Loads all transactions from local persistent storage.
  /// Preserves existing user data. Existing records without allocations
  /// default to empty allocations safely.
  Future<List<Transaction>> loadTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final bool hasLaunched = prefs.getBool(_firstLaunchKey) ?? false;
      final String? jsonString = prefs.getString(_transactionsKey);
      if (!hasLaunched && (jsonString == null || jsonString.isEmpty)) {
        final sampleList = _getSampleTransactions();
        try {
          await saveTransactions(sampleList);
          await prefs.setBool(_firstLaunchKey, true);
        } catch (e) {
          debugPrint('Error saving initial first-launch flag: $e');
        }
        return sampleList;
      }

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
      await prefs.setBool(_firstLaunchKey, true);
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

  // =========================================================================
  // MONEY ACCOUNTS FEATURE TOGGLE & PERSISTENCE
  // =========================================================================

  /// Loads whether Money Accounts feature is enabled.
  /// Defaults to false for new installations.
  Future<bool> isMoneyAccountsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_moneyAccountsEnabledKey) ?? false;
    } catch (e) {
      debugPrint('Error loading money accounts enabled status: $e');
      return false;
    }
  }

  /// Persists whether Money Accounts feature is enabled.
  /// Never deletes accounts or allocations when disabled.
  Future<void> setMoneyAccountsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_moneyAccountsEnabledKey, enabled);
    } catch (e) {
      debugPrint('Error saving money accounts enabled status: $e');
    }
  }

  /// Loads all saved accounts.
  Future<List<MoneyAccount>> loadAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_accountsKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      final List<dynamic> decodedList = json.decode(jsonString) as List<dynamic>;
      final accounts = decodedList
          .map((item) => MoneyAccount.fromMap(item as Map<String, dynamic>))
          .toList();
      return accounts;
    } catch (e, stack) {
      debugPrint('Error loading accounts: $e\n$stack');
      return [];
    }
  }

  /// Persists accounts list to storage.
  Future<bool> saveAccounts(List<MoneyAccount> accounts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> mapList =
          accounts.map((a) => a.toMap()).toList();
      final String jsonString = json.encode(mapList);
      return await prefs.setString(_accountsKey, jsonString);
    } catch (e, stack) {
      debugPrint('Error saving accounts: $e\n$stack');
      return false;
    }
  }

  /// Adds a single money account.
  Future<List<MoneyAccount>> addAccount(MoneyAccount account) async {
    final current = await loadAccounts();
    final updated = [...current, account];
    await saveAccounts(updated);
    return updated;
  }

  /// Updates an existing money account.
  Future<List<MoneyAccount>> updateAccount(MoneyAccount account) async {
    final current = await loadAccounts();
    final updated = current.map((a) => a.id == account.id ? account : a).toList();
    await saveAccounts(updated);
    return updated;
  }

  /// Archives or unarchives an account.
  Future<List<MoneyAccount>> archiveAccount(String id, bool archive) async {
    final current = await loadAccounts();
    final updated = current.map((a) {
      if (a.id == id) {
        return a.copyWith(isArchived: archive);
      }
      return a;
    }).toList();
    await saveAccounts(updated);
    return updated;
  }

  /// Deletes an account (only safe when account has no history).
  Future<List<MoneyAccount>> deleteAccount(String id) async {
    final current = await loadAccounts();
    final updated = current.where((a) => a.id != id).toList();
    await saveAccounts(updated);
    return updated;
  }

  // =========================================================================
  // ACCOUNT TRANSFERS & ATOMIC TRANSFER FEES
  // =========================================================================

  /// Loads all recorded account transfers.
  Future<List<AccountTransfer>> loadTransfers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_accountTransfersKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      final List<dynamic> decodedList = json.decode(jsonString) as List<dynamic>;
      final transfers = decodedList
          .map((item) => AccountTransfer.fromMap(item as Map<String, dynamic>))
          .toList();
      transfers.sort((a, b) => b.date.compareTo(a.date));
      return transfers;
    } catch (e, stack) {
      debugPrint('Error loading transfers: $e\n$stack');
      return [];
    }
  }

  /// Persists account transfers list to storage.
  Future<bool> saveTransfers(List<AccountTransfer> transfers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> mapList =
          transfers.map((t) => t.toMap()).toList();
      final String jsonString = json.encode(mapList);
      return await prefs.setString(_accountTransfersKey, jsonString);
    } catch (e, stack) {
      debugPrint('Error saving transfers: $e\n$stack');
      return false;
    }
  }

  /// Adds a transfer record and updates storage.
  Future<List<AccountTransfer>> addTransfer(AccountTransfer transfer) async {
    final current = await loadTransfers();
    final updated = [transfer, ...current];
    await saveTransfers(updated);
    return updated;
  }

  /// Deletes a transfer record and updates storage.
  Future<List<AccountTransfer>> deleteTransfer(String id) async {
    final current = await loadTransfers();
    final updated = current.where((t) => t.id != id).toList();
    await saveTransfers(updated);
    return updated;
  }

  /// Atomically saves or updates an AccountTransfer together with its linked fee transaction.
  /// Prevents inconsistencies where a transfer exists without its fee transaction, or vice-versa.
  Future<void> saveTransferWithFee({
    required AccountTransfer transfer,
    Transaction? feeTransaction,
  }) async {
    final transfers = await loadTransfers();
    final transactions = await loadTransactions();

    // 1. Manage linked fee transaction in transactions list
    List<Transaction> updatedTransactions = List.from(transactions);
    final existingTf = transfers.where((t) => t.id == transfer.id).firstOrNull;
    final oldFeeTxId = existingTf?.feeTransactionId;

    if (feeTransaction != null) {
      if (oldFeeTxId != null && oldFeeTxId != feeTransaction.id) {
        updatedTransactions.removeWhere((t) => t.id == oldFeeTxId);
      }
      final existingTxIndex =
          updatedTransactions.indexWhere((t) => t.id == feeTransaction.id);
      if (existingTxIndex >= 0) {
        updatedTransactions[existingTxIndex] = feeTransaction;
      } else {
        updatedTransactions = [feeTransaction, ...updatedTransactions];
      }
    } else if (oldFeeTxId != null) {
      // Fee was changed to 0; remove the old fee transaction
      updatedTransactions.removeWhere((t) => t.id == oldFeeTxId);
    }

    // 2. Manage transfer record in transfers list
    List<AccountTransfer> updatedTransfers = List.from(transfers);
    final existingTfIndex =
        updatedTransfers.indexWhere((t) => t.id == transfer.id);
    if (existingTfIndex >= 0) {
      updatedTransfers[existingTfIndex] = transfer;
    } else {
      updatedTransfers = [transfer, ...updatedTransfers];
    }
    updatedTransfers.sort((a, b) => b.date.compareTo(a.date));

    // 3. Persist both atomically
    await saveTransactions(updatedTransactions);
    await saveTransfers(updatedTransfers);
  }

  /// Atomically deletes an AccountTransfer and removes its linked fee transaction if present.
  Future<void> deleteTransferWithFee(String transferId) async {
    final transfers = await loadTransfers();
    final transactions = await loadTransactions();

    final transferToDelete =
        transfers.where((t) => t.id == transferId).firstOrNull;

    final updatedTransfers = transfers.where((t) => t.id != transferId).toList();
    List<Transaction> updatedTransactions = transactions;

    if (transferToDelete != null && transferToDelete.feeTransactionId != null) {
      updatedTransactions = transactions
          .where((t) => t.id != transferToDelete.feeTransactionId)
          .toList();
    }

    await saveTransactions(updatedTransactions);
    await saveTransfers(updatedTransfers);
  }

  // =========================================================================
  // LOANS & LOAN REPAYMENTS PERSISTENCE
  // =========================================================================

  /// Loads all loans from persistent storage.
  Future<List<Loan>> loadLoans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_loansKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      final List<dynamic> decodedList = json.decode(jsonString) as List<dynamic>;
      final loans = decodedList
          .map((item) => Loan.fromMap(item as Map<String, dynamic>))
          .toList();
      loans.sort((a, b) => b.date.compareTo(a.date));
      return loans;
    } catch (e, stack) {
      debugPrint('Error loading loans: $e\n$stack');
      return [];
    }
  }

  /// Persists loans list to storage.
  Future<bool> saveLoans(List<Loan> loans) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> mapList =
          loans.map((l) => l.toMap()).toList();
      final String jsonString = json.encode(mapList);
      return await prefs.setString(_loansKey, jsonString);
    } catch (e, stack) {
      debugPrint('Error saving loans: $e\n$stack');
      return false;
    }
  }

  /// Adds a loan and updates storage.
  Future<List<Loan>> addLoan(Loan loan) async {
    final current = await loadLoans();
    final updated = [loan, ...current];
    updated.sort((a, b) => b.date.compareTo(a.date));
    await saveLoans(updated);
    return updated;
  }

  /// Updates an existing loan.
  Future<List<Loan>> updateLoan(Loan loan) async {
    final current = await loadLoans();
    final updated = current.map((l) => l.id == loan.id ? loan : l).toList();
    updated.sort((a, b) => b.date.compareTo(a.date));
    await saveLoans(updated);
    return updated;
  }

  /// Archives or unarchives a loan.
  Future<List<Loan>> archiveLoan(String id, bool archive) async {
    final current = await loadLoans();
    final updated = current.map((l) {
      if (l.id == id) {
        return l.copyWith(isArchived: archive);
      }
      return l;
    }).toList();
    await saveLoans(updated);
    return updated;
  }

  /// Loads all loan repayments, optionally filtered by loanId.
  Future<List<LoanRepayment>> loadLoanRepayments([String? loanId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_loanRepaymentsKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      final List<dynamic> decodedList = json.decode(jsonString) as List<dynamic>;
      var repayments = decodedList
          .map((item) => LoanRepayment.fromMap(item as Map<String, dynamic>))
          .toList();
      if (loanId != null && loanId.isNotEmpty) {
        repayments = repayments.where((r) => r.loanId == loanId).toList();
      }
      repayments.sort((a, b) => b.date.compareTo(a.date));
      return repayments;
    } catch (e, stack) {
      debugPrint('Error loading loan repayments: $e\n$stack');
      return [];
    }
  }

  /// Persists loan repayments list to storage.
  Future<bool> saveLoanRepayments(List<LoanRepayment> repayments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> mapList =
          repayments.map((r) => r.toMap()).toList();
      final String jsonString = json.encode(mapList);
      return await prefs.setString(_loanRepaymentsKey, jsonString);
    } catch (e, stack) {
      debugPrint('Error saving loan repayments: $e\n$stack');
      return false;
    }
  }

  /// Atomically saves or updates a LoanRepayment together with its linked interest expense transaction.
  /// Prevents inconsistencies where a repayment exists without its interest transaction, or vice-versa.
  Future<void> saveRepaymentWithInterest({
    required LoanRepayment repayment,
    Transaction? interestTransaction,
  }) async {
    final repayments = await loadLoanRepayments();
    final transactions = await loadTransactions();

    // 1. Manage linked interest transaction in transactions list
    List<Transaction> updatedTransactions = List.from(transactions);
    final existingRep = repayments.where((r) => r.id == repayment.id).firstOrNull;
    final oldInterestTxId = existingRep?.interestTransactionId;

    if (interestTransaction != null) {
      if (oldInterestTxId != null && oldInterestTxId != interestTransaction.id) {
        updatedTransactions.removeWhere((t) => t.id == oldInterestTxId);
      }
      final existingTxIndex =
          updatedTransactions.indexWhere((t) => t.id == interestTransaction.id);
      if (existingTxIndex >= 0) {
        updatedTransactions[existingTxIndex] = interestTransaction;
      } else {
        updatedTransactions = [interestTransaction, ...updatedTransactions];
      }
    } else if (oldInterestTxId != null) {
      // Interest was changed to 0; remove the old interest transaction
      updatedTransactions.removeWhere((t) => t.id == oldInterestTxId);
    }

    // 2. Manage repayment record in repayments list
    List<LoanRepayment> updatedRepayments = List.from(repayments);
    final existingRepIndex =
        updatedRepayments.indexWhere((r) => r.id == repayment.id);
    if (existingRepIndex >= 0) {
      updatedRepayments[existingRepIndex] = repayment;
    } else {
      updatedRepayments = [repayment, ...updatedRepayments];
    }
    updatedRepayments.sort((a, b) => b.date.compareTo(a.date));

    // 3. Persist both atomically
    await saveTransactions(updatedTransactions);
    await saveLoanRepayments(updatedRepayments);
  }

  /// Atomically deletes a LoanRepayment and removes its linked interest expense transaction.
  Future<void> deleteRepaymentWithInterest(String repaymentId) async {
    final repayments = await loadLoanRepayments();
    final transactions = await loadTransactions();

    final repaymentToDelete =
        repayments.where((r) => r.id == repaymentId).firstOrNull;

    final updatedRepayments =
        repayments.where((r) => r.id != repaymentId).toList();
    List<Transaction> updatedTransactions = transactions;

    if (repaymentToDelete != null &&
        repaymentToDelete.interestTransactionId != null) {
      updatedTransactions = transactions
          .where((t) => t.id != repaymentToDelete.interestTransactionId)
          .toList();
    }

    await saveTransactions(updatedTransactions);
    await saveLoanRepayments(updatedRepayments);
  }

  /// Atomically deletes a Loan and all its associated repayments and linked interest transactions.
  Future<void> deleteLoanWithRepayments(String loanId) async {
    final loans = await loadLoans();
    final repayments = await loadLoanRepayments();
    final transactions = await loadTransactions();

    final repaymentsToDelete = repayments.where((r) => r.loanId == loanId).toList();
    final interestTxIdsToDelete = repaymentsToDelete
        .map((r) => r.interestTransactionId)
        .whereType<String>()
        .toSet();

    final updatedLoans = loans.where((l) => l.id != loanId).toList();
    final updatedRepayments = repayments.where((r) => r.loanId != loanId).toList();
    final updatedTransactions = transactions
        .where((t) => !interestTxIdsToDelete.contains(t.id))
        .toList();

    await saveTransactions(updatedTransactions);
    await saveLoanRepayments(updatedRepayments);
    await saveLoans(updatedLoans);
  }

  // =========================================================================
  // CATEGORIES MANAGEMENT & PERSISTENCE
  // =========================================================================

  /// Loads all categories (both default and custom) from storage,
  /// ensuring "Transfer Fees" is present and no duplicates exist.
  Future<void> loadCustomCategories() async {
    await loadAllCategories();
  }

  /// Loads all categories for Expense and Income.
  Future<void> loadAllCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expenseJson = prefs.getString(_categoriesExpenseKey);
      final incomeJson = prefs.getString(_categoriesIncomeKey);

      // --- EXPENSE CATEGORIES ---
      List<CategoryItem> loadedExpense = [];
      if (expenseJson != null) {
        try {
          final List<dynamic> list = json.decode(expenseJson);
          loadedExpense = list
              .map((item) => CategoryItem.fromMap(item as Map<String, dynamic>))
              .toList();
        } catch (e) {
          debugPrint('Error parsing expense categories: $e');
        }
      }

      if (loadedExpense.isEmpty) {
        // Fallback or first launch: migrate from default + custom v1
        final v1Json = prefs.getString(_customCategoriesExpenseKey);
        List<CategoryItem> v1Custom = [];
        if (v1Json != null) {
          try {
            final List<dynamic> list = json.decode(v1Json);
            v1Custom = list
                .map((item) => CategoryItem.fromMap(item as Map<String, dynamic>))
                .toList();
          } catch (_) {}
        }
        loadedExpense = [
          ...AppCategories.defaultExpenseCategories,
          ...v1Custom,
        ];
      }

      // Ensure "Transfer Fees" is present without duplicates
      final hasTransferFees = loadedExpense.any(
        (c) => c.name.trim().toLowerCase() == 'transfer fees',
      );
      if (!hasTransferFees) {
        loadedExpense.insert(
          4.clamp(0, loadedExpense.length),
          const CategoryItem(
            id: 'transfer_fees',
            name: 'Transfer Fees',
            icon: Icons.price_change_rounded,
            color: Color(0xFF64748B),
            iconKey: 'transfer_fees',
          ),
        );
      }

      // Ensure "Loan Interest" is present without duplicates
      final hasLoanInterest = loadedExpense.any(
        (c) => c.name.trim().toLowerCase() == 'loan interest',
      );
      if (!hasLoanInterest) {
        loadedExpense.insert(
          5.clamp(0, loadedExpense.length),
          const CategoryItem(
            id: 'loan_interest',
            name: 'Loan Interest',
            icon: Icons.percent_rounded,
            color: Color(0xFFD97706),
            iconKey: 'loan_interest',
          ),
        );
      }

      AppCategories.setExpenseCategories(loadedExpense);
      await saveCategories(loadedExpense, TransactionType.expense);

      // --- INCOME CATEGORIES ---
      List<CategoryItem> loadedIncome = [];
      if (incomeJson != null) {
        try {
          final List<dynamic> list = json.decode(incomeJson);
          loadedIncome = list
              .map((item) => CategoryItem.fromMap(item as Map<String, dynamic>))
              .toList();
        } catch (e) {
          debugPrint('Error parsing income categories: $e');
        }
      }

      if (loadedIncome.isEmpty) {
        final v1IncomeJson = prefs.getString(_customCategoriesIncomeKey);
        List<CategoryItem> v1IncomeCustom = [];
        if (v1IncomeJson != null) {
          try {
            final List<dynamic> list = json.decode(v1IncomeJson);
            v1IncomeCustom = list
                .map((item) => CategoryItem.fromMap(item as Map<String, dynamic>))
                .toList();
          } catch (_) {}
        }
        loadedIncome = [
          ...AppCategories.defaultIncomeCategories,
          ...v1IncomeCustom,
        ];
      }

      AppCategories.setIncomeCategories(loadedIncome);
      await saveCategories(loadedIncome, TransactionType.income);
    } catch (e, stack) {
      debugPrint('Error loading all categories: $e\n$stack');
    }
  }

  /// Persists category list for a transaction type.
  Future<void> saveCategories(List<CategoryItem> categories, TransactionType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = type == TransactionType.income
          ? _categoriesIncomeKey
          : _categoriesExpenseKey;
      final jsonStr = json.encode(categories.map((c) => c.toMap()).toList());
      await prefs.setString(key, jsonStr);
    } catch (e) {
      debugPrint('Error saving categories: $e');
    }
  }

  /// Adds a category and persists it.
  Future<void> addCustomCategory(CategoryItem item, TransactionType type) async {
    await addCategory(item, type);
  }

  /// Adds a category to active list and persists it.
  Future<void> addCategory(CategoryItem item, TransactionType type) async {
    final list = type == TransactionType.income
        ? AppCategories.allIncomeCategories
        : AppCategories.allExpenseCategories;
    final updated = [...list, item];
    if (type == TransactionType.income) {
      AppCategories.setIncomeCategories(updated);
    } else {
      AppCategories.setExpenseCategories(updated);
    }
    await saveCategories(updated, type);
  }

  /// Updates an existing category (including name, icon, color).
  /// When a category is renamed, all historical transactions using [oldName]
  /// are automatically updated to [updatedItem.name] without altering any other details.
  Future<void> updateCategory({
    required String oldName,
    required CategoryItem updatedItem,
    required TransactionType type,
  }) async {
    final list = type == TransactionType.income
        ? AppCategories.allIncomeCategories
        : AppCategories.allExpenseCategories;

    final updatedCategories = list.map((c) {
      if (c.id == updatedItem.id ||
          c.name.trim().toLowerCase() == oldName.trim().toLowerCase()) {
        return updatedItem;
      }
      return c;
    }).toList();

    if (type == TransactionType.income) {
      AppCategories.setIncomeCategories(updatedCategories);
    } else {
      AppCategories.setExpenseCategories(updatedCategories);
    }
    await saveCategories(updatedCategories, type);

    // If renamed, update all matching transactions
    if (oldName.trim().toLowerCase() != updatedItem.name.trim().toLowerCase()) {
      final transactions = await loadTransactions();
      bool hasChanges = false;
      final updatedTxList = transactions.map((tx) {
        if (tx.category.trim().toLowerCase() == oldName.trim().toLowerCase() &&
            tx.type == type) {
          hasChanges = true;
          return tx.copyWith(category: updatedItem.name);
        }
        return tx;
      }).toList();

      if (hasChanges) {
        await saveTransactions(updatedTxList);
      }
    }
  }

  /// Deletes a custom category (backwards compatible).
  Future<void> deleteCustomCategory(String name, TransactionType type) async {
    await deleteCategory(categoryName: name, type: type);
  }

  /// Deletes or archives a category with safeguards for historical transactions.
  /// If [reassignToCategoryName] is provided, all transactions using [categoryName]
  /// are reallocated to [reassignToCategoryName] before deletion.
  Future<void> deleteCategory({
    required String categoryName,
    required TransactionType type,
    String? reassignToCategoryName,
    bool archiveOnly = false,
  }) async {
    // 1. Reassign transactions if requested
    if (reassignToCategoryName != null && reassignToCategoryName.isNotEmpty) {
      final transactions = await loadTransactions();
      bool hasChanges = false;
      final updatedTxList = transactions.map((tx) {
        if (tx.category.trim().toLowerCase() == categoryName.trim().toLowerCase() &&
            tx.type == type) {
          hasChanges = true;
          return tx.copyWith(category: reassignToCategoryName);
        }
        return tx;
      }).toList();

      if (hasChanges) {
        await saveTransactions(updatedTxList);
      }
    }

    // 2. Remove or archive the category
    final list = type == TransactionType.income
        ? AppCategories.allIncomeCategories
        : AppCategories.allExpenseCategories;

    List<CategoryItem> updatedCategories;
    if (archiveOnly) {
      updatedCategories = list.map((c) {
        if (c.name.trim().toLowerCase() == categoryName.trim().toLowerCase()) {
          return c.copyWith(isArchived: true);
        }
        return c;
      }).toList();
    } else {
      updatedCategories = list
          .where((c) => c.name.trim().toLowerCase() != categoryName.trim().toLowerCase())
          .toList();
    }

    if (type == TransactionType.income) {
      AppCategories.setIncomeCategories(updatedCategories);
    } else {
      AppCategories.setExpenseCategories(updatedCategories);
    }
    await saveCategories(updatedCategories, type);
  }

  // =========================================================================
  // THEME PERSISTENCE
  // =========================================================================

  /// Loads saved theme mode (light or dark).
  /// Defaults to light mode if not set or if legacy 'system' mode was stored.
  Future<ThemeMode> loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_themeModeKey);
      switch (modeStr) {
        case 'dark':
          return ThemeMode.dark;
        case 'light':
        default:
          return ThemeMode.light;
      }
    } catch (e) {
      debugPrint('Error loading theme mode: $e');
      return ThemeMode.light;
    }
  }

  /// Persists theme mode (light or dark).
  Future<void> saveThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
      await prefs.setString(_themeModeKey, savedMode.name);
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
