import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'logger_service.dart';

/// Android: keeps the app running while a LAN game is open (KeepAliveService, a foreground
/// service with a "Partida en red activa" notification). Without it Android froze a host
/// that switched to another app, and the table stopped for everybody. No-op elsewhere.
class BackgroundKeeper {
  static const MethodChannel _channel = MethodChannel('io.github.abdicobos.pokerdicedash/keep_alive');

  static bool _running = false;
  static bool get running => _running;

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> start(String text) async {
    if (!_supported || _running) return;
    _running = true;
    try {
      await _channel.invokeMethod('start', {'text': text});
    } catch (e) {
      AppLogger().log('KeepAlive no disponible: $e');
    }
  }

  static Future<void> stop() async {
    if (!_supported || !_running) return;
    _running = false;
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      AppLogger().log('KeepAlive stop: $e');
    }
  }
}
