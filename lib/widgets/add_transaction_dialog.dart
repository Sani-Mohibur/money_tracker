import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/categories.dart';
import '../models/account_allocation.dart';
import '../models/account_transfer.dart';
import '../models/currency.dart';
import '../models/money_account.dart';
import '../models/transaction.dart';
import '../services/account_service.dart';
import '../services/currency_service.dart';
import '../utils/formatters.dart';

/// Allocation item holder for dynamic allocation form rows.
class _AllocationEntry {
  String? accountId;
  final TextEditingController controller;
  String? error;

  _AllocationEntry({
    this.accountId,
    required this.controller,
  });

  void dispose() {
    controller.dispose();
  }
}

/// Modal bottom sheet for creating or editing an Income or Expense transaction,
/// with optional Money Account allocation when enabled.
class AddTransactionSheet extends StatefulWidget {
  final Function(Transaction) onSave;
  final Transaction? initialTransaction;
  final bool isMoneyAccountsEnabled;
  final List<MoneyAccount> accounts;
  final List<Transaction> allTransactions;
  final List<AccountTransfer> transfers;

  const AddTransactionSheet({
    super.key,
    required this.onSave,
    this.initialTransaction,
    this.isMoneyAccountsEnabled = false,
    this.accounts = const [],
    this.allTransactions = const [],
    this.transfers = const [],
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  late TransactionType _selectedType;
  late String _selectedCategory;
  late DateTime _selectedDate;
  late String _selectedCurrencyCode;

  final CurrencyService _currencyService = CurrencyService();
  late final AccountService _accountService;

  final List<_AllocationEntry> _allocationEntries = [];

  bool get isEditMode => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    _accountService = AccountService(_currencyService);
    final init = widget.initialTransaction;

    if (init != null) {
      _selectedType = init.type;
      _selectedCategory = init.category;
      _selectedDate = init.date;
      _selectedCurrencyCode = init.currency;
      _amountController = TextEditingController(
        text: init.amount % 1 == 0
            ? init.amount.toInt().toString()
            : init.amount.toString(),
      );
      _titleController = TextEditingController(text: init.title);
      _noteController = TextEditingController(text: init.note);

      // Restore existing allocations if Money Accounts is enabled
      if (widget.isMoneyAccountsEnabled && init.allocations.isNotEmpty) {
        for (final alloc in init.allocations) {
          final ctrl = TextEditingController(
            text: alloc.amount % 1 == 0
                ? alloc.amount.toInt().toString()
                : alloc.amount.toString(),
          );
          ctrl.addListener(_onAllocationChanged);
          _allocationEntries.add(
            _AllocationEntry(
              accountId: alloc.accountId,
              controller: ctrl,
            ),
          );
        }
      }
    } else {
      _selectedType = TransactionType.expense;
      _selectedCategory = AppCategories.expenseCategories.first.name;
      _selectedDate = DateTime.now();
      _selectedCurrencyCode = _currencyService.defaultCurrencyCode;
      _amountController = TextEditingController();
      _titleController = TextEditingController();
      _noteController = TextEditingController();
    }

    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _titleController.dispose();
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

  double get _transactionAmount {
    return double.tryParse(_amountController.text.trim()) ?? 0.0;
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
    final diff = _transactionAmount - _totalAllocated;
    final currency = AppCurrency.fromCode(_selectedCurrencyCode);
    final rounded = AccountService.roundCurrency(diff, currency.decimalDigits);
    return rounded > 0.000001 ? rounded : 0.0;
  }

  /// Active accounts selectable for allocations (plus accounts already allocated in this transaction)
  List<MoneyAccount> get _availableAccounts {
    return widget.accounts.where((acc) {
      if (!acc.isArchived) return true;
      // Allow archived account only if it was already selected previously in this transaction
      return _allocationEntries.any((entry) => entry.accountId == acc.id);
    }).toList();
  }

  double _getAvailableFundsForAccount(MoneyAccount account) {
    final currentBal = _accountService.calculateAccountBalance(
      account,
      widget.allTransactions,
      widget.transfers,
    );
    return _accountService.getAvailableFundsForTransaction(
      account: account,
      currentBalance: currentBal,
      existingTransaction: widget.initialTransaction,
    );
  }

  void _validateAllocationsInline() {
    final txAmt = _transactionAmount;
    final usedAccounts = <String>{};

    for (int i = 0; i < _allocationEntries.length; i++) {
      final entry = _allocationEntries[i];
      final val = double.tryParse(entry.controller.text.trim());

      if (entry.accountId == null || entry.accountId!.isEmpty) {
        entry.error = 'Select an account.';
        continue;
      }

      if (usedAccounts.contains(entry.accountId)) {
        entry.error = 'Account already allocated in this transaction.';
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
          currency: _selectedCurrencyCode,
          createdAt: DateTime.now(),
        ),
      );

      // Check available funds for expense
      if (_selectedType == TransactionType.expense) {
        final available = _getAvailableFundsForAccount(account);
        final amtInAcc = _currencyService.convert(
          val,
          _selectedCurrencyCode,
          account.currency,
        );

        if (amtInAcc > available + 0.0001) {
          entry.error =
              'Exceeds available funds (${available.toStringAsFixed(2)} ${account.currency}).';
          continue;
        }
      }

      entry.error = null;
    }

    if (_totalAllocated > txAmt + 0.0001) {
      // Mark error on allocation entries that push it over
      for (final entry in _allocationEntries) {
        entry.error ??= 'Total allocations exceed transaction amount.';
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

    // Prefill with remaining unassigned amount if > 0
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
        _AllocationEntry(
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

  void _onTypeChanged(TransactionType type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      final categories = AppCategories.getCategoriesForType(type);
      _selectedCategory = categories.first.name;
      _validateAllocationsInline();
    });
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: _selectedType == TransactionType.income
                ? ColorScheme.fromSeed(seedColor: const Color(0xFF10B981))
                : ColorScheme.fromSeed(seedColor: const Color(0xFFEF4444)),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount greater than 0'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    // Money Accounts allocation validations
    List<AccountAllocation> allocations = [];
    if (widget.isMoneyAccountsEnabled && _allocationEntries.isNotEmpty) {
      _validateAllocationsInline();

      for (final entry in _allocationEntries) {
        if (entry.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please resolve allocation error: ${entry.error}'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      if (_totalAllocated > amount + 0.0001) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Total allocated cannot exceed transaction amount.'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      for (final entry in _allocationEntries) {
        final val = double.tryParse(entry.controller.text.trim()) ?? 0.0;
        if (entry.accountId != null && val > 0) {
          allocations.add(
            AccountAllocation(
              accountId: entry.accountId!,
              amount: val,
            ),
          );
        }
      }
    } else if (!widget.isMoneyAccountsEnabled && widget.initialTransaction != null) {
      // Preserve any existing allocations when feature is toggled off
      allocations = widget.initialTransaction!.allocations;
    }

    final String title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : _selectedCategory;

    final transaction = Transaction(
      id: widget.initialTransaction?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      type: _selectedType,
      category: _selectedCategory,
      date: _selectedDate,
      note: _noteController.text.trim(),
      currency: _selectedCurrencyCode,
      allocations: allocations,
    );

    widget.onSave(transaction);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isIncome = _selectedType == TransactionType.income;
    final primaryColor = isIncome
        ? const Color(0xFF10B981) // Emerald
        : const Color(0xFFEF4444); // Crimson
    final categories = AppCategories.getCategoriesForType(_selectedType);
    final currency = AppCurrency.fromCode(_selectedCurrencyCode);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Sheet Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditMode ? 'Edit Transaction' : 'New Transaction',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Income / Expense Toggle Segment
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        // Expense Tab
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _onTypeChanged(TransactionType.expense),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !isIncome ? const Color(0xFFEF4444) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: !isIncome
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 18,
                                    color: !isIncome ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Expense',
                                    style: TextStyle(
                                      color: !isIncome ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Income Tab
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _onTypeChanged(TransactionType.income),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isIncome ? const Color(0xFF10B981) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isIncome
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 18,
                                    color: isIncome ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Income',
                                    style: TextStyle(
                                      color: isIncome ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
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
                  const SizedBox(height: 18),

                  // Amount & Currency Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount Input
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Amount',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                              decoration: InputDecoration(
                                prefixIcon: Padding(
                                    padding: const EdgeInsets.only(left: 14, right: 6),
                                    child: Text(
                                      currency.symbol,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: primaryColor,
                                      ),
                                    )),
                                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                hintText: '0.00',
                                hintStyle: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w400,
                                  color: theme.hintColor.withValues(alpha: 0.4),
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter amount';
                                }
                                final parsed = double.tryParse(val.trim());
                                if (parsed == null || parsed <= 0) {
                                  return 'Must be > 0';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Currency Selector Dropdown
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Currency',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 62,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCurrencyCode,
                                  isExpanded: true,
                                  borderRadius: BorderRadius.circular(16),
                                  items: AppCurrency.all.map((c) {
                                    return DropdownMenuItem<String>(
                                      value: c.code,
                                      child: Row(
                                        children: [
                                          Text(
                                            c.symbol,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            c.code,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedCurrencyCode = val;
                                        _validateAllocationsInline();
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // =========================================================
                  // MONEY ALLOCATION SECTION (Conditional on Feature Toggle)
                  // =========================================================
                  if (widget.isMoneyAccountsEnabled) ...[
                    _buildMoneyAllocationSection(theme, primaryColor),
                    const SizedBox(height: 18),
                  ],

                  // Category Selector
                  Text(
                    'Category',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isSelected = cat.name == _selectedCategory;
                        return ChoiceChip(
                          avatar: Icon(
                            cat.icon,
                            size: 18,
                            color: isSelected ? Colors.white : cat.color,
                          ),
                          label: Text(cat.name),
                          selected: isSelected,
                          selectedColor: primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isSelected
                                  ? primaryColor
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = cat.name;
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Date and Title/Note Inputs in a clean card
                  Row(
                    children: [
                      // Date Selector Button
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_month_rounded,
                                      size: 18,
                                      color: primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        Formatters.formatFriendlyDate(_selectedDate),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title / Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Title / Label',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                hintText: _selectedCategory,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Optional Note
                  Text(
                    'Optional Note',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g., Grocery shopping, salary bonus...',
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Submit Button
                  FilledButton.icon(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      isEditMode
                          ? 'Update Transaction'
                          : (isIncome ? 'Save Income' : 'Save Expense'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the Money Allocation section with inline live recalculations,
  /// multi-account allocation rows, and available funds checks.
  Widget _buildMoneyAllocationSection(ThemeData theme, Color primaryColor) {
    final availableAccounts = _availableAccounts;
    final totalAlloc = _totalAllocated;
    final txAmount = _transactionAmount;
    final unassigned = _unassignedAmount;
    final isOverAllocated = totalAlloc > txAmount + 0.0001;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOverAllocated
              ? const Color(0xFFEF4444)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: isOverAllocated ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.pie_chart_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Money Allocation',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: availableAccounts.isEmpty ? null : _addAllocation,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Account', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Optionally allocate funds to one or more accounts. Any remaining amount stays unassigned.',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Allocation Rows
          if (_allocationEntries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No accounts selected. Entire amount will remain unassigned.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _allocationEntries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = _allocationEntries[index];
                return _buildAllocationRow(index, entry, theme);
              },
            ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Allocation Calculation Summary (Total, Allocated, Unassigned)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Allocated',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(totalAlloc, _selectedCurrencyCode),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isOverAllocated ? const Color(0xFFEF4444) : null,
                    ),
                  ),
                ],
              ),
              Container(
                height: 24,
                width: 1,
                color: theme.dividerColor,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Unassigned Amount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: unassigned > 0
                              ? const Color(0xFFD97706)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (unassigned > 0) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.help_outline_rounded,
                          size: 13,
                          color: Color(0xFFD97706),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    Formatters.formatCurrency(unassigned, _selectedCurrencyCode),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: unassigned > 0
                          ? const Color(0xFFD97706)
                          : const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (isOverAllocated) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Total allocations (${Formatters.formatCurrency(totalAlloc, _selectedCurrencyCode)}) exceed transaction amount (${Formatters.formatCurrency(txAmount, _selectedCurrencyCode)}).',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds a single allocation item row
  Widget _buildAllocationRow(int index, _AllocationEntry entry, ThemeData theme) {
    final availableAccounts = _availableAccounts;
    final selectedAccount = widget.accounts.where((a) => a.id == entry.accountId).firstOrNull;

    final double availableFunds = selectedAccount != null
        ? _getAvailableFundsForAccount(selectedAccount)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.error != null
              ? const Color(0xFFEF4444).withValues(alpha: 0.6)
              : theme.dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Account Dropdown Selector
              Expanded(
                flex: 3,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: entry.accountId,
                      isExpanded: true,
                      hint: const Text('Select Account', style: TextStyle(fontSize: 13)),
                      items: availableAccounts.map((acc) {
                        return DropdownMenuItem<String>(
                          value: acc.id,
                          child: Row(
                            children: [
                              Icon(acc.icon, size: 16, color: acc.color),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  acc.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newAccountId) {
                        setState(() {
                          entry.accountId = newAccountId;
                          _validateAllocationsInline();
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Allocation Amount Field
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: entry.controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      hintText: '0.00',
                      prefixText: '${AppCurrency.fromCode(_selectedCurrencyCode).symbol} ',
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Remove Allocation Button
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEF4444)),
                onPressed: () => _removeAllocation(index),
                tooltip: 'Remove Allocation',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          // Contextual Information & Available Funds
          if (selectedAccount != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_selectedType == TransactionType.expense)
                  Text(
                    'Available: ${Formatters.formatCurrency(availableFunds, selectedAccount.currency)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: availableFunds < 0
                          ? const Color(0xFFEF4444)
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Text(
                    'Account Currency: ${selectedAccount.currency}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                // Cross-currency conversion note if transaction and account currencies differ
                if (selectedAccount.currency.toUpperCase() != _selectedCurrencyCode.toUpperCase()) ...[
                  Builder(
                    builder: (context) {
                      final val = double.tryParse(entry.controller.text.trim()) ?? 0.0;
                      final converted = _currencyService.convert(
                        val,
                        _selectedCurrencyCode,
                        selectedAccount.currency,
                      );
                      return Text(
                        '≈ ${Formatters.formatCurrency(converted, selectedAccount.currency)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ],

          // Inline Error Message
          if (entry.error != null) ...[
            const SizedBox(height: 4),
            Text(
              entry.error!,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
