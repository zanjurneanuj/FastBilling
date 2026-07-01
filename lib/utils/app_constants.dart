// Utility constants and helpers
// TODO: Add utility code
class AppConstants {
  AppConstants._();

  // Hive box names
  static const String hiveBusinessBox = 'business_box';
  static const String hiveClientBox = 'client_box';
  static const String hiveInvoiceBox = 'invoice_box';
  static const String hiveCatalogBox = 'catalog_box';

  // App defaults
  static const List<String> currencies = [
    'INR',
    'USD',
    'EUR',
    'GBP',
    'AED',
    'SGD',
    'AUD',
    'CAD',
  ];
  static const List<int> taxRates = [0, 5, 12, 18, 28];
  static const List<int> dueDays = [7, 15, 30, 45, 60];
}
