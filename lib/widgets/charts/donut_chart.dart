import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants/categories.dart';
import '../../models/transaction.dart';
import '../../utils/formatters.dart';

class CategorySliceData {
  final String category;
  final double amount;
  final double percentage;
  final Color color;
  final IconData icon;

  const CategorySliceData({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.icon,
  });
}

/// A modern, responsive donut chart for category breakdown.
class DonutChart extends StatefulWidget {
  final Map<String, double> categoryAmounts;
  final String currencyCode;
  final TransactionType type;

  const DonutChart({
    super.key,
    required this.categoryAmounts,
    required this.currencyCode,
    this.type = TransactionType.expense,
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.categoryAmounts.values.fold(0.0, (sum, val) => sum + val);

    if (total <= 0 || widget.categoryAmounts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pie_chart_outline_rounded,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                'No data for this period',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build slice items sorted by highest amount first
    final sortedEntries = widget.categoryAmounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<CategorySliceData> slices = sortedEntries.map((e) {
      final cat = AppCategories.getCategoryItem(e.key, widget.type);
      return CategorySliceData(
        category: e.key,
        amount: e.value,
        percentage: (e.value / total) * 100,
        color: cat.color,
        icon: cat.icon,
      );
    }).toList();

    final activeSlice = _selectedIndex != null && _selectedIndex! < slices.length
        ? slices[_selectedIndex!]
        : null;

    return Column(
      children: [
        // Donut Chart Graphic
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(190, 190),
                painter: _DonutChartPainter(
                  slices: slices,
                  selectedIndex: _selectedIndex,
                ),
              ),
              // Center Display
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activeSlice != null
                        ? activeSlice.category
                        : (widget.type == TransactionType.expense
                            ? 'Total Expense'
                            : 'Total Income'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.formatCurrency(
                      activeSlice != null ? activeSlice.amount : total,
                      widget.currencyCode,
                    ),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: activeSlice != null
                          ? activeSlice.color
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (activeSlice != null)
                    Text(
                      '${activeSlice.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: activeSlice.color,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Breakdown Legend List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: slices.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final slice = slices[index];
            final isSelected = _selectedIndex == index;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedIndex = isSelected ? null : index;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? slice.color.withValues(alpha: 0.12)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? slice.color
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: slice.color.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(slice.icon, size: 16, color: slice.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slice.category,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: slice.percentage / 100,
                              minHeight: 4,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(slice.color),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Formatters.formatCurrency(
                              slice.amount, widget.currencyCode),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${slice.percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<CategorySliceData> slices;
  final int? selectedIndex;

  _DonutChartPainter({
    required this.slices,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    const strokeWidth = 24.0;
    final rect = Rect.fromCircle(center: center, radius: outerRadius - strokeWidth / 2);

    double startAngle = -math.pi / 2;
    const gapAngle = 0.04; // small aesthetic gap between arcs

    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final sweepAngle = (slice.percentage / 100) * 2 * math.pi;
      final isSelected = selectedIndex == i;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth + 6 : strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = slice.color;

      // Adjust for gap
      final effectiveSweep = math.max(0.01, sweepAngle - gapAngle);
      final effectiveStart = startAngle + (gapAngle / 2);

      canvas.drawArc(rect, effectiveStart, effectiveSweep, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.slices != slices || oldDelegate.selectedIndex != selectedIndex;
  }
}
