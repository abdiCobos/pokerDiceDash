import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/l10n/l10n.dart';
import 'package:poker_dice_dash/models/hand_evaluator.dart';
import 'package:poker_dice_dash/providers/game_provider.dart';
import 'package:poker_dice_dash/services/game_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every text exists in Spanish and English', () {
    final es = arb('es').keys.where((k) => !k.startsWith('@')).toSet();
    final en = arb('en').keys.where((k) => !k.startsWith('@')).toSet();
    expect(en, es);
    for (final k in es) {
      expect((arb('en')[k] as String).trim(), isNotEmpty, reason: k);
    }
  });

  test('the English texts are not left in Spanish', () {
    final en = arb('en');
    const spanish = ['Jugar', 'Salir', 'Cancelar', 'apuesta', 'crupier', 'mesa', 'sala', '¿', '¡'];
    for (final e in en.entries.where((e) => !e.key.startsWith('@'))) {
      for (final w in spanish) {
        expect((e.value as String).contains(w), isFalse, reason: '${e.key}: ${e.value}');
      }
    }
  });

  test('Spanish devices get Spanish, everybody else English', () {
    expect(resolveLocale(const Locale('es', 'MX')), const Locale('es'));
    expect(resolveLocale(const Locale('es')), const Locale('es'));
    expect(resolveLocale(const Locale('en', 'US')), const Locale('en'));
    expect(resolveLocale(const Locale('pt', 'BR')), const Locale('en'));
    expect(resolveLocale(null), const Locale('en'));
  });

  test('the language picked in Ajustes is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final s = GameSettings();
    await s.load();
    expect(s.language, AppLanguage.system);
    await s.setLanguage(AppLanguage.en);
    await s.load();
    expect(s.language, AppLanguage.en);
    await s.setLanguage(AppLanguage.system);
  });

  test('table messages and hands are worded in each language', () async {
    final es = await AppLocalizations.delegate.load(const Locale('es'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    const m = TableMessage(TableMessageKind.winsWith, name: 'Ana', hand: HandRank.fullHouse);
    expect(es.tableMessage(m), '¡Ana gana con Full House!');
    expect(en.tableMessage(m), 'Ana wins with Full House!');
    expect(en.handName(HandRank.fourOfAKind), 'Four of a Kind');
    expect(en.outcomeLabel('GANA'), 'WIN');
    expect(en.hostNotice(const HostNotice(HostNoticeKind.newHost, 'Luis')), 'Luis is the host now');
  });
}
