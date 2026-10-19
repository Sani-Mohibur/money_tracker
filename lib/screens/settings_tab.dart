import 'package:flutter/material.dart';
import '../constants/categories.dart';
import '../models/currency.dart';
import '../models/transaction.dart';
import '../services/currency_service.dart';
import '../services/storage_service.dart';
import '../utils/formatters.dart';

/// Settings tab for managing default currency, exchange rates,
/// transaction categories, theme mode, and data maintenance.
class SettingsTab extends StatefulWidget {
  final VoidCallback onDataChanged;
  final Function(ThemeMode) onThemeModeChanged;
  final ThemeMode currentThemeMode;

  const SettingsTab({
    super.key,
    required this.onDataChanged,
    required this.onThemeModeChanged,
    required this.currentThemeMode,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final CurrencyService _currencyService = CurrencyService();
  final StorageService _storageService = StorageService();

  Future<void> _selectDefaultCurrency() async {
    final currentCode = _currencyService.defaultCurrencyCode;

    await showModalBottomSheet(
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
                  'Select Default Currency',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: AppCurrency.all.length,
                  itemBuilder: (context, index) {
                    final c = AppCurrency.all[index];
                    final isSelected = c.code == currentCode;
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          c.symbol,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        '${c.code} - ${c.name}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
                          : null,
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await _currencyService.setDefaultCurrency(c.code);
                        if (!mounted) return;
                        setState(() {});
                        widget.onDataChanged();
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

  Future<void> _editExchangeRate(String code, double currentRate) async {
    final controller = TextEditingController(text: currentRate.toString());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $code Rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rate relative to 1.00 USD (e.g. 1 USD = X):'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '1 USD = ',
                suffixText: code,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save Rate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final parsed = double.tryParse(controller.text.trim());
      if (parsed != null && parsed > 0) {
        await _currencyService.updateRate(code, parsed);
        setState(() {});
        widget.onDataChanged();
      }
    }
  }

  Future<void> _resetRates() async {
    await _currencyService.resetRatesToDefault();
    setState(() {});
    widget.onDataChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exchange rates reset to default baseline.')),
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    TransactionType catType = TransactionType.expense;
    String selectedIconKey = 'shopping_bag';
    Color selectedColor = const Color(0xFF3B82F6);

    final Map<String, IconData> availableIcons = {
      'shopping_bag': Icons.shopping_bag_rounded,
      'cafe': Icons.local_cafe_rounded,
      'fitness': Icons.fitness_center_rounded,
      'pets': Icons.pets_rounded,
      'book': Icons.book_rounded,
      'savings': Icons.savings_rounded,
      'payments': Icons.payments_rounded,
      'celebration': Icons.celebration_rounded,
      'gaming': Icons.sports_esports_rounded,
      'car': Icons.car_rental_rounded,
    };

    final availableColors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF10B981), // Green
      const Color(0xFFEF4444), // Red
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFF14B8A6), // Teal
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Custom Category'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type Segment
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Expense')),
                          selected: catType == TransactionType.expense,
                          selectedColor: const Color(0xFFEF4444),
                          labelStyle: TextStyle(
                            color: catType == TransactionType.expense
                                ? Colors.white
                                : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setDialogState(
                              () => catType = TransactionType.expense),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Income')),
                          selected: catType == TransactionType.income,
                          selectedColor: const Color(0xFF10B981),
                          labelStyle: TextStyle(
                            color: catType == TransactionType.income
                                ? Colors.white
                                : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setDialogState(
                              () => catType = TransactionType.income),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Name Field
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Pick Icon
                  const Text('Select Icon:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: availableIcons.entries.map((entry) {
                      final isSel = selectedIconKey == entry.key;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedIconKey = entry.key),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? selectedColor.withValues(alpha: 0.2)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSel ? selectedColor : Colors.grey.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(entry.value, size: 20, color: selectedColor),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Pick Color
                  const Text('Select Color:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: availableColors.map((col) {
                      final isSel = selectedColor == col;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = col),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: isSel
                                ? Border.all(color: Colors.white, width: 2.5)
                                : null,
                            boxShadow: isSel
                                ? [BoxShadow(color: col.withValues(alpha: 0.6), blurRadius: 6)]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    final item = CategoryItem(
                      name: name,
                      icon: CategoryItem.getIconByKey(selectedIconKey),
                      color: selectedColor,
                      isCustom: true,
                      iconKey: selectedIconKey,
                    );
                    Navigator.of(ctx).pop();
                    await _storageService.addCustomCategory(item, catType);
                    if (!mounted) return;
                    setState(() {});
                    widget.onDataChanged();
                  }
                },
                child: const Text('Add Category'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultCurr = _currencyService.defaultCurrency;
    final rates = _currencyService.ratesToUsd;
    final lastUpdated = _currencyService.lastUpdated;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Currency & Exchange Rates
          _buildSectionHeader('CURRENCY & EXCHANGE RATES'),
          _buildCard(
            theme: theme,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      defaultCurr.symbol,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  title: const Text('Default Currency', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${defaultCurr.code} - ${defaultCurr.name}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _selectDefaultCurrency,
                ),
                const Divider(height: 1),
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: const Icon(Icons.currency_exchange_rounded),
                    title: const Text(
                      'Exchange Rates (Offline)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      'Last updated: ${Formatters.formatFullDate(lastUpdated)}',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rates are relative to 1.00 USD. Tap any rate to configure manually.',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            ...rates.entries.map((entry) {
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                trailing: Text(
                                  '1 USD = ${entry.value.toStringAsFixed(2)} ${entry.key}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                onTap: () => _editExchangeRate(entry.key, entry.value),
                              );
                            }),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _resetRates,
                              icon: const Icon(Icons.restore_rounded, size: 16),
                              label: const Text('Reset Rates to Market Baseline'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Categories Management
          _buildSectionHeader('CATEGORY MANAGEMENT'),
          _buildCard(
            theme: theme,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: const Text('Add Custom Category', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Create custom income or expense categories'),
                  trailing: const Icon(Icons.add_rounded),
                  onTap: _showAddCategoryDialog,
                ),
                if (AppCategories.customExpenseCategories.isNotEmpty ||
                    AppCategories.customIncomeCategories.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Custom Categories:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...AppCategories.customExpenseCategories.map((c) {
                              return Chip(
                                avatar: Icon(c.icon, size: 16, color: c.color),
                                label: Text(c.name),
                                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                                onDeleted: () async {
                                  await _storageService.deleteCustomCategory(
                                    c.name,
                                    TransactionType.expense,
                                  );
                                  if (!mounted) return;
                                  setState(() {});
                                  widget.onDataChanged();
                                },
                              );
                            }),
                            ...AppCategories.customIncomeCategories.map((c) {
                              return Chip(
                                avatar: Icon(c.icon, size: 16, color: c.color),
                                label: Text(c.name),
                                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                                onDeleted: () async {
                                  await _storageService.deleteCustomCategory(
                                    c.name,
                                    TransactionType.income,
                                  );
                                  if (!mounted) return;
                                  setState(() {});
                                  widget.onDataChanged();
                                },
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: App Appearance
          _buildSectionHeader('APPEARANCE'),
          _buildCard(
            theme: theme,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.palette_outlined),
                      SizedBox(width: 12),
                      Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined, size: 16),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 16),
                        label: Text('Dark'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                      ),
                    ],
                    selected: {widget.currentThemeMode},
                    onSelectionChanged: (set) {
                      widget.onThemeModeChanged(set.first);
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 4: Data Maintenance
          _buildSectionHeader('DATA MAINTENANCE'),
          _buildCard(
            theme: theme,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome_rounded),
                  title: const Text('Load Demo Transactions', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Populates sample data for testing'),
                  onTap: () async {
                    await _storageService.resetSampleData();
                    widget.onDataChanged();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demo transactions restored.')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444)),
                  title: const Text(
                    'Clear All Data',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
                  ),
                  subtitle: const Text('Permanently delete all stored transactions'),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear All Data?'),
                        content: const Text(
                          'Are you sure? All your transactions will be permanently erased.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Clear Everything'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await _storageService.clearAll();
                      widget.onDataChanged();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All transactions erased.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, required ThemeData theme}) {
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
