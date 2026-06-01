import 'dart:developer' as dev;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._();
  factory AppLogger() => _instance;
  AppLogger._();

  late FirebaseAnalytics _analytics;

  void init() {
    _analytics = FirebaseAnalytics.instance;
  }

  void log(String message) {
    FirebaseCrashlytics.instance.log(message);
  }

  void event(String name, {Map<String, Object>? params}) {
    _analytics.logEvent(name: name, parameters: params);
    FirebaseCrashlytics.instance.log('event:$name${params != null ? ' $params' : ''}');
  }

  void error(String message, [StackTrace? stack]) {
    FirebaseCrashlytics.instance.log('ERROR:$message');
    if (stack != null) {
      FirebaseCrashlytics.instance.recordError(message, stack, fatal: false);
    } else {
      FirebaseCrashlytics.instance.recordError(Exception(message), StackTrace.empty, fatal: false);
    }
    dev.log(message, name: 'AppLogger.error');
    if (stack != null) dev.log(stack.toString(), name: 'AppLogger.error');
  }

  void setUser(String? id, String? name) {
    if (id != null) FirebaseCrashlytics.instance.setUserIdentifier(id);
    if (name != null) FirebaseCrashlytics.instance.setCustomKey('player_name', name);
  }
}
