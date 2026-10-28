// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get cancel => 'Cancelar';

  @override
  String get exit => 'Salir';

  @override
  String get play => 'Jugar';

  @override
  String get yourName => 'Tu nombre';

  @override
  String get gotIt => 'Entendido';

  @override
  String get back => 'Volver';

  @override
  String get save => 'Guardar';

  @override
  String get create => 'Crear';

  @override
  String get enter => 'Entrar';

  @override
  String get connect => 'Conectar';

  @override
  String get close => 'Cerrar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get password => 'Contraseña';

  @override
  String get passwordOptional => 'Contraseña (opcional)';

  @override
  String get defaultPlayerName => 'Jugador';

  @override
  String get defaultLocalName => 'Yo';

  @override
  String get defaultHostName => 'Host';

  @override
  String get andJoin => ' y ';

  @override
  String get tagline => 'CASINO DE BOLSILLO';

  @override
  String get modeDiceDashSubtitle => 'Póker con dados y caos';

  @override
  String get modeTexasSubtitle => 'El póker clásico';

  @override
  String get modeBlackjackSubtitle => 'Gánale al crupier';

  @override
  String get playLan => 'Jugar en red';

  @override
  String get howToPlay => 'Cómo jugar';

  @override
  String get settings => 'Ajustes';

  @override
  String get quitAppTitle => '¿Salir del juego?';

  @override
  String get quitAppBody => '¿Estás seguro que quieres salir de la aplicación?';

  @override
  String get createRoom => 'Crear sala';

  @override
  String get createRoomSubtitle => 'Los demás se unen a tu partida';

  @override
  String get waitingEllipsis => 'Esperando...';

  @override
  String get joinRoom => 'Unirse a sala';

  @override
  String get joinRoomSubtitle => 'Busca partidas en tu Wi-Fi o entra por IP';

  @override
  String get sameWifiNote =>
      'Todos los dispositivos deben estar en la misma red Wi-Fi.';

  @override
  String get setupGame => 'Configurar Partida';

  @override
  String setupMode(String mode) {
    return 'Configurar $mode';
  }

  @override
  String get botCount => 'Cantidad de bots';

  @override
  String get botCountRange => 'Cantidad de bots (1 - 6)';

  @override
  String get botDifficulty => 'Dificultad de los bots';

  @override
  String get difficultyEasy => 'Fácil';

  @override
  String get difficultyNormal => 'Normal';

  @override
  String get difficultyHard => 'Difícil';

  @override
  String get difficultyEasyHint => 'Juegan a lo loco y cometen errores.';

  @override
  String get difficultyNormalHint =>
      'Juegan con cabeza, con algún error de vez en cuando.';

  @override
  String get difficultyHardHint =>
      'Juegan casi perfecto: cuidado con sus apuestas.';

  @override
  String get createRoomTitle => 'Crear Sala';

  @override
  String get gameMode => 'Modo de juego';

  @override
  String get roomName => 'Nombre de la sala';

  @override
  String get howTexas1 =>
      'Recibes 2 cartas; en la mesa salen 5 comunitarias (flop, turn y river).';

  @override
  String get howTexas2 =>
      'En cada ronda puedes retirarte (FOLD), igualar (CALL/CHECK) o subir (RAISE).';

  @override
  String get howTexas3 =>
      'Gana la mejor jugada de 5 cartas entre tus 2 y las 5 de la mesa.';

  @override
  String get howDice1 =>
      'Como Texas Hold\'em, pero antes de cada acción lanzas 2 dados.';

  @override
  String get howDice2 => 'Suma 7: el bote crece un 30 %.';

  @override
  String get howDice3 =>
      'Doble 1: ¡INTERCAMBIO! Las manos de todos se mezclan y se reparten de nuevo.';

  @override
  String get howDice4 =>
      'Doble 6: ¡ALL-IN! · Doble 3: espías una carta · 6 y 1: carta extra.';

  @override
  String get howBj1 =>
      'Apuesta y acércate a 21 sin pasarte. El As vale 1 u 11.';

  @override
  String get howBj2 =>
      'PEDIR toma carta, PLANTAR se queda, DOBLAR duplica la apuesta con una carta más, DIVIDIR separa una pareja.';

  @override
  String get howBj3 =>
      'Blackjack paga 3 a 2, el crupier se planta en 17 y 5 cartas sin pasarte (5-Card Charlie) ganan.';

  @override
  String get sound => 'Sonido';

  @override
  String get soundSubtitle => 'Cartas, fichas y dados';

  @override
  String get updateCheck => 'Avisar de versiones nuevas';

  @override
  String get updateCheckSubtitle => 'Revisa GitHub una vez al día';

  @override
  String get scene => 'Ambiente';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Automático';

  @override
  String get themeClasico => 'Clásico';

  @override
  String get themeClasicoDesc => 'Verde y simple';

  @override
  String get themeCantina => 'Cantina mexicana';

  @override
  String get themeCantinaDesc => 'Papel picado y tequila';

  @override
  String get themeGarito => 'Garito clandestino';

  @override
  String get themeGaritoDesc => 'Mafia y dinero sucio';

  @override
  String get cockTitle => '¡Pelea de gallos!';

  @override
  String get cockPrompt => 'Apuesta a tu favorito';

  @override
  String get cockFavorite => 'Favorito';

  @override
  String get cockUnderdog => 'Sorpresa';

  @override
  String cockPays(String mult) {
    return 'Paga x$mult';
  }

  @override
  String get cockPass => 'Paso';

  @override
  String cockYourBet(String chips, String name) {
    return 'Apostaste $chips a $name';
  }

  @override
  String get cockYouPassed => 'No apostaste esta vez';

  @override
  String get cockNoChips => 'No tienes fichas para apostar';

  @override
  String get cockWaiting => 'Esperando apuestas…';

  @override
  String cockWins(String name) {
    return '¡Gana $name!';
  }

  @override
  String cockYouWon(String chips) {
    return '¡Ganaste +$chips!';
  }

  @override
  String cockYouLost(String chips) {
    return 'Perdiste $chips';
  }

  @override
  String get cockNextHand => 'La partida sigue…';

  @override
  String get themeCasino => 'Casino de lujo';

  @override
  String get themeCasinoDesc => 'Candelabros y neón';

  @override
  String get updateTitle => 'Hay una versión nueva';

  @override
  String updateBody(String newVersion, String current) {
    return 'Ya salió la versión $newVersion (tienes la $current). Descárgala en GitHub e instálala encima: no pierdes tus fichas ni tus ajustes.\n\nPara jugar en red, todos deben tener la misma versión.';
  }

  @override
  String get notNow => 'Ahora no';

  @override
  String get download => 'Descargar';

  @override
  String get browserFailed =>
      'No se pudo abrir el navegador: el enlace quedó copiado.';

  @override
  String get leaveGameTitle => '¿Abandonar partida?';

  @override
  String get leaveGameBody => '¿Estás seguro que quieres salir de la partida?';

  @override
  String get leaveTableBody => '¿Estás seguro que quieres salir de la mesa?';

  @override
  String get roomClosedByHost => 'El anfitrión cerró la sala.';

  @override
  String get connectionLostHost => 'Se perdió la conexión con el anfitrión.';

  @override
  String get rollDice => 'Lanzar Dados';

  @override
  String get startGame => 'Iniciar Partida';

  @override
  String actingAs(String name) {
    return 'Actuando como: $name';
  }

  @override
  String get continueAction => 'CONTINUAR';

  @override
  String get raiseTitle => 'Subir apuesta';

  @override
  String raiseCallTotal(String call, String total) {
    return 'Igualas $call · Total $total';
  }

  @override
  String raiseTotal(String total) {
    return 'Total $total';
  }

  @override
  String get matchWonLocal => '¡Ganaste la partida!';

  @override
  String matchWonBy(String name) {
    return '¡$name gana la partida!';
  }

  @override
  String get matchWonLocalBody =>
      'Te quedaste con todas las fichas de la mesa.';

  @override
  String get matchWonByBody => 'Se quedó con todas las fichas de la mesa.';

  @override
  String get waitingHostRestart =>
      'Esperando a que el anfitrión empiece otra partida...';

  @override
  String get playAgain => 'Jugar otra vez';

  @override
  String get resultTie => '¡Empate!';

  @override
  String get resultYouWon => '¡Ganaste!';

  @override
  String resultWins(String name) {
    return '¡$name gana!';
  }

  @override
  String resultWith(String hand) {
    return 'Con $hand';
  }

  @override
  String get resultOthersFolded => 'Los demás se retiraron';

  @override
  String amountEach(String amount) {
    return '+$amount c/u';
  }

  @override
  String get pot => 'BOTE';

  @override
  String get winOdds => 'Probabilidad de ganar la mano';

  @override
  String get diceLucky => '¡SUERTE! +30%';

  @override
  String get diceSwap => '¡INTERCAMBIO!';

  @override
  String get diceAllIn => '¡ALL-IN!';

  @override
  String get diceSpy => '¡ESPÍA!';

  @override
  String get diceExtraCard => '¡CARTA EXTRA!';

  @override
  String get chaosTitle => '¡CAOS!';

  @override
  String get chaosSubtitle => 'Intercambio de manos activado';

  @override
  String get rebuy => 'RECOMPRAR';

  @override
  String winnerBadge(String amount) {
    return 'GANADOR +$amount';
  }

  @override
  String betAmount(String amount) {
    return 'Apuesta: \$$amount';
  }

  @override
  String get msgLuckySeven => 'Dados de la suerte. El Pot aumenta un 30%';

  @override
  String msgDoubleSix(String name) {
    return '¡Doble 6! $name va ALL-IN';
  }

  @override
  String msgSpy(String name, String target) {
    return '¡Espía! $name ve una carta de $target';
  }

  @override
  String msgExtraCard(String name) {
    return '¡Carta extra! $name se queda con sus dos mejores cartas';
  }

  @override
  String msgWinsByFold(String name) {
    return '¡$name gana por abandono!';
  }

  @override
  String msgSplitPot(String hand) {
    return '¡Empate! Bote dividido con $hand';
  }

  @override
  String msgWinsWith(String name, String hand) {
    return '¡$name gana con $hand!';
  }

  @override
  String get msgNoWinner => '¡Showdown! No hay ganador';

  @override
  String get msgChaos => '¡MODO CAOS! Intercambio de cartas';

  @override
  String get handHighCard => 'Carta Alta';

  @override
  String get handOnePair => 'Par';

  @override
  String get handTwoPair => 'Doble Par';

  @override
  String get handThreeOfAKind => 'Trío';

  @override
  String get handStraight => 'Escalera';

  @override
  String get handFlush => 'Color';

  @override
  String get handFullHouse => 'Full House';

  @override
  String get handFourOfAKind => 'Póker';

  @override
  String get handStraightFlush => 'Escalera de Color';

  @override
  String get handRoyalFlush => 'Escalera Real';

  @override
  String noticeHeirTakingOver(String name) {
    return 'El anfitrión salió. $name se queda con la mesa…';
  }

  @override
  String get noticeReconnecting => 'Conexión perdida, reconectando…';

  @override
  String noticeNewHost(String name) {
    return 'Ahora el anfitrión es $name';
  }

  @override
  String get noticeYouAreHost => 'El anfitrión salió: ahora tú tienes la mesa';

  @override
  String turnClockMine(String seconds) {
    return 'Te quedan $seconds s para jugar';
  }

  @override
  String turnClockOther(String name, String seconds) {
    return '$name tiene $seconds s';
  }

  @override
  String get rulesPays => 'BLACKJACK PAGA 3 A 2';

  @override
  String get rulesDealer => 'CRUPIER SE PLANTA EN 17  •  5-CARD CHARLIE';

  @override
  String shoeCount(String count) {
    return 'Mazo: $count';
  }

  @override
  String get dealer => 'CRUPIER';

  @override
  String handShort(String number) {
    return 'M$number';
  }

  @override
  String get ready => 'Listo';

  @override
  String get bettingEllipsis => 'Apostando...';

  @override
  String get outcomeBlackjack => 'BLACKJACK';

  @override
  String get outcomeCharlie => 'CHARLIE';

  @override
  String get outcomeWin => 'GANA';

  @override
  String get outcomePush => 'EMPATE';

  @override
  String get outcomeInsured => 'SEGURO';

  @override
  String get outcomeBust => 'BUST';

  @override
  String get outcomeLose => 'PIERDE';

  @override
  String get statusInProgress => 'Partida en curso...';

  @override
  String get statusDealing => 'Repartiendo cartas...';

  @override
  String get statusInsurance =>
      'El crupier muestra un As... esperando el seguro';

  @override
  String get statusDealerTurn => '🎩 Turno del Crupier... jugando mano';

  @override
  String statusBotTurn(String name) {
    return '🤖 Turno de $name... pensando jugada';
  }

  @override
  String statusAway(String name) {
    return '$name se desconectó... se planta en breve';
  }

  @override
  String statusTurnOf(String name) {
    return 'Turno de $name...';
  }

  @override
  String get statusWaitingBets => 'Esperando apuestas de los jugadores...';

  @override
  String insuranceOffer(String cost) {
    return 'El crupier muestra un As. ¿Seguro por \$$cost?';
  }

  @override
  String get insuranceExplain =>
      'Si tiene blackjack, el seguro paga 2 a 1 y recuperas tu apuesta.';

  @override
  String get noThanks => 'No, gracias';

  @override
  String insure(String cost) {
    return 'Asegurar \$$cost';
  }

  @override
  String get betLabel => 'APUESTA:';

  @override
  String get placeBet => 'APOSTAR';

  @override
  String get hit => 'PEDIR';

  @override
  String get stand => 'PLANTAR';

  @override
  String get double => 'DOBLAR';

  @override
  String get split => 'DIVIDIR';

  @override
  String bjYouBlackjack(String net) {
    return '¡Blackjack! Ganas +$net';
  }

  @override
  String bjYouCharlie(String net) {
    return '¡5-Card Charlie! Ganas +$net';
  }

  @override
  String bjYouWin(String net) {
    return '¡Ganaste +$net!';
  }

  @override
  String get bjYouPush => 'Empate: recuperas tu apuesta';

  @override
  String get bjYouInsured => 'Blackjack del crupier: el seguro te cubrió';

  @override
  String bjYouInsuredNet(String net) {
    return 'Blackjack del crupier: el seguro te cubrió ($net)';
  }

  @override
  String bjYouBust(String net) {
    return 'Te pasaste de 21 ($net)';
  }

  @override
  String bjDealerBlackjack(String net) {
    return '¡Blackjack del crupier! ($net)';
  }

  @override
  String bjDealerWins(String net) {
    return 'Gana el crupier ($net)';
  }

  @override
  String get bjRoundOver => 'Ronda finalizada';

  @override
  String get hostDealsSoon => 'El anfitrión reparte en breve...';

  @override
  String get newRound => 'Nueva Ronda';

  @override
  String waitingPlayersCount(String count) {
    return 'Esperando jugadores... ($count)';
  }

  @override
  String get wrongPassword => 'Contraseña incorrecta';

  @override
  String get roomFull => 'La sala está llena';

  @override
  String get joinError => 'Error al unirse';

  @override
  String enterRoom(String name) {
    return 'Entrar a $name';
  }

  @override
  String get noIpFound =>
      'No encontré una IP en lo que copiaste. Copia la IP que muestra la sala.';

  @override
  String get directIpTitle => 'Conexión Directa por IP';

  @override
  String get pasteIp => 'Pegar IP copiada';

  @override
  String get hostIpHint => 'IP del Host (ej: 192.168.1.50)';

  @override
  String get portHint => 'Puerto (ej: 54321)';

  @override
  String get invalidIpPort => 'Por favor ingresa una IP y puerto válidos';

  @override
  String get cannotConnect =>
      'No se pudo conectar al Host. Verifica la IP y el Firewall.';

  @override
  String get helpTitle => 'Ayuda de Conexión';

  @override
  String get help1Title => '1. Misma Red Wi-Fi';

  @override
  String get help1Body =>
      'Todos los dispositivos deben estar conectados al mismo Wi-Fi o punto de acceso (zona Wi-Fi móvil).';

  @override
  String get help2Title => '2. Firewall en Windows / PC';

  @override
  String get help2Body =>
      'Si la PC es el Host, asegúrate de permitir que la app acceda a la red a través del Firewall de Windows.';

  @override
  String get help3Title => '3. Conexión por IP Directa';

  @override
  String get help3Body =>
      'Si el descubrimiento automático no encuentra la sala, el Host verá su IP en pantalla. Usa el botón \"Por IP\" para conectarte directamente.';

  @override
  String get roomsTitle => 'Salas disponibles';

  @override
  String get help => 'Ayuda';

  @override
  String get notInList => '¿No ves la sala en la lista?';

  @override
  String get notInListSubtitle => 'Conéctate escribiendo la IP del Host';

  @override
  String get byIp => 'Por IP';

  @override
  String get connectingRoom => 'Conectando a la sala...';

  @override
  String get searchingRooms =>
      'Buscando salas automáticamente...\nAsegúrate de que ambos dispositivos estén en la misma red Wi-Fi';

  @override
  String get roomInGame => 'En juego';

  @override
  String get roomWaiting => 'Esperando jugadores';

  @override
  String roomPlayers(String count, String max) {
    return '$count/$max jugadores';
  }

  @override
  String get roomWithPassword => ' • CON CONTRASEÑA';

  @override
  String get roomIp => 'IP de la sala';

  @override
  String copiedAddress(String address) {
    return 'Copiado: $address. Pégalo en WhatsApp y los demás lo pegan en «Por IP».';
  }

  @override
  String get copy => 'Copiar';

  @override
  String get backToMenu => 'Volver al menú';

  @override
  String get options => 'Opciones';

  @override
  String get leaveTable => 'Salir de la mesa';

  @override
  String get fastGame => 'Juego rápido';

  @override
  String get fastGameSubtitle =>
      'Los bots piensan y el crupier reparte más rápido';

  @override
  String get showOdds => 'Mostrar mi probabilidad';

  @override
  String get showOddsSubtitle => 'Ayuda: tu % de ganar la mano en tu asiento';

  @override
  String get keepAwake => 'Pantalla siempre encendida';

  @override
  String get keepAwakeSubtitle => 'No se apaga mientras estás en la mesa';

  @override
  String get notifRoomOpen =>
      'Tu sala está abierta: la partida sigue aunque uses otras apps';

  @override
  String get notifLanActive => 'Partida en red activa';
}
