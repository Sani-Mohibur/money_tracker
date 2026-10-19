import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/formatters.dart';

class MonthTrendData {
  final String label;
  final double income;
  final double expense;

  const MonthTrendData({
    required this.label,
    required this.income,
    required this.expense,
  });
}

/// Bar chart representing monthly financial trends.
class MonthlyTrendChart extends StatelessWidget {
  final List<MonthTrendData> data;
  final String currencyCode;

  const MonthlyTrendChart({
    super.key,
    required this.data,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.isEmpty) {
      return const SizedBox(height: 180);
    }

    // Find highest value for scaling
    double maxVal = 0.0;
    for (final item in data) {
      maxVal = math.max(maxVal, math.max(item.income, item.expense));
    }
    if (maxVal <= 0) maxVal = 100.0;

    return Column(
      children: [
        // Legend indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: const Color(0xFF10B981), label: 'Income'),
            const SizedBox(width: 20),
            _LegendDot(color: const Color(0xFFEF4444), label: 'Expense'),
          ],
        ),
        const SizedBox(height: 16),

        // Bars Container
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((item) {
              final incomeHeight = (item.income / maxVal) * 140;
              final expenseHeight = (item.expense / maxVal) * 140;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Bars side by side
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Income Bar
                          Flexible(
                            child: Tooltip(
                              message: 'Income: ${Formatters.formatCurrency(item.income, currencyCode)}',
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 10,
                                height: math.max(4.0, incomeHeight),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          // Expense Bar
                          Flexible(
                            child: Tooltip(
                              message: 'Expense: ${Formatters.formatCurrency(item.expense, currencyCode)}',
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 10,
                                height: math.max(4.0, expenseHeight),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Month Label
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Visual horizontal comparison progress bar for Income vs Expense.
class IncomeExpenseRatioBar extends StatelessWidget {
  final double income;
  final double expense;
  final String currencyCode;

  const IncomeExpenseRatioBar({
    super.key,
    required this.income,
    required this.expense,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final total = income + expense;
    final incomeRatio = total > 0 ? income / total : 0.5;
    final expenseRatio = total > 0 ? expense / total : 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Income: ${Formatters.formatCompactCurrency(income, currencyCode)} (${(incomeRatio * 100).toStringAsFixed(0)}%)',
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            Text(
              'Expense: ${Formatters.formatCompactCurrency(expense, currencyCode)} (${(expenseRatio * 100).toStringAsFixed(0)}%)',
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: (incomeRatio * 100).toInt().clamp(1, 100),
                  child: Container(color: const Color(0xFF10B981)),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: (expenseRatio * 100).toInt().clamp(1, 100),
                  child: Container(color: const Color(0xFFEF4444)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
