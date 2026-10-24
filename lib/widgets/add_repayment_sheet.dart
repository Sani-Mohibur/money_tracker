import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account_allocation.dart';
import '../models/account_transfer.dart';
import '../models/currency.dart';
import '../models/loan.dart';
import '../models/loan_repayment.dart';
import '../models/money_account.dart';
import '../models/transaction.dart';
import '../services/account_service.dart';
import '../services/currency_service.dart';
import '../utils/formatters.dart';

/// Entry holder for dynamic repayment allocation rows.
class _RepaymentAllocationEntry {
  String? accountId;
  final TextEditingController controller;
  String? error;

  _RepaymentAllocationEntry({
    this.accountId,
    required this.controller,
  });

  void dispose() {
    controller.dispose();
  }
}

/// Modal bottom sheet for creating or editing a Loan Repayment.
class AddRepaymentSheet extends StatefulWidget {
  final Loan loan;
  final LoanRepayment? initialRepayment;
  final double currentOutstandingPrincipal;
  final bool isMoneyAccountsEnabled;
  final List<MoneyAccount> accounts;
  final List<Transaction> allTransactions;
  final List<AccountTransfer> transfers;
  final List<Loan> loans;
  final List<LoanRepayment> repayments;
  final Function(LoanRepayment repayment, Transaction? linkedInterestTransaction)
      onSave;

  const AddRepaymentSheet({
    super.key,
    required this.loan,
    this.initialRepayment,
    required this.currentOutstandingPrincipal,
    this.isMoneyAccountsEnabled = false,
    this.accounts = const [],
    this.allTransactions = const [],
    this.transfers = const [],
    this.loans = const [],
    this.repayments = const [],
    required this.onSave,
  });

  @override
  State<AddRepaymentSheet> createState() => _AddRepaymentSheetState();
}

class _AddRepaymentSheetState extends State<AddRepaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _principalController;
  late final TextEditingController _interestController;
  late final TextEditingController _noteController;

  late DateTime _selectedDate;
  final CurrencyService _currencyService = CurrencyService();
  late final AccountService _accountService;
  final List<_RepaymentAllocationEntry> _allocationEntries = [];

  bool get isEditMode => widget.initialRepayment != null;

  /// The max principal that can be repaid. If editing, add back the principal previously repaid.
  double get maxRepayablePrincipal {
    double maxVal = widget.currentOutstandingPrincipal;
    if (widget.initialRepayment != null) {
      maxVal += widget.initialRepayment!.principalAmount;
    }
    return maxVal;
  }

  @override
  void initState() {
    super.initState();
    _accountService = AccountService(_currencyService);
    final init = widget.initialRepayment;

    if (init != null) {
      _principalController = TextEditingController(
        text: init.principalAmount % 1 == 0
            ? init.principalAmount.toInt().toString()
            : init.principalAmount.toString(),
      );
      _interestController = TextEditingController(
        text: init.interestAmount % 1 == 0
            ? init.interestAmount.toInt().toString()
            : init.interestAmount.toString(),
      );
      _noteController = TextEditingController(text: init.note);
      _selectedDate = init.date;

      if (widget.isMoneyAccountsEnabled && init.allocations.isNotEmpty) {
        for (final alloc in init.allocations) {
          final ctrl = TextEditingController(
            text: alloc.amount % 1 == 0
                ? alloc.amount.toInt().toString()
                : alloc.amount.toString(),
          );
          ctrl.addListener(_onAllocationChanged);
          _allocationEntries.add(
            _RepaymentAllocationEntry(
              accountId: alloc.accountId,
              controller: ctrl,
            ),
          );
        }
      }
    } else {
      _principalController = TextEditingController();
      _interestController = TextEditingController(text: '0');
      _noteController = TextEditingController();
      _selectedDate = DateTime.now();
    }

    _principalController.addListener(_onAmountChanged);
    _interestController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _principalController.removeListener(_onAmountChanged);
    _interestController.removeListener(_onAmountChanged);
    _principalController.dispose();
    _interestController.dispose();
    _noteController.dispose();
    for (final entry in _allocationEntries) {
      entry.controller.removeListener(_onAllocationChanged);
      entry.dispose();
    }
    super.dispose();
  }

  void _onAmountChanged() {
    _validateAllocationsInline();
    setState(() {});
  }

  void _onAllocationChanged() {
    _validateAllocationsInline();
    setState(() {});
  }

  double get _principalAmount =>
      double.tryParse(_principalController.text.trim()) ?? 0.0;

  double get _interestAmount =>
      double.tryParse(_interestController.text.trim()) ?? 0.0;

  double get _totalPayment {
    final sum = _principalAmount + _interestAmount;
    final currency = AppCurrency.fromCode(widget.loan.currency);
    return AccountService.roundCurrency(sum, currency.decimalDigits);
  }

  double get _totalAllocated {
    double sum = 0.0;
    for (final entry in _allocationEntries) {
      final val = double.tryParse(entry.controller.text.trim()) ?? 0.0;
      sum += val;
    }
    final currency = AppCurrency.fromCode(widget.loan.currency);
    return AccountService.roundCurrency(sum, currency.decimalDigits);
  }

  double get _unassignedAmount {
    final diff = _totalPayment - _totalAllocated;
    final currency = AppCurrency.fromCode(widget.loan.currency);
    final rounded = AccountService.roundCurrency(diff, currency.decimalDigits);
    return rounded > 0.000001 ? rounded : 0.0;
  }

  List<MoneyAccount> get _availableAccounts {
    return widget.accounts.where((acc) {
      if (!acc.isArchived) return true;
      return _allocationEntries.any((entry) => entry.accountId == acc.id);
    }).toList();
  }

  double _getAvailableFundsForAccount(MoneyAccount account) {
    final currentBal = _accountService.calculateAccountBalance(
      account,
      widget.allTransactions,
      widget.transfers,
      loans: widget.loans,
      repayments: widget.repayments,
    );
    return _accountService.getAvailableFundsForRepayment(
      account: account,
      currentBalance: currentBal,
      existingRepayment: widget.initialRepayment,
    );
  }

  void _validateAllocationsInline() {
    final totalRequired = _totalPayment;
    final usedAccounts = <String>{};

    for (int i = 0; i < _allocationEntries.length; i++) {
      final entry = _allocationEntries[i];
      final val = double.tryParse(entry.controller.text.trim());

      if (entry.accountId == null || entry.accountId!.isEmpty) {
        entry.error = 'Select an account.';
        continue;
      }

      if (usedAccounts.contains(entry.accountId)) {
        entry.error = 'Account already allocated in this repayment.';
        continue;
      }
      usedAccounts.add(entry.accountId!);

      if (val == null || val <= 0) {
        entry.error = 'Amount must be > 0.';
        continue;
      }

      final account = widget.accounts.firstWhere(
        (a) => a.id == entry.accountId,
        orElse: () => MoneyAccount(
          id: '',
          name: 'Unknown',
          currency: widget.loan.currency,
          createdAt: DateTime.now(),
        ),
      );

      final available = _getAvailableFundsForAccount(account);
      final amtInAcc = _currencyService.convert(
        val,
        widget.loan.currency,
        account.currency,
      );

      if (amtInAcc > available + 0.0001) {
        entry.error =
            'Insufficient funds (Available: ${available.toStringAsFixed(2)} ${account.currency}).';
        continue;
      }

      entry.error = null;
    }

    if (_totalAllocated > totalRequired + 0.0001) {
      for (final entry in _allocationEntries) {
        entry.error ??= 'Total allocations exceed total payment.';
      }
    }
  }

  void _addAllocation() {
    final activeAccounts = _availableAccounts;
    final alreadySelectedIds = _allocationEntries
        .map((e) => e.accountId)
        .whereType<String>()
        .toSet();

    final remainingAccounts =
        activeAccounts.where((a) => !alreadySelectedIds.contains(a.id)).toList();

    if (remainingAccounts.isEmpty && activeAccounts.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All available accounts have already been added.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final String? defaultAccountId =
        remainingAccounts.isNotEmpty ? remainingAccounts.first.id : null;

    final remaining = _unassignedAmount;
    final ctrl = TextEditingController(
      text: remaining > 0
          ? (remaining % 1 == 0
              ? remaining.toInt().toString()
              : remaining.toStringAsFixed(2))
          : '',
    );
    ctrl.addListener(_onAllocationChanged);

    setState(() {
      _allocationEntries.add(
        _RepaymentAllocationEntry(
          accountId: defaultAccountId,
          controller: ctrl,
        ),
      );
      _validateAllocationsInline();
    });
  }

  void _removeAllocation(int index) {
    setState(() {
      final removed = _allocationEntries.removeAt(index);
      removed.controller.removeListener(_onAllocationChanged);
      removed.dispose();
      _validateAllocationsInline();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _repayAllRemaining() {
    final maxP = maxRepayablePrincipal;
    _principalController.text = maxP % 1 == 0
        ? maxP.toInt().toString()
        : maxP.toStringAsFixed(2);
    _validateAllocationsInline();
    setState(() {});
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final principal = _principalAmount;
    final interest = _interestAmount;
    final maxAllowedPrincipal = maxRepayablePrincipal;

    if (principal > maxAllowedPrincipal + 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Principal repayment cannot exceed outstanding principal (${maxAllowedPrincipal.toStringAsFixed(2)} ${widget.loan.currency}).',
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _validateAllocationsInline();
    if (_allocationEntries.any((e) => e.error != null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct allocation errors before saving.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_totalAllocated > _totalPayment + 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allocations cannot exceed total payment amount.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final List<AccountAllocation> allocations = [];
    if (widget.isMoneyAccountsEnabled) {
      for (final entry in _allocationEntries) {
        final amt = double.tryParse(entry.controller.text.trim()) ?? 0.0;
        if (entry.accountId != null && amt > 0) {
          allocations.add(
            AccountAllocation(
              accountId: entry.accountId!,
              amount: amt,
            ),
          );
        }
      }
    }

    final id = widget.initialRepayment?.id ??
        'rep-${DateTime.now().millisecondsSinceEpoch}';

    String? interestTxId = widget.initialRepayment?.interestTransactionId;
    Transaction? linkedInterestTx;

    if (interest > 0) {
      interestTxId ??= 'tx-interest-$id';
      final noteText = _noteController.text.trim();
      linkedInterestTx = Transaction(
        id: interestTxId,
        title: 'Loan Interest - ${widget.loan.title}',
        amount: interest,
        type: TransactionType.expense,
        category: 'Loan Interest',
        date: _selectedDate,
        note: noteText.isNotEmpty
            ? noteText
            : 'Interest paid for repayment of ${widget.loan.title}',
        currency: widget.loan.currency,
        allocations: const [],
      );
    }

    final repayment = LoanRepayment(
      id: id,
      loanId: widget.loan.id,
      principalAmount: principal,
      interestAmount: interest,
      date: _selectedDate,
      note: _noteController.text.trim(),
      currency: widget.loan.currency,
      allocations: allocations,
      interestTransactionId: interest > 0 ? interestTxId : null,
      createdAt: widget.initialRepayment?.createdAt ?? DateTime.now(),
    );

    widget.onSave(repayment, linkedInterestTx);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currency = AppCurrency.fromCode(widget.loan.currency);
    final maxP = maxRepayablePrincipal;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditMode ? 'Edit Repayment' : 'Repay Loan',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.loan.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable Form
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Outstanding Principal Info Row
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: isDark ? 0.12 : 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: isDark ? 0.35 : 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Outstanding Principal:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    Formatters.formatCurrency(
                                      maxP,
                                      widget.loan.currency,
                                    ),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                onPressed: _repayAllRemaining,
                                icon: const Icon(Icons.all_inclusive_rounded, size: 14),
                                label: const Text('Repay Full'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: theme.colorScheme.primary,
                                  side: BorderSide(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: isDark ? 0.6 : 0.4,
                                    ),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Principal & Interest Inputs Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Principal Repayment Amount
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _principalController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}'),
                                  ),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Principal Amount *',
                                  hintText: '0.00',
                                  prefixText: '${currency.symbol} ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Enter principal';
                                  }
                                  final num = double.tryParse(val.trim());
                                  if (num == null || num <= 0) {
                                    return 'Must be > 0';
                                  }
                                  if (num > maxP + 0.0001) {
                                    return 'Exceeds balance';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Interest Amount (Default 0)
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _interestController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}'),
                                  ),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Interest',
                                  hintText: '0',
                                  prefixText: '${currency.symbol} ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return null;
                                  }
                                  final num = double.tryParse(val.trim());
                                  if (num == null || num < 0) {
                                    return 'Interest >= 0';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Total Payment Outflow Display Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                : const Color(0xFFEF4444).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFFF87171).withValues(alpha: 0.4)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Cash Outflow:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    Formatters.formatCurrency(
                                      _totalPayment,
                                      widget.loan.currency,
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: isDark
                                          ? const Color(0xFFF87171)
                                          : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Principal Repayment (${Formatters.formatCurrency(_principalAmount, widget.loan.currency)}) '
                                '+ Interest (${Formatters.formatCurrency(_interestAmount, widget.loan.currency)}). '
                                '${_interestAmount > 0 ? "Only interest is recorded as an expense transaction." : "Zero-value expense is not created."}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Repayment Date Picker
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Repayment Date: ',
                                  style: TextStyle(fontSize: 13),
                                ),
                                Text(
                                  Formatters.formatDate(_selectedDate),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Notes Field
                        TextFormField(
                          controller: _noteController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Notes (Optional)',
                            hintText: 'e.g. Bank transfer reference, receipt ID',
                            prefixIcon: const Icon(Icons.notes_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Money Accounts Allocation
                        if (widget.isMoneyAccountsEnabled) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ACCOUNT ALLOCATION (PAYMENT OUTFLOW)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.8),
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    Text(
                                      'Deduct payment from money accounts',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addAllocation,
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: const Text('Add Account'),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (_allocationEntries.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                'No accounts assigned. The full payment (${Formatters.formatCurrency(_totalPayment, widget.loan.currency)}) will remain unassigned.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          else
                            ...List.generate(_allocationEntries.length, (index) {
                              final entry = _allocationEntries[index];
                              final accountsList = _availableAccounts;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // Account selector
                                        Expanded(
                                          flex: 3,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: entry.error != null
                                                    ? theme.colorScheme.error
                                                    : theme.colorScheme
                                                        .outlineVariant,
                                              ),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: entry.accountId,
                                                dropdownColor: theme.colorScheme.surface,
                                                isExpanded: true,
                                                hint: const Text(
                                                  'Select Account',
                                                  style: TextStyle(fontSize: 12),
                                                ),
                                                items: accountsList.map((acc) {
                                                  final avail =
                                                      _getAvailableFundsForAccount(
                                                    acc,
                                                  );
                                                  return DropdownMenuItem<String>(
                                                    value: acc.id,
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          acc.icon,
                                                          size: 16,
                                                          color: acc.color,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            '${acc.name} (${avail.toStringAsFixed(2)} ${acc.currency})',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                            overflow: TextOverflow
                                                                .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (val) {
                                                  setState(() {
                                                    entry.accountId = val;
                                                    _validateAllocationsInline();
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Amount field
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: entry.controller,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                              decimal: true,
                                            ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                RegExp(r'^\d*\.?\d{0,2}'),
                                              ),
                                            ],
                                            decoration: InputDecoration(
                                              hintText: '0.00',
                                              prefixText: '${currency.symbol} ',
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 12,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Remove row button
                                        IconButton(
                                          icon: Icon(
                                            Icons.remove_circle_outline_rounded,
                                            color: isDark
                                                ? const Color(0xFFF87171)
                                                : const Color(0xFFEF4444),
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              _removeAllocation(index),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                    if (entry.error != null) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 4,
                                          top: 4,
                                        ),
                                        child: Text(
                                          entry.error!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),

                          const SizedBox(height: 6),
                          // Unassigned tracking summary
                          Builder(
                            builder: (context) {
                              final hasUnassigned = _unassignedAmount > 0;
                              final summaryColor = hasUnassigned
                                  ? (isDark
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFFD97706))
                                  : (isDark
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFF059669));
                              final summaryBgColor = hasUnassigned
                                  ? (isDark
                                      ? const Color(0xFFFBBF24).withValues(alpha: 0.15)
                                      : const Color(0xFFD97706).withValues(alpha: 0.1))
                                  : (isDark
                                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                      : const Color(0xFF10B981).withValues(alpha: 0.1));
                              final summaryBorderColor = hasUnassigned
                                  ? (isDark
                                      ? const Color(0xFFFBBF24).withValues(alpha: 0.4)
                                      : const Color(0xFFD97706).withValues(alpha: 0.3))
                                  : (isDark
                                      ? const Color(0xFF34D399).withValues(alpha: 0.4)
                                      : const Color(0xFF10B981).withValues(alpha: 0.3));

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: summaryBgColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: summaryBorderColor),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          hasUnassigned
                                              ? Icons.info_outline_rounded
                                              : Icons.check_circle_outline_rounded,
                                          size: 15,
                                          color: summaryColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          hasUnassigned
                                              ? 'Unassigned Payment:'
                                              : 'Payment Fully Allocated',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: summaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (hasUnassigned)
                                      Text(
                                        Formatters.formatCurrency(
                                          _unassignedAmount,
                                          widget.loan.currency,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: summaryColor,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _submit,
                            icon: Icon(
                              isEditMode ? Icons.save_rounded : Icons.payment_rounded,
                            ),
                            label: Text(
                              isEditMode ? 'Update Repayment' : 'Record Repayment',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: isDark
                                  ? theme.colorScheme.primary
                                  : const Color(0xFF0F172A),
                              foregroundColor: isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
