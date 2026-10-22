import 'package:flutter/material.dart';
import '../constants/categories.dart';
import '../models/account_transfer.dart';
import '../models/currency.dart';
import '../models/money_account.dart';
import '../models/transaction.dart';
import '../services/currency_service.dart';
import '../services/storage_service.dart';
import '../utils/formatters.dart';
import 'account_management_screen.dart';
import 'category_management_screen.dart';

/// Settings tab for managing default currency, exchange rates,
/// transaction categories, money accounts, theme mode, and data maintenance.
class SettingsTab extends StatefulWidget {
  final VoidCallback onDataChanged;
  final Function(ThemeMode) onThemeModeChanged;
  final ThemeMode currentThemeMode;
  final List<Transaction> transactions;
  final Function(Transaction)? onUpdateTransaction;

  const SettingsTab({
    super.key,
    required this.onDataChanged,
    required this.onThemeModeChanged,
    required this.currentThemeMode,
    this.transactions = const [],
    this.onUpdateTransaction,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final CurrencyService _currencyService = CurrencyService();
  final StorageService _storageService = StorageService();

  bool _isMoneyAccountsEnabled = false;
  List<MoneyAccount> _accounts = [];
  List<AccountTransfer> _transfers = [];

  @override
  void initState() {
    super.initState();
    _loadMoneyAccountsData();
  }

  Future<void> _loadMoneyAccountsData() async {
    final enabled = await _storageService.isMoneyAccountsEnabled();
    final accounts = await _storageService.loadAccounts();
    final transfers = await _storageService.loadTransfers();
    if (!mounted) return;
    setState(() {
      _isMoneyAccountsEnabled = enabled;
      _accounts = accounts;
      _transfers = transfers;
    });
  }

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
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.category_outlined, color: theme.colorScheme.primary, size: 20),
              ),
              title: const Text('Category Management', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${AppCategories.expenseCategories.length} expense, ${AppCategories.incomeCategories.length} income categories',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => CategoryManagementScreen(
                      transactions: widget.transactions,
                      onDataChanged: () {
                        setState(() {});
                        widget.onDataChanged();
                      },
                    ),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(height: 24),

          // =================================================================
          // SECTION 2.5: MONEY ACCOUNTS (Positioned after Custom Categories)
          // =================================================================
          _buildSectionHeader('MONEY ACCOUNTS'),
          _buildCard(
            theme: theme,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    _isMoneyAccountsEnabled
                        ? Icons.account_balance_wallet_rounded
                        : Icons.account_balance_wallet_outlined,
                    color: _isMoneyAccountsEnabled ? theme.colorScheme.primary : null,
                  ),
                  title: const Text(
                    'Enable Money Accounts',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Track separate accounts (Bank, Cash, Wallets) and allocate transactions',
                  ),
                  value: _isMoneyAccountsEnabled,
                  onChanged: (val) async {
                    await _storageService.setMoneyAccountsEnabled(val);
                    setState(() {
                      _isMoneyAccountsEnabled = val;
                    });
                    widget.onDataChanged();
                  },
                ),
                if (_isMoneyAccountsEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.manage_accounts_outlined),
                    title: const Text('Manage Accounts', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${_accounts.length} account(s) configured'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => AccountManagementScreen(
                            transactions: widget.transactions,
                            accounts: _accounts,
                            transfers: _transfers,
                            onUpdateTransaction: widget.onUpdateTransaction ?? (_) {},
                            onDataChanged: () async {
                              await _loadMoneyAccountsData();
                              widget.onDataChanged();
                            },
                          ),
                        ),
                      );
                      await _loadMoneyAccountsData();
                      if (mounted) setState(() {});
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.account_tree_outlined),
                    title: const Text('Reconciliation & Transfers', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _accounts.isEmpty
                          ? 'Add accounts to view reconciliation'
                          : 'Track balance differences and inter-account transfers',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => AccountManagementScreen(
                            transactions: widget.transactions,
                            accounts: _accounts,
                            transfers: _transfers,
                            onUpdateTransaction: widget.onUpdateTransaction ?? (_) {},
                            onDataChanged: () async {
                              await _loadMoneyAccountsData();
                              widget.onDataChanged();
                            },
                          ),
                        ),
                      );
                      await _loadMoneyAccountsData();
                      if (mounted) setState(() {});
                    },
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
                    ],
                    selected: {
                      widget.currentThemeMode == ThemeMode.dark
                          ? ThemeMode.dark
                          : ThemeMode.light,
                    },
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
