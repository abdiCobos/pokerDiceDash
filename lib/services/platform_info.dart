import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Returns true if we're on a desktop platform (Windows, Linux, macOS)
bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// Returns true if we're on a mobile platform (Android, iOS)  
bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
