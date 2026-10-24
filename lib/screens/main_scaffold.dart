import 'package:flutter/material.dart';
import '../models/account_transfer.dart';
import '../models/loan.dart';
import '../models/loan_repayment.dart';
import '../models/money_account.dart';
import '../models/transaction.dart';
import '../services/currency_service.dart';
import '../services/storage_service.dart';
import '../widgets/add_transaction_dialog.dart';
import 'calendar_tab.dart';
import 'home_tab.dart';
import 'settings_tab.dart';
import 'statistics_tab.dart';
import 'transactions_tab.dart';

/// Main scaffold hosting the 5-tab persistent bottom navigation bar,
/// global Add Transaction FAB, and centralized data management.
class MainScaffold extends StatefulWidget {
  final Function(ThemeMode) onThemeModeChanged;
  final ThemeMode currentThemeMode;

  const MainScaffold({
    super.key,
    required this.onThemeModeChanged,
    required this.currentThemeMode,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final StorageService _storageService = StorageService();
  final CurrencyService _currencyService = CurrencyService();

  int _currentIndex = 0;
  List<Transaction> _transactions = [];
  bool _isMoneyAccountsEnabled = false;
  List<MoneyAccount> _accounts = [];
  List<AccountTransfer> _transfers = [];
  List<Loan> _loans = [];
  List<LoanRepayment> _repayments = [];
  bool _isLoading = true;
  String? _initErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _initErrorMessage = null;
    });

    try {
      await Future.wait([
        _currencyService.init(),
        _storageService.loadCustomCategories(),
      ]).timeout(const Duration(seconds: 4));

      final list = await _storageService
          .loadTransactions()
          .timeout(const Duration(seconds: 4));

      final isEnabled = await _storageService.isMoneyAccountsEnabled();
      final accounts = await _storageService.loadAccounts();
      final transfers = await _storageService.loadTransfers();
      final loans = await _storageService.loadLoans();
      final repayments = await _storageService.loadLoanRepayments();

      if (!mounted) return;
      setState(() {
        _transactions = list;
        _isMoneyAccountsEnabled = isEnabled;
        _accounts = accounts;
        _transfers = transfers;
        _loans = loans;
        _repayments = repayments;
        _isLoading = false;
        _initErrorMessage = null;
      });
    } catch (e, stack) {
      debugPrint('Startup initialization error: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _initErrorMessage = e.toString();
      });
    }
  }

  Future<void> _addTransaction(Transaction transaction) async {
    final updated = await _storageService.addTransaction(transaction);
    setState(() {
      _transactions = updated;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              transaction.isIncome ? Icons.trending_up : Icons.trending_down,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              '${transaction.isIncome ? "Income" : "Expense"} of ${transaction.amount} ${transaction.currency} saved',
            ),
          ],
        ),
        backgroundColor: transaction.isIncome
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _updateTransaction(Transaction transaction) async {
    final updated = await _storageService.updateTransaction(transaction);
    setState(() {
      _transactions = updated;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transaction "${transaction.title}" updated'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _deleteTransaction(String id) async {
    if (_repayments.any((r) => r.interestTransactionId == id)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This transaction is linked to a Loan Repayment. Please manage it from Loan Management.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final deleted = _transactions.firstWhere((item) => item.id == id);
    final updated = await _storageService.deleteTransaction(id);
    setState(() {
      _transactions = updated;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${deleted.title}"'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: const Color(0xFF60A5FA),
          onPressed: () => _addTransaction(deleted),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openAddTransactionModal([Transaction? existing]) {
    if (existing != null &&
        _repayments.any((r) => r.interestTransactionId == existing.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This transaction is linked to a Loan Repayment. Please edit it from Loan Management.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTransactionSheet(
        initialTransaction: existing,
        isMoneyAccountsEnabled: _isMoneyAccountsEnabled,
        accounts: _accounts,
        allTransactions: _transactions,
        transfers: _transfers,
        loans: _loans,
        repayments: _repayments,
        onSave: (tx) {
          if (existing != null) {
            _updateTransaction(tx);
          } else {
            _addTransaction(tx);
          }
        },
      ),
    );
  }

  String _getAppTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Money Tracker';
      case 1:
        return 'Calendar';
      case 2:
        return 'Analytics & Trends';
      case 3:
        return 'All Transactions';
      case 4:
        return 'Settings';
      default:
        return 'Money Tracker';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultCurrency = _currencyService.defaultCurrency;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getAppBarIcon(),
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _getAppTitle(),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
            ),
          ],
        ),
        actions: [
          // Currency Indicator Badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  defaultCurrency.symbol,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  defaultCurrency.code,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _initErrorMessage != null
              ? _buildErrorView(context)
              : IndexedStack(
                  index: _currentIndex,
                  children: [
                    // 0: Home Tab
                    HomeTab(
                      transactions: _transactions,
                      onAddTransaction: _addTransaction,
                      onUpdateTransaction: _openAddTransactionModal,
                      onDeleteTransaction: _deleteTransaction,
                      onNavigateToTransactions: () {
                        setState(() => _currentIndex = 3);
                      },
                      onOpenAddSheet: () => _openAddTransactionModal(),
                      isMoneyAccountsEnabled: _isMoneyAccountsEnabled,
                      accounts: _accounts,
                      transfers: _transfers,
                      loans: _loans,
                      repayments: _repayments,
                      onRefresh: _loadAll,
                    ),
                    // 1: Calendar Tab
                    CalendarTab(
                      transactions: _transactions,
                      onAddTransaction: _addTransaction,
                      onUpdateTransaction: _openAddTransactionModal,
                      onDeleteTransaction: _deleteTransaction,
                    ),
                    // 2: Statistics Tab
                    StatisticsTab(
                      transactions: _transactions,
                    ),
                    // 3: Transactions Tab
                    TransactionsTab(
                      transactions: _transactions,
                      onUpdateTransaction: _openAddTransactionModal,
                      onDeleteTransaction: _deleteTransaction,
                    ),
                    // 4: Settings Tab
                    SettingsTab(
                      currentThemeMode: widget.currentThemeMode,
                      onThemeModeChanged: widget.onThemeModeChanged,
                      transactions: _transactions,
                      accounts: _accounts,
                      transfers: _transfers,
                      loans: _loans,
                      repayments: _repayments,
                      onUpdateTransaction: _openAddTransactionModal,
                      onDataChanged: () async {
                        final list = await _storageService.loadTransactions();
                        final isEnabled = await _storageService.isMoneyAccountsEnabled();
                        final accounts = await _storageService.loadAccounts();
                        final transfers = await _storageService.loadTransfers();
                        final loans = await _storageService.loadLoans();
                        final repayments = await _storageService.loadLoanRepayments();
                        if (!mounted) return;
                        setState(() {
                          _transactions = list;
                          _isMoneyAccountsEnabled = isEnabled;
                          _accounts = accounts;
                          _transfers = transfers;
                          _loans = loans;
                          _repayments = repayments;
                        });
                      },
                    ),
                  ],
                ),
      // Global Floating Action Button accessible from every tab
      floatingActionButton: _initErrorMessage != null
          ? null
          : FloatingActionButton(
              onPressed: () => _openAddTransactionModal(),
              elevation: 4,
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.add_rounded, size: 28),
            ),
      // Comfortable, fixed bottom navigation bar
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        elevation: 3,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  IconData _getAppBarIcon() {
    switch (_currentIndex) {
      case 0:
        return Icons.account_balance_rounded;
      case 1:
        return Icons.calendar_month_rounded;
      case 2:
        return Icons.auto_graph_rounded;
      case 3:
        return Icons.receipt_long_rounded;
      case 4:
        return Icons.tune_rounded;
      default:
        return Icons.account_balance_rounded;
    }
  }

  Widget _buildErrorView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFEF4444),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Startup Initialization Issue',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The app encountered an issue while loading local storage or currency settings.',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Diagnostic Details:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _initErrorMessage ?? 'Unknown error',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _initErrorMessage = null;
                        _transactions = [];
                      });
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Continue'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loadAll,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
