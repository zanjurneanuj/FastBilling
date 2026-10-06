import 'dart:async';

import 'package:fast_billing/services/AppLockService.dart';
import 'package:fast_billing/services/PosPrinterService.dart';
import 'package:fast_billing/services/PdfTemplateService.dart';
import 'package:fast_billing/services/SessionService.dart';
import 'package:fast_billing/services/IntroService.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'views/screens/splash_view.dart';
import 'providers/providers.dart';
import 'utils/app_features.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('[FlutterError] ${details.exceptionAsString()}');
    };
    // First frame immediately: the branded splash animates while startup
    // work runs, instead of a blank native window waiting on the network.
    runApp(const _Root());
  }, (error, stack) {
    debugPrint('[UncaughtZoneError] $error\n$stack');
  });
}

/// Startup work. Only what the router's first redirect needs (intro flag,
/// Firebase, cached profile, local template/printer settings) is awaited;
/// network refreshes (subscription status, cross-device template sync)
/// finish in the background and notify their listeners.
Future<bool> _bootstrap() async {
  final sw = Stopwatch()..start();

  try {
    await Future.wait([IntroService.load(), AppLockService.load()]);
  } catch (e, st) {
    debugPrint('[Bootstrap] local settings load failed: $e\n$st');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    debugPrint('[Bootstrap] Firebase init failed: $e\n$st');
    return false;
  }

  try {
    await Future.wait([
      if (AppFeatures.posPrinter) PosPrinterService.loadSettings(),
      PdfTemplateService.loadLocal(),
    ]);
    // Loads the signed-in account's profile (awaited) and keeps per-account
    // state in sync with later sign-ins / sign-outs.
    await SessionService.start();
  } catch (e, st) {
    debugPrint('[Bootstrap] startup data load failed: $e\n$st');
  }

  debugPrint('[Bootstrap] ready in ${sw.elapsedMilliseconds} ms');
  return true;
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  /// Long enough for the splash animation to read as intentional, short
  /// enough not to slow anyone down when startup is fast.
  static const _minSplash = Duration(milliseconds: 900);

  bool? _ready;

  @override
  void initState() {
    super.initState();
    Future.wait([_bootstrap(), Future<void>.delayed(_minSplash)])
        .then((r) => mounted ? setState(() => _ready = r.first as bool) : null);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: switch (_ready) {
        null => const SplashView(key: ValueKey('splash')),
        true => MultiProvider(
            key: const ValueKey('app'),
            providers: appProviders,
            child: const ZanvoyApp(),
          ),
        false => const _BootstrapFailedApp(key: ValueKey('failed')),
      },
    );
  }
}

/// Shown instead of a hard crash if Firebase itself fails to initialize
/// (e.g. no network on first launch, misconfigured platform files) — the
/// app can't function without it, but a friendly retry screen beats a
/// white screen or a stack trace.
class _BootstrapFailedApp extends StatelessWidget {
  const _BootstrapFailedApp({super.key});

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
