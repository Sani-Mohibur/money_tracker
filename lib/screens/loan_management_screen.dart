import 'package:flutter/material.dart';
import '../models/account_transfer.dart';
import '../models/loan.dart';
import '../models/loan_repayment.dart';
import '../models/money_account.dart';
import '../models/transaction.dart';
import '../services/account_service.dart';
import '../services/currency_service.dart';
import '../services/storage_service.dart';
import '../utils/formatters.dart';
import '../widgets/add_loan_sheet.dart';
import 'loan_details_screen.dart';

/// Dedicated Loan Management screen accessible from Settings.
/// Allows adding loans, viewing loans, tracking liabilities, and monitoring repayment progress.
class LoanManagementScreen extends StatefulWidget {
  final List<Transaction> transactions;
  final List<MoneyAccount> accounts;
  final List<AccountTransfer> transfers;
  final bool isMoneyAccountsEnabled;
  final VoidCallback onDataChanged;

  const LoanManagementScreen({
    super.key,
    required this.transactions,
    required this.accounts,
    required this.transfers,
    this.isMoneyAccountsEnabled = false,
    required this.onDataChanged,
  });

  @override
  State<LoanManagementScreen> createState() => _LoanManagementScreenState();
}

class _LoanManagementScreenState extends State<LoanManagementScreen> {
  final StorageService _storageService = StorageService();
  final CurrencyService _currencyService = CurrencyService();
  late final AccountService _accountService;

  List<Loan> _loans = [];
  List<LoanRepayment> _repayments = [];
  List<Transaction> _transactions = [];
  List<MoneyAccount> _accounts = [];
  List<AccountTransfer> _transfers = [];
  bool _isLoading = true;

  String _selectedFilter = 'All'; // 'All', 'Active', 'Fully Repaid'

  @override
  void initState() {
    super.initState();
    _accountService = AccountService(_currencyService);
    _transactions = List.from(widget.transactions);
    _accounts = List.from(widget.accounts);
    _transfers = List.from(widget.transfers);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final loans = await _storageService.loadLoans();
    final repayments = await _storageService.loadLoanRepayments();
    final transactions = await _storageService.loadTransactions();
    final accounts = await _storageService.loadAccounts();
    final transfers = await _storageService.loadTransfers();

    if (!mounted) return;
    setState(() {
      _loans = loans;
      _repayments = repayments;
      _transactions = transactions;
      _accounts = accounts;
      _transfers = transfers;
      _isLoading = false;
    });
  }

  List<Loan> get _filteredLoans {
    return _loans.where((loan) {
      final isRepaid = _accountService.isLoanFullyRepaid(loan, _repayments);
      if (_selectedFilter == 'Active') return !isRepaid && !loan.isArchived;
      if (_selectedFilter == 'Fully Repaid') return isRepaid;
      return !loan.isArchived;
    }).toList();
  }

  void _showAddLoanSheet([Loan? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddLoanSheet(
        initialLoan: existing,
        isMoneyAccountsEnabled: widget.isMoneyAccountsEnabled,
        accounts: _accounts,
        alreadyRepaidPrincipal: existing != null
            ? _accountService.calculateTotalPrincipalRepaid(
                existing,
                _repayments,
              )
            : 0.0,
        onSave: (loan) async {
          if (existing != null) {
            await _storageService.updateLoan(loan);
          } else {
            await _storageService.addLoan(loan);
          }
          await _loadData();
          widget.onDataChanged();

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                existing != null
                    ? 'Loan "${loan.title}" updated'
                    : 'Loan "${loan.title}" recorded with net proceeds ${Formatters.formatCurrency(loan.netAmountReceived, loan.currency)}',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _openLoanDetails(Loan loan) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => LoanDetailsScreen(
          loan: loan,
          transactions: _transactions,
          accounts: _accounts,
          transfers: _transfers,
          allLoans: _loans,
          allRepayments: _repayments,
          isMoneyAccountsEnabled: widget.isMoneyAccountsEnabled,
          onDataChanged: () async {
            await _loadData();
            widget.onDataChanged();
          },
        ),
      ),
    );
    await _loadData();
    widget.onDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultCurrency = _currencyService.defaultCurrencyCode;

    final totalOutstanding =
        _accountService.calculateTotalOutstandingPrincipalAllLoans(
      _loans,
      _repayments,
      defaultCurrency,
    );
    final totalRepaid = _accountService.calculateTotalPrincipalRepaidAllLoans(
      _repayments,
      defaultCurrency,
    );
    final totalInterest = _accountService.calculateTotalInterestPaidAllLoans(
      _repayments,
      defaultCurrency,
    );

    final activeLoansCount = _loans
        .where((l) =>
            !_accountService.isLoanFullyRepaid(l, _repayments) && !l.isArchived)
        .length;
    final repaidLoansCount = _loans
        .where((l) => _accountService.isLoanFullyRepaid(l, _repayments))
        .length;

    final filtered = _filteredLoans;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Management'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Overview Metrics Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: _buildOverviewCard(
                        theme,
                        totalOutstanding,
                        totalRepaid,
                        totalInterest,
                        activeLoansCount,
                        repaidLoansCount,
                        defaultCurrency,
                      ),
                    ),
                  ),

                  // Filter Chips Row
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          _buildFilterChip('All', theme, _loans.length),
                          const SizedBox(width: 8),
                          _buildFilterChip('Active', theme, activeLoansCount),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Fully Repaid',
                            theme,
                            repaidLoansCount,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Loans List or Empty State
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(theme),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final loan = filtered[index];
                            return _buildLoanCard(theme, loan);
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLoanSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Take a Loan',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor:
            isDark ? theme.colorScheme.primary : const Color(0xFF0F172A),
        foregroundColor:
            isDark ? const Color(0xFF0F172A) : Colors.white,
      ),
    );
  }

  Widget _buildOverviewCard(
    ThemeData theme,
    double totalOutstanding,
    double totalRepaid,
    double totalInterest,
    int activeCount,
    int repaidCount,
    String defaultCurrency,
  ) {
    final isDark = theme.brightness == Brightness.dark;
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
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
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.real_estate_agent_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TOTAL OUTSTANDING DEBT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: activeCount > 0
                      ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                      : const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: activeCount > 0
                        ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                        : const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  activeCount > 0
                      ? '$activeCount Active'
                      : 'Debt Free',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: activeCount > 0
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF6EE7B7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.formatCurrency(totalOutstanding, defaultCurrency),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Principal Repaid',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.formatCurrency(totalRepaid, defaultCurrency),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Interest Paid',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.formatCurrency(totalInterest, defaultCurrency),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Fully Repaid',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$repaidCount loan(s)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ThemeData theme, int count) {
    final isSelected = _selectedFilter == label;
    final isDark = theme.brightness == Brightness.dark;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedFilter = label);
      },
      selectedColor: theme.colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.15),
      checkmarkColor: theme.colorScheme.primary,
      backgroundColor: isDark ? theme.colorScheme.surface : null,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      side: BorderSide(
        color: isSelected
            ? theme.colorScheme.primary
            : (isDark
                ? theme.colorScheme.outlineVariant.withValues(alpha: 0.8)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildLoanCard(ThemeData theme, Loan loan) {
    final isDark = theme.brightness == Brightness.dark;
    final outstanding =
        _accountService.calculateOutstandingPrincipal(loan, _repayments);
    final repaid =
        _accountService.calculateTotalPrincipalRepaid(loan, _repayments);
    final progress =
        _accountService.calculateRepaymentProgress(loan, _repayments);
    final isRepaid = _accountService.isLoanFullyRepaid(loan, _repayments);

    final statusTextColor = isRepaid
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
        : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706));
    final statusBgColor = isRepaid
        ? (isDark
            ? const Color(0xFF10B981).withValues(alpha: 0.2)
            : const Color(0xFF10B981).withValues(alpha: 0.12))
        : (isDark
            ? const Color(0xFFD97706).withValues(alpha: 0.2)
            : const Color(0xFFD97706).withValues(alpha: 0.12));
    final repaidTextColor =
        isDark ? const Color(0xFF34D399) : const Color(0xFF059669);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openLoanDetails(loan),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Title & Status Chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loan.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (loan.lender.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Lender: ${loan.lender}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isRepaid ? 'Fully Repaid' : 'Active',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Outstanding amount and progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Outstanding Principal',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          Formatters.formatCurrency(
                            outstanding,
                            loan.currency,
                          ),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: isRepaid
                                ? repaidTextColor
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${progress.toStringAsFixed(1)}% repaid',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isRepaid
                            ? repaidTextColor
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (progress / 100.0).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isRepaid
                          ? (isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF10B981))
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Footer Row: Principal, Repaid, Net Proceeds
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Principal: ${Formatters.formatCurrency(loan.principal, loan.currency)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Repaid: ${Formatters.formatCurrency(repaid, loan.currency)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: repaidTextColor,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary
                    .withValues(alpha: isDark ? 0.15 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.real_estate_agent_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Loans Recorded',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Take a loan to record borrowed funds, track fees, '
              'allocate proceeds to your accounts, and monitor repayments.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
