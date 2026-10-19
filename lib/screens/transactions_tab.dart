import 'package:flutter/material.dart';
import '../constants/categories.dart';
import '../models/transaction.dart';
import '../services/currency_service.dart';
import '../utils/formatters.dart';
import '../widgets/transaction_tile.dart';

/// Transactions tab showing complete transaction history, search bar,
/// multi-faceted filters, editing, and deleting capabilities.
class TransactionsTab extends StatefulWidget {
  final List<Transaction> transactions;
  final Function(Transaction) onUpdateTransaction;
  final Function(String) onDeleteTransaction;

  const TransactionsTab({
    super.key,
    required this.transactions,
    required this.onUpdateTransaction,
    required this.onDeleteTransaction,
  });

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTypeFilter = 'All'; // 'All', 'Income', 'Expense'
  String? _selectedCategoryFilter; // null = all
  DateTimeRange? _selectedDateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedTypeFilter = 'All';
      _selectedCategoryFilter = null;
      _selectedDateRange = null;
    });
  }

  List<Transaction> get _filteredList {
    return widget.transactions.where((t) {
      // Type filter
      if (_selectedTypeFilter == 'Income' && !t.isIncome) return false;
      if (_selectedTypeFilter == 'Expense' && !t.isExpense) return false;

      // Category filter
      if (_selectedCategoryFilter != null &&
          t.category.toLowerCase() != _selectedCategoryFilter!.toLowerCase()) {
        return false;
      }

      // Date range filter
      if (_selectedDateRange != null) {
        final tDate = DateTime(t.date.year, t.date.month, t.date.day);
        final start = DateTime(
          _selectedDateRange!.start.year,
          _selectedDateRange!.start.month,
          _selectedDateRange!.start.day,
        );
        final end = DateTime(
          _selectedDateRange!.end.year,
          _selectedDateRange!.end.month,
          _selectedDateRange!.end.day,
        );
        if (tDate.isBefore(start) || tDate.isAfter(end)) return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = t.title.toLowerCase().contains(q);
        final matchNote = t.note.toLowerCase().contains(q);
        final matchCategory = t.category.toLowerCase().contains(q);
        if (!matchTitle && !matchNote && !matchCategory) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyService = CurrencyService();
    final defaultCurrency = currencyService.defaultCurrencyCode;

    final filtered = _filteredList;
    final hasActiveFilter = _searchQuery.isNotEmpty ||
        _selectedTypeFilter != 'All' ||
        _selectedCategoryFilter != null ||
        _selectedDateRange != null;

    // Collect all unique categories present in transactions for filter
    final allCategoryNames = {
      ...AppCategories.expenseCategories.map((c) => c.name),
      ...AppCategories.incomeCategories.map((c) => c.name),
    }.toList();

    return Column(
      children: [
        // Top Search Bar & Filters Section
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: theme.scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input Field
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by title, category, or note...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: theme.hintColor.withValues(alpha: 0.6),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Filter Chips Scrollable Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Type Filter: All
                    _buildTypeChip('All', theme),
                    const SizedBox(width: 8),
                    _buildTypeChip('Income', theme, const Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    _buildTypeChip('Expense', theme, const Color(0xFFEF4444)),
                    const SizedBox(width: 8),

                    // Category Filter Dropdown Chip
                    FilterChip(
                      avatar: const Icon(Icons.category_rounded, size: 16),
                      label: Text(_selectedCategoryFilter ?? 'Category'),
                      selected: _selectedCategoryFilter != null,
                      onSelected: (_) {
                        _showCategoryFilterDialog(allCategoryNames);
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    const SizedBox(width: 8),

                    // Date Range Chip
                    FilterChip(
                      avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: Text(
                        _selectedDateRange != null
                            ? '${Formatters.formatShortDate(_selectedDateRange!.start)} - ${Formatters.formatShortDate(_selectedDateRange!.end)}'
                            : 'Date Range',
                      ),
                      selected: _selectedDateRange != null,
                      onSelected: (_) => _pickDateRange(),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),

                    if (hasActiveFilter) ...[
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Clear'),
                        onPressed: _clearAllFilters,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Result Count & Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filtered.length} transaction${filtered.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Net: ${Formatters.formatCurrency(
                      filtered.fold<double>(0.0, (sum, t) {
                        final conv = currencyService.convert(t.amount, t.currency);
                        return sum + (t.isIncome ? conv : -conv);
                      }),
                      defaultCurrency,
                    )}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Transactions List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No matching transactions',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try adjusting your search terms or clearing filters.',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (hasActiveFilter) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _clearAllFilters,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Reset Filters'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return TransactionTile(
                      transaction: item,
                      onTap: () => widget.onUpdateTransaction(item),
                      onDelete: () => widget.onDeleteTransaction(item.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String type, ThemeData theme, [Color? color]) {
    final isSelected = _selectedTypeFilter == type;
    final activeColor = color ?? theme.colorScheme.primary;

    return FilterChip(
      label: Text(type),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedTypeFilter = type;
        });
      },
      selectedColor: activeColor.withValues(alpha: 0.16),
      checkmarkColor: activeColor,
      labelStyle: TextStyle(
        color: isSelected ? activeColor : theme.colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected
            ? activeColor
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showCategoryFilterDialog(List<String> categories) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select Category',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.all_inclusive_rounded),
                title: const Text('All Categories'),
                selected: _selectedCategoryFilter == null,
                onTap: () {
                  setState(() => _selectedCategoryFilter = null);
                  Navigator.of(ctx).pop();
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = _selectedCategoryFilter == cat;
                    return ListTile(
                      title: Text(cat),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded, color: Color(0xFF10B981))
                          : null,
                      onTap: () {
                        setState(() => _selectedCategoryFilter = cat);
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
