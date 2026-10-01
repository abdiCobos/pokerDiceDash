import 'dart:developer' as dev;

class AppLogger {
  static final AppLogger _instance = AppLogger._();
  factory AppLogger() => _instance;
  AppLogger._();

  void init() {
  }

  void log(String message) {
    dev.log(message, name: 'AppLogger');
  }

  void event(String name, {Map<String, Object>? params}) {
    dev.log('EVENT: $name $params', name: 'AppLogger');
  }

  void error(String message, [StackTrace? stack]) {
    dev.log(message, name: 'AppLogger.error', level: 1000);
    if (stack != null) {
      dev.log(stack.toString(), name: 'AppLogger.error_stack', level: 1000);
    }
  }

  void setUser(String? id, String? name) {
    dev.log('Set user: id=$id, name=$name', name: 'AppLogger');
  }
}
