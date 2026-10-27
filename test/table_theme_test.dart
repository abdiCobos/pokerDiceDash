import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/services/game_settings.dart';
import 'package:poker_dice_dash/ui/widgets/scene_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every theme has its three scenes in the assets', () {
    for (final t in TableTheme.values.where((t) => t != TableTheme.clasico)) {
      for (final size in const [Size(873, 393), Size(1280, 720), Size(393, 873)]) {
        final asset = SceneBackground.assetFor(t, size)!;
        expect(File(asset).existsSync(), isTrue, reason: '$asset is missing (run tool/pixelart/cantina.py)');
      }
    }
  });

  test('the scene follows the screen shape: wide phone, PC, portrait menu', () {
    expect(SceneBackground.assetFor(TableTheme.garito, const Size(873, 393)), endsWith('garito_bg.png'));
    expect(SceneBackground.assetFor(TableTheme.garito, const Size(1280, 720)), endsWith('garito_bg_16x9.png'));
    expect(SceneBackground.assetFor(TableTheme.garito, const Size(393, 873)), endsWith('garito_menu.png'));
    expect(SceneBackground.assetFor(TableTheme.clasico, const Size(873, 393)), isNull, reason: 'clásico: plain green');
  });

  test('the chosen theme is saved and comes back on the next start', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = GameSettings();
    await settings.load();
    expect(settings.theme, TableTheme.casino, reason: 'casino is the default');
    var notified = 0;
    void listener() => notified++;
    settings.addListener(listener);
    await settings.setTheme(TableTheme.garito);
    settings.removeListener(listener);
    expect(notified, 1, reason: 'open screens repaint with the new scene');
    expect((await SharedPreferences.getInstance()).getString('table_theme'), 'garito');
    await settings.load();
    expect(settings.theme, TableTheme.garito);
    await settings.setTheme(TableTheme.casino);
  });

  test('every theme has its own felt', () {
    for (final t in TableTheme.values) {
      expect(TableFeltStyle.of(t).felt, hasLength(3));
    }
  });
}
