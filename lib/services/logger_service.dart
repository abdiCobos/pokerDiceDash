import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._();
  factory AppLogger() => _instance;
  AppLogger._();

  void init() {
  }

  void log(String message) {
    dev.log(message, name: 'AppLogger');
    // Debug builds also print, so `flutter run` and `adb logcat` show it live.
    if (kDebugMode) debugPrint('[AppLogger] $message');
  }

  void event(String name, {Map<String, Object>? params}) {
    dev.log('EVENT: $name $params', name: 'AppLogger');
    if (kDebugMode) debugPrint('[AppLogger] EVENT: $name $params');
  }

  void error(String message, [StackTrace? stack]) {
    dev.log(message, name: 'AppLogger.error', level: 1000);
    if (kDebugMode) debugPrint('[AppLogger] ERROR: $message');
    if (stack != null) {
      dev.log(stack.toString(), name: 'AppLogger.error_stack', level: 1000);
    }
  }

  void setUser(String? id, String? name) {
    dev.log('Set user: id=$id, name=$name', name: 'AppLogger');
  }
}
