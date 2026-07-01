import 'package:hive_flutter/hive_flutter.dart';

// import '../../models/business_model.dart';
// import '../../models/catalog_item_model.dart';
// import '../../models/client_model.dart';
// import '../../models/invoice_model.dart';
// import '../../models/line_item_model.dart';
// import '../../utils/app_constants.dart';

class HiveDB {
  HiveDB._();

  static Future<void> init() async {
    // 1. Init Hive with Flutter path
    await Hive.initFlutter();

    // 2. Register all adapters
    // Hive.registerAdapter(BusinessModelAdapter());
    // Hive.registerAdapter(LineItemModelAdapter());
    // Hive.registerAdapter(ClientModelAdapter());
    // Hive.registerAdapter(InvoiceModelAdapter());
    // Hive.registerAdapter(CatalogItemModelAdapter());

    // 3. Open all boxes
    await Future.wait([
      // Hive.openBox<BusinessModel>(AppConstants.hiveBusinessBox),
      // Hive.openBox<ClientModel>(AppConstants.hiveClientBox),
      // Hive.openBox<InvoiceModel>(AppConstants.hiveInvoiceBox),
      // Hive.openBox<CatalogItemModel>(AppConstants.hiveCatalogBox),
    ]);
  }

  // Box getters — use anywhere in the app
  // static Box<BusinessModel>    get businessBox => Hive.box(AppConstants.hiveBusinessBox);
  // static Box<ClientModel>      get clientBox   => Hive.box(AppConstants.hiveClientBox);
  // static Box<InvoiceModel>     get invoiceBox  => Hive.box(AppConstants.hiveInvoiceBox);
  // static Box<CatalogItemModel> get catalogBox  => Hive.box(AppConstants.hiveCatalogBox);
}