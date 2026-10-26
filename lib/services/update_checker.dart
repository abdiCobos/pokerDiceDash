import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';
import 'logger_service.dart';

/// A newer release on GitHub.
class UpdateInfo {
  final String version;
  final Uri page;
  const UpdateInfo(this.version, this.page);
}

/// Tells players installed from GitHub that a new version is out. It only reads the latest
/// release (once a day at most) and opens its page; it never downloads or installs anything.
/// The F-Droid build turns it off (`--dart-define=UPDATE_CHECK=false`): F-Droid updates the
/// app itself, signs it with its own key, and the app must not contact other servers there.
class UpdateChecker {
  static const bool availableInBuild = bool.fromEnvironment('UPDATE_CHECK', defaultValue: true);
  static const String releasesPage = 'https://github.com/abdiCobos/pokerDiceDash/releases/latest';
  static const String _api = 'https://api.github.com/repos/abdiCobos/pokerDiceDash/releases/latest';
  static const Duration interval = Duration(hours: 20);

  static const _enabledKey = 'update_check';
  static const _lastCheckKey = 'update_last_check';

  static Future<bool> isEnabled() async {
    if (!availableInBuild) return false;
    try {
      return (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setEnabled(bool v) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_enabledKey, v);
    } catch (_) {}
  }

  /// "1.10.0" > "1.9.3"; a leading "v" and anything after "+" or "-" are ignored.
  static bool isNewer(String remote, String local) {
    List<int> parts(String v) => v
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split(RegExp(r'[+\-]'))
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final a = parts(remote), b = parts(local);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Reads GitHub's "latest release" answer. Only pages of this repository are ever opened.
  static UpdateInfo? parseRelease(String body, {String current = appVersion}) {
    try {
      final m = jsonDecode(body);
      if (m is! Map || m['draft'] == true || m['prerelease'] == true) return null;
      final tag = m['tag_name'];
      if (tag is! String || !isNewer(tag, current)) return null;
      final url = m['html_url'];
      final page = url is String && url.startsWith('https://github.com/abdiCobos/pokerDiceDash/')
          ? Uri.parse(url)
          : Uri.parse(releasesPage);
      return UpdateInfo(tag.replaceFirst(RegExp(r'^[vV]'), ''), page);
    } catch (_) {
      return null;
    }
  }

  static bool isDue(DateTime? last, DateTime now) => last == null || now.difference(last) >= interval;

  /// Null when switched off, checked recently, offline, or already up to date.
  static Future<UpdateInfo?> check() async {
    if (!await isEnabled()) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_lastCheckKey);
      final now = DateTime.now();
      if (!isDue(lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs), now)) return null;
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      try {
        final req = await client.getUrl(Uri.parse(_api));
        req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
        req.headers.set(HttpHeaders.userAgentHeader, 'PokerDiceDash/$appVersion');
        final res = await req.close().timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) return null;
        final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 8));
        await prefs.setInt(_lastCheckKey, now.millisecondsSinceEpoch);
        return parseRelease(body);
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      AppLogger().log('Revision de version no disponible: $e');
      return null;
    }
  }
}
