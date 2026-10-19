import 'package:intl/intl.dart';
import '../models/currency.dart';

/// Formatting utilities for multi-currency and dates across the app.
class Formatters {
  /// Format double amount with specific currency symbol and decimals.
  /// Example: "$1,250.00", "৳1,250.00", "¥1,250"
  static String formatCurrency(double amount, [String currencyCode = 'USD']) {
    final currency = AppCurrency.fromCode(currencyCode);
    final formatter = NumberFormat.currency(
      symbol: currency.symbol,
      decimalDigits: currency.decimalDigits,
    );
    return formatter.format(amount);
  }

  /// Compact currency format (omitting decimals if clean integer).
  static String formatCompactCurrency(double amount, [String currencyCode = 'USD']) {
    final currency = AppCurrency.fromCode(currencyCode);
    if (amount % 1 == 0 || currency.decimalDigits == 0) {
      final formatter = NumberFormat.currency(
        symbol: currency.symbol,
        decimalDigits: 0,
      );
      return formatter.format(amount);
    }
    return formatCurrency(amount, currencyCode);
  }

  /// Format date as readable relative string or standard date
  /// e.g. "Today", "Yesterday", or "Oct 19, 2026"
  static String formatFriendlyDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    final difference = today.difference(targetDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference == -1) {
      return 'Tomorrow';
    } else if (date.year == now.year) {
      return DateFormat('MMM d').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  /// Formats date with year, e.g. "Oct 19, 2026"
  static String formatFullDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  /// Formats Month and Year, e.g. "October 2026"
  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  /// Formats short Month and Day, e.g. "Oct 19"
  static String formatShortDate(DateTime date) {
    return DateFormat('MMM d').format(date);
  }
}
