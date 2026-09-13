import '../providers/locale_provider.dart';

/// App text, translated for every [AppLocale] the language picker offers.
/// Lightweight by design (no .arb/gen-l10n pipeline) — a plain lookup keyed
/// by the already-selected AppLocale, so switching languages in Settings
/// actually changes visible text instead of only updating a preference.
class AppStrings {
  AppStrings._();

  static const String appName = 'Zanvoy';

  static String _pick(AppLocale l, String en, String hi, String mr) {
    switch (l) {
      case AppLocale.hindi:
        return hi;
      case AppLocale.marathi:
        return mr;
      case AppLocale.english:
        return en;
    }
  }

  // ── Login ────────────────────────────────────────
  static String welcomeBack(AppLocale l) =>
      _pick(l, 'Welcome back', 'वापसी पर स्वागत है', 'परत स्वागत आहे');
  static String loginSubtitle(AppLocale l) => _pick(
      l,
      'Sign in to manage your invoices.',
      'अपने चालान प्रबंधित करने के लिए साइन इन करें।',
      'तुमची इनव्हॉइस व्यवस्थापित करण्यासाठी साइन इन करा.');
  static String emailLabel(AppLocale l) => _pick(l, 'Email', 'ईमेल', 'ईमेल');
  static const String emailHint = 'you@example.com';
  static String passwordLabel(AppLocale l) =>
      _pick(l, 'Password', 'पासवर्ड', 'पासवर्ड');
  static String forgotPassword(AppLocale l) => _pick(
      l, 'Forgot password?', 'पासवर्ड भूल गए?', 'पासवर्ड विसरलात?');
  static String signIn(AppLocale l) =>
      _pick(l, 'Sign in', 'साइन इन करें', 'साइन इन करा');
  static String orDivider(AppLocale l) => _pick(l, 'or', 'या', 'किंवा');
  static String continueGoogle(AppLocale l) => _pick(
      l, 'Continue with Google', 'Google से जारी रखें', 'Google सह सुरू ठेवा');
  static String newHere(AppLocale l) =>
      _pick(l, 'New here?', 'यहाँ नए हैं?', 'नवीन आहात?');
  static String createAccount(AppLocale l) =>
      _pick(l, 'Create account', 'खाता बनाएं', 'खाते तयार करा');

  // ── Validation ───────────────────────────────────
  static String emailRequired(AppLocale l) =>
      _pick(l, 'Email is required', 'ईमेल आवश्यक है', 'ईमेल आवश्यक आहे');
  static String emailInvalid(AppLocale l) => _pick(
      l, 'Enter a valid email', 'एक मान्य ईमेल दर्ज करें', 'वैध ईमेल टाका');
  static String passwordRequired(AppLocale l) => _pick(
      l, 'Password is required', 'पासवर्ड आवश्यक है', 'पासवर्ड आवश्यक आहे');
  static String passwordMinLen(AppLocale l) => _pick(
      l, 'Minimum 6 characters', 'न्यूनतम 6 अक्षर', 'किमान 6 अक्षरे');

  // ── Navigation ───────────────────────────────────
  static String navHome(AppLocale l) => _pick(l, 'Home', 'होम', 'मुख्यपृष्ठ');
  static String navInvoices(AppLocale l) =>
      _pick(l, 'Invoices', 'चालान', 'इनव्हॉइस');
  static String navClients(AppLocale l) =>
      _pick(l, 'Clients', 'ग्राहक', 'क्लायंट');
  static String navReports(AppLocale l) =>
      _pick(l, 'Reports', 'रिपोर्ट', 'अहवाल');
  static String navSettings(AppLocale l) =>
      _pick(l, 'Settings', 'सेटिंग्स', 'सेटिंग्ज');
}
