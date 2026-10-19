/// Supported currencies in the application.
class AppCurrency {
  final String code;
  final String symbol;
  final String name;
  final int decimalDigits;
  final bool symbolOnLeft;

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    this.decimalDigits = 2,
    this.symbolOnLeft = true,
  });

  static const AppCurrency bdt = AppCurrency(
    code: 'BDT',
    symbol: '৳',
    name: 'Bangladeshi Taka',
    decimalDigits: 2,
  );

  static const AppCurrency usd = AppCurrency(
    code: 'USD',
    symbol: '\$',
    name: 'US Dollar',
    decimalDigits: 2,
  );

  static const AppCurrency eur = AppCurrency(
    code: 'EUR',
    symbol: '€',
    name: 'Euro',
    decimalDigits: 2,
  );

  static const AppCurrency gbp = AppCurrency(
    code: 'GBP',
    symbol: '£',
    name: 'British Pound',
    decimalDigits: 2,
  );

  static const AppCurrency inr = AppCurrency(
    code: 'INR',
    symbol: '₹',
    name: 'Indian Rupee',
    decimalDigits: 2,
  );

  static const AppCurrency jpy = AppCurrency(
    code: 'JPY',
    symbol: '¥',
    name: 'Japanese Yen',
    decimalDigits: 0,
  );

  static const AppCurrency cad = AppCurrency(
    code: 'CAD',
    symbol: 'C\$',
    name: 'Canadian Dollar',
    decimalDigits: 2,
  );

  static const AppCurrency aud = AppCurrency(
    code: 'AUD',
    symbol: 'A\$',
    name: 'Australian Dollar',
    decimalDigits: 2,
  );

  /// All supported currencies list.
  static const List<AppCurrency> all = [
    bdt,
    usd,
    eur,
    gbp,
    inr,
    jpy,
    cad,
    aud,
  ];

  /// Find currency by 3-letter code, defaulting to USD if not found.
  static AppCurrency fromCode(String code) {
    return all.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => usd,
    );
  }

  /// Default baseline exchange rates relative to 1 USD.
  /// (e.g. 1 USD = 121.50 BDT, 1 USD = 0.92 EUR, etc.)
  static const Map<String, double> defaultRatesToUsd = {
    'USD': 1.0,
    'BDT': 121.50,
    'EUR': 0.92,
    'GBP': 0.79,
    'INR': 86.50,
    'JPY': 152.00,
    'CAD': 1.38,
    'AUD': 1.52,
  };
}
