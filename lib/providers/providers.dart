import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import 'theme_provider.dart';
import 'locale_provider.dart';

final List<SingleChildWidget> appProviders = [
  ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
  ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
  ChangeNotifierProvider<AuthViewModel>(create: (_) => AuthViewModel()),
 // ChangeNotifierProvider<OnboardingViewModel>(create: (_) => OnboardingViewModel()),
  ChangeNotifierProvider<DashboardViewModel>(create: (_) => DashboardViewModel()),
  // ChangeNotifierProvider<InvoiceViewModel>(create: (_) => InvoiceViewModel()),
  // ChangeNotifierProvider<ClientViewModel>(create: (_) => ClientViewModel()),
  // ChangeNotifierProvider<CatalogViewModel>(create: (_) => CatalogViewModel()),
  // ChangeNotifierProvider<ReportsViewModel>(create: (_) => ReportsViewModel()),
  // ChangeNotifierProvider<SettingsViewModel>(create: (_) => SettingsViewModel()),
];