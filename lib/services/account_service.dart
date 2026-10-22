import 'dart:math';
import '../models/account_allocation.dart';
import '../models/account_transfer.dart';
import '../models/currency.dart';
import '../models/money_account.dart';
import '../models/transaction.dart';
import 'currency_service.dart';

/// Accounting and balance calculation service for Money Accounts.
/// Ensures consistent financial accounting, unassigned tracking,
/// reconciliation difference calculations, and funds validation.
class AccountService {
  final CurrencyService _currencyService;

  AccountService([CurrencyService? currencyService])
      : _currencyService = currencyService ?? CurrencyService();

  /// Calculates the current balance of a specific account in its native currency.
  /// Includes transaction allocations and account transfers.
  double calculateAccountBalance(
    MoneyAccount account,
    List<Transaction> transactions,
    List<AccountTransfer> transfers,
  ) {
    double balance = 0.0;

    // 1. Transaction allocations
    for (final tx in transactions) {
      for (final alloc in tx.allocations) {
        if (alloc.accountId == account.id && alloc.amount > 0) {
          final converted = _currencyService.convert(
            alloc.amount,
            tx.currency,
            account.currency,
          );
          if (tx.isIncome) {
            balance += converted;
          } else if (tx.isExpense) {
            balance -= converted;
          }
        }
      }
    }

    // 2. Transfers between accounts
    for (final transfer in transfers) {
      if (transfer.fromAccountId == account.id) {
        balance -= transfer.amount;
      }
      if (transfer.toAccountId == account.id) {
        balance += transfer.toAmount;
      }
    }

    // Decimal rounding consistent with account currency
    final currency = AppCurrency.fromCode(account.currency);
    return roundCurrency(balance, currency.decimalDigits);
  }

  /// Calculates balances for all accounts at once.
  Map<String, double> calculateAllBalances(
    List<MoneyAccount> accounts,
    List<Transaction> transactions,
    List<AccountTransfer> transfers,
  ) {
    final Map<String, double> result = {};
    for (final account in accounts) {
      result[account.id] = calculateAccountBalance(
        account,
        transactions,
        transfers,
      );
    }
    return result;
  }

  /// Calculates available funds for an account when creating or editing a transaction.
  /// When editing [existingTransaction], reverses its old allocation effect so the user
  /// doesn't get blocked by funds tied up in the transaction being updated.
  double getAvailableFundsForTransaction({
    required MoneyAccount account,
    required double currentBalance,
    Transaction? existingTransaction,
  }) {
    double available = currentBalance;

    if (existingTransaction != null) {
      for (final alloc in existingTransaction.allocations) {
        if (alloc.accountId == account.id && alloc.amount > 0) {
          final converted = _currencyService.convert(
            alloc.amount,
            existingTransaction.currency,
            account.currency,
          );
          if (existingTransaction.isExpense) {
            // Reversing an expense frees up the money
            available += converted;
          } else if (existingTransaction.isIncome) {
            // Reversing an income deducts the money
            available -= converted;
          }
        }
      }
    }

    final currency = AppCurrency.fromCode(account.currency);
    return roundCurrency(available, currency.decimalDigits);
  }

  /// Checks if an account has any associated transaction history or transfers.
  bool hasAccountHistory(
    String accountId,
    List<Transaction> transactions,
    List<AccountTransfer> transfers,
  ) {
    final hasTx = transactions.any(
      (tx) => tx.allocations.any((a) => a.accountId == accountId),
    );
    if (hasTx) return true;

    final hasTf = transfers.any(
      (t) => t.fromAccountId == accountId || t.toAccountId == accountId,
    );
    return hasTf;
  }

  /// Calculates overall financial balance from all transactions in default currency.
  double calculateOverallBalance(
    List<Transaction> transactions, [
    String? targetCurrencyCode,
  ]) {
    final targetCurrency = targetCurrencyCode ?? _currencyService.defaultCurrencyCode;
    double total = 0.0;

    for (final tx in transactions) {
      final converted = _currencyService.convert(
        tx.amount,
        tx.currency,
        targetCurrency,
      );
      if (tx.isIncome) {
        total += converted;
      } else {
        total -= converted;
      }
    }

    final currency = AppCurrency.fromCode(targetCurrency);
    return roundCurrency(total, currency.decimalDigits);
  }

  /// Calculates total active accounts balance converted into target currency.
  double calculateCombinedActiveAccountsBalance(
    List<MoneyAccount> accounts,
    Map<String, double> accountBalances, [
    String? targetCurrencyCode,
  ]) {
    final targetCurrency = targetCurrencyCode ?? _currencyService.defaultCurrencyCode;
    double combined = 0.0;

    for (final account in accounts) {
      if (!account.isArchived) {
        final bal = accountBalances[account.id] ?? 0.0;
        combined += _currencyService.convert(
          bal,
          account.currency,
          targetCurrency,
        );
      }
    }

    final currency = AppCurrency.fromCode(targetCurrency);
    return roundCurrency(combined, currency.decimalDigits);
  }

  /// Calculates total unassigned income converted to target currency.
  double calculateTotalUnassignedIncome(
    List<Transaction> transactions, [
    String? targetCurrencyCode,
  ]) {
    final targetCurrency = targetCurrencyCode ?? _currencyService.defaultCurrencyCode;
    double unassigned = 0.0;

    for (final tx in transactions) {
      if (tx.isIncome && tx.hasUnassigned) {
        unassigned += _currencyService.convert(
          tx.unassignedAmount,
          tx.currency,
          targetCurrency,
        );
      }
    }

    final currency = AppCurrency.fromCode(targetCurrency);
    return roundCurrency(unassigned, currency.decimalDigits);
  }

  /// Calculates total unassigned expense converted to target currency.
  double calculateTotalUnassignedExpense(
    List<Transaction> transactions, [
    String? targetCurrencyCode,
  ]) {
    final targetCurrency = targetCurrencyCode ?? _currencyService.defaultCurrencyCode;
    double unassigned = 0.0;

    for (final tx in transactions) {
      if (tx.isExpense && tx.hasUnassigned) {
        unassigned += _currencyService.convert(
          tx.unassignedAmount,
          tx.currency,
          targetCurrency,
        );
      }
    }

    final currency = AppCurrency.fromCode(targetCurrency);
    return roundCurrency(unassigned, currency.decimalDigits);
  }

  /// Calculates the reconciliation difference:
  /// Reconciliation Difference = Overall Balance - Sum of Active Account Balances
  double calculateReconciliationDifference({
    required double overallBalance,
    required double combinedActiveAccountsBalance,
    String? targetCurrencyCode,
  }) {
    final diff = overallBalance - combinedActiveAccountsBalance;
    final targetCurrency = targetCurrencyCode ?? _currencyService.defaultCurrencyCode;
    final currency = AppCurrency.fromCode(targetCurrency);
    return roundCurrency(diff, currency.decimalDigits);
  }

  /// Validates an allocation for a transaction.
  /// Returns an error string if invalid, or null if valid.
  String? validateAllocation({
    required AccountAllocation allocation,
    required MoneyAccount account,
    required TransactionType type,
    required String transactionCurrency,
    required double availableAccountBalance,
    required double remainingTransactionAmountToAllocate,
  }) {
    if (allocation.amount <= 0.000001) {
      return 'Amount must be greater than zero.';
    }

    if (allocation.amount > remainingTransactionAmountToAllocate + 0.0001) {
      return 'Allocation exceeds transaction amount.';
    }

    if (type == TransactionType.expense) {
      final amountInAccountCurrency = _currencyService.convert(
        allocation.amount,
        transactionCurrency,
        account.currency,
      );

      if (amountInAccountCurrency > availableAccountBalance + 0.0001) {
        return 'Insufficient funds in ${account.name} (Available: ${availableAccountBalance.toStringAsFixed(2)} ${account.currency}).';
      }
    }

    return null;
  }

  /// Calculates available funds for an account when creating or editing a transfer.
  /// When editing [existingTransfer], reverses its previous effects so funds are not falsely locked.
  double getAvailableFundsForTransfer({
    required MoneyAccount account,
    required double currentBalance,
    AccountTransfer? existingTransfer,
  }) {
    double available = currentBalance;
    if (existingTransfer != null) {
      if (existingTransfer.fromAccountId == account.id) {
        available += (existingTransfer.amount + existingTransfer.fee);
      }
      if (existingTransfer.toAccountId == account.id) {
        available -= existingTransfer.toAmount;
      }
    }
    final currency = AppCurrency.fromCode(account.currency);
    return roundCurrency(available, currency.decimalDigits);
  }

  /// Validates account transfer parameters, including optional transfer fee.
  String? validateTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    double fee = 0.0,
    required double fromAccountBalance,
    required String fromAccountCurrency,
  }) {
    if (fromAccountId.isEmpty || toAccountId.isEmpty) {
      return 'Please select both source and destination accounts.';
    }
    if (fromAccountId == toAccountId) {
      return 'Source and destination accounts must be different.';
    }
    if (amount <= 0) {
      return 'Transfer amount must be greater than zero.';
    }
    if (fee < 0) {
      return 'Transfer fee cannot be negative.';
    }
    final totalRequired = amount + fee;
    if (totalRequired > fromAccountBalance + 0.0001) {
      return 'Insufficient funds in source account (Required: ${totalRequired.toStringAsFixed(2)} $fromAccountCurrency, Available: ${fromAccountBalance.toStringAsFixed(2)} $fromAccountCurrency).';
    }
    return null;
  }

  /// Case-insensitive uniqueness check for account name.
  bool isAccountNameUnique(
    String name,
    List<MoneyAccount> existingAccounts, [
    String? excludeAccountId,
  ]) {
    final clean = name.trim().toLowerCase();
    return !existingAccounts.any(
      (a) => a.id != excludeAccountId && a.name.trim().toLowerCase() == clean,
    );
  }

  /// Rounding helper for currency amounts.
  static double roundCurrency(double val, int decimals) {
    if (decimals <= 0) return val.roundToDouble();
    final factor = pow(10, decimals);
    return (val * factor).round() / factor;
  }
}
