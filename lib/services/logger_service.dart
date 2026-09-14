import 'dart:developer' as dev;
import 'package:sentry_flutter/sentry_flutter.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._();
  factory AppLogger() => _instance;
  AppLogger._();

  void init() {
    // Sentry initialized in main.dart
  }

  void log(String message) {
    dev.log(message, name: 'AppLogger');
    Sentry.addBreadcrumb(Breadcrumb(message: message, category: 'log'));
  }

  void event(String name, {Map<String, Object>? params}) {
    dev.log('EVENT: $name $params', name: 'AppLogger');
    Sentry.addBreadcrumb(
      Breadcrumb(message: 'Event: $name', category: 'event', data: params),
    );
  }

  void error(String message, [StackTrace? stack]) {
    dev.log(message, name: 'AppLogger.error', level: 1000);
    if (stack != null) {
      dev.log(stack.toString(), name: 'AppLogger.error_stack', level: 1000);
    }
    Sentry.captureException(Exception(message), stackTrace: stack);
  }

  void setUser(String? id, String? name) {
    dev.log('Set user: id=$id, name=$name', name: 'AppLogger');
    Sentry.configureScope((scope) {
      scope.setUser(SentryUser(id: id, username: name));
    });
  }
}
