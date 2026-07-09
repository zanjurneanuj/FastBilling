import 'package:fast_billing/services/auth_service.dart';
import 'package:fast_billing/utils/go_router_refresh_stream.dart';
import 'package:fast_billing/services/ProfileService.dart';
import 'package:fast_billing/views/screens/PdfTemplateView.dart';
import 'package:fast_billing/views/screens/register_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'utils/app_colors.dart';
import 'utils/app_strings.dart';
import 'views/screens/login_view.dart';
import 'views/screens/onboarding_view.dart';
import 'views/screens/home_view.dart';
import 'views/screens/invoice_list_view.dart';
import 'views/screens/invoice_create_view.dart';
import 'views/screens/invoice_preview_view.dart';
import 'views/screens/clients_view.dart';
import 'views/screens/client_detail_view.dart';
import 'views/screens/catalog_view.dart';
import 'views/screens/reports_view.dart';
import 'views/screens/settings_view.dart';

class ZanvoyApp extends StatelessWidget {
  const ZanvoyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Both providers drive a full app rebuild when they change
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final locale    = context.watch<LocaleProvider>().locale;

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,

      // ── Theme ──────────────────────────────────────────────────────────────
      themeMode: themeMode,
      theme:     _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),

      // ── Localisation ───────────────────────────────────────────────────────
      locale: locale,
      supportedLocales: LocaleProvider.supportedLocales,
      // Uncomment when you add .arb files:
      // localizationsDelegates: AppLocalizations.localizationsDelegates,

      routerConfig: _router,
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg      = isDark ? AppColors.darkBackground   : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface      : AppColors.lightSurface;
    final fill    = isDark ? AppColors.darkInputFill    : AppColors.lightInputFill;
    final txtPri  = isDark ? AppColors.darkTextPrimary  : AppColors.lightTextPrimary;
    final txtSec  = isDark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final border  = isDark ? AppColors.darkBorder       : AppColors.lightBorder;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
      ).copyWith(
        primary:   AppColors.primary,
        secondary: AppColors.accent,
        surface:   surface,
        onPrimary: Colors.white,
        error:     AppColors.error,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: txtPri,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: txtPri,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: border),
          foregroundColor: txtPri,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: TextStyle(color: txtSec),
        hintStyle: TextStyle(color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerColor: border,
      iconTheme: IconThemeData(color: txtSec),
    );
  }
}

// ─── Router ───────────────────────────────────────────────────────────────────

final GoRouter _router = GoRouter(
  initialLocation: '/login',
  refreshListenable: Listenable.merge([
    GoRouterRefreshStream(AuthService.authStateChanges),
    ProfileService.changed,
  ]),  redirect: (context, state) {
    final loggedIn   = AuthService.isLoggedIn;
    final hasProfile = ProfileService.hasProfile;
    final loc = state.matchedLocation;
    final onAuth = loc == '/login' || loc == '/register';

    if (!loggedIn) return onAuth ? null : '/login';
    if (!hasProfile) return loc == '/onboarding' ? null : '/onboarding';
    if (onAuth || loc == '/onboarding') return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/login',           builder: (c, s) => const LoginView()),
    GoRoute(path: '/register', builder: (c, s) => const RegisterView()), 
    GoRoute(path: '/onboarding',      builder: (c, s) => const OnboardingView()),
    GoRoute(path: '/home',            builder: (c, s) => const HomeView()),
    GoRoute(path: '/invoices',        builder: (c, s) => const InvoiceListView()),
    GoRoute(path: '/invoices/create', builder: (c, s) => const InvoiceCreateView()),
    GoRoute(
      path: '/invoices/:id/preview',
      builder: (c, s) => InvoicePreviewView(invoiceId: s.pathParameters['id']!),
    ),
    GoRoute(path: '/clients',         builder: (c, s) => const ClientsView()),
    GoRoute(
      path: '/clients/:id',
      builder: (c, s) => ClientDetailView(clientId: s.pathParameters['id']!),
    ),
    GoRoute(path: '/catalog',         builder: (c, s) => const CatalogView()),
    GoRoute(path: '/reports',         builder: (c, s) => const ReportsView()),
    GoRoute(
      path: '/settings',
      builder: (c, s) => const SettingsView(),
      routes: [
        GoRoute(
          path: 'pdf-template',              // no leading slash — it becomes /settings/pdf-template
          builder: (c, s) => const PdfTemplateView(),
        ),
      ],
    ),
  ],
);
