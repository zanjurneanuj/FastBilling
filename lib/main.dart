import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/local/hive_db.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Hive init — registers adapters + opens boxes
  await HiveDB.init();

  runApp(
    MultiProvider(
      providers: appProviders,
      child: const ZanvoyApp(),
    ),
  );
}