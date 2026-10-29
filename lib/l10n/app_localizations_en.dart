// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get exit => 'Exit';

  @override
  String get play => 'Play';

  @override
  String get yourName => 'Your name';

  @override
  String get gotIt => 'Got it';

  @override
  String get back => 'Back';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get enter => 'Join';

  @override
  String get connect => 'Connect';

  @override
  String get close => 'Close';

  @override
  String get confirm => 'Confirm';

  @override
  String get password => 'Password';

  @override
  String get passwordOptional => 'Password (optional)';

  @override
  String get defaultPlayerName => 'Player';

  @override
  String get defaultLocalName => 'Me';

  @override
  String get defaultHostName => 'Host';

  @override
  String get andJoin => ' and ';

  @override
  String get tagline => 'POCKET CASINO';

  @override
  String get modeDiceDashSubtitle => 'Poker with dice and chaos';

  @override
  String get modeTexasSubtitle => 'Classic poker';

  @override
  String get modeBlackjackSubtitle => 'Beat the dealer';

  @override
  String get playLan => 'Play with friends';

  @override
  String get howToPlay => 'How to play';

  @override
  String get settings => 'Settings';

  @override
  String get quitAppTitle => 'Quit the game?';

  @override
  String get quitAppBody => 'Are you sure you want to quit?';

  @override
  String get createRoom => 'Create a room';

  @override
  String get createRoomSubtitle => 'Others join your game';

  @override
  String get waitingEllipsis => 'Waiting...';

  @override
  String get joinRoom => 'Join a room';

  @override
  String get joinRoomSubtitle => 'Find games on your Wi-Fi or join by IP';

  @override
  String get sameWifiNote => 'All devices must be on the same Wi-Fi network.';

  @override
  String get setupGame => 'Game setup';

  @override
  String setupMode(String mode) {
    return '$mode setup';
  }

  @override
  String get botCount => 'Number of bots';

  @override
  String get botCountRange => 'Number of bots (1 - 6)';

  @override
  String get botDifficulty => 'Bot difficulty';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyNormal => 'Normal';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get difficultyEasyHint => 'They play wild and make mistakes.';

  @override
  String get difficultyNormalHint => 'They play smart, with the odd mistake.';

  @override
  String get difficultyHardHint =>
      'They play almost perfectly: watch their bets.';

  @override
  String get createRoomTitle => 'Create a room';

  @override
  String get gameMode => 'Game mode';

  @override
  String get roomName => 'Room name';

  @override
  String get howTexas1 =>
      'You get 2 cards; 5 shared cards come out on the table (flop, turn and river).';

  @override
  String get howTexas2 =>
      'Each round you can FOLD, match the bet (CALL/CHECK) or RAISE.';

  @override
  String get howTexas3 =>
      'The best 5-card hand out of your 2 and the 5 on the table wins.';

  @override
  String get howDice1 =>
      'Like Texas Hold\'em, but you roll 2 dice before every move.';

  @override
  String get howDice2 => 'Total 7: the pot grows by 30%.';

  @override
  String get howDice3 =>
      'Double 1: SWAP! Everyone\'s cards are shuffled and dealt again.';

  @override
  String get howDice4 =>
      'Double 6: ALL-IN! · Double 3: peek at a card · 6 and 1: extra card.';

  @override
  String get howBj1 =>
      'Bet and get as close to 21 as you can without going over. An ace is 1 or 11.';

  @override
  String get howBj2 =>
      'HIT takes a card, STAND keeps your hand, DOUBLE doubles the bet for one more card, SPLIT separates a pair.';

  @override
  String get howBj3 =>
      'Blackjack pays 3 to 2, the dealer stands on 17 and 5 cards without busting (5-Card Charlie) win.';

  @override
  String get sound => 'Sound';

  @override
  String get soundSubtitle => 'Cards, chips and dice';

  @override
  String get updateCheck => 'Tell me about new versions';

  @override
  String get updateCheckSubtitle => 'Checks GitHub once a day';

  @override
  String get scene => 'Scene';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Automatic';

  @override
  String get themeClasico => 'Classic';

  @override
  String get themeClasicoDesc => 'Plain green';

  @override
  String get themeCantina => 'Mexican cantina';

  @override
  String get themeCantinaDesc => 'Papel picado and tequila';

  @override
  String get themeGarito => 'Underground den';

  @override
  String get themeGaritoDesc => 'Mob money and danger';

  @override
  String get cockTitle => 'Rooster fight!';

  @override
  String get cockPrompt => 'Bet on your favourite';

  @override
  String get cockFavorite => 'Favourite';

  @override
  String get cockUnderdog => 'Underdog';

  @override
  String cockPays(String mult) {
    return 'Pays x$mult';
  }

  @override
  String get cockPass => 'Pass';

  @override
  String cockYourBet(String chips, String name) {
    return 'You bet $chips on $name';
  }

  @override
  String get cockYouPassed => 'You sat this one out';

  @override
  String get cockNoChips => 'No chips to bet';

  @override
  String get cockWaiting => 'Waiting for bets…';

  @override
  String cockWins(String name) {
    return '$name wins!';
  }

  @override
  String cockYouWon(String chips) {
    return 'You won +$chips!';
  }

  @override
  String cockYouLost(String chips) {
    return 'You lost $chips';
  }

  @override
  String get cockNextHand => 'Back to the table…';

  @override
  String get rouletteAnnounce => 'PLACE YOUR BETS!';

  @override
  String get rouletteHello => '\"Welcome to the roulette. Red or black?\"';

  @override
  String get rouletteRed => 'Red';

  @override
  String get rouletteBlack => 'Black';

  @override
  String get rouletteEven => 'Even';

  @override
  String get rouletteOdd => 'Odd';

  @override
  String get rouletteNumber => 'Number';

  @override
  String get roulettePaysOutside => 'Pays x2';

  @override
  String get roulettePaysNumber => 'Straight up: pays x36';

  @override
  String get roulettePickNumber => 'Pick a number';

  @override
  String get rouletteChip => 'Chip';

  @override
  String rouletteYourBet(String chips, String what) {
    return 'You bet $chips on $what';
  }

  @override
  String get rouletteNoMoreBets => '\"No more bets.\"';

  @override
  String get rouletteCongrats => '\"Congratulations!\"';

  @override
  String get rouletteHouseThanks => '\"The house thanks you.\"';

  @override
  String get rouletteZero => 'ZERO';

  @override
  String get rouletteRedWord => 'RED';

  @override
  String get rouletteBlackWord => 'BLACK';

  @override
  String get raidAlarm => 'THE COPS!';

  @override
  String get raidLookoutShout => '\"Cops are coming! What will you do?\"';

  @override
  String get raidMood0 => '\"The comandante is in a hurry.\"';

  @override
  String get raidMood1 => '\"The comandante looks like any other night.\"';

  @override
  String get raidMood2 => '\"The comandante is in a foul mood.\"';

  @override
  String raidTip(String cost) {
    return 'Tip the lookout ($cost)';
  }

  @override
  String get raidTipReal => '\"It\'s real, boss. They\'re at the door.\"';

  @override
  String get raidTipFake => '\"Relax, just a patrol driving by.\"';

  @override
  String get raidBribe => 'Bribe';

  @override
  String get raidHide => 'Hide chips';

  @override
  String get raidFlee => 'Run';

  @override
  String get raidSnitch => 'Snitch on the bosses';

  @override
  String get raidSurrender => 'Give up';

  @override
  String get raidRecord => 'Record';

  @override
  String get raidDecided => 'You decided. Waiting for the others…';

  @override
  String get raidOutOfIt => 'No chips: nobody is after you';

  @override
  String raidAccuse(String name) {
    return '\"It was $name, comandante! The whole table is theirs!\"';
  }

  @override
  String raidAccuseNoBoss(String name) {
    return 'The house boss blames $name';
  }

  @override
  String raidPayDouble(String amount) {
    return 'Pay double ($amount)';
  }

  @override
  String get raidAccuseBack => 'Rat out the boss (coin toss)';

  @override
  String get raidAcceptBlame => 'Take the blame (+500 back later)';

  @override
  String raidBlamedOther(String name) {
    return 'The boss blames $name…';
  }

  @override
  String get raidReal => '\"Nobody move!\"';

  @override
  String get raidFake => 'False alarm: just a patrol passing by';

  @override
  String raidPrice(String price) {
    return 'The comandante wanted $price';
  }

  @override
  String get raidOutBribed => 'Bribe taken';

  @override
  String get raidOutBribeFailed => 'Envelope too thin: searched';

  @override
  String get raidOutHidden => 'Found nothing';

  @override
  String get raidOutFound => 'Chips found';

  @override
  String get raidOutEscaped => 'Got away';

  @override
  String get raidOutCaught => 'Caught running';

  @override
  String get raidOutSnitched => 'Snitched: reward';

  @override
  String get raidOutJailed => 'Off to jail';

  @override
  String get raidOutLawyer => 'Their lawyer got them out';

  @override
  String get raidOutScapegoatPaid => 'Paid double and walked';

  @override
  String get raidOutScapegoatWon => 'Won the coin toss';

  @override
  String get raidOutBossJailed => 'The boss went down';

  @override
  String get raidOutWastedBribe => 'Bribed nobody';

  @override
  String get raidOutDropped => 'Dropped chips running';

  @override
  String get raidOutFalseSurrender => 'Gave up to nobody';

  @override
  String get raidOutNothing => 'All quiet';

  @override
  String get raidRevenge => 'The mob never forgets: you are marked';

  @override
  String raidLawyer(String fee) {
    return 'Call Lic. Saúl! ($fee)';
  }

  @override
  String get raidLawyerName => 'Lic. Saúl Buenhombre';

  @override
  String get raidLawyerPitch => '\"Trouble with the law? I\'ll get you out!\"';

  @override
  String get raidPaperName => 'THE DAILY GOSSIP';

  @override
  String get raidPaperReal => 'MOB DEN BUSTED DOWNTOWN';

  @override
  String get raidPaperFake => 'FALSE ALARM DOWNTOWN';

  @override
  String raidPaperDetained(String names) {
    return 'Arrested: $names';
  }

  @override
  String get raidPaperNone => 'No arrests: everyone vanished';

  @override
  String get raidPaperFakeSub =>
      'A patrol drove by and half the den ran for it';

  @override
  String get raidSentence => 'Sentence: 5 years';

  @override
  String get raidYearsLater => '5 years later…';

  @override
  String get raidNewTable => 'A new table. The mob remembers.';

  @override
  String get raidJailLan => 'Jailed: out for 2 hands';

  @override
  String get raidInJail => 'In jail';

  @override
  String get themeCasino => 'Luxury casino';

  @override
  String get themeCasinoDesc => 'Chandeliers and neon';

  @override
  String get updateTitle => 'A new version is out';

  @override
  String updateBody(String newVersion, String current) {
    return 'Version $newVersion is out (you have $current). Download it from GitHub and install it over this one: you keep your chips and settings.\n\nTo play together, everyone needs the same version.';
  }

  @override
  String get notNow => 'Not now';

  @override
  String get download => 'Download';

  @override
  String get browserFailed =>
      'Could not open the browser: the link was copied.';

  @override
  String get leaveGameTitle => 'Leave the game?';

  @override
  String get leaveGameBody => 'Are you sure you want to leave the game?';

  @override
  String get leaveTableBody => 'Are you sure you want to leave the table?';

  @override
  String get roomClosedByHost => 'The host closed the room.';

  @override
  String get connectionLostHost => 'Lost the connection to the host.';

  @override
  String get rollDice => 'Roll dice';

  @override
  String get startGame => 'Start game';

  @override
  String actingAs(String name) {
    return 'Playing as: $name';
  }

  @override
  String get continueAction => 'CONTINUE';

  @override
  String get raiseTitle => 'Raise';

  @override
  String raiseCallTotal(String call, String total) {
    return 'Call $call · Total $total';
  }

  @override
  String raiseTotal(String total) {
    return 'Total $total';
  }

  @override
  String get matchWonLocal => 'You won the match!';

  @override
  String matchWonBy(String name) {
    return '$name wins the match!';
  }

  @override
  String get matchWonLocalBody => 'You took every chip on the table.';

  @override
  String get matchWonByBody => 'They took every chip on the table.';

  @override
  String get waitingHostRestart =>
      'Waiting for the host to start another match...';

  @override
  String get playAgain => 'Play again';

  @override
  String get resultTie => 'Split pot!';

  @override
  String get resultYouWon => 'You won!';

  @override
  String resultWins(String name) {
    return '$name wins!';
  }

  @override
  String resultWith(String hand) {
    return 'With $hand';
  }

  @override
  String get resultOthersFolded => 'Everyone else folded';

  @override
  String amountEach(String amount) {
    return '+$amount each';
  }

  @override
  String get pot => 'POT';

  @override
  String get winOdds => 'Chance of winning the hand';

  @override
  String get diceLucky => 'LUCKY! +30%';

  @override
  String get diceSwap => 'SWAP!';

  @override
  String get diceAllIn => 'ALL-IN!';

  @override
  String get diceSpy => 'SPY!';

  @override
  String get diceExtraCard => 'EXTRA CARD!';

  @override
  String get chaosTitle => 'CHAOS!';

  @override
  String get chaosSubtitle => 'Hands are being swapped';

  @override
  String get rebuy => 'REBUY';

  @override
  String winnerBadge(String amount) {
    return 'WINNER +$amount';
  }

  @override
  String betAmount(String amount) {
    return 'Bet: \$$amount';
  }

  @override
  String get msgLuckySeven => 'Lucky dice. The pot grows by 30%';

  @override
  String msgDoubleSix(String name) {
    return 'Double 6! $name goes ALL-IN';
  }

  @override
  String msgSpy(String name, String target) {
    return 'Spy! $name sees one of $target\'s cards';
  }

  @override
  String msgExtraCard(String name) {
    return 'Extra card! $name keeps their best two cards';
  }

  @override
  String msgWinsByFold(String name) {
    return '$name wins: everyone else folded!';
  }

  @override
  String msgSplitPot(String hand) {
    return 'Split pot with $hand!';
  }

  @override
  String msgWinsWith(String name, String hand) {
    return '$name wins with $hand!';
  }

  @override
  String get msgNoWinner => 'Showdown! No winner';

  @override
  String get msgChaos => 'CHAOS MODE! Cards are swapped';

  @override
  String get handHighCard => 'High Card';

  @override
  String get handOnePair => 'Pair';

  @override
  String get handTwoPair => 'Two Pair';

  @override
  String get handThreeOfAKind => 'Three of a Kind';

  @override
  String get handStraight => 'Straight';

  @override
  String get handFlush => 'Flush';

  @override
  String get handFullHouse => 'Full House';

  @override
  String get handFourOfAKind => 'Four of a Kind';

  @override
  String get handStraightFlush => 'Straight Flush';

  @override
  String get handRoyalFlush => 'Royal Flush';

  @override
  String noticeHeirTakingOver(String name) {
    return 'The host left. $name takes over the table…';
  }

  @override
  String get noticeReconnecting => 'Connection lost, reconnecting…';

  @override
  String noticeNewHost(String name) {
    return '$name is the host now';
  }

  @override
  String get noticeYouAreHost => 'The host left: the table is yours now';

  @override
  String turnClockMine(String seconds) {
    return '$seconds s left to play';
  }

  @override
  String turnClockOther(String name, String seconds) {
    return '$name has $seconds s';
  }

  @override
  String get rulesPays => 'BLACKJACK PAYS 3 TO 2';

  @override
  String get rulesDealer => 'DEALER STANDS ON 17  •  5-CARD CHARLIE';

  @override
  String shoeCount(String count) {
    return 'Shoe: $count';
  }

  @override
  String get dealer => 'DEALER';

  @override
  String handShort(String number) {
    return 'H$number';
  }

  @override
  String get ready => 'Ready';

  @override
  String get bettingEllipsis => 'Betting...';

  @override
  String get outcomeBlackjack => 'BLACKJACK';

  @override
  String get outcomeCharlie => 'CHARLIE';

  @override
  String get outcomeWin => 'WIN';

  @override
  String get outcomePush => 'PUSH';

  @override
  String get outcomeInsured => 'INSURED';

  @override
  String get outcomeBust => 'BUST';

  @override
  String get outcomeLose => 'LOSE';

  @override
  String get statusInProgress => 'Round in progress...';

  @override
  String get statusDealing => 'Dealing...';

  @override
  String get statusInsurance =>
      'The dealer shows an ace... waiting for insurance';

  @override
  String get statusDealerTurn => '🎩 Dealer\'s turn... playing the hand';

  @override
  String statusBotTurn(String name) {
    return '🤖 $name\'s turn... thinking';
  }

  @override
  String statusAway(String name) {
    return '$name disconnected... stands shortly';
  }

  @override
  String statusTurnOf(String name) {
    return '$name\'s turn...';
  }

  @override
  String get statusWaitingBets => 'Waiting for the players to bet...';

  @override
  String insuranceOffer(String cost) {
    return 'The dealer shows an ace. Insurance for \$$cost?';
  }

  @override
  String get insuranceExplain =>
      'If the dealer has blackjack, insurance pays 2 to 1 and you get your bet back.';

  @override
  String get noThanks => 'No, thanks';

  @override
  String insure(String cost) {
    return 'Insure \$$cost';
  }

  @override
  String get betLabel => 'BET:';

  @override
  String get placeBet => 'BET';

  @override
  String get hit => 'HIT';

  @override
  String get stand => 'STAND';

  @override
  String get double => 'DOUBLE';

  @override
  String get split => 'SPLIT';

  @override
  String bjYouBlackjack(String net) {
    return 'Blackjack! You win +$net';
  }

  @override
  String bjYouCharlie(String net) {
    return '5-Card Charlie! You win +$net';
  }

  @override
  String bjYouWin(String net) {
    return 'You won +$net!';
  }

  @override
  String get bjYouPush => 'Push: you get your bet back';

  @override
  String get bjYouInsured => 'Dealer blackjack: insurance covered you';

  @override
  String bjYouInsuredNet(String net) {
    return 'Dealer blackjack: insurance covered you ($net)';
  }

  @override
  String bjYouBust(String net) {
    return 'You went over 21 ($net)';
  }

  @override
  String bjDealerBlackjack(String net) {
    return 'Dealer blackjack! ($net)';
  }

  @override
  String bjDealerWins(String net) {
    return 'The dealer wins ($net)';
  }

  @override
  String get bjRoundOver => 'Round over';

  @override
  String get hostDealsSoon => 'The host deals shortly...';

  @override
  String get newRound => 'New round';

  @override
  String waitingPlayersCount(String count) {
    return 'Waiting for players... ($count)';
  }

  @override
  String get wrongPassword => 'Wrong password';

  @override
  String get roomFull => 'The room is full';

  @override
  String get joinError => 'Could not join';

  @override
  String enterRoom(String name) {
    return 'Join $name';
  }

  @override
  String get noIpFound =>
      'No IP address in what you copied. Copy the IP the room shows.';

  @override
  String get directIpTitle => 'Join by IP';

  @override
  String get pasteIp => 'Paste copied IP';

  @override
  String get hostIpHint => 'Host IP (e.g. 192.168.1.50)';

  @override
  String get portHint => 'Port (e.g. 54321)';

  @override
  String get invalidIpPort => 'Please enter a valid IP and port';

  @override
  String get cannotConnect =>
      'Could not connect to the host. Check the IP and the firewall.';

  @override
  String get helpTitle => 'Connection help';

  @override
  String get help1Title => '1. Same Wi-Fi network';

  @override
  String get help1Body => 'All devices must be on the same Wi-Fi or hotspot.';

  @override
  String get help2Title => '2. Windows / PC firewall';

  @override
  String get help2Body =>
      'If the PC is the host, allow the app through the Windows Firewall.';

  @override
  String get help3Title => '3. Join by IP';

  @override
  String get help3Body =>
      'If the room does not show up on its own, the host sees its IP on screen. Use \"By IP\" to connect directly.';

  @override
  String get roomsTitle => 'Available rooms';

  @override
  String get help => 'Help';

  @override
  String get notInList => 'Can\'t see the room?';

  @override
  String get notInListSubtitle => 'Connect by typing the host\'s IP';

  @override
  String get byIp => 'By IP';

  @override
  String get connectingRoom => 'Connecting to the room...';

  @override
  String get searchingRooms =>
      'Looking for rooms...\nMake sure both devices are on the same Wi-Fi network';

  @override
  String get roomInGame => 'In game';

  @override
  String get roomWaiting => 'Waiting for players';

  @override
  String roomPlayers(String count, String max) {
    return '$count/$max players';
  }

  @override
  String get roomWithPassword => ' • PASSWORD';

  @override
  String get roomIp => 'Room IP';

  @override
  String copiedAddress(String address) {
    return 'Copied: $address. Send it on WhatsApp and the others paste it in \"By IP\".';
  }

  @override
  String get copy => 'Copy';

  @override
  String get backToMenu => 'Back to menu';

  @override
  String get options => 'Options';

  @override
  String get leaveTable => 'Leave the table';

  @override
  String get fastGame => 'Fast game';

  @override
  String get fastGameSubtitle => 'Bots think and the dealer deals faster';

  @override
  String get showOdds => 'Show my odds';

  @override
  String get showOddsSubtitle => 'Help: your % to win the hand on your seat';

  @override
  String get keepAwake => 'Keep the screen on';

  @override
  String get keepAwakeSubtitle => 'It stays on while you are at the table';

  @override
  String get notifRoomOpen =>
      'Your room is open: the game keeps going while you use other apps';

  @override
  String get notifLanActive => 'Network game in progress';
}
