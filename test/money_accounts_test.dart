import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_tracker/models/account_allocation.dart';
import 'package:money_tracker/models/account_transfer.dart';
import 'package:money_tracker/models/money_account.dart';
import 'package:money_tracker/models/transaction.dart';
import 'package:money_tracker/services/account_service.dart';
import 'package:money_tracker/services/currency_service.dart';
import 'package:money_tracker/services/storage_service.dart';
import 'package:money_tracker/constants/categories.dart';
import 'package:money_tracker/screens/account_management_screen.dart';
import 'package:money_tracker/screens/category_management_screen.dart';
import 'package:money_tracker/screens/home_tab.dart';
import 'package:money_tracker/screens/settings_tab.dart';
import 'package:money_tracker/widgets/account_breakdown_sheet.dart';
import 'package:money_tracker/widgets/add_transaction_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppCategories.reset();
  });

  group('Model & Migration Tests', () {
    test('Transaction backwards compatibility: missing allocations defaults to empty list', () {
      final legacyMap = {
        'id': 'legacy-tx-1',
        'title': 'Dinner',
        'amount': 45.0,
        'type': 'expense',
        'category': 'Food & Dining',
        'date': '2026-10-18T19:00:00.000',
        'note': 'No allocations in legacy data',
        'currency': 'USD',
      };

      final tx = Transaction.fromMap(legacyMap);
      expect(tx.id, 'legacy-tx-1');
      expect(tx.allocations, isEmpty);
      expect(tx.totalAllocated, 0.0);
      expect(tx.unassignedAmount, 45.0);
      expect(tx.hasUnassigned, isTrue);
    });

    test('Transaction with allocations serialization round-trip', () {
      final original = Transaction(
        id: 'tx-alloc-1',
        title: 'Freelance & Bonus',
        amount: 1000.0,
        type: TransactionType.income,
        category: 'Freelance & Work',
        date: DateTime(2026, 10, 19),
        currency: 'USD',
        allocations: const [
          AccountAllocation(accountId: 'bank-1', amount: 600.0),
          AccountAllocation(accountId: 'wallet-1', amount: 300.0),
        ],
      );

      expect(original.totalAllocated, 900.0);
      expect(original.unassignedAmount, 100.0);
      expect(original.hasUnassigned, isTrue);

      final jsonStr = original.toJson();
      final restored = Transaction.fromJson(jsonStr);

      expect(restored.id, original.id);
      expect(restored.amount, 1000.0);
      expect(restored.allocations.length, 2);
      expect(restored.allocations[0].accountId, 'bank-1');
      expect(restored.allocations[0].amount, 600.0);
      expect(restored.allocations[1].accountId, 'wallet-1');
      expect(restored.allocations[1].amount, 300.0);
      expect(restored.totalAllocated, 900.0);
      expect(restored.unassignedAmount, 100.0);
    });

    test('MoneyAccount serialization and properties', () {
      final account = MoneyAccount(
        id: 'acc-1',
        name: 'Primary Checking',
        description: 'Main bank account',
        currency: 'USD',
        iconKey: 'bank',
        colorValue: 0xFF2563EB,
        isArchived: false,
        createdAt: DateTime(2026, 10, 19),
      );

      final map = account.toMap();
      final fromMap = MoneyAccount.fromMap(map);

      expect(fromMap.id, 'acc-1');
      expect(fromMap.name, 'Primary Checking');
      expect(fromMap.currency, 'USD');
      expect(fromMap.isArchived, isFalse);
      expect(fromMap.iconKey, 'bank');
    });

    test('AccountTransfer serialization and properties', () {
      final transfer = AccountTransfer(
        id: 'tf-1',
        fromAccountId: 'acc-bank',
        toAccountId: 'acc-wallet',
        amount: 150.0,
        toAmount: 150.0,
        date: DateTime(2026, 10, 19),
        note: 'ATM Cash Withdrawal',
      );

      final map = transfer.toMap();
      final fromMap = AccountTransfer.fromMap(map);

      expect(fromMap.id, 'tf-1');
      expect(fromMap.fromAccountId, 'acc-bank');
      expect(fromMap.toAccountId, 'acc-wallet');
      expect(fromMap.amount, 150.0);
      expect(fromMap.toAmount, 150.0);
    });
  });

  group('StorageService Money Accounts Tests', () {
    test('Money accounts toggle defaults to false and preserves data on toggle', () async {
      final storage = StorageService();

      // Default is false
      expect(await storage.isMoneyAccountsEnabled(), isFalse);

      // Create an account
      final acc = MoneyAccount(
        id: 'acc-test',
        name: 'Test Wallet',
        currency: 'USD',
        createdAt: DateTime.now(),
      );
      await storage.addAccount(acc);
      await storage.setMoneyAccountsEnabled(true);
      expect(await storage.isMoneyAccountsEnabled(), isTrue);

      // Disable feature toggle: data must NEVER be deleted
      await storage.setMoneyAccountsEnabled(false);
      expect(await storage.isMoneyAccountsEnabled(), isFalse);

      final accountsAfterDisable = await storage.loadAccounts();
      expect(accountsAfterDisable.length, 1);
      expect(accountsAfterDisable.first.id, 'acc-test');

      // Re-enabling restores access
      await storage.setMoneyAccountsEnabled(true);
      expect(await storage.isMoneyAccountsEnabled(), isTrue);
    });

    test('Creating, updating, archiving, and deleting accounts in StorageService', () async {
      final storage = StorageService();

      final acc1 = MoneyAccount(
        id: 'acc-1',
        name: 'Bank',
        currency: 'USD',
        createdAt: DateTime.now(),
      );
      await storage.addAccount(acc1);

      var list = await storage.loadAccounts();
      expect(list.length, 1);
      expect(list.first.name, 'Bank');

      // Update
      final updated = acc1.copyWith(name: 'Chase Bank');
      await storage.updateAccount(updated);
      list = await storage.loadAccounts();
      expect(list.first.name, 'Chase Bank');

      // Archive
      await storage.archiveAccount('acc-1', true);
      list = await storage.loadAccounts();
      expect(list.first.isArchived, isTrue);

      // Unarchive
      await storage.archiveAccount('acc-1', false);
      list = await storage.loadAccounts();
      expect(list.first.isArchived, isFalse);

      // Delete
      await storage.deleteAccount('acc-1');
      list = await storage.loadAccounts();
      expect(list, isEmpty);
    });

    test('Transfers persistence in StorageService', () async {
      final storage = StorageService();

      final tf = AccountTransfer(
        id: 'tf-1',
        fromAccountId: 'acc-1',
        toAccountId: 'acc-2',
        amount: 200.0,
        toAmount: 200.0,
        date: DateTime.now(),
      );
      await storage.addTransfer(tf);

      var transfers = await storage.loadTransfers();
      expect(transfers.length, 1);
      expect(transfers.first.amount, 200.0);

      await storage.deleteTransfer('tf-1');
      transfers = await storage.loadTransfers();
      expect(transfers, isEmpty);
    });

    test('ThemeMode storage supports Light and Dark with fallback from legacy system', () async {
      final storage = StorageService();

      // Default when nothing saved is light
      expect(await storage.loadThemeMode(), ThemeMode.light);

      // Save and load Dark
      await storage.saveThemeMode(ThemeMode.dark);
      expect(await storage.loadThemeMode(), ThemeMode.dark);

      // Save and load Light
      await storage.saveThemeMode(ThemeMode.light);
      expect(await storage.loadThemeMode(), ThemeMode.light);

      // Legacy 'system' value in SharedPreferences falls back safely to Light
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_theme_mode_v1', 'system');
      expect(await storage.loadThemeMode(), ThemeMode.light);
    });
  });

  group('Accounting & Balance Calculation Engine Tests', () {
    late CurrencyService currencyService;
    late AccountService accountService;

    setUp(() {
      currencyService = CurrencyService();
      accountService = AccountService(currencyService);
    });

    test('Single-currency scenario from prompt: unassigned transaction and reconciliation', () {
      // Prompt example:
      // Starting overall balance: $1,000
      // Bank balance: $600
      // Wallet balance: $400
      // The user records a $300 expense without specifying an account.
      // Correct result:
      // - Overall balance: $700
      // - Bank balance: $600
      // - Wallet balance: $400
      // - Unassigned expense: $300
      // Reconciliation difference = Overall balance - Sum of active account balances = 700 - 1000 = -300

      final bank = MoneyAccount(
        id: 'bank-acc',
        name: 'Bank',
        currency: 'USD',
        createdAt: DateTime.now(),
      );
      final wallet = MoneyAccount(
        id: 'wallet-acc',
        name: 'Wallet',
        currency: 'USD',
        createdAt: DateTime.now(),
      );

      final accounts = [bank, wallet];

      // Income tx: $1000 allocated $600 to Bank, $400 to Wallet
      final initialIncome = Transaction(
        id: 'tx-income-1',
        title: 'Salary Deposit',
        amount: 1000.0,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime(2026, 10, 1),
        currency: 'USD',
        allocations: const [
          AccountAllocation(accountId: 'bank-acc', amount: 600.0),
          AccountAllocation(accountId: 'wallet-acc', amount: 400.0),
        ],
      );

      // Unassigned expense: $300 with NO allocations
      final unassignedExpense = Transaction(
        id: 'tx-expense-unassigned',
        title: 'Unknown Cash Expense',
        amount: 300.0,
        type: TransactionType.expense,
        category: 'Other Expense',
        date: DateTime(2026, 10, 2),
        currency: 'USD',
        allocations: const [],
      );

      final transactions = [initialIncome, unassignedExpense];

      // 1. Bank balance must remain $600
      final bankBalance = accountService.calculateAccountBalance(bank, transactions, []);
      expect(bankBalance, 600.0);

      // 2. Wallet balance must remain $400
      final walletBalance = accountService.calculateAccountBalance(wallet, transactions, []);
      expect(walletBalance, 400.0);

      // 3. Overall balance must be $700 ($1000 - $300)
      final overallBalance = accountService.calculateOverallBalance(transactions, 'USD');
      expect(overallBalance, 700.0);

      // 4. Sum of active accounts must be $1,000 ($600 + $400)
      final allBalances = accountService.calculateAllBalances(accounts, transactions, []);
      final sumOfAccounts = accountService.calculateCombinedActiveAccountsBalance(
        accounts,
        allBalances,
        'USD',
      );
      expect(sumOfAccounts, 1000.0);

      // 5. Total unassigned expense must be $300
      final totalUnassignedExpense = accountService.calculateTotalUnassignedExpense(transactions, 'USD');
      expect(totalUnassignedExpense, 300.0);

      // 6. Reconciliation difference = 700 - 1000 = -300
      final diff = accountService.calculateReconciliationDifference(
        overallBalance: overallBalance,
        combinedActiveAccountsBalance: sumOfAccounts,
        targetCurrencyCode: 'USD',
      );
      expect(diff, -300.0);
    });

    test('Multiple account allocations in a single transaction (income & expense)', () {
      final bank = MoneyAccount(id: 'bank-1', name: 'Bank', currency: 'USD', createdAt: DateTime.now());
      final wallet = MoneyAccount(id: 'wallet-1', name: 'Wallet', currency: 'USD', createdAt: DateTime.now());
      final accounts = [bank, wallet];

      // Income: $1000 -> Bank: $600, Wallet: $300, Unassigned: $100
      final incomeTx = Transaction(
        id: 'tx-1',
        title: 'Mixed Income',
        amount: 1000.0,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime.now(),
        currency: 'USD',
        allocations: const [
          AccountAllocation(accountId: 'bank-1', amount: 600.0),
          AccountAllocation(accountId: 'wallet-1', amount: 300.0),
        ],
      );

      // Expense: $300 -> Bank: $100, Wallet: $150, Unassigned: $50
      final expenseTx = Transaction(
        id: 'tx-2',
        title: 'Mixed Expense',
        amount: 300.0,
        type: TransactionType.expense,
        category: 'Shopping',
        date: DateTime.now(),
        currency: 'USD',
        allocations: const [
          AccountAllocation(accountId: 'bank-1', amount: 100.0),
          AccountAllocation(accountId: 'wallet-1', amount: 150.0),
        ],
      );

      final txList = [incomeTx, expenseTx];

      // Bank: $600 income - $100 expense = $500
      expect(accountService.calculateAccountBalance(bank, txList, []), 500.0);

      // Wallet: $300 income - $150 expense = $150
      expect(accountService.calculateAccountBalance(wallet, txList, []), 150.0);

      // Overall balance: $1000 - $300 = $700
      expect(accountService.calculateOverallBalance(txList, 'USD'), 700.0);

      // Unassigned income = $100
      expect(accountService.calculateTotalUnassignedIncome(txList, 'USD'), 100.0);

      // Unassigned expense = $50
      expect(accountService.calculateTotalUnassignedExpense(txList, 'USD'), 50.0);

      // Sum of accounts: $500 + $150 = $650
      final balances = accountService.calculateAllBalances(accounts, txList, []);
      final combined = accountService.calculateCombinedActiveAccountsBalance(accounts, balances, 'USD');
      expect(combined, 650.0);

      // Reconciliation difference: Overall ($700) - Combined ($650) = +$50 ($100 unassigned income - $50 unassigned expense)
      final diff = accountService.calculateReconciliationDifference(
        overallBalance: 700.0,
        combinedActiveAccountsBalance: 650.0,
        targetCurrencyCode: 'USD',
      );
      expect(diff, 50.0);
    });

    test('Inter-account transfer affects accounts but does NOT affect overall balance', () {
      final bank = MoneyAccount(id: 'bank-1', name: 'Bank', currency: 'USD', createdAt: DateTime.now());
      final wallet = MoneyAccount(id: 'wallet-1', name: 'Wallet', currency: 'USD', createdAt: DateTime.now());

      final deposit = Transaction(
        id: 'tx-init',
        title: 'Deposit',
        amount: 500.0,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime.now(),
        currency: 'USD',
        allocations: const [
          AccountAllocation(accountId: 'bank-1', amount: 500.0),
        ],
      );

      // Transfer $200 from Bank to Wallet
      final transfer = AccountTransfer(
        id: 'tf-1',
        fromAccountId: 'bank-1',
        toAccountId: 'wallet-1',
        amount: 200.0,
        toAmount: 200.0,
        date: DateTime.now(),
      );

      final txList = [deposit];
      final tfList = [transfer];

      // Bank balance: 500 - 200 = 300
      expect(accountService.calculateAccountBalance(bank, txList, tfList), 300.0);

      // Wallet balance: 0 + 200 = 200
      expect(accountService.calculateAccountBalance(wallet, txList, tfList), 200.0);

      // Overall balance: Still 500. Transfers do NOT create income or expense!
      expect(accountService.calculateOverallBalance(txList, 'USD'), 500.0);
    });

    test('Available funds validation prevents overdraft for expense allocations', () {
      final bank = MoneyAccount(id: 'bank-1', name: 'Bank', currency: 'USD', createdAt: DateTime.now());

      // Bank has $200
      final deposit = Transaction(
        id: 'tx-init',
        title: 'Deposit',
        amount: 200.0,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime.now(),
        currency: 'USD',
        allocations: const [AccountAllocation(accountId: 'bank-1', amount: 200.0)],
      );

      final currentBal = accountService.calculateAccountBalance(bank, [deposit], []);
      expect(currentBal, 200.0);

      // Try allocating $250 expense to Bank -> must fail validation
      final err = accountService.validateAllocation(
        allocation: const AccountAllocation(accountId: 'bank-1', amount: 250.0),
        account: bank,
        type: TransactionType.expense,
        transactionCurrency: 'USD',
        availableAccountBalance: currentBal,
        remainingTransactionAmountToAllocate: 300.0,
      );

      expect(err, isNotNull);
      expect(err!.contains('Insufficient funds'), isTrue);

      // Try allocating $150 expense to Bank -> must pass
      final validErr = accountService.validateAllocation(
        allocation: const AccountAllocation(accountId: 'bank-1', amount: 150.0),
        account: bank,
        type: TransactionType.expense,
        transactionCurrency: 'USD',
        availableAccountBalance: currentBal,
        remainingTransactionAmountToAllocate: 300.0,
      );

      expect(validErr, isNull);
    });

    test('Editing an existing transaction reverses old allocations when computing available funds', () {
      final bank = MoneyAccount(id: 'bank-1', name: 'Bank', currency: 'USD', createdAt: DateTime.now());

      // Initial deposit: $500 to Bank
      final deposit = Transaction(
        id: 'tx-dep',
        title: 'Deposit',
        amount: 500.0,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime.now(),
        currency: 'USD',
        allocations: const [AccountAllocation(accountId: 'bank-1', amount: 500.0)],
      );

      // Existing expense of $200 from Bank (current balance is now $300)
      final existingExpense = Transaction(
        id: 'tx-exp-1',
        title: 'Existing Grocery',
        amount: 200.0,
        type: TransactionType.expense,
        category: 'Groceries',
        date: DateTime.now(),
        currency: 'USD',
        allocations: const [AccountAllocation(accountId: 'bank-1', amount: 200.0)],
      );

      final txList = [deposit, existingExpense];
      final currentBalance = accountService.calculateAccountBalance(bank, txList, []);
      expect(currentBalance, 300.0);

      // When editing existingExpense: the $200 that was allocated to Bank is temporarily freed up!
      // So available funds for this edit should be $300 + $200 = $500!
      final availableForEdit = accountService.getAvailableFundsForTransaction(
        account: bank,
        currentBalance: currentBalance,
        existingTransaction: existingExpense,
      );

      expect(availableForEdit, 500.0);
    });

    test('Case-insensitive account name uniqueness validation', () {
      final accounts = [
        MoneyAccount(id: 'acc-1', name: 'Bank Account', currency: 'USD', createdAt: DateTime.now()),
        MoneyAccount(id: 'acc-2', name: 'Cash', currency: 'USD', createdAt: DateTime.now()),
      ];

      expect(accountService.isAccountNameUnique('bank account', accounts), isFalse);
      expect(accountService.isAccountNameUnique('BANK ACCOUNT', accounts), isFalse);
      expect(accountService.isAccountNameUnique('  cash  ', accounts), isFalse);
      expect(accountService.isAccountNameUnique('Crypto Wallet', accounts), isTrue);

      // When editing acc-1, keeping the same name 'Bank Account' should be allowed
      expect(accountService.isAccountNameUnique('Bank Account', accounts, 'acc-1'), isTrue);
    });
  });

  group('Widget & UI Tests', () {
    testWidgets('SettingsTab shows Money Accounts section and toggle enables options', (tester) async {
      final storage = StorageService();
      await storage.setMoneyAccountsEnabled(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsTab(
              currentThemeMode: ThemeMode.light,
              onThemeModeChanged: (_) {},
              onDataChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "MONEY ACCOUNTS" section header exists
      expect(find.text('MONEY ACCOUNTS'), findsOneWidget);
      expect(find.text('Enable Money Accounts'), findsOneWidget);

      // Initially disabled, so "Manage Accounts" is hidden
      expect(find.text('Manage Accounts'), findsNothing);

      // Tap Switch to enable
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      // Now "Manage Accounts" and "Reconciliation & Transfers" must be visible
      expect(find.text('Manage Accounts'), findsOneWidget);
      expect(find.text('Reconciliation & Transfers'), findsOneWidget);
    });

    testWidgets('AccountManagementScreen displays empty state and allows account creation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountManagementScreen(
            transactions: const [],
            accounts: const [],
            transfers: const [],
            onUpdateTransaction: (_) {},
            onDataChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and tabs
      expect(find.text('Money Accounts'), findsOneWidget);
      expect(find.text('No accounts created yet'), findsOneWidget);
      expect(find.text('Create First Account'), findsOneWidget);

      // Tap Create First Account
      await tester.tap(find.text('Create First Account'));
      await tester.pumpAndSettle();

      expect(find.text('New Money Account'), findsOneWidget);
      expect(find.text('Account Name'), findsOneWidget);

      // Enter name
      await tester.enterText(find.widgetWithText(TextField, 'Account Name'), 'Main Checking');
      await tester.pumpAndSettle();

      // Tap Create Account
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Account appears in the list
      expect(find.text('Main Checking'), findsOneWidget);
    });

    testWidgets('HomeTab Income and Expense cards are tap-enabled only when Money Accounts is enabled', (tester) async {
      final tx = Transaction(
        id: 'tx-1',
        title: 'Salary',
        amount: 1500.0,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime.now(),
        currency: 'USD',
      );

      // Test 1: Feature DISABLED
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeTab(
              transactions: [tx],
              onAddTransaction: (_) {},
              onUpdateTransaction: (_) {},
              onDeleteTransaction: (_) {},
              onNavigateToTransactions: () {},
              onOpenAddSheet: () {},
              isMoneyAccountsEnabled: false,
              accounts: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tapping Income card does not open breakdown
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      expect(find.text('Income by Account'), findsNothing);
      expect(find.text('Allocation Breakdown'), findsNothing);

      // Test 2: Feature ENABLED
      final bank = MoneyAccount(
        id: 'acc-bank',
        name: 'Bank Account',
        currency: 'USD',
        createdAt: DateTime.now(),
      );

      final txAllocated = Transaction(
        id: 'tx-1',
        title: 'Salary',
        amount: 1000.0,
        currency: 'USD',
        date: DateTime.now(),
        type: TransactionType.income,
        category: 'Salary',
        allocations: [
          AccountAllocation(accountId: 'acc-bank', amount: 600.0),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeTab(
              transactions: [txAllocated],
              onAddTransaction: (_) {},
              onUpdateTransaction: (_) {},
              onDeleteTransaction: (_) {},
              onNavigateToTransactions: () {},
              onOpenAddSheet: () {},
              isMoneyAccountsEnabled: true,
              accounts: [bank],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tapping Income card opens Income details without ALLOCATION BREAKDOWN
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      expect(find.text('Income by Account'), findsOneWidget);
      expect(find.text('ALLOCATION BREAKDOWN'), findsNothing);
      expect(find.text('Unassigned to Accounts'), findsOneWidget);

      // Close Income sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Tapping Expense card opens Expense details without ALLOCATION BREAKDOWN
      await tester.tap(find.text('Expense'));
      await tester.pumpAndSettle();
      expect(find.text('Expenses by Account'), findsOneWidget);
      expect(find.text('ALLOCATION BREAKDOWN'), findsNothing);

      // Close Expense sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Tapping Allocation Breakdown row opens Allocation Breakdown sheet
      expect(find.text('Allocation Breakdown'), findsOneWidget);
      await tester.tap(find.text('Allocation Breakdown'));
      await tester.pumpAndSettle();
      expect(find.text('ALLOCATION BREAKDOWN'), findsOneWidget);
      expect(find.text('Bank Account'), findsOneWidget);
    });

    testWidgets('AddTransactionSheet shows Money Allocation section when enabled', (tester) async {
      final bank = MoneyAccount(
        id: 'acc-bank',
        name: 'Bank Account',
        currency: 'USD',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddTransactionSheet(
              onSave: (_) {},
              isMoneyAccountsEnabled: true,
              accounts: [bank],
              allTransactions: const [],
              transfers: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Money Allocation section is present
      expect(find.text('Money Allocation'), findsOneWidget);
      expect(find.text('Add Account'), findsOneWidget);
      expect(find.text('Unassigned Amount'), findsOneWidget);

      // Enter amount $500
      await tester.enterText(find.widgetWithText(TextFormField, '0.00'), '500');
      await tester.pumpAndSettle();

      // Tap "Add Account" to add allocation
      await tester.tap(find.text('Add Account'));
      await tester.pumpAndSettle();

      // Dropdown with account is present
      expect(find.text('Bank Account'), findsOneWidget);
    });

    testWidgets('SettingsTab Theme Mode selector displays only Light and Dark and switches mode', (tester) async {
      ThemeMode selectedMode = ThemeMode.light;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SettingsTab(
                  currentThemeMode: selectedMode,
                  onThemeModeChanged: (mode) {
                    setState(() {
                      selectedMode = mode;
                    });
                  },
                  onDataChanged: () {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Theme Mode header
      expect(find.text('Theme Mode'), findsOneWidget);

      // Verify Light and Dark options exist
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      // Verify System option does NOT exist
      expect(find.text('System'), findsNothing);

      // Tap Dark to switch theme
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(selectedMode, ThemeMode.dark);

      // Tap Light to switch back
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(selectedMode, ThemeMode.light);
    });
  });

  group('Transfer Fee & Accounting Invariants Tests', () {
    late CurrencyService currencyService;
    late AccountService accountService;

    setUp(() {
      currencyService = CurrencyService();
      accountService = AccountService(currencyService);
    });

    test('AccountTransfer fee defaults to 0 and serializes/deserializes correctly', () {
      final transferWithFee = AccountTransfer(
        id: 'tf-fee-1',
        fromAccountId: 'binance-1',
        toAccountId: 'crypto-1',
        amount: 100.0,
        toAmount: 100.0,
        date: DateTime(2026, 10, 19),
        note: 'Transfer to Cold Storage',
        fee: 2.50,
        feeTransactionId: 'fee-tx-123',
      );

      expect(transferWithFee.fee, 2.50);
      expect(transferWithFee.feeTransactionId, 'fee-tx-123');

      final map = transferWithFee.toMap();
      final restored = AccountTransfer.fromMap(map);

      expect(restored.id, 'tf-fee-1');
      expect(restored.amount, 100.0);
      expect(restored.fee, 2.50);
      expect(restored.feeTransactionId, 'fee-tx-123');

      // Test backward compatibility when fee is missing in map
      final legacyMap = {
        'id': 'tf-legacy',
        'fromAccountId': 'a1',
        'toAccountId': 'a2',
        'amount': 50.0,
        'toAmount': 50.0,
        'date': DateTime.now().toIso8601String(),
        'note': 'Legacy transfer',
      };
      final legacyRestored = AccountTransfer.fromMap(legacyMap);
      expect(legacyRestored.fee, 0.0);
      expect(legacyRestored.feeTransactionId, isNull);
    });

    test('Transfer fee validation rules: negative fee fails, insufficient funds fails', () {
      // 1. Negative fee must be rejected
      final negativeFeeErr = accountService.validateTransfer(
        fromAccountId: 'acc-1',
        toAccountId: 'acc-2',
        amount: 100.0,
        fee: -1.0,
        fromAccountBalance: 200.0,
        fromAccountCurrency: 'USD',
      );
      expect(negativeFeeErr, contains('cannot be negative'));

      // 2. Insufficient funds with amount + fee
      // Binance has $100 available, user transfers $100 with $2 fee (total $102 required)
      final insufficientErr = accountService.validateTransfer(
        fromAccountId: 'acc-1',
        toAccountId: 'acc-2',
        amount: 100.0,
        fee: 2.0,
        fromAccountBalance: 100.0,
        fromAccountCurrency: 'USD',
      );
      expect(insufficientErr, contains('Insufficient funds'));
      expect(insufficientErr, contains('102.00'));

      // 3. Sufficient funds passes
      final validErr = accountService.validateTransfer(
        fromAccountId: 'acc-1',
        toAccountId: 'acc-2',
        amount: 100.0,
        fee: 2.0,
        fromAccountBalance: 102.0,
        fromAccountCurrency: 'USD',
      );
      expect(validErr, isNull);

      // 4. Zero fee passes
      final zeroFeeErr = accountService.validateTransfer(
        fromAccountId: 'acc-1',
        toAccountId: 'acc-2',
        amount: 100.0,
        fee: 0.0,
        fromAccountBalance: 100.0,
        fromAccountCurrency: 'USD',
      );
      expect(zeroFeeErr, isNull);
    });

    test(r'Accounting Invariant: $100 Binance to Crypto with $2 fee deducts $102, credits $100, reduces overall balance by $2', () {
      final binance = MoneyAccount(
        id: 'acc-binance',
        name: 'Binance',
        currency: 'USD',
        createdAt: DateTime.now(),
      );
      final cryptoWallet = MoneyAccount(
        id: 'acc-crypto',
        name: 'Crypto Wallet',
        currency: 'USD',
        createdAt: DateTime.now(),
      );

      // Initial funding: Binance starts with $102 income
      final initialFunding = Transaction(
        id: 'tx-fund-binance',
        title: 'Crypto Deposit',
        amount: 102.0,
        type: TransactionType.income,
        category: 'Investments',
        date: DateTime.now().subtract(const Duration(days: 1)),
        currency: 'USD',
        allocations: const [
          AccountAllocation(accountId: 'acc-binance', amount: 102.0),
        ],
      );

      // Transfer: $100 from Binance to Crypto Wallet with $2 fee
      final transfer = AccountTransfer(
        id: 'tf-100',
        fromAccountId: 'acc-binance',
        toAccountId: 'acc-crypto',
        amount: 100.0,
        toAmount: 100.0,
        fee: 2.0,
        feeTransactionId: 'tx-fee-2',
        date: DateTime.now(),
        note: 'Transfer to Cold Storage',
      );

      // Linked fee transaction: $2 expense allocated to Binance
      final feeTransaction = Transaction(
        id: 'tx-fee-2',
        title: 'Transfer Fee',
        amount: 2.0,
        type: TransactionType.expense,
        category: 'Transfer Fees',
        date: DateTime.now(),
        currency: 'USD',
        note: 'Transfer fee for moving money from Binance to Crypto Wallet.',
        allocations: const [
          AccountAllocation(accountId: 'acc-binance', amount: 2.0),
        ],
      );

      final allTransactions = [initialFunding, feeTransaction];
      final allTransfers = [transfer];

      // 1. Source Account (Binance): initial $102 - $2 (fee expense) - $100 (transfer) = $0.00
      final binanceBalance = accountService.calculateAccountBalance(
        binance,
        allTransactions,
        allTransfers,
      );
      expect(binanceBalance, 0.0);

      // 2. Destination Account (Crypto Wallet): receives $100 transfer = $100.00
      final cryptoBalance = accountService.calculateAccountBalance(
        cryptoWallet,
        allTransactions,
        allTransfers,
      );
      expect(cryptoBalance, 100.0);

      // 3. Overall Balance: $102 (income) - $2 (fee expense) = $100.00
      // Notice: overall balance reduced by exactly the $2 fee; principal does not count as income or expense
      final overallBalance = accountService.calculateOverallBalance(allTransactions);
      expect(overallBalance, 100.0);

      // 4. Combined active accounts balance: Binance ($0) + Crypto ($100) = $100.00
      final combinedBalance = accountService.calculateCombinedActiveAccountsBalance(
        [binance, cryptoWallet],
        {'acc-binance': binanceBalance, 'acc-crypto': cryptoBalance},
      );
      expect(combinedBalance, 100.0);

      // 5. Reconciliation difference: overall ($100) - combined accounts ($100) = $0.00 (Perfect reconciliation)
      final reconciliationDiff = accountService.calculateReconciliationDifference(
        overallBalance: overallBalance,
        combinedActiveAccountsBalance: combinedBalance,
      );
      expect(reconciliationDiff, 0.0);
    });

    test('getAvailableFundsForTransfer reverses amount + fee when editing existing transfer', () {
      final binance = MoneyAccount(
        id: 'acc-binance',
        name: 'Binance',
        currency: 'USD',
        createdAt: DateTime.now(),
      );

      final existingTransfer = AccountTransfer(
        id: 'tf-edit',
        fromAccountId: 'acc-binance',
        toAccountId: 'acc-crypto',
        amount: 100.0,
        toAmount: 100.0,
        fee: 2.0,
        feeTransactionId: 'fee-1',
        date: DateTime.now(),
      );

      // Current balance is $0 (because $100 and $2 fee were already deducted)
      final availableFunds = accountService.getAvailableFundsForTransfer(
        account: binance,
        currentBalance: 0.0,
        existingTransfer: existingTransfer,
      );

      // Available funds when editing should restore $102 ($100 amount + $2 fee)
      expect(availableFunds, 102.0);
    });

    test('StorageService atomic saveTransferWithFee and deleteTransferWithFee without duplicates', () async {
      final storage = StorageService();

      final transfer = AccountTransfer(
        id: 'tf-atomic-1',
        fromAccountId: 'acc-1',
        toAccountId: 'acc-2',
        amount: 50.0,
        toAmount: 50.0,
        fee: 1.50,
        feeTransactionId: 'tx-fee-atomic',
        date: DateTime.now(),
      );

      final feeTx = Transaction(
        id: 'tx-fee-atomic',
        title: 'Transfer Fee',
        amount: 1.50,
        type: TransactionType.expense,
        category: 'Transfer Fees',
        date: DateTime.now(),
        currency: 'USD',
        allocations: const [
          AccountAllocation(accountId: 'acc-1', amount: 1.50),
        ],
      );

      // 1. Save atomically
      await storage.saveTransferWithFee(transfer: transfer, feeTransaction: feeTx);

      var transfers = await storage.loadTransfers();
      var transactions = await storage.loadTransactions();

      expect(transfers.any((t) => t.id == 'tf-atomic-1'), isTrue);
      expect(transactions.any((tx) => tx.id == 'tx-fee-atomic'), isTrue);
      expect(transfers.where((t) => t.id == 'tf-atomic-1').length, 1);
      expect(transactions.where((tx) => tx.id == 'tx-fee-atomic').length, 1);

      // 2. Edit transfer: update amount and fee to $2.00
      final updatedTransfer = transfer.copyWith(fee: 2.00);
      final updatedFeeTx = feeTx.copyWith(amount: 2.00);

      await storage.saveTransferWithFee(
        transfer: updatedTransfer,
        feeTransaction: updatedFeeTx,
      );

      transfers = await storage.loadTransfers();
      transactions = await storage.loadTransactions();

      // No duplicate transactions or transfers
      expect(transfers.where((t) => t.id == 'tf-atomic-1').length, 1);
      expect(transactions.where((tx) => tx.id == 'tx-fee-atomic').length, 1);
      expect(transfers.firstWhere((t) => t.id == 'tf-atomic-1').fee, 2.00);
      expect(transactions.firstWhere((tx) => tx.id == 'tx-fee-atomic').amount, 2.00);

      // 3. Edit transfer: change fee to 0 (fee transaction must be removed)
      final zeroFeeTransfer = updatedTransfer.copyWith(fee: 0.0, feeTransactionId: null);
      await storage.saveTransferWithFee(
        transfer: zeroFeeTransfer,
        feeTransaction: null,
      );

      transfers = await storage.loadTransfers();
      transactions = await storage.loadTransactions();

      expect(transfers.firstWhere((t) => t.id == 'tf-atomic-1').fee, 0.0);
      expect(transactions.any((tx) => tx.id == 'tx-fee-atomic'), isFalse);

      // 4. Delete transfer atomically
      await storage.deleteTransferWithFee('tf-atomic-1');
      transfers = await storage.loadTransfers();
      expect(transfers.any((t) => t.id == 'tf-atomic-1'), isFalse);
    });
  });

  group('Category Management & Migration Tests', () {
    test('Transfer Fees exists as default expense category without duplicates', () {
      final transferFeeCategories = AppCategories.defaultExpenseCategories
          .where((c) => c.name.toLowerCase() == 'transfer fees')
          .toList();

      expect(transferFeeCategories.length, 1);
      expect(transferFeeCategories.first.name, 'Transfer Fees');
      expect(transferFeeCategories.first.iconKey, 'transfer_fees');
    });

    test('loadAllCategories ensures Transfer Fees is loaded and deduplicated', () async {
      final storage = StorageService();
      await storage.loadAllCategories();

      final expenseCats = AppCategories.expenseCategories;
      final tfCount = expenseCats.where((c) => c.name.toLowerCase() == 'transfer fees').length;
      expect(tfCount, 1);
    });

    test('Updating category name cascades to all matching historical transactions', () async {
      final storage = StorageService();

      // Seed a transaction with category "Food & Dining"
      final tx1 = Transaction(
        id: 'tx-cat-1',
        title: 'Dinner',
        amount: 30.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: DateTime.now(),
        currency: 'USD',
      );
      final tx2 = Transaction(
        id: 'tx-cat-2',
        title: 'Lunch',
        amount: 15.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: DateTime.now(),
        currency: 'USD',
      );
      final txOther = Transaction(
        id: 'tx-cat-3',
        title: 'Salary',
        amount: 2000.0,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime.now(),
        currency: 'USD',
      );
      await storage.saveTransactions([tx1, tx2, txOther]);

      // Rename category "Food & Dining" to "Dining & Cafes"
      final existingCat = AppCategories.expenseCategories.firstWhere((c) => c.name == 'Food & Dining');
      final updatedCat = existingCat.copyWith(name: 'Dining & Cafes');

      await storage.updateCategory(
        oldName: 'Food & Dining',
        updatedItem: updatedCat,
        type: TransactionType.expense,
      );

      final updatedTransactions = await storage.loadTransactions();
      final diningTx1 = updatedTransactions.firstWhere((t) => t.id == 'tx-cat-1');
      final diningTx2 = updatedTransactions.firstWhere((t) => t.id == 'tx-cat-2');
      final salaryTx = updatedTransactions.firstWhere((t) => t.id == 'tx-cat-3');

      // Transactions using the old name are updated
      expect(diningTx1.category, 'Dining & Cafes');
      expect(diningTx2.category, 'Dining & Cafes');
      // Amounts and IDs preserved
      expect(diningTx1.amount, 30.0);
      expect(diningTx2.amount, 15.0);
      // Unrelated transactions untouched
      expect(salaryTx.category, 'Salary');
    });

    test('Deleting category with safe reassignment moves historical transactions', () async {
      final storage = StorageService();

      // Create a custom category "Coffee"
      final coffeeCat = CategoryItem(
        id: 'cat-coffee',
        name: 'Coffee',
        icon: Icons.local_cafe_rounded,
        color: const Color(0xFF78350F),
        iconKey: 'cafe',
        isCustom: true,
      );
      await storage.addCategory(coffeeCat, TransactionType.expense);

      final coffeeTx = Transaction(
        id: 'tx-coffee-1',
        title: 'Espresso',
        amount: 4.50,
        type: TransactionType.expense,
        category: 'Coffee',
        date: DateTime.now(),
        currency: 'USD',
      );
      await storage.saveTransactions([coffeeTx]);

      // Delete "Coffee" and reassign to "Groceries"
      await storage.deleteCategory(
        categoryName: 'Coffee',
        type: TransactionType.expense,
        reassignToCategoryName: 'Groceries',
      );

      final transactions = await storage.loadTransactions();
      final updatedTx = transactions.firstWhere((t) => t.id == 'tx-coffee-1');
      expect(updatedTx.category, 'Groceries');

      final expenseCats = AppCategories.expenseCategories;
      expect(expenseCats.any((c) => c.name == 'Coffee'), isFalse);
    });

    test('Deleting category with archiveOnly hides category but preserves historical transactions', () async {
      final storage = StorageService();

      final gymCat = CategoryItem(
        id: 'cat-gym',
        name: 'Gym Membership',
        icon: Icons.fitness_center_rounded,
        color: const Color(0xFF10B981),
        iconKey: 'fitness',
        isCustom: true,
      );
      await storage.addCategory(gymCat, TransactionType.expense);

      final gymTx = Transaction(
        id: 'tx-gym-1',
        title: 'Monthly Gym',
        amount: 50.0,
        type: TransactionType.expense,
        category: 'Gym Membership',
        date: DateTime.now(),
        currency: 'USD',
      );
      await storage.saveTransactions([gymTx]);

      // Archive "Gym Membership"
      await storage.deleteCategory(
        categoryName: 'Gym Membership',
        type: TransactionType.expense,
        archiveOnly: true,
      );

      // Active expense categories does not include archived category
      expect(AppCategories.expenseCategories.any((c) => c.name == 'Gym Membership'), isFalse);

      // Transaction still retains its historical category name
      final transactions = await storage.loadTransactions();
      expect(transactions.firstWhere((t) => t.id == 'tx-gym-1').category, 'Gym Membership');

      // getCategoryItem still finds archived category metadata
      final item = AppCategories.getCategoryItem('Gym Membership', TransactionType.expense);
      expect(item.name, 'Gym Membership');
    });
  });

  group('Category Management Widget Tests', () {
    testWidgets('CategoryManagementScreen displays Expense and Income tabs with categories', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategoryManagementScreen(
            transactions: const [],
            onDataChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title
      expect(find.text('Category Management'), findsOneWidget);

      // Expense and Income tabs
      expect(find.textContaining('Expense ('), findsOneWidget);
      expect(find.textContaining('Income ('), findsOneWidget);

      // Add Category FAB
      expect(find.text('Add Category'), findsOneWidget);

      // Verify "Transfer Fees" is listed under Expense tab
      expect(find.text('Transfer Fees'), findsOneWidget);

      // Switch to Income tab
      await tester.tap(find.textContaining('Income ('));
      await tester.pumpAndSettle();

      // Verify income categories
      expect(find.text('Salary'), findsOneWidget);
    });

    testWidgets('SettingsTab navigates to CategoryManagementScreen when Category Management tile is tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsTab(
              onDataChanged: () {},
              onThemeModeChanged: (_) {},
              currentThemeMode: ThemeMode.light,
              transactions: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Category Management tile
      expect(find.text('Category Management'), findsOneWidget);

      // Tap Category Management
      await tester.tap(find.text('Category Management'));
      await tester.pumpAndSettle();

      // Dedicated screen opened with tabs
      expect(find.textContaining('Expense ('), findsOneWidget);
      expect(find.textContaining('Income ('), findsOneWidget);
    });

    testWidgets('AccountManagementScreen displays transfer with fee and editing pre-fills fee', (tester) async {
      final binance = MoneyAccount(
        id: 'acc-binance',
        name: 'Binance',
        currency: 'USD',
        createdAt: DateTime.now(),
      );
      final crypto = MoneyAccount(
        id: 'acc-crypto',
        name: 'Crypto Wallet',
        currency: 'USD',
        createdAt: DateTime.now(),
      );

      final transfer = AccountTransfer(
        id: 'tf-test-fee',
        fromAccountId: 'acc-binance',
        toAccountId: 'acc-crypto',
        amount: 100.0,
        toAmount: 100.0,
        fee: 2.0,
        feeTransactionId: 'fee-tx-1',
        date: DateTime.now(),
        note: 'Cold storage move',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountManagementScreen(
              transactions: const [],
              accounts: [binance, crypto],
              transfers: [transfer],
              onUpdateTransaction: (_) {},
              onDataChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Transfers tab
      await tester.tap(find.text('Transfers (1)'));
      await tester.pumpAndSettle();

      // Verify transfer card displays transfer amount and fee
      expect(find.text('Binance → Crypto Wallet'), findsOneWidget);
      expect(find.textContaining('Fee: \$2.00'), findsOneWidget);
      expect(find.textContaining('Total deducted: \$102.00'), findsOneWidget);

      // Tap Edit transfer icon
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      // Edit dialog opens with title "Edit Transfer" and prefilled fee
      expect(find.text('Edit Transfer'), findsOneWidget);
      expect(find.text('Transfer Fee (Optional)'), findsOneWidget);
      expect(find.text('2.00'), findsOneWidget); // Pre-filled fee
      expect(find.text('100.00'), findsOneWidget); // Pre-filled amount
      expect(find.text('Total Deducted from Source:'), findsOneWidget);
      expect(find.text('Update Transfer'), findsOneWidget);
    });
  });

  group('Home Allocation Breakdown Transfer Tests', () {
    testWidgets('Allocation Breakdown reflects transfer debits and credits while preserving total balance', (tester) async {
      final now = DateTime.now();
      final accountA = MoneyAccount(
        id: 'acc-a',
        name: 'Account A',
        currency: 'USD',
        createdAt: now,
      );
      final accountB = MoneyAccount(
        id: 'acc-b',
        name: 'Account B',
        currency: 'USD',
        createdAt: now,
      );

      final incomeTx1 = Transaction(
        id: 'tx-inc-1',
        title: 'Salary A',
        amount: 120.0,
        currency: 'USD',
        date: now,
        type: TransactionType.income,
        category: 'Salary',
        allocations: [
          AccountAllocation(accountId: 'acc-a', amount: 120.0),
        ],
      );

      final incomeTx2 = Transaction(
        id: 'tx-inc-2',
        title: 'Bonus B',
        amount: 100.0,
        currency: 'USD',
        date: now,
        type: TransactionType.income,
        category: 'Bonus',
        allocations: [
          AccountAllocation(accountId: 'acc-b', amount: 100.0),
        ],
      );

      // Transfer $20 from A to B
      final transfer = AccountTransfer(
        id: 'tf-1',
        fromAccountId: 'acc-a',
        toAccountId: 'acc-b',
        amount: 20.0,
        toAmount: 20.0,
        date: now,
        note: 'Transfer 20 from A to B',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountBreakdownSheet(
              isAllocationOnly: true,
              allTransactions: [incomeTx1, incomeTx2],
              accounts: [accountA, accountB],
              transfers: [transfer],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Total Balance is $220.00
      expect(find.text('TOTAL BALANCE'), findsOneWidget);
      expect(find.text('\$220.00'), findsOneWidget);
      expect(find.text('2 accounts'), findsOneWidget);
      expect(find.text('ALLOCATION BREAKDOWN'), findsOneWidget);

      // Account A reflects $100.00 ($120 income - $20 transfer)
      expect(find.text('Account A'), findsOneWidget);
      expect(find.text('\$100.00'), findsOneWidget);

      // Account B reflects $120.00 ($100 income + $20 transfer)
      expect(find.text('Account B'), findsOneWidget);
      expect(find.text('\$120.00'), findsOneWidget);
    });

    testWidgets('Expense and Income details sheets completely remove Allocation Breakdown', (tester) async {
      final now = DateTime.now();
      final account = MoneyAccount(
        id: 'acc-1',
        name: 'Checking',
        currency: 'USD',
        createdAt: now,
      );

      final expenseTx = Transaction(
        id: 'tx-exp-1',
        title: 'Groceries',
        amount: 50.0,
        currency: 'USD',
        date: now,
        type: TransactionType.expense,
        category: 'Food',
        allocations: [
          AccountAllocation(accountId: 'acc-1', amount: 50.0),
        ],
      );

      final incomeTx = Transaction(
        id: 'tx-inc-1',
        title: 'Salary',
        amount: 200.0,
        currency: 'USD',
        date: now,
        type: TransactionType.income,
        category: 'Salary',
        allocations: [
          AccountAllocation(accountId: 'acc-1', amount: 200.0),
        ],
      );

      // 1. Expense details sheet - completely removes Allocation Breakdown
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountBreakdownSheet(
              isIncome: false,
              isAllocationOnly: false,
              allTransactions: [expenseTx],
              accounts: [account],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Expenses by Account'), findsOneWidget);
      expect(find.text('TOTAL EXPENSES'), findsOneWidget);
      expect(find.text('\$50.00'), findsWidgets);
      expect(find.text('ALLOCATION BREAKDOWN'), findsNothing);

      // 2. Income details sheet - completely removes Allocation Breakdown
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountBreakdownSheet(
              isIncome: true,
              isAllocationOnly: false,
              allTransactions: [incomeTx],
              accounts: [account],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Income by Account'), findsOneWidget);
      expect(find.text('TOTAL INCOME'), findsOneWidget);
      expect(find.text('\$200.00'), findsWidgets);
      expect(find.text('ALLOCATION BREAKDOWN'), findsNothing);
    });

    testWidgets('HomeTab passes transfers to AccountBreakdownSheet and opens with correct balances', (tester) async {
      final now = DateTime.now();
      final accountA = MoneyAccount(
        id: 'acc-a',
        name: 'Account A',
        currency: 'USD',
        createdAt: now,
      );
      final accountB = MoneyAccount(
        id: 'acc-b',
        name: 'Account B',
        currency: 'USD',
        createdAt: now,
      );

      final incomeTx1 = Transaction(
        id: 'tx-inc-1',
        title: 'Salary A',
        amount: 120.0,
        currency: 'USD',
        date: now,
        type: TransactionType.income,
        category: 'Salary',
        allocations: [
          AccountAllocation(accountId: 'acc-a', amount: 120.0),
        ],
      );

      final incomeTx2 = Transaction(
        id: 'tx-inc-2',
        title: 'Bonus B',
        amount: 100.0,
        currency: 'USD',
        date: now,
        type: TransactionType.income,
        category: 'Bonus',
        allocations: [
          AccountAllocation(accountId: 'acc-b', amount: 100.0),
        ],
      );

      final transfer = AccountTransfer(
        id: 'tf-1',
        fromAccountId: 'acc-a',
        toAccountId: 'acc-b',
        amount: 20.0,
        toAmount: 20.0,
        date: now,
        note: 'Transfer 20 from A to B',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeTab(
              transactions: [incomeTx1, incomeTx2],
              onAddTransaction: (_) {},
              onUpdateTransaction: (_) {},
              onDeleteTransaction: (_) {},
              onNavigateToTransactions: () {},
              onOpenAddSheet: () {},
              isMoneyAccountsEnabled: true,
              accounts: [accountA, accountB],
              transfers: [transfer],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Income to open Income details sheet
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      // Income details sheet does not have ALLOCATION BREAKDOWN
      expect(find.text('Income by Account'), findsOneWidget);
      expect(find.text('ALLOCATION BREAKDOWN'), findsNothing);
      expect(find.text('TOTAL INCOME'), findsOneWidget);
      expect(find.text('\$220.00'), findsWidgets);

      // Dismiss Income sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Tap on Allocation Breakdown row under Total Balance
      expect(find.text('Allocation Breakdown'), findsOneWidget);
      await tester.tap(find.text('Allocation Breakdown'));
      await tester.pumpAndSettle();

      // Modal bottom sheet for Allocation Breakdown is open
      expect(find.text('ALLOCATION BREAKDOWN'), findsOneWidget);
      expect(find.text('TOTAL BALANCE'), findsWidgets);

      // Total balance is $220.00
      expect(find.text('\$220.00'), findsWidgets);

      // Account A is $100.00 and Account B is $120.00
      expect(find.text('\$100.00'), findsOneWidget);
      expect(find.text('\$120.00'), findsOneWidget);
    });

    testWidgets('Allocation Breakdown updates dynamically when transfer is updated or deleted', (tester) async {
      final now = DateTime.now();
      final accountA = MoneyAccount(
        id: 'acc-a',
        name: 'Account A',
        currency: 'USD',
        createdAt: now,
      );
      final accountB = MoneyAccount(
        id: 'acc-b',
        name: 'Account B',
        currency: 'USD',
        createdAt: now,
      );

      final incomeTx1 = Transaction(
        id: 'tx-inc-1',
        title: 'Salary A',
        amount: 120.0,
        currency: 'USD',
        date: now,
        type: TransactionType.income,
        category: 'Salary',
        allocations: [
          AccountAllocation(accountId: 'acc-a', amount: 120.0),
        ],
      );

      final incomeTx2 = Transaction(
        id: 'tx-inc-2',
        title: 'Bonus B',
        amount: 100.0,
        currency: 'USD',
        date: now,
        type: TransactionType.income,
        category: 'Bonus',
        allocations: [
          AccountAllocation(accountId: 'acc-b', amount: 100.0),
        ],
      );

      final transfer1 = AccountTransfer(
        id: 'tf-1',
        fromAccountId: 'acc-a',
        toAccountId: 'acc-b',
        amount: 20.0,
        toAmount: 20.0,
        date: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountBreakdownSheet(
              isAllocationOnly: true,
              allTransactions: [incomeTx1, incomeTx2],
              accounts: [accountA, accountB],
              transfers: [transfer1],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\$100.00'), findsOneWidget);
      expect(find.text('\$120.00'), findsOneWidget);

      // Now edit transfer to $50
      final transferEdited = AccountTransfer(
        id: 'tf-1',
        fromAccountId: 'acc-a',
        toAccountId: 'acc-b',
        amount: 50.0,
        toAmount: 50.0,
        date: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountBreakdownSheet(
              isAllocationOnly: true,
              allTransactions: [incomeTx1, incomeTx2],
              accounts: [accountA, accountB],
              transfers: [transferEdited],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Account A: 120 - 50 = $70.00; Account B: 100 + 50 = $150.00
      expect(find.text('\$70.00'), findsOneWidget);
      expect(find.text('\$150.00'), findsOneWidget);

      // Now delete transfer (transfers: [])
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountBreakdownSheet(
              isAllocationOnly: true,
              allTransactions: [incomeTx1, incomeTx2],
              accounts: [accountA, accountB],
              transfers: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Restored to original balances: A = $120.00, B = $100.00
      expect(find.text('\$120.00'), findsOneWidget);
      expect(find.text('\$100.00'), findsOneWidget);
    });

    testWidgets('Allocation Breakdown hides accounts with zero balance and shows only nonzero balance accounts', (tester) async {
      final now = DateTime.now();
      final accountNonzero = MoneyAccount(
        id: 'acc-nonzero',
        name: 'Checking Account',
        currency: 'USD',
        createdAt: now,
      );
      final accountZero = MoneyAccount(
        id: 'acc-zero',
        name: 'Empty Savings',
        currency: 'USD',
        createdAt: now,
      );
      final accountNegative = MoneyAccount(
        id: 'acc-neg',
        name: 'Credit Card',
        currency: 'USD',
        createdAt: now,
      );

      final incomeTx = Transaction(
        id: 'tx-1',
        title: 'Salary',
        amount: 250.0,
        currency: 'USD',
        date: now,
        type: TransactionType.income,
        category: 'Salary',
        allocations: [
          AccountAllocation(accountId: 'acc-nonzero', amount: 250.0),
        ],
      );

      final expenseTx = Transaction(
        id: 'tx-2',
        title: 'Shopping',
        amount: 50.0,
        currency: 'USD',
        date: now,
        type: TransactionType.expense,
        category: 'Shopping',
        allocations: [
          AccountAllocation(accountId: 'acc-neg', amount: 50.0),
        ],
      );

      // Render Allocation Breakdown with 3 accounts:
      // acc-nonzero: $250.00
      // acc-zero: $0.00 (should be HIDDEN)
      // acc-neg: -$50.00 (nonzero, should be shown)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountBreakdownSheet(
              isAllocationOnly: true,
              allTransactions: [incomeTx, expenseTx],
              accounts: [accountNonzero, accountZero, accountNegative],
              transfers: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only 2 nonzero accounts shown in badge and list
      expect(find.text('2 accounts'), findsOneWidget);
      expect(find.text('Checking Account'), findsOneWidget);
      expect(find.text('\$250.00'), findsOneWidget);
      expect(find.text('Credit Card'), findsOneWidget);
      expect(find.text('-\$50.00'), findsOneWidget);

      // Account with zero balance is NOT shown
      expect(find.text('Empty Savings'), findsNothing);

      // Scenario where all accounts have $0 balance
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountBreakdownSheet(
              isAllocationOnly: true,
              allTransactions: const [],
              accounts: [accountNonzero, accountZero],
              transfers: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 accounts'), findsOneWidget);
      expect(find.text('Checking Account'), findsNothing);
      expect(find.text('Empty Savings'), findsNothing);
      expect(find.text('No accounts with nonzero balance'), findsOneWidget);
    });
  });
}


