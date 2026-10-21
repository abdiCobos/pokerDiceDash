import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/game_provider.dart';
import 'services/p2p_service.dart';
import 'services/logger_service.dart';
import 'services/game_settings.dart';
import 'ui/screens/lobby_screen.dart';

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
  await GameSettings().load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider(p2pService: p2pService)),
      ],
      child: PokerDiceDashApp(prefs: prefs),
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
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _TableFadeTransitionsBuilder(),
            TargetPlatform.iOS: _TableFadeTransitionsBuilder(),
            TargetPlatform.linux: _TableFadeTransitionsBuilder(),
            TargetPlatform.macOS: _TableFadeTransitionsBuilder(),
            TargetPlatform.windows: _TableFadeTransitionsBuilder(),
          },
        ),
      ),
      home: const LobbyScreen(),
    );
  }
}

/// Screen changes fade in with a slight zoom, like sitting down at the table.
/// The outgoing screen dims a little instead of sliding away.
class _TableFadeTransitionsBuilder extends PageTransitionsBuilder {
  const _TableFadeTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final exit = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: enter,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1).animate(enter),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.6).animate(exit),
          child: child,
        ),
      ),
    );
  }
}
