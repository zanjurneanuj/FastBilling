import 'dart:async';

import 'package:fast_billing/services/PosPrinterService.dart';
import 'package:fast_billing/services/PdfTemplateService.dart';
import 'package:fast_billing/services/SubscriptionService.dart';
import 'package:fast_billing/services/IntroService.dart';
import 'package:fast_billing/services/auth_service.dart';
import 'package:fast_billing/services/ProfileService.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';

void main() {
  runZonedGuarded(_bootstrap, (error, stack) {
    debugPrint('[UncaughtZoneError] $error\n$stack');
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };

  // Local-only, must complete before the router's first redirect decision.
  try {
    await IntroService.load();
  } catch (e, st) {
    debugPrint('[Bootstrap] intro flag load failed: $e\n$st');
  }

  var firebaseReady = true;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    firebaseReady = false;
    debugPrint('[Bootstrap] Firebase init failed: $e\n$st');
  }

  if (firebaseReady) {
    try {
      if (AuthService.isLoggedIn) {
        await ProfileService.load();
        await SubscriptionService.refresh();
      }
      await PosPrinterService.loadSettings();
      await PdfTemplateService.load();
    } catch (e, st) {
      debugPrint('[Bootstrap] startup data load failed: $e\n$st');
    }
  }

  runApp(
    firebaseReady
        ? MultiProvider(providers: appProviders, child: const ZanvoyApp())
        : const _BootstrapFailedApp(),
  );
}

/// Shown instead of a hard crash if Firebase itself fails to initialize
/// (e.g. no network on first launch, misconfigured platform files) — the
/// app can't function without it, but a friendly retry screen beats a
/// white screen or a stack trace.
class _BootstrapFailedApp extends StatelessWidget {
  const _BootstrapFailedApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  "Couldn't connect. Please check your internet connection and restart the app.",
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
