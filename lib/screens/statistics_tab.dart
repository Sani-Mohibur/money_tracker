import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/currency_service.dart';
import '../utils/formatters.dart';
import '../widgets/charts/bar_chart.dart';
import '../widgets/charts/donut_chart.dart';

/// Statistics tab displaying visual financial analytics, category breakdowns,
/// monthly trends, and spending comparisons.
class StatisticsTab extends StatefulWidget {
  final List<Transaction> transactions;

  const StatisticsTab({
    super.key,
    required this.transactions,
  });

  @override
  State<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<StatisticsTab> {
  String _selectedPeriod = 'This Month'; // 'This Month', 'Last Month', 'This Year', 'All Time'
  TransactionType _chartType = TransactionType.expense;

  List<Transaction> _filterByPeriod(List<Transaction> list) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'This Month':
        return list.where((t) => t.date.year == now.year && t.date.month == now.month).toList();
      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        return list.where((t) => t.date.year == lastMonth.year && t.date.month == lastMonth.month).toList();
      case 'This Year':
        return list.where((t) => t.date.year == now.year).toList();
      case 'All Time':
      default:
        return list;
    }
  }

  /// Calculates data for the last 6 months trend chart.
  List<MonthTrendData> _getRecentMonthsTrend(CurrencyService currencyService) {
    final now = DateTime.now();
    final List<MonthTrendData> result = [];

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthLabel = DateFormat('MMM').format(monthDate);

      double inc = 0.0;
      double exp = 0.0;

      for (final t in widget.transactions) {
        if (t.date.year == monthDate.year && t.date.month == monthDate.month) {
          final converted = currencyService.convert(t.amount, t.currency);
          if (t.isIncome) {
            inc += converted;
          } else {
            exp += converted;
          }
        }
      }

      result.add(MonthTrendData(
        label: monthLabel,
        income: inc,
        expense: exp,
      ));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyService = CurrencyService();
    final defaultCurrency = currencyService.defaultCurrencyCode;

    final periodTransactions = _filterByPeriod(widget.transactions);

    // Totals for selected period in default currency
    double periodIncome = 0.0;
    double periodExpense = 0.0;
    final Map<String, double> categorySums = {};

    for (final t in periodTransactions) {
      final converted = currencyService.convert(t.amount, t.currency);
      if (t.isIncome) {
        periodIncome += converted;
      } else {
        periodExpense += converted;
      }

      if (t.type == _chartType) {
        categorySums[t.category] = (categorySums[t.category] ?? 0.0) + converted;
      }
    }

    final netSavings = periodIncome - periodExpense;
    final savingsRate = periodIncome > 0
        ? ((netSavings / periodIncome) * 100).clamp(-100.0, 100.0)
        : 0.0;

    final sixMonthsTrend = _getRecentMonthsTrend(currencyService);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Segment Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['This Month', 'Last Month', 'This Year', 'All Time'].map((p) {
                final isSelected = _selectedPeriod == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(p),
                    selected: isSelected,
                    selectedColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedPeriod = p;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Overview Cards Grid
          Row(
            children: [
              // Income Card
              Expanded(
                child: _MetricCard(
                  title: 'Total Income',
                  amount: Formatters.formatCurrency(periodIncome, defaultCurrency),
                  color: const Color(0xFF10B981),
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 12),
              // Expense Card
              Expanded(
                child: _MetricCard(
                  title: 'Total Expense',
                  amount: Formatters.formatCurrency(periodExpense, defaultCurrency),
                  color: const Color(0xFFEF4444),
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Savings Rate & Net Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net Savings',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.formatCurrency(netSavings, defaultCurrency),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: netSavings >= 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (savingsRate >= 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        savingsRate >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 16,
                        color: savingsRate >= 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${savingsRate.toStringAsFixed(1)}% savings rate',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: savingsRate >= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Category Breakdown Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Category Breakdown',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    // Toggle Expense / Income for donut
                    SegmentedButton<TransactionType>(
                      segments: const [
                        ButtonSegment(
                          value: TransactionType.expense,
                          label: Text('Expense', style: TextStyle(fontSize: 11)),
                        ),
                        ButtonSegment(
                          value: TransactionType.income,
                          label: Text('Income', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                      selected: {_chartType},
                      onSelectionChanged: (set) {
                        setState(() {
                          _chartType = set.first;
                        });
                      },
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DonutChart(
                  categoryAmounts: categorySums,
                  currencyCode: defaultCurrency,
                  type: _chartType,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Monthly Trends Section (6 Months)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '6-Month Spending Trends',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Comparative monthly income and expense history',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                MonthlyTrendChart(
                  data: sixMonthsTrend,
                  currencyCode: defaultCurrency,
                ),
              ],
            ),
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
