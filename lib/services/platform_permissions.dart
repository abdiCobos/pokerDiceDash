import 'package:flutter/foundation.dart';
import 'platform_info.dart';

Future<void> requestHardwarePermissions() async {
  if (!isMobile) return;
  try {
    // Lazy import to avoid compile errors on desktop
    // ignore: depend_on_referenced_packages
    final handler = await _loadPermissionHandler();
    if (handler != null) {
      await handler.requestAll();
    }
  } catch (_) {
    // Permissions not critical on desktop
  }
}

Future<dynamic> _loadPermissionHandler() async {
  // Dynamic import to avoid compile-time dependency
  try {
    // ignore: undefined_function
    return await _loadMobilePermissions();
  } catch (_) {
    return null;
  }
}

Future<dynamic> _loadMobilePermissions() async {
  throw UnimplementedError('Mobile only');
}
