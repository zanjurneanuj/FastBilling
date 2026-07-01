import 'package:flutter/material.dart';

/// Supported app locales
enum AppLocale {
  english('en', 'English'),
  hindi('hi', 'हिन्दी'),
  marathi('mr', 'मराठी');

  const AppLocale(this.code, this.label);
  final String code;
  final String label;

  Locale get locale => Locale(code);
}

class LocaleProvider extends ChangeNotifier {
  AppLocale _current = AppLocale.english;

  AppLocale get current => _current;
  Locale get locale => _current.locale;
  String get languageCode => _current.code;

  void setLocale(AppLocale locale) {
    if (_current == locale) return;
    _current = locale;
    notifyListeners();
  }

  /// Supported locales list — pass to MaterialApp.supportedLocales
  static List<Locale> get supportedLocales =>
      AppLocale.values.map((l) => l.locale).toList();
}
