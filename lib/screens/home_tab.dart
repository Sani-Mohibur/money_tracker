import 'package:flutter/material.dart';
import '../models/account_transfer.dart';
import '../models/money_account.dart';
import '../models/transaction.dart';
import '../services/currency_service.dart';
import '../utils/formatters.dart';
import '../widgets/account_breakdown_sheet.dart';
import '../widgets/balance_card.dart';
import '../widgets/charts/bar_chart.dart';
import '../widgets/transaction_tile.dart';

/// Home tab showing total balance, spending overview, current month summary,
/// and recent transactions, with interactive account breakdown cards when enabled.
class HomeTab extends StatelessWidget {
  final List<Transaction> transactions;
  final Function(Transaction) onAddTransaction;
  final Function(Transaction) onUpdateTransaction;
  final Function(String) onDeleteTransaction;
  final VoidCallback onNavigateToTransactions;
  final VoidCallback onOpenAddSheet;
  final bool isMoneyAccountsEnabled;
  final List<MoneyAccount> accounts;
  final List<AccountTransfer> transfers;
  final Future<void> Function()? onRefresh;

  const HomeTab({
    super.key,
    required this.transactions,
    required this.onAddTransaction,
    required this.onUpdateTransaction,
    required this.onDeleteTransaction,
    required this.onNavigateToTransactions,
    required this.onOpenAddSheet,
    this.isMoneyAccountsEnabled = false,
    this.accounts = const [],
    this.transfers = const [],
    this.onRefresh,
  });

  void _openBreakdown(BuildContext context, bool isIncome) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AccountBreakdownSheet(
        isIncome: isIncome,
        isAllocationOnly: false,
        allTransactions: transactions,
        accounts: accounts,
        transfers: transfers,
        onTransactionTap: onUpdateTransaction,
      ),
    );
  }

  void _openAllocationBreakdown(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AccountBreakdownSheet(
        isAllocationOnly: true,
        allTransactions: transactions,
        accounts: accounts,
        transfers: transfers,
        onTransactionTap: onUpdateTransaction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyService = CurrencyService();
    final defaultCurrency = currencyService.defaultCurrencyCode;

    // Converted all-time totals
    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    for (final t in transactions) {
      final converted = currencyService.convert(t.amount, t.currency);
      if (t.isIncome) {
        totalIncome += converted;
      } else {
        totalExpenses += converted;
      }
    }

    // Current month calculations
    final now = DateTime.now();
    final currentMonthTransactions = transactions.where((t) {
      return t.date.year == now.year && t.date.month == now.month;
    }).toList();

    double monthIncome = 0.0;
    double monthExpense = 0.0;
    for (final t in currentMonthTransactions) {
      final converted = currencyService.convert(t.amount, t.currency);
      if (t.isIncome) {
        monthIncome += converted;
      } else {
        monthExpense += converted;
      }
    }

    final recentTransactions = transactions.take(5).toList();

    return RefreshIndicator(
      onRefresh: () async {
        if (onRefresh != null) {
          await onRefresh!();
        }
      },
      child: CustomScrollView(
        slivers: [
          // Dashboard Balance Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: BalanceCard(
                totalIncome: totalIncome,
                totalExpenses: totalExpenses,
                currencyCode: defaultCurrency,
                subtitle: 'All-time net balance in $defaultCurrency',
                onIncomeTap: isMoneyAccountsEnabled ? () => _openBreakdown(context, true) : null,
                onExpenseTap: isMoneyAccountsEnabled ? () => _openBreakdown(context, false) : null,
                onAllocationBreakdownTap: isMoneyAccountsEnabled ? () => _openAllocationBreakdown(context) : null,
              ),
            ),
          ),

          // Current Month Summary Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              Formatters.formatMonthYear(now),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${currentMonthTransactions.length} items',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Spending overview ratio bar
                    IncomeExpenseRatioBar(
                      income: monthIncome,
                      expense: monthExpense,
                      currencyCode: defaultCurrency,
                    ),
                    const SizedBox(height: 12),

                    // Net savings pill for current month
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Month Net Savings:',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          Formatters.formatCurrency(monthIncome - monthExpense, defaultCurrency),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: (monthIncome - monthExpense) >= 0
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Recent Transactions Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (transactions.isNotEmpty)
                    TextButton(
                      onPressed: onNavigateToTransactions,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'View All',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right_rounded, size: 16),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Recent Transactions List
          if (recentTransactions.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No transactions yet',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "+" below to record your first income or expense.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: onOpenAddSheet,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Transaction'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = recentTransactions[index];
                    return TransactionTile(
                      transaction: item,
                      onTap: () => onUpdateTransaction(item),
                      onDelete: () => onDeleteTransaction(item.id),
                    );
                  },
                  childCount: recentTransactions.length,
                ),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 90),
          ),
        ],
      ),
    );
  }
}
