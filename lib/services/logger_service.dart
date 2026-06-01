import 'dart:developer' as dev;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._();
  factory AppLogger() => _instance;
  AppLogger._();

  late FirebaseAnalytics _analytics;
  bool _crashlyticsReady = false;

  void init() {
    _analytics = FirebaseAnalytics.instance;
    _crashlyticsReady = true;
  }

  void log(String message) {
    dev.log(message, name: 'AppLogger');
    if (_crashlyticsReady) {
      FirebaseCrashlytics.instance.log(message);
      // Set as custom key so it appears in crash reports
      FirebaseCrashlytics.instance.setCustomKey('log', message.length > 100 ? message.substring(0, 100) : message);
    }
  }

  void event(String name, {Map<String, Object>? params}) {
    dev.log('EVENT: $name $params', name: 'AppLogger');
    if (_crashlyticsReady) {
      _analytics.logEvent(name: name, parameters: params);
      FirebaseCrashlytics.instance.log('event:$name${params != null ? ' $params' : ''}');
      FirebaseCrashlytics.instance.setCustomKey('last_event', name);
    }
  }

  void error(String message, [StackTrace? stack]) {
    dev.log(message, name: 'AppLogger.error', level: 1000);
    if (_crashlyticsReady) {
      FirebaseCrashlytics.instance.log('ERROR:$message');
      FirebaseCrashlytics.instance.setCustomKey('last_error', message.length > 100 ? message.substring(0, 100) : message);
      final st = stack ?? StackTrace.current;
      // recordError as non-fatal so it appears in dashboard
      FirebaseCrashlytics.instance.recordError(
        message,
        st,
        fatal: false,
        reason: 'AppError',
      );
    }
  }

  void setUser(String? id, String? name) {
    if (id != null) FirebaseCrashlytics.instance.setUserIdentifier(id);
    if (name != null) FirebaseCrashlytics.instance.setCustomKey('player_name', name);
  }
}
