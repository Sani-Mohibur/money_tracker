# Changelog

All notable changes to the **Money Tracker** application will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-10-25

### Added
- **Loan & Liability Management System**:
  - Introduced a dedicated Loan Management module accessible from Settings and Home tab summary cards.
  - **Taking Loans (Borrowing Records)**:
    - Record loans with title, lender name, origination date, gross principal, processing fee, currency, and notes.
    - Integrated proper double-entry accounting principles: loan principal is tracked as a debt liability rather than revenue/income.
    - Automatic deduction of processing fees from gross principal to compute true net proceeds entering available cash.
    - Multi-account split allocation: assign net loan proceeds across one or more Money Accounts (Bank, Cash, Wallets), or preserve unassigned proceeds.
  - **Outstanding Balance & Debt Tracking**:
    - Real-time tracking of remaining principal balance, total principal repaid, and total interest paid.
    - Hero progress indicator showcasing debt amortization progress from 0% to 100%.
    - Dynamic status indicators transitioning automatically between **Active** and **Fully Repaid**.
  - **Partial & Full Repayments**:
    - Record partial repayments over time or utilize the one-tap **"Repay Full"** shortcut to prefill the exact outstanding principal balance.
    - Distinct separation of **Principal Repayment** and **Interest Paid**:
      - Principal repayments reduce outstanding loan liabilities without counting as an expense.
      - Interest paid automatically generates a linked expense transaction under the dedicated **"Loan Interest"** category.
    - Allocation of total repayment cash outflow across active Money Accounts.
    - Comprehensive repayment history list with date, breakdown, and swipe-to-delete or tap-to-inspect capabilities.
  - **Comprehensive Unit & Integration Test Suite**:
    - Added full accounting and lifecycle test coverage in `test/loan_management_test.dart` verifying net proceeds calculation, unassigned funds tracking, interest transaction linkage, and balance integrity.

### Fixed
- **Dark Mode UI & Contrast Fixes (Loan Management)**:
  - Fixed low-contrast and low-opacity appearance on primary action buttons ("+ Record Loan", "Make Repayment", "Record Repayment", "Update Loan", and "Update Repayment") in dark mode by switching to theme-aware primary styling and high-contrast text.
  - Resolved card edge blending against dark scaffold backgrounds by introducing subtle white borders on overview and hero cards in dark mode.
  - Enhanced visibility of status badges, chips, and icons by adopting high-contrast Emerald (`#34D399`), Amber (`#FBBF24`), and Rose (`#F87171`) hues in dark mode while preserving light mode aesthetics.
  - Fixed dropdown menu background contrast in currency and account selectors within bottom sheets.
  - Fixed delete dialog confirmation buttons to ensure text contrast remains crisp across both light and dark themes.

---

## [1.0.0] - 2026-10-18

### Added
- **Core Financial Tracking**:
  - Record income and expense transactions with amount, category, date, notes, and currency.
  - Search transactions by title, filter by type (Income, Expense, All), and filter across date ranges.
- **Visual Analytics & Reporting**:
  - Native Donut chart showing category-based income and expense percentage distributions.
  - Native Bar chart comparing periodic income and expense trends (Weekly, Monthly, Yearly).
  - Lightweight chart rendering using Flutter `CustomPainter` with zero external charting dependencies.
- **Calendar Tab**:
  - Monthly calendar view highlighting days with financial activity.
  - Interactive daily breakdown displaying transactions, daily income, daily expenses, and net daily balance.
- **Money Accounts Subsystem**:
  - Multi-account management for Bank Accounts, Cash, Digital Wallets, and Savings.
  - Multi-account transaction allocations.
  - Inter-account transfers with linked transfer fee expense tracking.
  - Theoretical balance calculation and balance reconciliation against physical account statements.
- **Multi-Currency Engine**:
  - Support for 8 global currencies: BDT (৳), USD ($), EUR (€), GBP (£), INR (₹), JPY (¥), CAD (C$), and AUD (A$).
  - Configurable default currency with automatic baseline exchange rate conversions.
- **Custom Category Management**:
  - Create, customize, and archive expense and income categories with custom icon and color pickers.
- **Material 3 Design & Theming**:
  - Full Material 3 implementation with persistent Light and Dark themes.
- **Privacy & Data Portability**:
  - Completely offline-first architecture with local persistence via `SharedPreferences`.
  - JSON backup export and restore capabilities.
  - Factory reset option to wipe local data.
