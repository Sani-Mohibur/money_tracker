import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency.dart';

/// Service managing currencies, exchange rates, and offline-first currency conversions.
class CurrencyService {
  static const String _defaultCurrencyKey = 'pref_default_currency';
  static const String _exchangeRatesKey = 'pref_exchange_rates_v1';
  static const String _ratesLastUpdatedKey = 'pref_rates_last_updated';

  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  String _defaultCurrencyCode = 'USD';
  Map<String, double> _ratesToUsd = Map.from(AppCurrency.defaultRatesToUsd);
  DateTime _lastUpdated = DateTime.now();

  String get defaultCurrencyCode => _defaultCurrencyCode;
  AppCurrency get defaultCurrency => AppCurrency.fromCode(_defaultCurrencyCode);
  Map<String, double> get ratesToUsd => Map.unmodifiable(_ratesToUsd);
  DateTime get lastUpdated => _lastUpdated;

  /// Initializes currency service by loading saved preferences and rates.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedDefault = prefs.getString(_defaultCurrencyKey);
      if (savedDefault != null && savedDefault.isNotEmpty) {
        _defaultCurrencyCode = savedDefault;
      }

      final savedRatesJson = prefs.getString(_exchangeRatesKey);
      if (savedRatesJson != null && savedRatesJson.isNotEmpty) {
        try {
          final Map<String, dynamic> decoded = json.decode(savedRatesJson);
          final Map<String, double> loadedRates = {};
          decoded.forEach((key, value) {
            if (value is num) {
              loadedRates[key] = value.toDouble();
            }
          });
          // Ensure all supported currencies have at least default rate
          for (final entry in AppCurrency.defaultRatesToUsd.entries) {
            loadedRates.putIfAbsent(entry.key, () => entry.value);
          }
          _ratesToUsd = loadedRates;
        } catch (e) {
          debugPrint('Error parsing saved exchange rates: $e');
          _ratesToUsd = Map.from(AppCurrency.defaultRatesToUsd);
        }
      } else {
        _ratesToUsd = Map.from(AppCurrency.defaultRatesToUsd);
      }

      final savedTime = prefs.getString(_ratesLastUpdatedKey);
      if (savedTime != null) {
        _lastUpdated = DateTime.tryParse(savedTime) ?? DateTime.now();
      } else {
        _lastUpdated = DateTime.now();
      }
    } catch (e, stack) {
      debugPrint('Error initializing CurrencyService: $e\n$stack');
      _defaultCurrencyCode = 'USD';
      _ratesToUsd = Map.from(AppCurrency.defaultRatesToUsd);
      _lastUpdated = DateTime.now();
    }
  }

  /// Sets the application's default currency and persists it.
  Future<void> setDefaultCurrency(String code) async {
    _defaultCurrencyCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultCurrencyKey, code);
  }

  /// Updates exchange rate for a currency relative to 1 USD.
  Future<void> updateRate(String currencyCode, double rateToUsd) async {
    if (rateToUsd <= 0) return;
    _ratesToUsd[currencyCode.toUpperCase()] = rateToUsd;
    _lastUpdated = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_exchangeRatesKey, json.encode(_ratesToUsd));
    await prefs.setString(_ratesLastUpdatedKey, _lastUpdated.toIso8601String());
  }

  /// Resets exchange rates to default baseline values.
  Future<void> resetRatesToDefault() async {
    _ratesToUsd = Map.from(AppCurrency.defaultRatesToUsd);
    _lastUpdated = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_exchangeRatesKey, json.encode(_ratesToUsd));
    await prefs.setString(_ratesLastUpdatedKey, _lastUpdated.toIso8601String());
  }

  /// Converts an amount from [fromCode] to [toCode] using current exchange rates.
  /// If [toCode] is omitted, converts into default currency.
  double convert(double amount, String fromCode, [String? toCode]) {
    final targetCode = (toCode ?? _defaultCurrencyCode).toUpperCase();
    final sourceCode = fromCode.toUpperCase();

    if (sourceCode == targetCode || amount == 0.0) {
      return amount;
    }

    final sourceRate = _ratesToUsd[sourceCode] ?? 1.0;
    final targetRate = _ratesToUsd[targetCode] ?? 1.0;

    // Convert from source currency to USD, then USD to target currency
    final amountInUsd = amount / sourceRate;
    return amountInUsd * targetRate;
  }
}
