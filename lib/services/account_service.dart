import 'dart:math';
import '../models/account_allocation.dart';
import '../models/account_transfer.dart';
import '../models/currency.dart';
import '../models/loan.dart';
import '../models/loan_repayment.dart';
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
  /// Includes transaction allocations, account transfers, loan receipts, and loan repayments.
  double calculateAccountBalance(
    MoneyAccount account,
    List<Transaction> transactions,
    List<AccountTransfer> transfers, {
    List<Loan> loans = const [],
    List<LoanRepayment> repayments = const [],
  }) {
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

    // 3. Loan net proceeds allocations (credits account balance)
    for (final loan in loans) {
      for (final alloc in loan.allocations) {
        if (alloc.accountId == account.id && alloc.amount > 0) {
          final converted = _currencyService.convert(
            alloc.amount,
            loan.currency,
            account.currency,
          );
          balance += converted;
        }
      }
    }

    // 4. Loan repayments allocations (debits account balance)
    for (final repayment in repayments) {
      for (final alloc in repayment.allocations) {
        if (alloc.accountId == account.id && alloc.amount > 0) {
          final converted = _currencyService.convert(
            alloc.amount,
            repayment.currency,
            account.currency,
          );
          balance -= converted;
        }
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
    List<AccountTransfer> transfers, {
    List<Loan> loans = const [],
    List<LoanRepayment> repayments = const [],
  }) {
    final Map<String, double> result = {};
    for (final account in accounts) {
      result[account.id] = calculateAccountBalance(
        account,
        transactions,
        transfers,
        loans: loans,
        repayments: repayments,
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

  /// Checks if an account has any associated transaction history, transfers, or loan records.
  bool hasAccountHistory(
    String accountId,
    List<Transaction> transactions,
    List<AccountTransfer> transfers, {
    List<Loan> loans = const [],
    List<LoanRepayment> repayments = const [],
  }) {
    final hasTx = transactions.any(
      (tx) => tx.allocations.any((a) => a.accountId == accountId),
    );
    if (hasTx) return true;

    final hasTf = transfers.any(
      (t) => t.fromAccountId == accountId || t.toAccountId == accountId,
    );
    if (hasTf) return true;

    final hasLoan = loans.any(
      (l) => l.allocations.any((a) => a.accountId == accountId),
    );
    if (hasLoan) return true;

    final hasRepayment = repayments.any(
      (r) => r.allocations.any((a) => a.accountId == accountId),
    );
    return hasRepayment;
  }

  /// Calculates overall financial balance from all transactions, loans, and repayments in default currency.
  /// - Income transactions: +amount
  /// - Expense transactions (including loan interest): -amount
  /// - Loans net proceeds: +netAmountReceived
  /// - Repayments: -principalAmount
  /// (Total cash outflow of repayment equals principal + interest; interest is in transactions)
  double calculateOverallBalance(
    List<Transaction> transactions, [
    String? targetCurrencyCode,
    List<Loan> loans = const [],
    List<LoanRepayment> repayments = const [],
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

    for (final loan in loans) {
      final converted = _currencyService.convert(
        loan.netAmountReceived,
        loan.currency,
        targetCurrency,
      );
      total += converted;
    }

    for (final repayment in repayments) {
      final converted = _currencyService.convert(
        repayment.principalAmount,
        repayment.currency,
        targetCurrency,
      );
      total -= converted;
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

  /// Calculates available funds for an account when creating or editing a loan.
  /// When editing [existingLoan], reverses its previous proceeds credited to this account.
  double getAvailableFundsForLoan({
    required MoneyAccount account,
    required double currentBalance,
    Loan? existingLoan,
  }) {
    double available = currentBalance;
    if (existingLoan != null) {
      for (final alloc in existingLoan.allocations) {
        if (alloc.accountId == account.id && alloc.amount > 0) {
          final converted = _currencyService.convert(
            alloc.amount,
            existingLoan.currency,
            account.currency,
          );
          available -= converted;
        }
      }
    }
    final currency = AppCurrency.fromCode(account.currency);
    return roundCurrency(available, currency.decimalDigits);
  }

  /// Calculates available funds for an account when creating or editing a repayment.
  /// When editing [existingRepayment], reverses its previous debit to free up available funds.
  double getAvailableFundsForRepayment({
    required MoneyAccount account,
    required double currentBalance,
    LoanRepayment? existingRepayment,
  }) {
    double available = currentBalance;
    if (existingRepayment != null) {
      for (final alloc in existingRepayment.allocations) {
        if (alloc.accountId == account.id && alloc.amount > 0) {
          final converted = _currencyService.convert(
            alloc.amount,
            existingRepayment.currency,
            account.currency,
          );
          available += converted;
        }
      }
    }
    final currency = AppCurrency.fromCode(account.currency);
    return roundCurrency(available, currency.decimalDigits);
  }

  /// Outstanding principal of a specific loan in its native currency.
  double calculateOutstandingPrincipal(
    Loan loan,
    List<LoanRepayment> repayments,
  ) {
    final loanRepayments = repayments.where((r) => r.loanId == loan.id);
    final totalPrincipalRepaid = loanRepayments.fold(
      0.0,
      (sum, r) => sum + r.principalAmount,
    );
    final diff = loan.principal - totalPrincipalRepaid;
    final currency = AppCurrency.fromCode(loan.currency);
    final rounded = roundCurrency(diff, currency.decimalDigits);
    return rounded > 0.000001 ? rounded : 0.0;
  }

  /// Total principal repaid for a specific loan in its native currency.
  double calculateTotalPrincipalRepaid(
    Loan loan,
    List<LoanRepayment> repayments,
  ) {
    final loanRepayments = repayments.where((r) => r.loanId == loan.id);
    final total = loanRepayments.fold(0.0, (sum, r) => sum + r.principalAmount);
    final currency = AppCurrency.fromCode(loan.currency);
    return roundCurrency(total, currency.decimalDigits);
  }

  /// Total interest paid for a specific loan in its native currency.
  double calculateTotalInterestPaid(
    Loan loan,
    List<LoanRepayment> repayments,
  ) {
    final loanRepayments = repayments.where((r) => r.loanId == loan.id);
    final total = loanRepayments.fold(0.0, (sum, r) => sum + r.interestAmount);
    final currency = AppCurrency.fromCode(loan.currency);
    return roundCurrency(total, currency.decimalDigits);
  }

  /// Repayment progress percentage (0.0 to 100.0) based on original loan principal.
  /// Formula: (Total Principal Repaid ÷ Original Loan Principal) * 100
  double calculateRepaymentProgress(
    Loan loan,
    List<LoanRepayment> repayments,
  ) {
    if (loan.principal <= 0) return 0.0;
    final repaid = calculateTotalPrincipalRepaid(loan, repayments);
    final progress = (repaid / loan.principal) * 100.0;
    return progress.clamp(0.0, 100.0);
  }

  /// Whether a loan is fully repaid.
  bool isLoanFullyRepaid(
    Loan loan,
    List<LoanRepayment> repayments,
  ) {
    return calculateOutstandingPrincipal(loan, repayments) <= 0.000001;
  }

  /// Total outstanding principal across all loans converted to target currency.
  double calculateTotalOutstandingPrincipalAllLoans(
    List<Loan> loans,
    List<LoanRepayment> repayments, [
    String? targetCurrencyCode,
  ]) {
    final targetCurrency =
        targetCurrencyCode ?? _currencyService.defaultCurrencyCode;
    double total = 0.0;
    for (final loan in loans) {
      if (!loan.isArchived) {
        final outstanding = calculateOutstandingPrincipal(loan, repayments);
        total += _currencyService.convert(
          outstanding,
          loan.currency,
          targetCurrency,
        );
      }
    }
    final currency = AppCurrency.fromCode(targetCurrency);
    return roundCurrency(total, currency.decimalDigits);
  }

  /// Total principal repaid across all loans converted to target currency.
  double calculateTotalPrincipalRepaidAllLoans(
    List<LoanRepayment> repayments, [
    String? targetCurrencyCode,
  ]) {
    final targetCurrency =
        targetCurrencyCode ?? _currencyService.defaultCurrencyCode;
    double total = 0.0;
    for (final rep in repayments) {
      total += _currencyService.convert(
        rep.principalAmount,
        rep.currency,
        targetCurrency,
      );
    }
    final currency = AppCurrency.fromCode(targetCurrency);
    return roundCurrency(total, currency.decimalDigits);
  }

  /// Total interest paid across all loans converted to target currency.
  double calculateTotalInterestPaidAllLoans(
    List<LoanRepayment> repayments, [
    String? targetCurrencyCode,
  ]) {
    final targetCurrency =
        targetCurrencyCode ?? _currencyService.defaultCurrencyCode;
    double total = 0.0;
    for (final rep in repayments) {
      total += _currencyService.convert(
        rep.interestAmount,
        rep.currency,
        targetCurrency,
      );
    }
    final currency = AppCurrency.fromCode(targetCurrency);
    return roundCurrency(total, currency.decimalDigits);
  }

  /// Validates loan creation or editing parameters.
  String? validateLoan({
    required String title,
    required double principal,
    required double fee,
    required List<AccountAllocation> allocations,
    double alreadyRepaidPrincipal = 0.0,
  }) {
    if (title.trim().isEmpty) {
      return 'Please enter a loan title.';
    }
    if (principal <= 0) {
      return 'Loan principal must be greater than zero.';
    }
    if (fee < 0) {
      return 'Loan fee cannot be negative.';
    }
    if (fee >= principal) {
      return 'Loan fee must be less than the loan principal.';
    }
    if (principal < alreadyRepaidPrincipal - 0.0001) {
      return 'Principal cannot be less than already repaid principal (${alreadyRepaidPrincipal.toStringAsFixed(2)}).';
    }
    final netAmount = principal - fee;
    final totalAlloc = allocations.fold(0.0, (s, a) => s + a.amount);
    if (totalAlloc > netAmount + 0.0001) {
      return 'Allocated amount exceeds net proceeds (${netAmount.toStringAsFixed(2)}).';
    }
    return null;
  }

  /// Validates loan repayment parameters.
  String? validateRepayment({
    required double principalAmount,
    required double interestAmount,
    required double outstandingPrincipal,
    required List<AccountAllocation> allocations,
    Map<String, double> availableAccountBalances = const {},
    String repaymentCurrency = 'USD',
    Map<String, String> accountCurrencies = const {},
  }) {
    if (principalAmount <= 0) {
      return 'Principal repayment amount must be greater than zero.';
    }
    if (interestAmount < 0) {
      return 'Interest amount cannot be negative.';
    }
    if (principalAmount > outstandingPrincipal + 0.0001) {
      return 'Principal repayment cannot exceed outstanding principal (${outstandingPrincipal.toStringAsFixed(2)}).';
    }
    final totalPayment = principalAmount + interestAmount;
    final totalAlloc = allocations.fold(0.0, (s, a) => s + a.amount);
    if (totalAlloc > totalPayment + 0.0001) {
      return 'Allocated amount exceeds total payment (${totalPayment.toStringAsFixed(2)}).';
    }

    // Validate each account's available funds
    for (final alloc in allocations) {
      final available = availableAccountBalances[alloc.accountId] ?? 0.0;
      final accCurrency =
          accountCurrencies[alloc.accountId] ?? repaymentCurrency;
      final allocInAccCurrency = _currencyService.convert(
        alloc.amount,
        repaymentCurrency,
        accCurrency,
      );
      if (allocInAccCurrency > available + 0.0001) {
        return 'Insufficient funds in allocated account (Required: ${allocInAccCurrency.toStringAsFixed(2)} $accCurrency, Available: ${available.toStringAsFixed(2)} $accCurrency).';
      }
    }

    return null;
  }

  /// Rounding helper for currency amounts.
  static double roundCurrency(double val, int decimals) {
    if (decimals <= 0) return val.roundToDouble();
    final factor = pow(10, decimals);
    return (val * factor).round() / factor;
  }
}
