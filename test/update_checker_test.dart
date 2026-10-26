import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/app_version.dart';
import 'package:poker_dice_dash/services/update_checker.dart';

void main() {
  test('appVersion matches pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.split(':').last.trim().split('+').first, appVersion);
  });

  test('compares versions as numbers', () {
    expect(UpdateChecker.isNewer('v1.2.0', '1.1.0'), isTrue);
    expect(UpdateChecker.isNewer('1.10.0', '1.9.3'), isTrue);
    expect(UpdateChecker.isNewer('v2.0', '1.9.9'), isTrue);
    expect(UpdateChecker.isNewer('v1.1.0', '1.1.0'), isFalse);
    expect(UpdateChecker.isNewer('v1.0.9', '1.1.0'), isFalse);
    expect(UpdateChecker.isNewer('v1.1.1+3', '1.1.0'), isTrue);
  });

  test('reads the latest GitHub release and only opens pages of this repository', () {
    final ok = UpdateChecker.parseRelease(
      '{"tag_name":"v1.2.0","html_url":"https://github.com/abdiCobos/pokerDiceDash/releases/tag/v1.2.0"}',
      current: '1.1.0',
    );
    expect(ok?.version, '1.2.0');
    expect(ok?.page.toString(), 'https://github.com/abdiCobos/pokerDiceDash/releases/tag/v1.2.0');

    final elsewhere = UpdateChecker.parseRelease('{"tag_name":"v1.2.0","html_url":"https://example.com/x"}', current: '1.1.0');
    expect(elsewhere?.page.toString(), UpdateChecker.releasesPage);

    expect(UpdateChecker.parseRelease('{"tag_name":"v1.1.0"}', current: '1.1.0'), isNull, reason: 'same version');
    expect(UpdateChecker.parseRelease('{"tag_name":"v9.0.0","prerelease":true}', current: '1.1.0'), isNull);
    expect(UpdateChecker.parseRelease('not json', current: '1.1.0'), isNull);
  });

  test('asks GitHub at most about once a day', () {
    final now = DateTime(2026, 10, 25, 12);
    expect(UpdateChecker.isDue(null, now), isTrue);
    expect(UpdateChecker.isDue(now.subtract(const Duration(hours: 3)), now), isFalse);
    expect(UpdateChecker.isDue(now.subtract(const Duration(hours: 21)), now), isTrue);
  });

  test('the F-Droid recipe builds without the update check', () {
    final recipe = File('metadata/io.github.abdicobos.pokerdicedash.yml').readAsStringSync();
    final builds = RegExp(r'build: .*flutter build apk.*').allMatches(recipe).map((m) => m[0]!).toList();
    expect(builds, isNotEmpty);
    for (final b in builds) {
      expect(b, contains('--dart-define=UPDATE_CHECK=false'));
    }
  });
}
