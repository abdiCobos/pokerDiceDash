import 'package:flutter/widgets.dart';

import '../models/hand_evaluator.dart';
import '../providers/game_provider.dart';
import '../services/game_settings.dart';
import '../services/poker_bot_ai.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// Texts are in lib/l10n/app_es.arb and app_en.arb, written by tool/l10n_strings.py.
/// Rules and network messages carry codes; these helpers word them in the player's language.
extension L10nContext on BuildContext {
  AppLocalizations get t => AppLocalizations.of(this);
}

/// Spanish for Spanish-speaking devices, English for everybody else.
Locale resolveLocale(Locale? device) => device?.languageCode == 'es' ? const Locale('es') : const Locale('en');

extension AppTexts on AppLocalizations {
  String handName(HandRank rank) => switch (rank) {
        HandRank.highCard => handHighCard,
        HandRank.onePair => handOnePair,
        HandRank.twoPair => handTwoPair,
        HandRank.threeOfAKind => handThreeOfAKind,
        HandRank.straight => handStraight,
        HandRank.flush => handFlush,
        HandRank.fullHouse => handFullHouse,
        HandRank.fourOfAKind => handFourOfAKind,
        HandRank.straightFlush => handStraightFlush,
        HandRank.royalFlush => handRoyalFlush,
      };

  String themeName(TableTheme theme) => switch (theme) {
        TableTheme.clasico => themeClasico,
        TableTheme.cantina => themeCantina,
        TableTheme.garito => themeGarito,
      };

  String themeDescription(TableTheme theme) => switch (theme) {
        TableTheme.clasico => themeClasicoDesc,
        TableTheme.cantina => themeCantinaDesc,
        TableTheme.garito => themeGaritoDesc,
      };

  String difficultyName(BotDifficulty d) => switch (d) {
        BotDifficulty.easy => difficultyEasy,
        BotDifficulty.normal => difficultyNormal,
        BotDifficulty.hard => difficultyHard,
      };

  String difficultyHint(BotDifficulty d) => switch (d) {
        BotDifficulty.easy => difficultyEasyHint,
        BotDifficulty.normal => difficultyNormalHint,
        BotDifficulty.hard => difficultyHardHint,
      };

  String tableMessage(TableMessage m) {
    final hand = m.hand == null ? '' : handName(m.hand!);
    return switch (m.kind) {
      TableMessageKind.luckySeven => msgLuckySeven,
      TableMessageKind.doubleSix => msgDoubleSix(m.name),
      TableMessageKind.spy => msgSpy(m.name, m.target),
      TableMessageKind.extraCard => msgExtraCard(m.name),
      TableMessageKind.winsByFold => msgWinsByFold(m.name),
      TableMessageKind.splitPot => msgSplitPot(hand),
      TableMessageKind.winsWith => msgWinsWith(m.name, hand),
      TableMessageKind.noWinner => msgNoWinner,
      TableMessageKind.chaos => msgChaos,
    };
  }

  String hostNotice(HostNotice n) => switch (n.kind) {
        HostNoticeKind.heirTakingOver => noticeHeirTakingOver(n.name),
        HostNoticeKind.reconnecting => noticeReconnecting,
        HostNoticeKind.newHost => noticeNewHost(n.name),
        HostNoticeKind.youAreHost => noticeYouAreHost,
      };

  /// Blackjack seat badge for an outcome code from the host ('GANA', 'PIERDE'...).
  String outcomeLabel(String code) => switch (code) {
        'BLACKJACK' => outcomeBlackjack,
        'CHARLIE' => outcomeCharlie,
        'GANA' => outcomeWin,
        'EMPATE' => outcomePush,
        'SEGURO' => outcomeInsured,
        'BUST' => outcomeBust,
        'PIERDE' => outcomeLose,
        _ => code,
      };
}
