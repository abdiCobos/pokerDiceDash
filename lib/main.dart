import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/game_provider.dart';
import 'services/p2p_service.dart';
import 'services/logger_service.dart';
import 'ui/screens/lobby_screen.dart';

import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppLogger().init();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);
  final p2pService = P2PService();

  final prefs = await SharedPreferences.getInstance();

  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: 'https://0bf3a6dc1cee47f993fcd572d2db4c3d@app.glitchtip.com/27827');
      options.tracesSampleRate = 0.01;
      options.enableAutoSessionTracking = false;
    },
    appRunner: () => runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => GameProvider(p2pService: p2pService)),
        ],
        child: PokerDiceDashApp(prefs: prefs),
      ),
    ),
  );
}

class PokerDiceDashApp extends StatelessWidget {
  final SharedPreferences prefs;
  const PokerDiceDashApp({super.key, required this.prefs});

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
      home: const LobbyScreen(),
    );
  }
}
