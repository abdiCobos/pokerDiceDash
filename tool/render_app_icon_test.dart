// Renders the app icon from code so it can be tweaked and regenerated.
//
//   flutter test tool/render_app_icon_test.dart
//   dart run flutter_launcher_icons
//
// Writes into tool/icon/ (kept out of the APK assets):
//   icon_full.png        1024x1024 legacy icon (felt + artwork, rounded square)
//   icon_background.png  1024x1024 adaptive background (felt)
//   icon_foreground.png  1024x1024 adaptive foreground (artwork, transparent)
// Geometry uses the adaptive-icon grid: 108 units, artwork inside the 66u safe circle.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/ui/widgets/app_icon_painter.dart';

const double kSize = 1024;
const outDir = 'tool/icon';

Future<void> _render(WidgetTester tester, AppIconLayer layer, String name) async {
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    AppIconPainter(layer).paint(canvas, const Size(kSize, kSize));
    final image = await recorder.endRecording().toImage(kSize.toInt(), kSize.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$outDir/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render app icon', (tester) async {
    final fonts = Directory(
      // flutter_tester lives in <flutter>/bin/cache/artifacts/engine/<platform>/.
      '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts',
    );
    final roboto = File('${fonts.path}/roboto-black.ttf');
    if (roboto.existsSync()) {
      final loader = FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(roboto.readAsBytesSync())));
      await loader.load();
    } else {
      // ignore: avoid_print
      print('WARNING: Roboto not found at ${roboto.path}, the "A" will use the test font');
    }
    await _render(tester, AppIconLayer.full, 'icon_full.png');
    await _render(tester, AppIconLayer.background, 'icon_background.png');
    await _render(tester, AppIconLayer.foreground, 'icon_foreground.png');
  });
}
