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
import '../widgets/add_repayment_sheet.dart';

/// Screen displaying complete details, progress indicator, and repayment history
/// for an individual borrowed loan.
class LoanDetailsScreen extends StatefulWidget {
  final Loan loan;
  final List<Transaction> transactions;
  final List<MoneyAccount> accounts;
  final List<AccountTransfer> transfers;
  final List<Loan> allLoans;
  final List<LoanRepayment> allRepayments;
  final bool isMoneyAccountsEnabled;
  final VoidCallback onDataChanged;

  const LoanDetailsScreen({
    super.key,
    required this.loan,
    required this.transactions,
    required this.accounts,
    required this.transfers,
    required this.allLoans,
    required this.allRepayments,
    this.isMoneyAccountsEnabled = false,
    required this.onDataChanged,
  });

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen> {
  final StorageService _storageService = StorageService();
  final CurrencyService _currencyService = CurrencyService();
  late final AccountService _accountService;

  late Loan _loan;
  late List<LoanRepayment> _repayments;
  late List<Transaction> _transactions;
  late List<MoneyAccount> _accounts;
  late List<AccountTransfer> _transfers;
  late List<Loan> _allLoans;
  late List<LoanRepayment> _allRepayments;

  @override
  void initState() {
    super.initState();
    _accountService = AccountService(_currencyService);
    _loan = widget.loan;
    _transactions = List.from(widget.transactions);
    _accounts = List.from(widget.accounts);
    _transfers = List.from(widget.transfers);
    _allLoans = List.from(widget.allLoans);
    _allRepayments = List.from(widget.allRepayments);
    _repayments = _allRepayments
        .where((r) => r.loanId == widget.loan.id)
        .toList();
    _loadFreshData();
  }

  Future<void> _loadFreshData() async {
    final freshLoans = await _storageService.loadLoans();
    final freshAllRepayments = await _storageService.loadLoanRepayments();
    final freshRepayments =
        freshAllRepayments.where((r) => r.loanId == widget.loan.id).toList();
    final freshTransactions = await _storageService.loadTransactions();
    final freshAccounts = await _storageService.loadAccounts();
    final freshTransfers = await _storageService.loadTransfers();

    final currentLoan = freshLoans.firstWhere(
      (l) => l.id == widget.loan.id,
      orElse: () => _loan,
    );

    if (!mounted) return;
    setState(() {
      _loan = currentLoan;
      _allRepayments = freshAllRepayments;
      _repayments = freshRepayments;
      _allLoans = freshLoans;
      _transactions = freshTransactions;
      _accounts = freshAccounts;
      _transfers = freshTransfers;
    });
  }

  double get _outstandingPrincipal =>
      _accountService.calculateOutstandingPrincipal(_loan, _repayments);

  double get _totalPrincipalRepaid =>
      _accountService.calculateTotalPrincipalRepaid(_loan, _repayments);

  double get _totalInterestPaid =>
      _accountService.calculateTotalInterestPaid(_loan, _repayments);

  double get _repaymentProgress =>
      _accountService.calculateRepaymentProgress(_loan, _repayments);

  bool get _isFullyRepaid =>
      _accountService.isLoanFullyRepaid(_loan, _repayments);

  void _showAddRepaymentSheet([LoanRepayment? existingRepayment]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddRepaymentSheet(
        loan: _loan,
        initialRepayment: existingRepayment,
        currentOutstandingPrincipal: _outstandingPrincipal,
        isMoneyAccountsEnabled: widget.isMoneyAccountsEnabled,
        accounts: _accounts,
        allTransactions: _transactions,
        transfers: _transfers,
        loans: _allLoans,
        repayments: _allRepayments,
        onSave: (repayment, interestTx) async {
          await _storageService.saveRepaymentWithInterest(
            repayment: repayment,
            interestTransaction: interestTx,
          );
          await _loadFreshData();
          widget.onDataChanged();

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                existingRepayment != null
                    ? 'Repayment updated successfully'
                    : 'Repayment of ${Formatters.formatCurrency(repayment.totalPayment, _loan.currency)} recorded',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _showEditLoanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddLoanSheet(
        initialLoan: _loan,
        isMoneyAccountsEnabled: widget.isMoneyAccountsEnabled,
        accounts: _accounts,
        alreadyRepaidPrincipal: _totalPrincipalRepaid,
        onSave: (updated) async {
          await _storageService.updateLoan(updated);
          await _loadFreshData();
          widget.onDataChanged();

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loan details updated'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteRepayment(LoanRepayment repayment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Repayment?'),
        content: Text(
          'Are you sure you want to delete this repayment of '
          '${Formatters.formatCurrency(repayment.totalPayment, repayment.currency)}?\n\n'
          'This will restore ${Formatters.formatCurrency(repayment.principalAmount, repayment.currency)} to the loan liability, '
          'reverse account allocations, and remove its linked interest expense transaction.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Repayment'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storageService.deleteRepaymentWithInterest(repayment.id);
      await _loadFreshData();
      widget.onDataChanged();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Repayment deleted and balance restored.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteLoan() async {
    final hasRepayments = _repayments.isNotEmpty;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${_loan.title}"?'),
        content: Text(
          hasRepayments
              ? 'This loan has ${_repayments.length} recorded repayment(s).\n\n'
                  'Deleting this loan will permanently delete all its repayments, reverse account allocations, '
                  'and remove all associated interest expense transactions.\n\n'
                  'Are you sure you want to proceed?'
              : 'Are you sure you want to delete this loan record? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storageService.deleteLoanWithRepayments(_loan.id);
      widget.onDataChanged();

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loan "${_loan.title}" deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isFullyRepaid = _isFullyRepaid;
    final progress = _repaymentProgress;

    return Scaffold(
      appBar: AppBar(
        title: Text(_loan.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Loan',
            onPressed: _showEditLoanSheet,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'delete') {
                _deleteLoan();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: isDark
                          ? const Color(0xFFF87171)
                          : const Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Delete Loan',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFF87171)
                            : const Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Status Card
            _buildHeroProgressCard(theme, isFullyRepaid, progress),
            const SizedBox(height: 16),

            // Financial Summary Grid
            _buildFinancialSummaryGrid(theme),
            const SizedBox(height: 16),

            // Loan Allocations (if Money Accounts enabled and allocations exist)
            if (widget.isMoneyAccountsEnabled && _loan.allocations.isNotEmpty) ...[
              _buildLoanAllocationsSection(theme),
              const SizedBox(height: 16),
            ],

            // Action: Repay Button (if not fully repaid)
            if (!isFullyRepaid)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => _showAddRepaymentSheet(),
                  icon: const Icon(Icons.payment_rounded),
                  label: const Text(
                    'Make Repayment',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark
                        ? theme.colorScheme.primary
                        : const Color(0xFF0F172A),
                    foregroundColor:
                        isDark ? const Color(0xFF0F172A) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF10B981).withValues(alpha: 0.18)
                      : const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF34D399).withValues(alpha: 0.5)
                        : const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: isDark
                          ? const Color(0xFF34D399)
                          : const Color(0xFF059669),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'This loan is fully repaid',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF34D399)
                            : const Color(0xFF059669),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Repayment History Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'REPAYMENT HISTORY (${_repayments.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    letterSpacing: 1.1,
                  ),
                ),
                if (!isFullyRepaid && _repayments.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _showAddRepaymentSheet(),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Repayment'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Repayment History List or Empty State
            if (_repayments.isEmpty)
              _buildEmptyRepaymentHistory(theme)
            else
              ..._repayments.map((rep) => _buildRepaymentTile(theme, rep)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroProgressCard(
    ThemeData theme,
    bool isFullyRepaid,
    double progress,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFullyRepaid
              ? [const Color(0xFF065F46), const Color(0xFF047857)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
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
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _loan.lender.isNotEmpty
                        ? 'Lender: ${_loan.lender}'
                        : 'Loan Liability',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isFullyRepaid
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFullyRepaid
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFullyRepaid
                          ? Icons.check_circle_rounded
                          : Icons.pending_actions_rounded,
                      color: isFullyRepaid
                          ? Colors.white
                          : const Color(0xFFFBBF24),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isFullyRepaid ? 'Fully Repaid' : 'Active Loan',
                      style: TextStyle(
                        color: isFullyRepaid
                            ? Colors.white
                            : const Color(0xFFFBBF24),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            'OUTSTANDING PRINCIPAL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.formatCurrency(
                _outstandingPrincipal,
                _loan.currency,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Repayment Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Repayment Progress',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              Text(
                '${progress.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (progress / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                isFullyRepaid
                    ? const Color(0xFF34D399)
                    : const Color(0xFF38BDF8),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Repaid ${Formatters.formatCurrency(_totalPrincipalRepaid, _loan.currency)} '
            'of ${Formatters.formatCurrency(_loan.principal, _loan.currency)} original principal',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryGrid(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Loan Accounting Breakdown',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildSummaryRow(
            'Original Principal',
            Formatters.formatCurrency(_loan.principal, _loan.currency),
            theme,
          ),
          _buildSummaryRow(
            'Loan Fee (Deducted upfront)',
            Formatters.formatCurrency(_loan.fee, _loan.currency),
            theme,
          ),
          _buildSummaryRow(
            'Net Amount Received',
            Formatters.formatCurrency(_loan.netAmountReceived, _loan.currency),
            theme,
            isHighlight: true,
          ),
          const Divider(height: 16),
          _buildSummaryRow(
            'Total Principal Repaid',
            Formatters.formatCurrency(_totalPrincipalRepaid, _loan.currency),
            theme,
            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
          ),
          _buildSummaryRow(
            'Total Interest Paid',
            Formatters.formatCurrency(_totalInterestPaid, _loan.currency),
            theme,
            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
          ),
          _buildSummaryRow(
            'Total Payment Cash Outflow',
            Formatters.formatCurrency(
              _totalPrincipalRepaid + _totalInterestPaid,
              _loan.currency,
            ),
            theme,
            color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
          ),
          const Divider(height: 16),
          _buildSummaryRow(
            'Loan Date',
            Formatters.formatDate(_loan.date),
            theme,
          ),
          if (_loan.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Notes: ${_loan.note}',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    ThemeData theme, {
    bool isHighlight = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
              color: isHighlight
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
              color: color ??
                  (isHighlight
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanAllocationsSection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net Proceeds Account Allocations',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_loan.hasUnassigned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFD97706).withValues(alpha: 0.2)
                        : const Color(0xFFD97706).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Unassigned: ${Formatters.formatCurrency(_loan.unassignedAmount, _loan.currency)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ..._loan.allocations.map((alloc) {
            final acc = _accounts.firstWhere(
              (a) => a.id == alloc.accountId,
              orElse: () => MoneyAccount(
                id: alloc.accountId,
                name: 'Account',
                currency: _loan.currency,
                createdAt: DateTime.now(),
              ),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(acc.icon, size: 16, color: acc.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      acc.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(alloc.amount, _loan.currency),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyRepaymentHistory(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 10),
          const Text(
            'No Repayments Yet',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'When you pay down principal or pay interest, tap "Make Repayment" to track it here.',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRepaymentTile(ThemeData theme, LoanRepayment rep) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(14),
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
                      color: isDark
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: isDark
                          ? const Color(0xFF34D399)
                          : const Color(0xFF059669),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Formatters.formatDate(rep.date),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Edit Repayment',
                    onPressed: () => _showAddRepaymentSheet(rep),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: isDark
                          ? const Color(0xFFF87171)
                          : const Color(0xFFEF4444),
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete Repayment',
                    onPressed: () => _deleteRepayment(rep),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 14),

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
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(
                      rep.principalAmount,
                      rep.currency,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF34D399)
                          : const Color(0xFF059669),
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
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(
                      rep.interestAmount,
                      rep.currency,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: rep.interestAmount > 0
                          ? (isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFD97706))
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total Payment',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(
                      rep.totalPayment,
                      rep.currency,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFFF87171)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (rep.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Note: ${rep.note}',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          if (widget.isMoneyAccountsEnabled && rep.allocations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: rep.allocations.map((alloc) {
                final acc = _accounts.firstWhere(
                  (a) => a.id == alloc.accountId,
                  orElse: () => MoneyAccount(
                    id: alloc.accountId,
                    name: 'Account',
                    currency: rep.currency,
                    createdAt: DateTime.now(),
                  ),
                );
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(acc.icon, size: 12, color: acc.color),
                      const SizedBox(width: 4),
                      Text(
                        '${acc.name}: ${Formatters.formatCurrency(alloc.amount, rep.currency)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
