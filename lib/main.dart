import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/game_provider.dart';
import 'services/p2p_service.dart';
import 'services/logger_service.dart';
import 'ui/screens/lobby_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  AppLogger().init();

  FlutterError.onError = (errorDetails) {
    AppLogger().error('FlutterError: ${errorDetails.exceptionAsString()}', errorDetails.stack);
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger().error('PlatformDispatcher: $error', stack);
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);
  final p2pService = P2PService();

  final prefs = await SharedPreferences.getInstance();
  final hasSeenDisclaimer = prefs.getBool('disclaimer_seen') ?? false;

  runApp(
    ChangeNotifierProvider(
      create: (_) => GameProvider(p2pService: p2pService),
      child: PokerDiceDashApp(showDisclaimer: !hasSeenDisclaimer, prefs: prefs),
    ),
  );
}

class PokerDiceDashApp extends StatelessWidget {
  final bool showDisclaimer;
  final SharedPreferences prefs;
  const PokerDiceDashApp({super.key, required this.showDisclaimer, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poker Dice Dash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: const Color(0xFF052915),
        useMaterial3: true,
        textTheme: GoogleFonts.robotoTextTheme(),
      ),
      home: showDisclaimer ? _DisclaimerScreen(prefs: prefs) : const LobbyScreen(),
    );
  }
}

class _DisclaimerScreen extends StatelessWidget {
  final SharedPreferences prefs;
  const _DisclaimerScreen({required this.prefs});

  @override
  Widget build(BuildContext context) {
    final s = (MediaQuery.of(context).size.width / 400).clamp(0.7, 1.4);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment.center, radius: 0.9, colors: [Color(0xFF0A4D28), Color(0xFF052915)]),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24 * s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bug_report, size: 60 * s, color: Colors.amber),
                SizedBox(height: 16 * s),
                Text('Aviso importante', style: TextStyle(color: Colors.amber, fontSize: 20 * s, fontWeight: FontWeight.bold)),
                SizedBox(height: 12 * s),
                Text(
                  'Esta aplicación se encuentra en fase de desarrollo.\n\n'
                  'Para ayudarnos a mejorar tu experiencia, se envían reportes anónimos de errores y estadísticas de uso.\n\n'
                  'No se recopila información personal. Los datos solo se usan para detectar fallos y corregirlos.',
                  style: TextStyle(color: Colors.white70, fontSize: 13 * s, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24 * s),
                ElevatedButton(
                  onPressed: () {
                    prefs.setBool('disclaimer_seen', true);
                    AppLogger().event('disclaimer_accepted');
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LobbyScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 32 * s, vertical: 12 * s),
                    textStyle: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
