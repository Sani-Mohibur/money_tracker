import 'package:flutter/material.dart';
import '../utils/formatters.dart';

/// Dashboard hero widget displaying Total Balance, Total Income, and Total Expenses.
class BalanceCard extends StatelessWidget {
  final double totalIncome;
  final double totalExpenses;
  final double? customNetBalance;
  final String currencyCode;
  final String? subtitle;
  final VoidCallback? onIncomeTap;
  final VoidCallback? onExpenseTap;
  final VoidCallback? onAllocationBreakdownTap;

  const BalanceCard({
    super.key,
    required this.totalIncome,
    required this.totalExpenses,
    this.customNetBalance,
    required this.currencyCode,
    this.subtitle,
    this.onIncomeTap,
    this.onExpenseTap,
    this.onAllocationBreakdownTap,
  });

  double get netBalance => customNetBalance ?? (totalIncome - totalExpenses);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNegative = netBalance < 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B), // Slate 800
            Color(0xFF0F172A), // Slate 900
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with Label & Status indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TOTAL BALANCE',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isNegative
                        ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                        : const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isNegative
                          ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                          : const Color(0xFF10B981).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isNegative ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        color: isNegative ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isNegative ? 'Deficit' : 'Healthy',
                        style: TextStyle(
                          color: isNegative ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Big Main Balance with selected currency
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Formatters.formatCurrency(netBalance, currencyCode),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
            if (onAllocationBreakdownTap != null) ...[
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAllocationBreakdownTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF60A5FA).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.pie_chart_outline_rounded,
                                size: 14,
                                color: Color(0xFF93C5FD),
                              ),
                            ),
                            const SizedBox(width: 9),
                            const Text(
                              'Allocation Breakdown',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              'View Accounts',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ] else ...[
              const SizedBox(height: 22),
            ],

            // Income and Expense Breakdown Tiles
            Row(
              children: [
                // Income Card
                Expanded(
                  child: _SummaryPill(
                    title: 'Income',
                    amount: totalIncome,
                    currencyCode: currencyCode,
                    isIncome: true,
                    onTap: onIncomeTap,
                  ),
                ),
                const SizedBox(width: 14),
                // Expense Card
                Expanded(
                  child: _SummaryPill(
                    title: 'Expense',
                    amount: totalExpenses,
                    currencyCode: currencyCode,
                    isIncome: false,
                    onTap: onExpenseTap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String title;
  final double amount;
  final String currencyCode;
  final bool isIncome;
  final VoidCallback? onTap;

  const _SummaryPill({
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.isIncome,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const incomeColor = Color(0xFF10B981); // Emerald
    const expenseColor = Color(0xFFEF4444); // Crimson
    final color = isIncome ? incomeColor : expenseColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.09),
            ),
          ),
          child: Row(
            children: [
              // Icon badge
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              // Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Formatters.formatCurrency(amount, currencyCode),
                        style: TextStyle(
                          color: isIncome ? const Color(0xFF34D399) : const Color(0xFFF87171),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
