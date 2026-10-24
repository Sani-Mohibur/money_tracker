import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_tracker/constants/categories.dart';
import 'package:money_tracker/models/account_allocation.dart';
import 'package:money_tracker/models/loan.dart';
import 'package:money_tracker/models/loan_repayment.dart';
import 'package:money_tracker/models/money_account.dart';
import 'package:money_tracker/models/transaction.dart';
import 'package:money_tracker/screens/loan_details_screen.dart';
import 'package:money_tracker/screens/loan_management_screen.dart';
import 'package:money_tracker/screens/settings_tab.dart';
import 'package:money_tracker/screens/account_management_screen.dart';
import 'package:money_tracker/services/account_service.dart';
import 'package:money_tracker/services/storage_service.dart';
import 'package:money_tracker/widgets/account_breakdown_sheet.dart';
import 'package:money_tracker/widgets/add_loan_sheet.dart';
import 'package:money_tracker/widgets/add_repayment_sheet.dart';
import 'package:money_tracker/widgets/add_transaction_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'has_launched_before': true,
      'saved_transactions_v1': '[]',
      'saved_loans_v1': '[]',
      'saved_loan_repayments_v1': '[]',
      'pref_money_accounts_enabled': true,
    });
  });

  group('Loan and LoanRepayment Models', () {
    test('Loan model serialization, netAmountReceived, and allocation helpers', () {
      final loan = Loan(
        id: 'loan_1',
        title: 'Bank Personal Loan',
        lender: 'City Bank',
        principal: 25000.0,
        fee: 500.0,
        date: DateTime(2026, 3, 1),
        note: 'Home renovation loan',
        currency: 'USD',
        allocations: const [
          AccountAllocation(accountId: 'acc_checking', amount: 20000.0),
          AccountAllocation(accountId: 'acc_savings', amount: 4500.0),
        ],
        createdAt: DateTime(2026, 3, 1),
      );

      expect(loan.netAmountReceived, 24500.0);
      expect(loan.totalAllocated, 24500.0);
      expect(loan.unassignedAmount, 0.0);
      expect(loan.hasUnassigned, isFalse);

      final map = loan.toMap();
      final reconstructed = Loan.fromMap(map);

      expect(reconstructed.id, 'loan_1');
      expect(reconstructed.title, 'Bank Personal Loan');
      expect(reconstructed.lender, 'City Bank');
      expect(reconstructed.principal, 25000.0);
      expect(reconstructed.fee, 500.0);
      expect(reconstructed.netAmountReceived, 24500.0);
      expect(reconstructed.allocations.length, 2);
      expect(reconstructed.allocations.first.accountId, 'acc_checking');
      expect(reconstructed.allocations.first.amount, 20000.0);
    });

    test('Loan unassigned amount calculation when partially allocated', () {
      final loan = Loan(
        id: 'loan_2',
        title: 'Emergency Loan',
        principal: 10000.0,
        fee: 200.0,
        date: DateTime(2026, 3, 1),
        allocations: const [
          AccountAllocation(accountId: 'acc_checking', amount: 6000.0),
        ],
        createdAt: DateTime(2026, 3, 1),
      );

      expect(loan.netAmountReceived, 9800.0);
      expect(loan.totalAllocated, 6000.0);
      expect(loan.unassignedAmount, 3800.0);
      expect(loan.hasUnassigned, isTrue);
    });

    test('LoanRepayment model serialization, totalPayment, and unassigned helpers', () {
      final repayment = LoanRepayment(
        id: 'rep_1',
        loanId: 'loan_1',
        principalAmount: 10000.0,
        interestAmount: 2000.0,
        date: DateTime(2026, 4, 1),
        note: 'First installment',
        currency: 'USD',
        interestTransactionId: 'tx_interest_1',
        allocations: const [
          AccountAllocation(accountId: 'acc_checking', amount: 8000.0),
        ],
        createdAt: DateTime(2026, 4, 1),
      );

      expect(repayment.totalPayment, 12000.0);
      expect(repayment.totalAllocated, 8000.0);
      expect(repayment.unassignedAmount, 4000.0);
      expect(repayment.hasUnassigned, isTrue);

      final map = repayment.toMap();
      final reconstructed = LoanRepayment.fromMap(map);

      expect(reconstructed.id, 'rep_1');
      expect(reconstructed.loanId, 'loan_1');
      expect(reconstructed.principalAmount, 10000.0);
      expect(reconstructed.interestAmount, 2000.0);
      expect(reconstructed.totalPayment, 12000.0);
      expect(reconstructed.interestTransactionId, 'tx_interest_1');
      expect(reconstructed.allocations.length, 1);
    });
  });

  group('Accounting & Invariant Calculations', () {
    final accountService = AccountService();

    test('Zero-fee loan increases overall balance by principal with no fee deducted', () {
      final loan = Loan(
        id: 'l_zero_fee',
        title: 'Zero Fee Loan',
        principal: 10000.0,
        fee: 0.0,
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );

      final balance = accountService.calculateOverallBalance(
        [],
        'USD',
        [loan],
        [],
      );

      expect(loan.netAmountReceived, 10000.0);
      expect(balance, 10000.0);
    });

    test('Non-zero fee loan: Net proceeds = Principal - Fee increases balance; fee is not an expense', () {
      // User prompt scenario:
      // Loan principal: 25,000, fee: 500 -> Net proceeds: 24,500
      final loan = Loan(
        id: 'l_prompt',
        title: 'Personal Loan',
        principal: 25000.0,
        fee: 500.0,
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );

      final balance = accountService.calculateOverallBalance(
        [],
        'USD',
        [loan],
        [],
      );

      // Balance must be 24,500, NOT 25,000
      expect(loan.netAmountReceived, 24500.0);
      expect(balance, 24500.0);
    });

    test('Outstanding principal, total repaid, total interest, and progress calculations', () {
      final loan = Loan(
        id: 'l_progress',
        title: 'Car Loan',
        principal: 25000.0,
        fee: 500.0,
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );

      final repayments = [
        LoanRepayment(
          id: 'r1',
          loanId: 'l_progress',
          principalAmount: 5000.0,
          interestAmount: 500.0,
          date: DateTime(2026, 2, 1),
          createdAt: DateTime(2026, 2, 1),
        ),
        LoanRepayment(
          id: 'r2',
          loanId: 'l_progress',
          principalAmount: 5000.0,
          interestAmount: 300.0,
          date: DateTime(2026, 3, 1),
          createdAt: DateTime(2026, 3, 1),
        ),
      ];

      final totalRepaid = accountService.calculateTotalPrincipalRepaid(loan, repayments);
      final outstanding = accountService.calculateOutstandingPrincipal(loan, repayments);
      final totalInterest = accountService.calculateTotalInterestPaid(loan, repayments);
      final progress = accountService.calculateRepaymentProgress(loan, repayments);
      final isFullyRepaid = accountService.isLoanFullyRepaid(loan, repayments);

      expect(totalRepaid, 10000.0);
      expect(outstanding, 15000.0);
      expect(totalInterest, 800.0);
      // Progress = (10000 / 25000) * 100 = 40.0%
      expect(progress, 40.0);
      expect(isFullyRepaid, isFalse);
    });

    test('Repayment accounting: Total payment deducted from balance, interest recorded as expense, principal reduces liability without duplicate expense', () {
      // User prompt scenario:
      // Initial state: Loan of 25,000 (fee 500) -> Net balance 24,500
      final loan = Loan(
        id: 'l_prompt_rep',
        title: 'Personal Loan',
        principal: 25000.0,
        fee: 500.0,
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );

      // Repayment: Principal repayment 10,000, Interest 2,000 -> Total payment 12,000
      final repayment = LoanRepayment(
        id: 'r_prompt',
        loanId: 'l_prompt_rep',
        principalAmount: 10000.0,
        interestAmount: 2000.0,
        date: DateTime(2026, 2, 1),
        interestTransactionId: 'tx_int_prompt',
        createdAt: DateTime(2026, 2, 1),
      );

      // The 2000 interest is recorded as an expense transaction
      final interestTx = Transaction(
        id: 'tx_int_prompt',
        title: 'Loan Interest - Personal Loan',
        amount: 2000.0,
        type: TransactionType.expense,
        category: 'Loan Interest',
        date: DateTime(2026, 2, 1),
      );

      final overallBalance = accountService.calculateOverallBalance(
        [interestTx],
        'USD',
        [loan],
        [repayment],
      );

      // Net proceeds: +24,500
      // Repayment: -10,000 (principal) - 2,000 (interest expense) = -12,000 total payment
      // Expected overall balance: 24,500 - 12,000 = 12,500
      expect(overallBalance, 12500.0);

      final outstanding = accountService.calculateOutstandingPrincipal(loan, [repayment]);
      expect(outstanding, 15000.0);
    });

    test('Zero interest repayment does not create duplicate or negative balance', () {
      final loan = Loan(
        id: 'l_zero_int',
        title: 'Family Loan',
        principal: 5000.0,
        fee: 0.0,
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );

      final repayment = LoanRepayment(
        id: 'r_zero_int',
        loanId: 'l_zero_int',
        principalAmount: 2000.0,
        interestAmount: 0.0, // 0 interest
        date: DateTime(2026, 2, 1),
        interestTransactionId: null,
        createdAt: DateTime(2026, 2, 1),
      );

      final overallBalance = accountService.calculateOverallBalance(
        [],
        'USD',
        [loan],
        [repayment],
      );

      // 5000 - 2000 = 3000
      expect(overallBalance, 3000.0);
      expect(accountService.calculateOutstandingPrincipal(loan, [repayment]), 3000.0);
    });

    test('Loan reaches 100% progress and is marked fully repaid when outstanding is 0', () {
      final loan = Loan(
        id: 'l_full',
        title: 'Study Loan',
        principal: 10000.0,
        fee: 0.0,
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );

      final repayment = LoanRepayment(
        id: 'r_full',
        loanId: 'l_full',
        principalAmount: 10000.0,
        interestAmount: 500.0,
        date: DateTime(2026, 5, 1),
        createdAt: DateTime(2026, 5, 1),
      );

      expect(accountService.calculateOutstandingPrincipal(loan, [repayment]), 0.0);
      expect(accountService.calculateRepaymentProgress(loan, [repayment]), 100.0);
      expect(accountService.isLoanFullyRepaid(loan, [repayment]), isTrue);
    });
  });

  group('Money Accounts Allocation and Balance Engine', () {
    final accountService = AccountService();

    test('Loan net proceeds allocate to specific accounts; account balances increase', () {
      final checking = MoneyAccount(
        id: 'chk',
        name: 'Checking Account',
        currency: 'USD',
        createdAt: DateTime(2026, 1, 1),
      );
      final savings = MoneyAccount(
        id: 'svg',
        name: 'Savings Account',
        currency: 'USD',
        createdAt: DateTime(2026, 1, 1),
      );

      final loan = Loan(
        id: 'l_alloc',
        title: 'Business Loan',
        principal: 20000.0,
        fee: 1000.0, // Net: 19000
        date: DateTime(2026, 1, 1),
        allocations: const [
          AccountAllocation(accountId: 'chk', amount: 15000.0),
          AccountAllocation(accountId: 'svg', amount: 4000.0),
        ],
        createdAt: DateTime(2026, 1, 1),
      );

      final chkBalance = accountService.calculateAccountBalance(
        checking,
        [],
        [],
        loans: [loan],
        repayments: [],
      );

      final svgBalance = accountService.calculateAccountBalance(
        savings,
        [],
        [],
        loans: [loan],
        repayments: [],
      );

      expect(chkBalance, 15000.0);
      expect(svgBalance, 4000.0);
    });

    test('Repayment total payment (principal + interest) debited from allocated accounts', () {
      final checking = MoneyAccount(
        id: 'chk',
        name: 'Checking Account',
        currency: 'USD',
        createdAt: DateTime(2026, 1, 1),
      );

      // Step 1: Initial income into checking
      final initialIncome = Transaction(
        id: 'tx_inc',
        title: 'Salary',
        amount: 30000.0,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime(2026, 1, 1),
        allocations: const [
          AccountAllocation(accountId: 'chk', amount: 30000.0),
        ],
      );

      // Step 2: Loan with 0 fee received into checking
      final loan = Loan(
        id: 'l_1',
        title: 'Loan 1',
        principal: 10000.0,
        fee: 0.0,
        date: DateTime(2026, 1, 2),
        allocations: const [
          AccountAllocation(accountId: 'chk', amount: 10000.0),
        ],
        createdAt: DateTime(2026, 1, 2),
      );

      // Checking balance now: 40000
      // Step 3: Repayment: Principal 5000 + Interest 1000 = Total Payment 6000 allocated to checking
      final repayment = LoanRepayment(
        id: 'rep_1',
        loanId: 'l_1',
        principalAmount: 5000.0,
        interestAmount: 1000.0,
        date: DateTime(2026, 2, 1),
        interestTransactionId: 'tx_int_1',
        allocations: const [
          AccountAllocation(accountId: 'chk', amount: 6000.0),
        ],
        createdAt: DateTime(2026, 2, 1),
      );

      // Interest transaction (has NO allocations because repayment handles the cash outflow!)
      final interestTx = Transaction(
        id: 'tx_int_1',
        title: 'Loan Interest - Loan 1',
        amount: 1000.0,
        type: TransactionType.expense,
        category: 'Loan Interest',
        date: DateTime(2026, 2, 1),
      );

      final chkBalance = accountService.calculateAccountBalance(
        checking,
        [initialIncome, interestTx],
        [],
        loans: [loan],
        repayments: [repayment],
      );

      // Initial 30000 + Loan 10000 - Repayment 6000 = 34000
      expect(chkBalance, 34000.0);

      final overallBalance = accountService.calculateOverallBalance(
        [initialIncome, interestTx],
        'USD',
        [loan],
        [repayment],
      );

      // Overall: 30000 (income) - 1000 (interest expense) + 10000 (net loan) - 5000 (principal repaid) = 34000
      expect(overallBalance, 34000.0);
    });

    test('Unassigned loan amounts are never automatically assigned to random accounts', () {
      final checking = MoneyAccount(
        id: 'chk',
        name: 'Checking Account',
        currency: 'USD',
        createdAt: DateTime(2026, 1, 1),
      );

      final loan = Loan(
        id: 'l_unassigned',
        title: 'Personal Loan',
        principal: 10000.0,
        fee: 0.0,
        date: DateTime(2026, 1, 1),
        allocations: const [], // completely unallocated
        createdAt: DateTime(2026, 1, 1),
      );

      final chkBalance = accountService.calculateAccountBalance(
        checking,
        [],
        [],
        loans: [loan],
        repayments: [],
      );

      expect(chkBalance, 0.0);
      expect(loan.unassignedAmount, 10000.0);

      final overallBalance = accountService.calculateOverallBalance(
        [],
        'USD',
        [loan],
        [],
      );
      expect(overallBalance, 10000.0);
    });

    test('Validation: Rejects invalid loan and repayment amounts', () {
      // Loan validations
      expect(
        accountService.validateLoan(
          title: '',
          principal: 1000.0,
          fee: 0.0,
          allocations: [],
        ),
        'Please enter a loan title.',
      );

      expect(
        accountService.validateLoan(
          title: 'Loan',
          principal: 0.0,
          fee: 0.0,
          allocations: [],
        ),
        'Loan principal must be greater than zero.',
      );

      expect(
        accountService.validateLoan(
          title: 'Loan',
          principal: 1000.0,
          fee: -50.0,
          allocations: [],
        ),
        'Loan fee cannot be negative.',
      );

      expect(
        accountService.validateLoan(
          title: 'Loan',
          principal: 1000.0,
          fee: 1000.0,
          allocations: [],
        ),
        'Loan fee must be less than the loan principal.',
      );

      // Repayment validations
      expect(
        accountService.validateRepayment(
          principalAmount: 0.0,
          interestAmount: 0.0,
          outstandingPrincipal: 5000.0,
          allocations: [],
        ),
        'Principal repayment amount must be greater than zero.',
      );

      expect(
        accountService.validateRepayment(
          principalAmount: 1000.0,
          interestAmount: -10.0,
          outstandingPrincipal: 5000.0,
          allocations: [],
        ),
        'Interest amount cannot be negative.',
      );

      expect(
        accountService.validateRepayment(
          principalAmount: 6000.0, // exceeds 5000 outstanding
          interestAmount: 0.0,
          outstandingPrincipal: 5000.0,
          allocations: [],
        ),
        contains('cannot exceed outstanding principal'),
      );
    });

    test('Available funds reversal when editing repayment prevents false insufficient funds error', () {
      final checking = MoneyAccount(
        id: 'chk',
        name: 'Checking',
        currency: 'USD',
        createdAt: DateTime.now(),
      );

      // Repayment of 8000 from checking
      final repayment = LoanRepayment(
        id: 'r1',
        loanId: 'l1',
        principalAmount: 8000.0,
        interestAmount: 0.0,
        date: DateTime.now(),
        allocations: const [AccountAllocation(accountId: 'chk', amount: 8000.0)],
        createdAt: DateTime.now(),
      );

      // Current balance in checking is 2000. Without reversal, available is 2000.
      final availWithoutReversal = accountService.getAvailableFundsForRepayment(
        account: checking,
        currentBalance: 2000.0,
      );
      expect(availWithoutReversal, 2000.0);

      // With reversal (editing r1), checking restores the 8000 allocation, resulting in 10000 available.
      final availWithReversal = accountService.getAvailableFundsForRepayment(
        account: checking,
        currentBalance: 2000.0,
        existingRepayment: repayment,
      );
      expect(availWithReversal, 10000.0);
    });
  });

  group('StorageService Atomic Persistence and Reversals', () {
    test('saveRepaymentWithInterest atomically persists repayment and linked expense transaction', () async {
      final storage = StorageService();
      final loan = Loan(
        id: 'loan_atomic',
        title: 'Mortgage',
        principal: 50000.0,
        fee: 0.0,
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );

      await storage.saveLoans([loan]);

      final interestTx = Transaction(
        id: 'tx_int_atomic',
        title: 'Loan Interest - Mortgage',
        amount: 2500.0,
        type: TransactionType.expense,
        category: 'Loan Interest',
        date: DateTime(2026, 2, 1),
      );

      final repayment = LoanRepayment(
        id: 'rep_atomic',
        loanId: 'loan_atomic',
        principalAmount: 10000.0,
        interestAmount: 2500.0,
        date: DateTime(2026, 2, 1),
        interestTransactionId: 'tx_int_atomic',
        createdAt: DateTime(2026, 2, 1),
      );

      await storage.saveRepaymentWithInterest(
        repayment: repayment,
        interestTransaction: interestTx,
      );

      // Verify repayment saved with interestTransactionId populated
      final repayments = await storage.loadLoanRepayments();
      expect(repayments.length, 1);
      expect(repayments.first.interestTransactionId, 'tx_int_atomic');

      // Verify interest expense transaction created
      final transactions = await storage.loadTransactions();
      expect(transactions.length, 1);
      final tx = transactions.first;
      expect(tx.id, 'tx_int_atomic');
      expect(tx.amount, 2500.0);
      expect(tx.isExpense, isTrue);
      expect(tx.title, 'Loan Interest - Mortgage');
      expect(tx.category, 'Loan Interest');
    });

    test('deleteRepaymentWithInterest atomically deletes repayment and removes linked interest transaction', () async {
      final storage = StorageService();
      final loan = Loan(
        id: 'loan_del',
        title: 'Student Loan',
        principal: 15000.0,
        fee: 0.0,
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      await storage.saveLoans([loan]);

      final interestTx = Transaction(
        id: 'tx_int_del',
        title: 'Loan Interest - Student Loan',
        amount: 1000.0,
        type: TransactionType.expense,
        category: 'Loan Interest',
        date: DateTime(2026, 2, 1),
      );

      final repayment = LoanRepayment(
        id: 'rep_del',
        loanId: 'loan_del',
        principalAmount: 5000.0,
        interestAmount: 1000.0,
        date: DateTime(2026, 2, 1),
        interestTransactionId: 'tx_int_del',
        createdAt: DateTime(2026, 2, 1),
      );

      await storage.saveRepaymentWithInterest(
        repayment: repayment,
        interestTransaction: interestTx,
      );

      // Confirm both exist
      expect((await storage.loadLoanRepayments()).length, 1);
      expect((await storage.loadTransactions()).length, 1);

      // Delete repayment
      await storage.deleteRepaymentWithInterest('rep_del');

      // Both must be deleted cleanly
      expect((await storage.loadLoanRepayments()).length, 0);
      expect((await storage.loadTransactions()).length, 0);
    });

    test('deleteLoanWithRepayments cascades atomically to delete loan, all repayments, and interest transactions', () async {
      final storage = StorageService();
      final loan = Loan(
        id: 'loan_cascade',
        title: 'Company Loan',
        principal: 40000.0,
        fee: 500.0,
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      await storage.saveLoans([loan]);

      final r1 = LoanRepayment(
        id: 'r1',
        loanId: 'loan_cascade',
        principalAmount: 10000.0,
        interestAmount: 1500.0,
        date: DateTime(2026, 2, 1),
        interestTransactionId: 'int_r1',
        createdAt: DateTime(2026, 2, 1),
      );
      final r2 = LoanRepayment(
        id: 'r2',
        loanId: 'loan_cascade',
        principalAmount: 10000.0,
        interestAmount: 1200.0,
        date: DateTime(2026, 3, 1),
        interestTransactionId: 'int_r2',
        createdAt: DateTime(2026, 3, 1),
      );

      final tx1 = Transaction(
        id: 'int_r1',
        title: 'Loan Interest - Company Loan',
        amount: 1500.0,
        type: TransactionType.expense,
        category: 'Loan Interest',
        date: DateTime(2026, 2, 1),
      );
      final tx2 = Transaction(
        id: 'int_r2',
        title: 'Loan Interest - Company Loan',
        amount: 1200.0,
        type: TransactionType.expense,
        category: 'Loan Interest',
        date: DateTime(2026, 3, 1),
      );

      await storage.saveRepaymentWithInterest(repayment: r1, interestTransaction: tx1);
      await storage.saveRepaymentWithInterest(repayment: r2, interestTransaction: tx2);

      expect((await storage.loadLoans()).length, 1);
      expect((await storage.loadLoanRepayments()).length, 2);
      expect((await storage.loadTransactions()).length, 2);

      // Cascade delete loan
      await storage.deleteLoanWithRepayments('loan_cascade');

      expect((await storage.loadLoans()).length, 0);
      expect((await storage.loadLoanRepayments()).length, 0);
      expect((await storage.loadTransactions()).length, 0);
    });

    test('loadAllCategories ensures Loan Interest default category is loaded and deduplicated', () async {
      final storage = StorageService();
      await storage.loadAllCategories();
      final expenseCategories = AppCategories.allExpenseCategories;

      final matches = expenseCategories.where((c) => c.name.toLowerCase() == 'loan interest').toList();
      expect(matches.length, 1);
      expect(matches.first.iconKey, 'loan_interest');
    });
  });

  group('UI & Widget Tests', () {
    testWidgets('SettingsTab navigates to LoanManagementScreen when Loan Management tile tapped', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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

      final loanTile = find.text('Loan Management');
      expect(loanTile, findsOneWidget);

      await tester.tap(loanTile);
      await tester.pumpAndSettle();

      // Verified navigation to LoanManagementScreen
      expect(find.byType(LoanManagementScreen), findsOneWidget);
      expect(find.text('No Loans Recorded'), findsOneWidget);
    });

    testWidgets('LoanManagementScreen renders overview metrics, chips, and empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoanManagementScreen(
            transactions: const [],
            accounts: const [],
            transfers: const [],
            isMoneyAccountsEnabled: true,
            onDataChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Loan Management'), findsOneWidget);
      expect(find.text('TOTAL OUTSTANDING DEBT'), findsOneWidget);
      expect(find.text('Principal Repaid'), findsOneWidget);
      expect(find.text('Interest Paid'), findsOneWidget);
      expect(find.text('All (0)'), findsOneWidget);
      expect(find.text('Active (0)'), findsOneWidget);
      expect(find.text('Fully Repaid (0)'), findsOneWidget);
      expect(find.text('No Loans Recorded'), findsOneWidget);
      expect(find.text('Take a Loan'), findsOneWidget);
    });

    testWidgets('AddLoanSheet calculates Net Proceeds correctly and validates input', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => AddLoanSheet(
                      accounts: [
                        MoneyAccount(
                          id: 'chk',
                          name: 'Checking',
                          currency: 'USD',
                          createdAt: DateTime.now(),
                        ),
                      ],
                      isMoneyAccountsEnabled: true,
                      onSave: (_) {},
                    ),
                  );
                },
                child: const Text('Open Add Loan'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Add Loan'));
      await tester.pumpAndSettle();

      expect(find.text('Take a Loan'), findsOneWidget);
      expect(find.textContaining('Net Amount Received'), findsOneWidget);

      // Find Loan Title input and enter title
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Loan Name *'),
        'Car Loan',
      );
      await tester.pumpAndSettle();

      // Enter Principal 25000 and Fee 500
      final principalField = find.widgetWithText(TextFormField, 'Principal Amount *');
      await tester.enterText(principalField, '25000');
      await tester.pumpAndSettle();

      final feeField = find.widgetWithText(TextFormField, 'Loan Fee');
      await tester.enterText(feeField, '500');
      await tester.pumpAndSettle();

      // Verify Net Amount Received banner updates to $24,500.00
      expect(find.textContaining('24,500.00'), findsWidgets);
    });

    testWidgets('LoanDetailsScreen shows financial details, progress, and prevents repayment when fully repaid', (tester) async {
      final loan = Loan(
        id: 'l_det',
        title: 'Mortgage Loan',
        principal: 10000.0,
        fee: 0.0,
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );

      final repayment = LoanRepayment(
        id: 'r_det',
        loanId: 'l_det',
        principalAmount: 10000.0,
        interestAmount: 500.0,
        date: DateTime(2026, 2, 1),
        createdAt: DateTime(2026, 2, 1),
      );

      final storage = StorageService();
      await storage.saveLoans([loan]);
      await storage.saveLoanRepayments([repayment]);

      await tester.pumpWidget(
        MaterialApp(
          home: LoanDetailsScreen(
            loan: loan,
            transactions: const [],
            accounts: const [],
            transfers: const [],
            allLoans: [loan],
            allRepayments: [repayment],
            isMoneyAccountsEnabled: false,
            onDataChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mortgage Loan'), findsOneWidget);
      expect(find.text('Fully Repaid'), findsOneWidget);
      expect(find.text('100.0%'), findsOneWidget);
      expect(find.textContaining('REPAYMENT HISTORY'), findsOneWidget);
      expect(find.text('This loan is fully repaid'), findsOneWidget);
    });
  });

  group('Money Accounts Balance Synchronization across Loans and Repayments', () {
    testWidgets('Example 1 — Taking a loan: Wallet starts at 100, taking 500 loan reflects 600 in Allocation Breakdown and Add Expense form', (tester) async {
      final now = DateTime.now();
      final wallet = MoneyAccount(
        id: 'acc_wallet',
        name: 'Wallet',
        currency: 'USD',
        createdAt: now,
      );

      // Initial income of $100 allocated to Wallet
      final initialTx = Transaction(
        id: 'tx_init',
        title: 'Initial Funds',
        amount: 100.0,
        currency: 'USD',
        date: now,
        type: TransactionType.income,
        category: 'Salary',
        allocations: [
          AccountAllocation(accountId: 'acc_wallet', amount: 100.0),
        ],
      );

      // Loan of $500 taken and allocated 100% to Wallet
      final loan = Loan(
        id: 'loan_500',
        title: 'Personal Loan',
        principal: 500.0,
        fee: 0.0,
        date: now,
        createdAt: now,
        allocations: [
          AccountAllocation(accountId: 'acc_wallet', amount: 500.0),
        ],
      );

      // 1. Check AccountBreakdownSheet (Allocation Breakdown) shows $600.00
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountBreakdownSheet(
              isAllocationOnly: true,
              allTransactions: [initialTx],
              accounts: [wallet],
              loans: [loan],
              repayments: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TOTAL BALANCE'), findsOneWidget);
      expect(find.text('\$600.00'), findsWidgets);
      expect(find.text('Wallet'), findsOneWidget);

      // 2. Check AddTransactionSheet (Add Expense form) displays actual balance of $600.00
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddTransactionSheet(
              onSave: (_) {},
              isMoneyAccountsEnabled: true,
              accounts: [wallet],
              allTransactions: [initialTx],
              transfers: const [],
              loans: [loan],
              repayments: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter amount 600
      await tester.enterText(find.widgetWithText(TextFormField, '0.00'), '600');
      await tester.pumpAndSettle();

      // Tap "Add Account" to allocate
      await tester.tap(find.text('Add Account'));
      await tester.pumpAndSettle();

      // Verify Available Funds displays $600.00 (not $100.00)
      expect(find.text('Available: \$600.00'), findsOneWidget);

      // No error for allocating $600
      expect(find.textContaining('Exceeds available funds'), findsNothing);
    });

    testWidgets('Example 2 — Repaying a loan: Repayment is deducted and appears consistently across Breakdown, AccountManagementScreen, and Add Expense form', (tester) async {
      final now = DateTime.now();
      final wallet = MoneyAccount(
        id: 'acc_wallet',
        name: 'Wallet',
        currency: 'USD',
        createdAt: now,
      );

      // Initial income of $1000 allocated to Wallet
      final initialTx = Transaction(
        id: 'tx_init',
        title: 'Initial Funds',
        amount: 1000.0,
        currency: 'USD',
        date: now,
        type: TransactionType.income,
        category: 'Salary',
        allocations: [
          AccountAllocation(accountId: 'acc_wallet', amount: 1000.0),
        ],
      );

      // Loan of $500 allocated to Wallet (Total now $1500)
      final loan = Loan(
        id: 'loan_500',
        title: 'Personal Loan',
        principal: 500.0,
        fee: 0.0,
        date: now,
        createdAt: now,
        allocations: [
          AccountAllocation(accountId: 'acc_wallet', amount: 500.0),
        ],
      );

      // Repayment of $300 allocated from Wallet ($1500 - $300 = $1200)
      final repayment = LoanRepayment(
        id: 'rep_300',
        loanId: 'loan_500',
        principalAmount: 300.0,
        interestAmount: 0.0,
        date: now,
        createdAt: now,
        allocations: [
          AccountAllocation(accountId: 'acc_wallet', amount: 300.0),
        ],
      );

      // 1. Allocation Breakdown shows $1,200.00
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountBreakdownSheet(
              isAllocationOnly: true,
              allTransactions: [initialTx],
              accounts: [wallet],
              loans: [loan],
              repayments: [repayment],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TOTAL BALANCE'), findsOneWidget);
      expect(find.text('\$1,200.00'), findsWidgets);

      // 2. AccountManagementScreen displays $1,200.00
      await tester.pumpWidget(
        MaterialApp(
          home: AccountManagementScreen(
            transactions: [initialTx],
            accounts: [wallet],
            transfers: const [],
            loans: [loan],
            repayments: [repayment],
            onUpdateTransaction: (_) {},
            onDataChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('\$1,200.00'), findsWidgets);

      // 3. AddTransactionSheet displays Available: $1,200.00
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddTransactionSheet(
              onSave: (_) {},
              isMoneyAccountsEnabled: true,
              accounts: [wallet],
              allTransactions: [initialTx],
              transfers: const [],
              loans: [loan],
              repayments: [repayment],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, '0.00'), '1200');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Account'));
      await tester.pumpAndSettle();

      expect(find.text('Available: \$1,200.00'), findsOneWidget);
      expect(find.textContaining('Exceeds available funds'), findsNothing);
    });

    testWidgets('AddRepaymentSheet respects global repayment deductions across all loans', (tester) async {
      final now = DateTime.now();
      final wallet = MoneyAccount(
        id: 'acc_wallet',
        name: 'Wallet',
        currency: 'USD',
        createdAt: now,
      );

      // Wallet has $1000
      final initialTx = Transaction(
        id: 'tx_init',
        title: 'Salary',
        amount: 1000.0,
        currency: 'USD',
        date: now,
        type: TransactionType.income,
        category: 'Salary',
        allocations: [
          AccountAllocation(accountId: 'acc_wallet', amount: 1000.0),
        ],
      );

      // Loan 1 and Loan 2
      final loan1 = Loan(
        id: 'loan_1',
        title: 'Loan 1',
        principal: 500.0,
        fee: 0.0,
        date: now,
        createdAt: now,
      );
      final loan2 = Loan(
        id: 'loan_2',
        title: 'Loan 2',
        principal: 1000.0,
        fee: 0.0,
        date: now,
        createdAt: now,
      );

      // Repayment of $200 made on Loan 1 from Wallet
      final rep1 = LoanRepayment(
        id: 'rep_1',
        loanId: 'loan_1',
        principalAmount: 200.0,
        interestAmount: 0.0,
        date: now,
        createdAt: now,
        allocations: [
          AccountAllocation(accountId: 'acc_wallet', amount: 200.0),
        ],
      );

      // Open AddRepaymentSheet for Loan 2 passing repayments: [rep1]
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddRepaymentSheet(
              loan: loan2,
              currentOutstandingPrincipal: 1000.0,
              isMoneyAccountsEnabled: true,
              accounts: [wallet],
              allTransactions: [initialTx],
              transfers: const [],
              loans: [loan1, loan2],
              repayments: [rep1],
              onSave: (repayment, tx) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter repayment of 800
      await tester.enterText(find.widgetWithText(TextFormField, 'Principal Amount *'), '800');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Account'));
      await tester.pumpAndSettle();

      // Wallet available funds is 1000 - 200 = 800, so entering 800 has no error
      expect(find.textContaining('Insufficient funds'), findsNothing);

      // Entering 850 exceeds available funds of 800
      final allocField = find.byType(TextFormField).last;
      await tester.enterText(allocField, '850');
      await tester.pumpAndSettle();

      expect(find.textContaining('Insufficient funds (Available: 800.00 USD)'), findsOneWidget);
    });
  });
}
