import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account_allocation.dart';
import '../models/currency.dart';
import '../models/loan.dart';
import '../models/money_account.dart';
import '../services/account_service.dart';
import '../services/currency_service.dart';
import '../utils/formatters.dart';

/// Entry holder for dynamic loan allocation rows.
class _LoanAllocationEntry {
  String? accountId;
  final TextEditingController controller;
  String? error;

  _LoanAllocationEntry({
    this.accountId,
    required this.controller,
  });

  void dispose() {
    controller.dispose();
  }
}

/// Modal bottom sheet for creating or editing a Loan.
class AddLoanSheet extends StatefulWidget {
  final Loan? initialLoan;
  final bool isMoneyAccountsEnabled;
  final List<MoneyAccount> accounts;
  final double alreadyRepaidPrincipal;
  final Function(Loan) onSave;

  const AddLoanSheet({
    super.key,
    this.initialLoan,
    this.isMoneyAccountsEnabled = false,
    this.accounts = const [],
    this.alreadyRepaidPrincipal = 0.0,
    required this.onSave,
  });

  @override
  State<AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends State<AddLoanSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _lenderController;
  late final TextEditingController _principalController;
  late final TextEditingController _feeController;
  late final TextEditingController _noteController;

  late DateTime _selectedDate;
  late String _selectedCurrencyCode;

  final CurrencyService _currencyService = CurrencyService();
  final List<_LoanAllocationEntry> _allocationEntries = [];

  bool get isEditMode => widget.initialLoan != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initialLoan;

    if (init != null) {
      _titleController = TextEditingController(text: init.title);
      _lenderController = TextEditingController(text: init.lender);
      _principalController = TextEditingController(
        text: init.principal % 1 == 0
            ? init.principal.toInt().toString()
            : init.principal.toString(),
      );
      _feeController = TextEditingController(
        text: init.fee % 1 == 0
            ? init.fee.toInt().toString()
            : init.fee.toString(),
      );
      _noteController = TextEditingController(text: init.note);
      _selectedDate = init.date;
      _selectedCurrencyCode = init.currency;

      if (widget.isMoneyAccountsEnabled && init.allocations.isNotEmpty) {
        for (final alloc in init.allocations) {
          final ctrl = TextEditingController(
            text: alloc.amount % 1 == 0
                ? alloc.amount.toInt().toString()
                : alloc.amount.toString(),
          );
          ctrl.addListener(_onAllocationChanged);
          _allocationEntries.add(
            _LoanAllocationEntry(
              accountId: alloc.accountId,
              controller: ctrl,
            ),
          );
        }
      }
    } else {
      _titleController = TextEditingController();
      _lenderController = TextEditingController();
      _principalController = TextEditingController();
      _feeController = TextEditingController(text: '0');
      _noteController = TextEditingController();
      _selectedDate = DateTime.now();
      _selectedCurrencyCode = _currencyService.defaultCurrencyCode;
    }

    _principalController.addListener(_onAmountChanged);
    _feeController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _principalController.removeListener(_onAmountChanged);
    _feeController.removeListener(_onAmountChanged);
    _titleController.dispose();
    _lenderController.dispose();
    _principalController.dispose();
    _feeController.dispose();
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

  double get _feeAmount =>
      double.tryParse(_feeController.text.trim()) ?? 0.0;

  double get _netAmountReceived {
    final net = _principalAmount - _feeAmount;
    final currency = AppCurrency.fromCode(_selectedCurrencyCode);
    return AccountService.roundCurrency(
      net > 0 ? net : 0.0,
      currency.decimalDigits,
    );
  }

  double get _totalAllocated {
    double sum = 0.0;
    for (final entry in _allocationEntries) {
      final val = double.tryParse(entry.controller.text.trim()) ?? 0.0;
      sum += val;
    }
    final currency = AppCurrency.fromCode(_selectedCurrencyCode);
    return AccountService.roundCurrency(sum, currency.decimalDigits);
  }

  double get _unassignedAmount {
    final diff = _netAmountReceived - _totalAllocated;
    final currency = AppCurrency.fromCode(_selectedCurrencyCode);
    final rounded = AccountService.roundCurrency(diff, currency.decimalDigits);
    return rounded > 0.000001 ? rounded : 0.0;
  }

  List<MoneyAccount> get _availableAccounts {
    return widget.accounts.where((acc) {
      if (!acc.isArchived) return true;
      return _allocationEntries.any((entry) => entry.accountId == acc.id);
    }).toList();
  }

  void _validateAllocationsInline() {
    final net = _netAmountReceived;
    final usedAccounts = <String>{};

    for (int i = 0; i < _allocationEntries.length; i++) {
      final entry = _allocationEntries[i];
      final val = double.tryParse(entry.controller.text.trim());

      if (entry.accountId == null || entry.accountId!.isEmpty) {
        entry.error = 'Select an account.';
        continue;
      }

      if (usedAccounts.contains(entry.accountId)) {
        entry.error = 'Account already allocated in this loan.';
        continue;
      }
      usedAccounts.add(entry.accountId!);

      if (val == null || val <= 0) {
        entry.error = 'Amount must be > 0.';
        continue;
      }

      entry.error = null;
    }

    if (_totalAllocated > net + 0.0001) {
      for (final entry in _allocationEntries) {
        entry.error ??= 'Total allocations exceed net proceeds.';
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
        _LoanAllocationEntry(
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final principal = _principalAmount;
    final fee = _feeAmount;

    if (fee >= principal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loan fee must be less than the loan principal.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (principal < widget.alreadyRepaidPrincipal - 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Principal cannot be less than already repaid principal (${widget.alreadyRepaidPrincipal.toStringAsFixed(2)}).',
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

    if (_totalAllocated > _netAmountReceived + 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allocations cannot exceed net received amount.'),
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

    final id = widget.initialLoan?.id ??
        'loan-${DateTime.now().millisecondsSinceEpoch}';

    final loan = Loan(
      id: id,
      title: _titleController.text.trim(),
      lender: _lenderController.text.trim(),
      principal: principal,
      fee: fee,
      date: _selectedDate,
      note: _noteController.text.trim(),
      currency: _selectedCurrencyCode,
      allocations: allocations,
      createdAt: widget.initialLoan?.createdAt ?? DateTime.now(),
      isArchived: widget.initialLoan?.isArchived ?? false,
    );

    widget.onSave(loan);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currency = AppCurrency.fromCode(_selectedCurrencyCode);

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
                    Text(
                      isEditMode ? 'Edit Loan' : 'Take a Loan',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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
                        // Loan Name/Title
                        TextFormField(
                          controller: _titleController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Loan Name *',
                            hintText: 'e.g. Personal Loan, Bank Loan, Car Loan',
                            prefixIcon: const Icon(Icons.edit_note_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a loan title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Lender Name (Optional)
                        TextFormField(
                          controller: _lenderController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Lender (Optional)',
                            hintText: 'e.g. Bank of America, Alice, Family',
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Currency and Date Row
                        Row(
                          children: [
                            // Currency Selector
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedCurrencyCode,
                                    dropdownColor: theme.colorScheme.surface,
                                    isExpanded: true,
                                    items: AppCurrency.all.map((c) {
                                      return DropdownMenuItem<String>(
                                        value: c.code,
                                        child: Text(
                                          '${c.symbol} ${c.code}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedCurrencyCode = val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Date Picker Button
                            Expanded(
                              child: InkWell(
                                onTap: _pickDate,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
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
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          Formatters.formatDate(_selectedDate),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Principal & Fee Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Loan Principal
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
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Loan Fee (Default 0)
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _feeController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}'),
                                  ),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Loan Fee',
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
                                    return 'Fee >= 0';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Net Proceeds Calculation Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Net Amount Received:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    Formatters.formatCurrency(
                                      _netAmountReceived,
                                      _selectedCurrencyCode,
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Principal (${Formatters.formatCurrency(_principalAmount, _selectedCurrencyCode)}) - Fee (${Formatters.formatCurrency(_feeAmount, _selectedCurrencyCode)}). '
                                'Only the net proceeds affect your available balance.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Notes Field
                        TextFormField(
                          controller: _noteController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Notes (Optional)',
                            hintText: 'Add loan terms, repayment schedule, or agreement note',
                            prefixIcon: const Icon(Icons.notes_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Money Accounts Allocation (only visible when Money Accounts enabled)
                        if (widget.isMoneyAccountsEnabled) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ACCOUNT ALLOCATION',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.8),
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    Text(
                                      'Allocate net proceeds to money accounts',
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
                                'No accounts assigned yet. The full net proceeds (${Formatters.formatCurrency(_netAmountReceived, _selectedCurrencyCode)}) will remain unassigned.',
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
                                                            '${acc.name} (${acc.currency})',
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
                                      ? const Color(0xFFD97706).withValues(alpha: 0.2)
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
                                              ? 'Unassigned Proceeds:'
                                              : 'Proceeds Fully Allocated',
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
                                          _selectedCurrencyCode,
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
                              isEditMode ? Icons.save_rounded : Icons.add_rounded,
                            ),
                            label: Text(
                              isEditMode ? 'Update Loan' : 'Record Loan',
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
