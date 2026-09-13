import 'package:flutter/material.dart';

import '../services/local_db_service.dart';

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
  static const _localeKey = 'settings_locale';

  AppLocale _current = AppLocale.english;

  LocaleProvider() {
    _restore();
  }

  Future<void> _restore() async {
    final code = await LocalDbService.instance.getSetting(_localeKey);
    if (code == null) return;
    final match = AppLocale.values.where((l) => l.code == code);
    if (match.isEmpty) return;
    _current = match.first;
    notifyListeners();
  }

  AppLocale get current => _current;
  Locale get locale => _current.locale;
  String get languageCode => _current.code;

  void setLocale(AppLocale locale) {
    if (_current == locale) return;
    _current = locale;
    notifyListeners();
    LocalDbService.instance.saveSetting(_localeKey, locale.code);
  }

  /// Supported locales list — pass to MaterialApp.supportedLocales
  static List<Locale> get supportedLocales =>
      AppLocale.values.map((l) => l.locale).toList();
}
