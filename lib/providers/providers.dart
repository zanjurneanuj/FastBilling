import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../viewmodels/InvoicePreviewViewModel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/client_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/reports_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'theme_provider.dart';
import 'locale_provider.dart';

final List<SingleChildWidget> appProviders = [
  ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
  ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
  ChangeNotifierProvider<AuthViewModel>(create: (_) => AuthViewModel()),
  ChangeNotifierProvider<DashboardViewModel>(create: (_) => DashboardViewModel()),
  ChangeNotifierProvider<ClientsViewModel>(create: (_) => ClientsViewModel()),
  ChangeNotifierProvider<ReportsViewModel>(create: (_) => ReportsViewModel()),
  ChangeNotifierProvider<SettingsViewModel>(create: (_) => SettingsViewModel()),
  ChangeNotifierProvider<InvoicePreviewViewModel>(create: (_) => InvoicePreviewViewModel()),
];