# Money Tracker 💰

A modern, fast, and privacy-focused personal finance and expense tracking application built with **Flutter** and **Material 3**. Money Tracker is designed to be completely **offline-first**, storing all financial records securely on your device with no mandatory account creation, tracking, or cloud dependencies.

---

## 🌟 Key Features

### 💳 Transaction Management
- **Income & Expense Tracking:** Log transactions with title, amount, category, date, notes, and currency.
- **Categorization:** Preloaded with comprehensive categories for daily spending and earnings.
- **Split Account Allocation:** Assign transaction funds across one or more money accounts, or keep them unassigned.
- **Search & Filtering:** Real-time search by keywords, filter by transaction type (Income / Expense / All), and filter across custom date intervals.

### 📊 Statistics & Visual Analytics
- **Category Breakdown (Donut Chart):** Interactive donut chart visualizing expense and income distribution by category with percentage breakdowns.
- **Spending Trends (Bar Chart):** Compare income versus expenses across flexible periods (Weekly, Monthly, Yearly).
- **Lightweight Custom Visualizations:** Charts are built natively using Flutter `CustomPainter` without heavy third-party charting libraries, ensuring high performance and smooth 60fps animations.

### 📅 Calendar View
- **Date-Centric Overview:** Monthly calendar view displaying markers on days with financial activity.
- **Daily Inspection:** Tap any day to inspect the exact transactions, income, expense, and net balance recorded on that date.
- **Quick Date Navigation:** Jump across months or instantly return to today.

### 🏦 Money Accounts Subsystem
- **Multi-Account Tracking:** Manage separate financial accounts such as Bank Accounts, Cash Wallets, Digital Wallets, and Savings.
- **Inter-Account Transfers:** Transfer funds between accounts with optional transfer fee logging (automatically linked as an expense).
- **Reconciliation & Balances:** Calculate real-time theoretical balances based on allocations, transfers, and loans, and reconcile against actual account statements.
- **Visual Account Breakdown:** Modal sheets and summary cards showing liquidity distributions across active accounts.

### 🤝 Loan & Liability Management *(New in v1.0.1)*
- **Borrowing Records:** Track loans taken from banks, institutions, or individuals with principal amount, lender details, and origination date.
- **Net Proceeds Accounting:** Accurately deducts processing fees from gross principal to calculate net received funds, preventing artificial inflation of income.
- **Funds Allocation:** Deposit loan proceeds directly into designated money accounts.
- **Repayment Tracking:** Record partial or full repayments with customizable splits between **Principal** and **Interest**:
  - *Principal repayment* reduces outstanding debt liability without skewing expense metrics.
  - *Interest paid* is automatically recorded as an ordinary expense under the "Loan Interest" category.
  - Repayment cash outflows can be drawn from designated money accounts.
- **Real-Time Debt Progress:** Monitor outstanding balances, total paid principal, total interest paid, total cash outflow, and repayment progress indicators.
- **Status Lifecycle:** Automatic status tracking switching between **Active** and **Fully Repaid**.

### 🌐 Multi-Currency Support
- **Global Currency Engine:** Built-in support for 8 global currencies:
  - 🇧🇩 **BDT** (৳ - Bangladeshi Taka)
  - 🇺🇸 **USD** ($ - US Dollar)
  - 🇪🇺 **EUR** (€ - Euro)
  - 🇬🇧 **GBP** (£ - British Pound)
  - 🇮🇳 **INR** (₹ - Indian Rupee)
  - 🇯🇵 **JPY** (¥ - Japanese Yen)
  - 🇨🇦 **CAD** (C$ - Canadian Dollar)
  - 🇦🇺 **AUD** (A$ - Australian Dollar)
- **Default Currency Setting:** Set a global default currency for summary cards and reporting with baseline currency conversion.

### 🏷️ Custom Category Management
- **Tailored Categories:** Create, edit, and archive custom income and expense categories.
- **Color & Icon Customization:** Choose from a curated icon set and vibrant color palette for easy visual identification.

### 🌓 Material 3 Theming
- **Adaptive Light & Dark Modes:** Fully compliant with Material 3 design principles.
- **High-Contrast Dark Mode:** Engineered for readability with elevated card surfaces, high-contrast action buttons, and accessible badge indicators.
- **Theme Persistence:** Seamlessly switches between System, Light, and Dark modes, persisted across app restarts.

### 🔒 Privacy & Data Maintenance
- **100% Offline-First:** Zero network requests required. All data stays strictly on the user's device.
- **Backup & Restore:** Export all transactions, accounts, transfers, loans, and categories into a JSON file, or restore backups effortlessly.
- **Factory Reset:** One-click clear option to wipe local state and start fresh with default categories.

---

## 🛠️ Technology Stack

| Layer | Technology |
|---|---|
| **Framework** | [Flutter](https://flutter.dev/) (Channel stable, SDK `^3.13.5`) |
| **Language** | [Dart](https://dart.dev/) |
| **Design System** | Material Design 3 (`useMaterial3: true`) |
| **Data Persistence** | [`shared_preferences`](https://pub.dev/packages/shared_preferences) (Local JSON serialization) |
| **Formatting** | [`intl`](https://pub.dev/packages/intl) (Date and currency formatting) |
| **Icons** | Material Icons & [`cupertino_icons`](https://pub.dev/packages/cupertino_icons) |
| **Charts** | Custom `CustomPainter` implementations (Zero external charting bloat) |
| **Testing** | `flutter_test` (Unit tests for accounting models, services, and widget flows) |

---

## 📁 Project Architecture

The codebase follows a modular, layered architecture ensuring separation of concerns:

```
lib/
├── constants/          # Static definitions, default categories, and color palettes
│   └── categories.dart
├── models/             # Domain data models with JSON serialization and accounting helpers
│   ├── account_allocation.dart
│   ├── account_transfer.dart
│   ├── currency.dart
│   ├── loan.dart
│   ├── loan_repayment.dart
│   ├── money_account.dart
│   └── transaction.dart
├── screens/            # Full-screen views and primary application tabs
│   ├── account_management_screen.dart
│   ├── calendar_tab.dart
│   ├── category_management_screen.dart
│   ├── home_screen.dart
│   ├── home_tab.dart
│   ├── loan_details_screen.dart
│   ├── loan_management_screen.dart
│   ├── main_scaffold.dart
│   ├── settings_tab.dart
│   ├── statistics_tab.dart
│   └── transactions_tab.dart
├── services/           # Business logic, calculations, and local storage operations
│   ├── account_service.dart
│   ├── currency_service.dart
│   └── storage_service.dart
├── utils/              # General utility helpers, formatters, and validators
│   └── formatters.dart
├── widgets/            # Reusable UI widgets, bottom sheets, dialogs, and custom charts
│   ├── charts/
│   │   ├── bar_chart.dart
│   │   └── donut_chart.dart
│   ├── account_breakdown_sheet.dart
│   ├── add_loan_sheet.dart
│   ├── add_repayment_sheet.dart
│   ├── add_transaction_dialog.dart
│   ├── balance_card.dart
│   └── transaction_tile.dart
└── main.dart           # Application root, theme configurations, and initialization
```

---

## 🚀 Getting Started

### Prerequisites

Ensure you have the following installed on your machine:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.13.5 or higher)
- [Dart SDK](https://dart.dev/get-dart)
- Android Studio / VS Code with Flutter and Dart extensions
- An active Android emulator, iOS simulator, or physical device

### Installation & Setup

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/your-username/money_tracker.git
   cd money_tracker
   ```

2. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify Setup:**
   ```bash
   flutter doctor
   ```

### Running the App

To launch the app in debug mode on a connected device or emulator:

```bash
flutter run
```

To run in release mode for maximum performance:

```bash
flutter run --release
```

---

## 🧪 Running Tests

The test suite validates financial balance calculations, loan accounting rules, allocation logic, and storage integrity:

```bash
flutter test
```

To run a specific test suite:

```bash
flutter test test/loan_management_test.dart
flutter test test/money_accounts_test.dart
```

---

## 📦 Building for Production

### Android

- **Build APK:**
  ```bash
  flutter build apk --release
  ```
- **Build App Bundle (for Google Play):**
  ```bash
  flutter build appbundle --release
  ```

### iOS

- **Build iOS Archive:**
  ```bash
  flutter build ipa --release
  ```

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).
