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
import '../services/storage_service.dart';
import '../utils/formatters.dart';

/// Account management screen accessible from Settings when Money Accounts is enabled.
/// Supports creating, editing, archiving accounts, inter-account transfers,
/// reconciliation overview, and unassigned transaction review.
class AccountManagementScreen extends StatefulWidget {
  final List<Transaction> transactions;
  final List<MoneyAccount> accounts;
  final List<AccountTransfer> transfers;
  final List<Loan> loans;
  final List<LoanRepayment> repayments;
  final Function(Transaction) onUpdateTransaction;
  final VoidCallback onDataChanged;

  const AccountManagementScreen({
    super.key,
    required this.transactions,
    required this.accounts,
    required this.transfers,
    this.loans = const [],
    this.repayments = const [],
    required this.onUpdateTransaction,
    required this.onDataChanged,
  });

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final CurrencyService _currencyService = CurrencyService();
  late final AccountService _accountService;

  late TabController _tabController;
  late List<MoneyAccount> _accounts;
  late List<AccountTransfer> _transfers;
  late List<Transaction> _transactions;
  late List<Loan> _loans;
  late List<LoanRepayment> _repayments;

  @override
  void initState() {
    super.initState();
    _accountService = AccountService(_currencyService);
    _accounts = List.from(widget.accounts);
    _transfers = List.from(widget.transfers);
    _transactions = List.from(widget.transactions);
    _loans = List.from(widget.loans);
    _repayments = List.from(widget.repayments);
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final a = await _storageService.loadAccounts();
    final tf = await _storageService.loadTransfers();
    final tx = await _storageService.loadTransactions();
    final l = await _storageService.loadLoans();
    final r = await _storageService.loadLoanRepayments();
    if (!mounted) return;
    setState(() {
      if (a.isNotEmpty || _accounts.isEmpty) _accounts = a.isNotEmpty ? a : _accounts;
      if (tf.isNotEmpty || _transfers.isEmpty) _transfers = tf.isNotEmpty ? tf : _transfers;
      if (tx.isNotEmpty || _transactions.isEmpty) _transactions = tx.isNotEmpty ? tx : _transactions;
      if (l.isNotEmpty || _loans.isEmpty) _loans = l.isNotEmpty ? l : _loans;
      if (r.isNotEmpty || _repayments.isEmpty) _repayments = r.isNotEmpty ? r : _repayments;
    });
  }

  @override
  void didUpdateWidget(covariant AccountManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accounts != widget.accounts) {
      _accounts = List.from(widget.accounts);
    }
    if (oldWidget.transfers != widget.transfers) {
      _transfers = List.from(widget.transfers);
    }
    if (oldWidget.transactions != widget.transactions) {
      _transactions = List.from(widget.transactions);
    }
    if (oldWidget.loans != widget.loans) {
      _loans = List.from(widget.loans);
    }
    if (oldWidget.repayments != widget.repayments) {
      _repayments = List.from(widget.repayments);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // =========================================================================
  // ACCOUNT CRUD OPERATIONS
  // =========================================================================

  Future<void> _showAccountDialog([MoneyAccount? existing]) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    String selectedCurrency = existing?.currency ?? _currencyService.defaultCurrencyCode;
    String selectedIconKey = existing?.iconKey ?? 'bank';
    Color selectedColor = existing != null ? existing.color : const Color(0xFF0F172A);
    String? nameError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: Text(existing != null ? 'Edit Account' : 'New Money Account'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account Name Field
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Account Name',
                      hintText: 'e.g. Bank Account, Cash, Crypto',
                      errorText: nameError,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) {
                      if (nameError != null) {
                        setDialogState(() => nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Optional Description
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'e.g. Primary checking, savings',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Currency Dropdown
                  Row(
                    children: [
                      const Text('Currency:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(ctx).colorScheme.outlineVariant,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedCurrency,
                              isExpanded: true,
                              items: AppCurrency.all.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c.code,
                                  child: Text('${c.symbol} ${c.code} - ${c.name}',
                                      style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: existing != null
                                  ? null // Prevent changing currency if account already has history
                                  : (val) {
                                      if (val != null) {
                                        setDialogState(() => selectedCurrency = val);
                                      }
                                    },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (existing != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Account currency cannot be changed after creation.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Icon Selector
                  const Text('Select Icon:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MoneyAccount.availableIcons.map((entry) {
                      final isSel = selectedIconKey == entry.key;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedIconKey = entry.key),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? selectedColor.withValues(alpha: 0.18)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSel ? selectedColor : Colors.grey.withValues(alpha: 0.3),
                              width: isSel ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(entry.value, size: 20, color: selectedColor),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Color Selector
                  const Text('Select Color:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: MoneyAccount.availableColors.map((col) {
                      final isSel = selectedColor.toARGB32() == col.toARGB32();
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = col),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: isSel ? Border.all(color: Colors.white, width: 2.5) : null,
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
                  if (name.isEmpty) {
                    setDialogState(() => nameError = 'Account name cannot be empty.');
                    return;
                  }

                  // Case-insensitive uniqueness check
                  if (!_accountService.isAccountNameUnique(name, _accounts, existing?.id)) {
                    setDialogState(() => nameError = 'An account with this name already exists.');
                    return;
                  }

                  Navigator.of(ctx).pop();

                  if (existing != null) {
                    final updated = existing.copyWith(
                      name: name,
                      description: descController.text.trim(),
                      iconKey: selectedIconKey,
                      colorValue: selectedColor.toARGB32(),
                    );
                    final list = await _storageService.updateAccount(updated);
                    setState(() => _accounts = list);
                  } else {
                    final newAcc = MoneyAccount(
                      id: 'acc_${DateTime.now().microsecondsSinceEpoch}',
                      name: name,
                      description: descController.text.trim(),
                      currency: selectedCurrency,
                      iconKey: selectedIconKey,
                      colorValue: selectedColor.toARGB32(),
                      createdAt: DateTime.now(),
                    );
                    final list = await _storageService.addAccount(newAcc);
                    setState(() => _accounts = list);
                  }

                  widget.onDataChanged();
                },
                child: Text(existing != null ? 'Update Account' : 'Create Account'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _archiveAccount(MoneyAccount account, bool archive) async {
    final list = await _storageService.archiveAccount(account.id, archive);
    setState(() => _accounts = list);
    widget.onDataChanged();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          archive
              ? 'Archived "${account.name}". It will no longer appear for new transactions.'
              : 'Restored "${account.name}" to active accounts.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteAccount(MoneyAccount account) async {
    final hasHistory = _accountService.hasAccountHistory(
      account.id,
      _transactions,
      _transfers,
      loans: _loans,
      repayments: _repayments,
    );

    if (hasHistory) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Delete Account'),
          content: Text(
            'Account "${account.name}" has historical transactions or transfers. '
            'Deleting it would break transaction history.\n\n'
            'You can Archive it instead. Archived accounts preserve all records without appearing in new transactions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.archive_outlined, size: 18),
              label: const Text('Archive Account'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _archiveAccount(account, true);
              },
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${account.name}"?'),
        content: const Text(
          'This account has no transaction history. Are you sure you want to permanently delete it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final list = await _storageService.deleteAccount(account.id);
      setState(() => _accounts = list);
      widget.onDataChanged();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account "${account.name}" deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // =========================================================================
  // INTER-ACCOUNT TRANSFERS (WITH OPTIONAL TRANSFER FEE & EDITING)
  // =========================================================================

  Future<void> _showTransferDialog({
    MoneyAccount? preselectedSource,
    AccountTransfer? existingTransfer,
  }) async {
    final activeAccounts = _accounts.where((a) => !a.isArchived).toList();
    if (activeAccounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need at least 2 active accounts to make a transfer.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String fromId = existingTransfer?.fromAccountId ?? preselectedSource?.id ?? activeAccounts.first.id;
    String toId = existingTransfer?.toAccountId ??
        activeAccounts.firstWhere((a) => a.id != fromId, orElse: () => activeAccounts.last).id;

    final initialFromAcc = activeAccounts.firstWhere(
      (a) => a.id == fromId,
      orElse: () => activeAccounts.first,
    );

    final amountController = TextEditingController(
      text: existingTransfer != null ? existingTransfer.amount.toStringAsFixed(2) : '',
    );
    final feeController = TextEditingController(
      text: existingTransfer != null && existingTransfer.fee > 0
          ? existingTransfer.fee.toStringAsFixed(2)
          : '0',
    );
    final noteController = TextEditingController(text: existingTransfer?.note ?? '');
    DateTime transferDate = existingTransfer?.date ?? DateTime.now();
    String feeCurrency = initialFromAcc.currency;
    String? transferError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final fromAccount = activeAccounts.firstWhere(
            (a) => a.id == fromId,
            orElse: () => activeAccounts.first,
          );
          final toAccount = activeAccounts.firstWhere(
            (a) => a.id == toId,
            orElse: () => activeAccounts.last,
          );

          final rawBalance = _accountService.calculateAccountBalance(
            fromAccount,
            _transactions,
            _transfers,
            loans: _loans,
            repayments: _repayments,
          );
          final availableBalance = _accountService.getAvailableFundsForTransfer(
            account: fromAccount,
            currentBalance: rawBalance,
            existingTransfer: existingTransfer,
          );

          final enteredAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
          final enteredFee = double.tryParse(feeController.text.trim()) ?? 0.0;

          final double feeInSourceCurrency = feeCurrency == fromAccount.currency
              ? enteredFee
              : _currencyService.convert(enteredFee, feeCurrency, fromAccount.currency);

          final double totalSourceDeduction = enteredAmount + feeInSourceCurrency;

          final double destinationAmount = fromAccount.currency == toAccount.currency
              ? enteredAmount
              : _currencyService.convert(
                  enteredAmount,
                  fromAccount.currency,
                  toAccount.currency,
                );

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, size: 22),
                const SizedBox(width: 8),
                Text(existingTransfer != null ? 'Edit Transfer' : 'Transfer Funds'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Direct transfer between accounts. Transfer fee is recorded as an expense reducing balance once.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),

                  // From Account
                  const Text('From Account (Source):',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: fromId,
                        isExpanded: true,
                        items: activeAccounts.map((acc) {
                          return DropdownMenuItem<String>(
                            value: acc.id,
                            child: Row(
                              children: [
                                Icon(acc.icon, size: 16, color: acc.color),
                                const SizedBox(width: 8),
                                Expanded(child: Text(acc.name, style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (newFrom) {
                          if (newFrom != null) {
                            setDialogState(() {
                              fromId = newFrom;
                              if (toId == fromId) {
                                toId = activeAccounts.firstWhere((a) => a.id != fromId).id;
                              }
                              final newFromAcc = activeAccounts.firstWhere((a) => a.id == newFrom);
                              feeCurrency = newFromAcc.currency;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Available: ${Formatters.formatCurrency(availableBalance, fromAccount.currency)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: availableBalance < 0
                          ? const Color(0xFFEF4444)
                          : Theme.of(ctx).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // To Account
                  const Text('To Account (Destination):',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: toId,
                        isExpanded: true,
                        items: activeAccounts.map((acc) {
                          return DropdownMenuItem<String>(
                            value: acc.id,
                            child: Row(
                              children: [
                                Icon(acc.icon, size: 16, color: acc.color),
                                const SizedBox(width: 8),
                                Expanded(child: Text(acc.name, style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (newTo) {
                          if (newTo != null) {
                            setDialogState(() {
                              toId = newTo;
                              if (fromId == toId) {
                                fromId = activeAccounts.firstWhere((a) => a.id != toId).id;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Transfer Amount
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Transfer Amount',
                      prefixText: '${AppCurrency.fromCode(fromAccount.currency).symbol} ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) {
                      setDialogState(() => transferError = null);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Transfer Fee Field with currency selector
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: feeController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Transfer Fee (Optional)',
                            prefixText: '${AppCurrency.fromCode(feeCurrency).symbol} ',
                            hintText: '0',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (val) {
                            setDialogState(() => transferError = null);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
                          ),
                          alignment: Alignment.center,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: feeCurrency,
                              isExpanded: true,
                              items: AppCurrency.all.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c.code,
                                  child: Text('${c.code} (${c.symbol})', style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => feeCurrency = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Note (optional)
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: 'Note (Optional)',
                      hintText: 'e.g. ATM cash withdrawal',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Live Transfer Breakdown / Deduction Summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Transfer Amount:', style: TextStyle(fontSize: 12)),
                            Text(
                              Formatters.formatCurrency(enteredAmount, fromAccount.currency),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        if (enteredFee > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Transfer Fee:', style: TextStyle(fontSize: 12)),
                              Text(
                                feeCurrency == fromAccount.currency
                                    ? Formatters.formatCurrency(enteredFee, feeCurrency)
                                    : '${Formatters.formatCurrency(enteredFee, feeCurrency)} (≈ ${Formatters.formatCurrency(feeInSourceCurrency, fromAccount.currency)})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Divider(height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Deducted from Source:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              Formatters.formatCurrency(totalSourceDeduction, fromAccount.currency),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: totalSourceDeduction > availableBalance
                                    ? const Color(0xFFEF4444)
                                    : Theme.of(ctx).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Destination Receives:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              Formatters.formatCurrency(destinationAmount, toAccount.currency),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (transferError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      transferError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
                  final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                  final feeParsed = double.tryParse(feeController.text.trim()) ?? 0.0;

                  if (amt <= 0) {
                    setDialogState(() => transferError = 'Transfer amount must be greater than zero.');
                    return;
                  }
                  if (feeParsed < 0) {
                    setDialogState(() => transferError = 'Transfer fee cannot be negative.');
                    return;
                  }

                  final err = _accountService.validateTransfer(
                    fromAccountId: fromId,
                    toAccountId: toId,
                    amount: amt,
                    fee: feeInSourceCurrency,
                    fromAccountBalance: availableBalance,
                    fromAccountCurrency: fromAccount.currency,
                  );

                  if (err != null) {
                    setDialogState(() => transferError = err);
                    return;
                  }

                  Navigator.of(ctx).pop();

                  final transferId = existingTransfer?.id ??
                      'tf_${DateTime.now().microsecondsSinceEpoch}';
                  final feeTxId = feeInSourceCurrency > 0
                      ? (existingTransfer?.feeTransactionId ??
                          'tx_fee_${DateTime.now().microsecondsSinceEpoch}')
                      : null;

                  final transfer = AccountTransfer(
                    id: transferId,
                    fromAccountId: fromId,
                    toAccountId: toId,
                    amount: amt,
                    toAmount: destinationAmount,
                    date: transferDate,
                    note: noteController.text.trim(),
                    fee: feeInSourceCurrency,
                    feeTransactionId: feeTxId,
                  );

                  Transaction? feeTransaction;
                  if (feeInSourceCurrency > 0 && feeTxId != null) {
                    feeTransaction = Transaction(
                      id: feeTxId,
                      title: 'Transfer Fee',
                      amount: feeParsed,
                      date: transferDate,
                      type: TransactionType.expense,
                      category: 'Transfer Fees',
                      note:
                          'Transfer fee for moving money from ${fromAccount.name} to ${toAccount.name}.',
                      currency: feeCurrency,
                      allocations: [
                        AccountAllocation(
                          accountId: fromId,
                          amount: feeParsed,
                        ),
                      ],
                    );
                  }

                  await _storageService.saveTransferWithFee(
                    transfer: transfer,
                    feeTransaction: feeTransaction,
                  );

                  final freshTransfers = await _storageService.loadTransfers();
                  final freshTransactions = await _storageService.loadTransactions();

                  if (!mounted) return;
                  setState(() {
                    _transfers = freshTransfers;
                    _transactions = freshTransactions;
                  });
                  widget.onDataChanged();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(existingTransfer != null
                          ? 'Transfer updated successfully.'
                          : 'Transferred ${Formatters.formatCurrency(amt, fromAccount.currency)} successfully.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Text(existingTransfer != null ? 'Update Transfer' : 'Confirm Transfer'),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // UNASSIGNED TRANSACTIONS REVIEW MODAL
  // =========================================================================

  void _showUnassignedTransactionsModal() {
    final unassignedList = _transactions.where((t) => t.hasUnassigned).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Unassigned Transactions',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                        ),
                        Text(
                          '${unassignedList.length} transactions with unallocated funds',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: unassignedList.isEmpty
                    ? const Center(
                        child: Text('All transactions have been fully allocated!'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: unassignedList.length,
                        itemBuilder: (context, index) {
                          final tx = unassignedList[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                tx.title.isNotEmpty ? tx.title : tx.category,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${Formatters.formatFriendlyDate(tx.date)} • Unassigned: ${Formatters.formatCurrency(tx.unassignedAmount, tx.currency)} of ${Formatters.formatCurrency(tx.amount, tx.currency)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(Icons.edit_note_rounded),
                              onTap: () async {
                                Navigator.of(ctx).pop();
                                widget.onUpdateTransaction(tx);
                                await _loadAllData();
                                widget.onDataChanged();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // BUILD METHOD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultCurrency = _currencyService.defaultCurrencyCode;

    // Balances calculation
    final accountBalances = _accountService.calculateAllBalances(
      _accounts,
      _transactions,
      _transfers,
      loans: _loans,
      repayments: _repayments,
    );

    final overallBalance = _accountService.calculateOverallBalance(
      _transactions,
      defaultCurrency,
      _loans,
      _repayments,
    );
    final combinedActiveAccounts = _accountService.calculateCombinedActiveAccountsBalance(
      _accounts,
      accountBalances,
    );
    final totalUnassignedIncome = _accountService.calculateTotalUnassignedIncome(_transactions);
    final totalUnassignedExpense = _accountService.calculateTotalUnassignedExpense(_transactions);
    final reconciliationDifference = _accountService.calculateReconciliationDifference(
      overallBalance: overallBalance,
      combinedActiveAccountsBalance: combinedActiveAccounts,
    );

    final activeAccounts = _accounts.where((a) => !a.isArchived).toList();
    final archivedAccounts = _accounts.where((a) => a.isArchived).toList();
    final hasReconciliationDifference = reconciliationDifference.abs() > 0.0001;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Transfer Funds',
            onPressed: activeAccounts.length >= 2 ? () => _showTransferDialog() : null,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New Account',
            onPressed: () => _showAccountDialog(),
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Summary & Reconciliation Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _buildReconciliationSummaryCard(
                  theme: theme,
                  defaultCurrency: defaultCurrency,
                  overallBalance: overallBalance,
                  combinedActiveAccounts: combinedActiveAccounts,
                  totalUnassignedIncome: totalUnassignedIncome,
                  totalUnassignedExpense: totalUnassignedExpense,
                  reconciliationDifference: reconciliationDifference,
                  hasDifference: hasReconciliationDifference,
                ),
              ),
            ),

            // Tab Bar
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  tabs: [
                    Tab(text: 'Active (${activeAccounts.length})'),
                    Tab(text: 'Archived (${archivedAccounts.length})'),
                    Tab(text: 'Transfers (${_transfers.length})'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Active Accounts Tab
            _buildAccountsList(activeAccounts, accountBalances, theme, false),

            // Archived Accounts Tab
            _buildAccountsList(archivedAccounts, accountBalances, theme, true),

            // Transfers History Tab
            _buildTransfersList(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildReconciliationSummaryCard({
    required ThemeData theme,
    required String defaultCurrency,
    required double overallBalance,
    required double combinedActiveAccounts,
    required double totalUnassignedIncome,
    required double totalUnassignedExpense,
    required double reconciliationDifference,
    required bool hasDifference,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACCOUNT RECONCILIATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasDifference
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                      : const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasDifference ? Icons.info_outline_rounded : Icons.check_circle_outline,
                      size: 13,
                      color: hasDifference ? const Color(0xFFD97706) : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasDifference ? 'Unassigned Present' : 'Balanced',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hasDifference ? const Color(0xFFD97706) : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Side-by-side Balances
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Financial Balance',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.formatCurrency(overallBalance, defaultCurrency),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
              ),
              Container(height: 32, width: 1, color: theme.dividerColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sum of Active Accounts',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.formatCurrency(combinedActiveAccounts, defaultCurrency),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (hasDifference) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Reconciliation Difference:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        Formatters.formatCurrency(reconciliationDifference, defaultCurrency),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Difference is explained by unassigned transactions (${Formatters.formatCurrency(totalUnassignedIncome, defaultCurrency)} unassigned income, ${Formatters.formatCurrency(totalUnassignedExpense, defaultCurrency)} unassigned expenses). This is expected behavior.',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _showUnassignedTransactionsModal,
                    borderRadius: BorderRadius.circular(6),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Review and assign transactions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
                      ],
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

  Widget _buildAccountsList(
    List<MoneyAccount> list,
    Map<String, double> balances,
    ThemeData theme,
    bool isArchivedTab,
  ) {
    if (list.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isArchivedTab ? Icons.archive_outlined : Icons.account_balance_wallet_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                isArchivedTab ? 'No archived accounts' : 'No accounts created yet',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                isArchivedTab
                    ? 'Accounts you archive will be stored here safely.'
                    : 'Create your Bank Accounts, Cash, Wallets, or Crypto Accounts to track allocations.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
              if (!isArchivedTab) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _showAccountDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create First Account'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final account = list[index];
        final balance = balances[account.id] ?? 0.0;
        final isDifferentCurrency =
            account.currency.toUpperCase() != _currencyService.defaultCurrencyCode.toUpperCase();
        final convertedBalance = isDifferentCurrency
            ? _currencyService.convert(balance, account.currency)
            : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Account Icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: account.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(account.icon, color: account.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    // Name & description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  account.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (account.isArchived) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Archived',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (account.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              account.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Balance
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Formatters.formatCurrency(balance, account.currency),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: balance >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                        if (isDifferentCurrency && convertedBalance != null)
                          Text(
                            '≈ ${Formatters.formatCurrency(convertedBalance, _currencyService.defaultCurrencyCode)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!account.isArchived)
                      TextButton.icon(
                        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                        label: const Text('Transfer', style: TextStyle(fontSize: 12)),
                        onPressed: () => _showTransferDialog(preselectedSource: account),
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showAccountDialog(account),
                    ),
                    TextButton.icon(
                      icon: Icon(
                        account.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                        size: 16,
                      ),
                      label: Text(
                        account.isArchived ? 'Restore' : 'Archive',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _archiveAccount(account, !account.isArchived),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      tooltip: 'Delete Account',
                      onPressed: () => _deleteAccount(account),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransfersList(ThemeData theme) {
    if (_transfers.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'No Transfers Recorded',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Use "Transfer Funds" to move balances between your accounts.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _transfers.length,
      itemBuilder: (context, index) {
        final transfer = _transfers[index];
        final fromAcc = _accounts.where((a) => a.id == transfer.fromAccountId).firstOrNull;
        final toAcc = _accounts.where((a) => a.id == transfer.toAccountId).firstOrNull;

        final fromName = fromAcc?.name ?? 'Unknown Account';
        final toName = toAcc?.name ?? 'Unknown Account';
        final fromCurrency = fromAcc?.currency ?? 'USD';
        final toCurrency = toAcc?.currency ?? 'USD';

        final totalDeducted = transfer.amount + transfer.fee;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.swap_horiz_rounded, size: 20),
            ),
            title: Text(
              '$fromName → $toName',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  '${Formatters.formatFriendlyDate(transfer.date)}${transfer.note.isNotEmpty ? " • ${transfer.note}" : ""}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (transfer.fee > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Fee: ${Formatters.formatCurrency(transfer.fee, fromCurrency)} • Total deducted: ${Formatters.formatCurrency(totalDeducted, fromCurrency)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.formatCurrency(transfer.amount, fromCurrency),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    if (fromCurrency != toCurrency)
                      Text(
                        'to ${Formatters.formatCurrency(transfer.toAmount, toCurrency)}',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit Transfer',
                  onPressed: () => _showTransferDialog(existingTransfer: transfer),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                  tooltip: 'Delete Transfer',
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Transfer?'),
                        content: const Text(
                          'Reverses the effects of this transfer and any linked transfer fee, restoring account balances.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await _storageService.deleteTransferWithFee(transfer.id);
                      final freshTransfers = await _storageService.loadTransfers();
                      final freshTransactions = await _storageService.loadTransactions();
                      if (!mounted) return;
                      setState(() {
                        _transfers = freshTransfers;
                        _transactions = freshTransactions;
                      });
                      widget.onDataChanged();

                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Transfer and linked fee deleted.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            onTap: () => _showTransferDialog(existingTransfer: transfer),
          ),
        );
      },
    );
  }
}
