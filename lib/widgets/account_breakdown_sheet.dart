import 'package:flutter/material.dart';
import '../models/account_transfer.dart';
import '../models/currency.dart';
import '../models/loan.dart';
import '../models/loan_repayment.dart';
import '../models/money_account.dart';
import '../models/transaction.dart';
import '../services/account_service.dart';
import '../services/currency_service.dart';
import '../services/storage_service.dart';
import '../utils/formatters.dart';

/// Modal bottom sheet showing account-wise breakdown for Income or Expenses,
/// detailing how much went to each account and unassigned funds.
/// When [isAllocationOnly] is true, displays the Allocation Breakdown of money accounts.
class AccountBreakdownSheet extends StatefulWidget {
  final bool isIncome;
  final bool isAllocationOnly;
  final List<Transaction> allTransactions;
  final List<MoneyAccount> accounts;
  final List<AccountTransfer> transfers;
  final List<Loan> loans;
  final List<LoanRepayment> repayments;
  final Function(Transaction)? onTransactionTap;

  const AccountBreakdownSheet({
    super.key,
    this.isIncome = true,
    this.isAllocationOnly = false,
    required this.allTransactions,
    required this.accounts,
    this.transfers = const [],
    this.loans = const [],
    this.repayments = const [],
    this.onTransactionTap,
  });

  @override
  State<AccountBreakdownSheet> createState() => _AccountBreakdownSheetState();
}

class _AccountBreakdownSheetState extends State<AccountBreakdownSheet> {
  final CurrencyService _currencyService = CurrencyService();
  final StorageService _storageService = StorageService();
  late final AccountService _accountService;
  late List<AccountTransfer> _transfers;
  late List<Loan> _loans;
  late List<LoanRepayment> _repayments;
  bool _filterCurrentMonth = true;

  @override
  void initState() {
    super.initState();
    _accountService = AccountService(_currencyService);
    _transfers = List.from(widget.transfers);
    _loans = List.from(widget.loans);
    _repayments = List.from(widget.repayments);
    _loadFreshData();
  }

  Future<void> _loadFreshData() async {
    final freshTransfers = await _storageService.loadTransfers();
    final freshLoans = await _storageService.loadLoans();
    final freshRepayments = await _storageService.loadLoanRepayments();
    if (!mounted) return;
    setState(() {
      if (freshTransfers.isNotEmpty || widget.transfers.isEmpty) {
        _transfers = freshTransfers;
      }
      if (freshLoans.isNotEmpty || widget.loans.isEmpty) {
        _loans = freshLoans;
      }
      if (freshRepayments.isNotEmpty || widget.repayments.isEmpty) {
        _repayments = freshRepayments;
      }
    });
  }

  @override
  void didUpdateWidget(covariant AccountBreakdownSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transfers != widget.transfers) {
      _transfers = List.from(widget.transfers);
    }
    if (oldWidget.loans != widget.loans) {
      _loans = List.from(widget.loans);
    }
    if (oldWidget.repayments != widget.repayments) {
      _repayments = List.from(widget.repayments);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultCurrency = _currencyService.defaultCurrencyCode;
    final now = DateTime.now();

    // Filter by type and time period
    final relevantTransactions = widget.allTransactions.where((t) {
      if (widget.isAllocationOnly) return true;
      if (widget.isIncome ? !t.isIncome : !t.isExpense) return false;
      if (_filterCurrentMonth) {
        return t.date.year == now.year && t.date.month == now.month;
      }
      return true;
    }).toList();

    // Calculate total converted into default currency for Income/Expense details
    double totalAmount = 0.0;
    double totalUnassigned = 0.0;
    final Map<String, double> accountAllocatedMap = {};

    for (final acc in widget.accounts) {
      accountAllocatedMap[acc.id] = 0.0;
    }

    if (!widget.isAllocationOnly) {
      for (final tx in relevantTransactions) {
        final convertedTxAmount = _currencyService.convert(
          tx.amount,
          tx.currency,
          defaultCurrency,
        );
        totalAmount += convertedTxAmount;

        double txAllocatedInDefault = 0.0;
        for (final alloc in tx.allocations) {
          final convertedAlloc = _currencyService.convert(
            alloc.amount,
            tx.currency,
            defaultCurrency,
          );
          txAllocatedInDefault += convertedAlloc;

          if (accountAllocatedMap.containsKey(alloc.accountId)) {
            accountAllocatedMap[alloc.accountId] =
                accountAllocatedMap[alloc.accountId]! + convertedAlloc;
          } else {
            accountAllocatedMap[alloc.accountId] = convertedAlloc;
          }
        }

        final unassignedInTx = convertedTxAmount - txAllocatedInDefault;
        if (unassignedInTx > 0.0001) {
          totalUnassigned += unassignedInTx;
        }
      }
    }

    final currency = AppCurrency.fromCode(defaultCurrency);
    totalAmount = AccountService.roundCurrency(totalAmount, currency.decimalDigits);
    totalUnassigned = AccountService.roundCurrency(totalUnassigned, currency.decimalDigits);

    // Calculate current account balances (reusing AccountService)
    final accountBalances = _accountService.calculateAllBalances(
      widget.accounts,
      widget.allTransactions,
      _transfers,
      loans: _loans,
      repayments: _repayments,
    );

    final Map<String, double> displayBalances = {};
    for (final acc in widget.accounts) {
      final rawBal = accountBalances[acc.id] ?? 0.0;
      final converted = _currencyService.convert(
        rawBal,
        acc.currency,
        defaultCurrency,
      );
      displayBalances[acc.id] = AccountService.roundCurrency(
        converted,
        currency.decimalDigits,
      );
    }

    if (widget.isAllocationOnly) {
      double activeSum = 0.0;
      for (final acc in widget.accounts) {
        if (!acc.isArchived) {
          final bal = displayBalances[acc.id] ?? 0.0;
          activeSum += bal;
        }
      }
      totalAmount = AccountService.roundCurrency(activeSum, currency.decimalDigits);
      final unassignedInc = _accountService.calculateTotalUnassignedIncome(widget.allTransactions, defaultCurrency);
      final unassignedExp = _accountService.calculateTotalUnassignedExpense(widget.allTransactions, defaultCurrency);
      totalUnassigned = AccountService.roundCurrency(unassignedInc + unassignedExp, currency.decimalDigits);
    }

    final nonzeroAccounts = widget.accounts.where((account) {
      if (account.isArchived) return false;
      final bal = displayBalances[account.id] ?? 0.0;
      return bal.abs() > 0.0001;
    }).toList();

    final String sheetTitle;
    final IconData sheetIcon;
    final Color primaryColor;

    if (widget.isAllocationOnly) {
      sheetTitle = 'Allocation Breakdown';
      sheetIcon = Icons.pie_chart_outline_rounded;
      primaryColor = const Color(0xFF3B82F6); // Blue
    } else if (widget.isIncome) {
      sheetTitle = 'Income by Account';
      sheetIcon = Icons.arrow_downward_rounded;
      primaryColor = const Color(0xFF10B981); // Emerald
    } else {
      sheetTitle = 'Expenses by Account';
      sheetIcon = Icons.arrow_upward_rounded;
      primaryColor = const Color(0xFFEF4444); // Crimson
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          sheetIcon,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        sheetTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Period Selector Chips (Only for Income and Expense details pages)
            if (!widget.isAllocationOnly) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(Formatters.formatMonthYear(now)),
                      selected: _filterCurrentMonth,
                      selectedColor: primaryColor,
                      labelStyle: TextStyle(
                        color: _filterCurrentMonth ? Colors.white : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (val) => setState(() => _filterCurrentMonth = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('All Time'),
                      selected: !_filterCurrentMonth,
                      selectedColor: primaryColor,
                      labelStyle: TextStyle(
                        color: !_filterCurrentMonth ? Colors.white : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (val) => setState(() => _filterCurrentMonth = false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Main Content Scrollable
            Expanded(
              child: (widget.isAllocationOnly ? widget.accounts.isEmpty : relevantTransactions.isEmpty)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isAllocationOnly
                                ? Icons.account_balance_wallet_outlined
                                : Icons.receipt_long_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.isAllocationOnly
                                ? 'No accounts configured'
                                : 'No ${widget.isIncome ? "income" : "expense"} in this period',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      children: [
                        // Total Summary Card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.isAllocationOnly
                                        ? 'TOTAL BALANCE'
                                        : (widget.isIncome ? 'TOTAL INCOME' : 'TOTAL EXPENSES'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    Formatters.formatCurrency(totalAmount, defaultCurrency),
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  widget.isAllocationOnly
                                      ? '${nonzeroAccounts.length} ${nonzeroAccounts.length == 1 ? 'account' : 'accounts'}'
                                      : '${relevantTransactions.length} txns',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Allocation Breakdown List (Only in Allocation Breakdown page)
                        if (widget.isAllocationOnly) ...[
                          const SizedBox(height: 16),
                          Text(
                            'ALLOCATION BREAKDOWN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (nonzeroAccounts.isEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20.0),
                              child: Center(
                                child: Text(
                                  'No accounts with nonzero balance',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            ...nonzeroAccounts.map((account) {
                              final allocated = displayBalances[account.id] ?? 0.0;
                              final percentage = totalAmount > 0
                                  ? (allocated / totalAmount * 100).clamp(0.0, 100.0)
                                  : 0.0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: account.color.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(account.icon, size: 18, color: account.color),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            account.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${percentage.toStringAsFixed(1)}% of total',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      Formatters.formatCurrency(allocated, defaultCurrency),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],

                        // Unassigned Funds Tile
                        if (totalUnassigned > 0.0001) ...[
                          const SizedBox(height: 12),
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.help_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Unassigned to Accounts',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        totalAmount > 0
                                            ? '${(totalUnassigned / totalAmount * 100).toStringAsFixed(1)}% of total'
                                            : '0% of total',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  Formatters.formatCurrency(totalUnassigned, defaultCurrency),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Relevant Transactions Header & List (Only in Income and Expense details pages)
                        if (!widget.isAllocationOnly) ...[
                          const SizedBox(height: 16),
                          Text(
                            'TRANSACTIONS IN PERIOD',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),

                          ...relevantTransactions.map((tx) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: Material(
                                color: theme.colorScheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    widget.onTransactionTap?.call(tx);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tx.title.isNotEmpty ? tx.title : tx.category,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${Formatters.formatFriendlyDate(tx.date)}${tx.allocations.isNotEmpty ? " • ${tx.allocations.length} account(s)" : " • Unassigned"}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          Formatters.formatCurrency(tx.amount, tx.currency),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
