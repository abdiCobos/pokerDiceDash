import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @exit.
  ///
  /// In es, this message translates to:
  /// **'Salir'**
  String get exit;

  /// No description provided for @play.
  ///
  /// In es, this message translates to:
  /// **'Jugar'**
  String get play;

  /// No description provided for @yourName.
  ///
  /// In es, this message translates to:
  /// **'Tu nombre'**
  String get yourName;

  /// No description provided for @gotIt.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get gotIt;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get back;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @create.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get create;

  /// No description provided for @enter.
  ///
  /// In es, this message translates to:
  /// **'Entrar'**
  String get enter;

  /// No description provided for @connect.
  ///
  /// In es, this message translates to:
  /// **'Conectar'**
  String get connect;

  /// No description provided for @close.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get confirm;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @passwordOptional.
  ///
  /// In es, this message translates to:
  /// **'Contraseña (opcional)'**
  String get passwordOptional;

  /// No description provided for @defaultPlayerName.
  ///
  /// In es, this message translates to:
  /// **'Jugador'**
  String get defaultPlayerName;

  /// No description provided for @defaultLocalName.
  ///
  /// In es, this message translates to:
  /// **'Yo'**
  String get defaultLocalName;

  /// No description provided for @defaultHostName.
  ///
  /// In es, this message translates to:
  /// **'Host'**
  String get defaultHostName;

  /// No description provided for @andJoin.
  ///
  /// In es, this message translates to:
  /// **' y '**
  String get andJoin;

  /// No description provided for @tagline.
  ///
  /// In es, this message translates to:
  /// **'CASINO DE BOLSILLO'**
  String get tagline;

  /// No description provided for @modeDiceDashSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Póker con dados y caos'**
  String get modeDiceDashSubtitle;

  /// No description provided for @modeTexasSubtitle.
  ///
  /// In es, this message translates to:
  /// **'El póker clásico'**
  String get modeTexasSubtitle;

  /// No description provided for @modeBlackjackSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Gánale al crupier'**
  String get modeBlackjackSubtitle;

  /// No description provided for @playLan.
  ///
  /// In es, this message translates to:
  /// **'Jugar en red'**
  String get playLan;

  /// No description provided for @howToPlay.
  ///
  /// In es, this message translates to:
  /// **'Cómo jugar'**
  String get howToPlay;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @quitAppTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Salir del juego?'**
  String get quitAppTitle;

  /// No description provided for @quitAppBody.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro que quieres salir de la aplicación?'**
  String get quitAppBody;

  /// No description provided for @createRoom.
  ///
  /// In es, this message translates to:
  /// **'Crear sala'**
  String get createRoom;

  /// No description provided for @createRoomSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Los demás se unen a tu partida'**
  String get createRoomSubtitle;

  /// No description provided for @waitingEllipsis.
  ///
  /// In es, this message translates to:
  /// **'Esperando...'**
  String get waitingEllipsis;

  /// No description provided for @joinRoom.
  ///
  /// In es, this message translates to:
  /// **'Unirse a sala'**
  String get joinRoom;

  /// No description provided for @joinRoomSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Busca partidas en tu Wi-Fi o entra por IP'**
  String get joinRoomSubtitle;

  /// No description provided for @sameWifiNote.
  ///
  /// In es, this message translates to:
  /// **'Todos los dispositivos deben estar en la misma red Wi-Fi.'**
  String get sameWifiNote;

  /// No description provided for @setupGame.
  ///
  /// In es, this message translates to:
  /// **'Configurar Partida'**
  String get setupGame;

  /// No description provided for @setupMode.
  ///
  /// In es, this message translates to:
  /// **'Configurar {mode}'**
  String setupMode(String mode);

  /// No description provided for @botCount.
  ///
  /// In es, this message translates to:
  /// **'Cantidad de bots'**
  String get botCount;

  /// No description provided for @botCountRange.
  ///
  /// In es, this message translates to:
  /// **'Cantidad de bots (1 - 6)'**
  String get botCountRange;

  /// No description provided for @botDifficulty.
  ///
  /// In es, this message translates to:
  /// **'Dificultad de los bots'**
  String get botDifficulty;

  /// No description provided for @difficultyEasy.
  ///
  /// In es, this message translates to:
  /// **'Fácil'**
  String get difficultyEasy;

  /// No description provided for @difficultyNormal.
  ///
  /// In es, this message translates to:
  /// **'Normal'**
  String get difficultyNormal;

  /// No description provided for @difficultyHard.
  ///
  /// In es, this message translates to:
  /// **'Difícil'**
  String get difficultyHard;

  /// No description provided for @difficultyEasyHint.
  ///
  /// In es, this message translates to:
  /// **'Juegan a lo loco y cometen errores.'**
  String get difficultyEasyHint;

  /// No description provided for @difficultyNormalHint.
  ///
  /// In es, this message translates to:
  /// **'Juegan con cabeza, con algún error de vez en cuando.'**
  String get difficultyNormalHint;

  /// No description provided for @difficultyHardHint.
  ///
  /// In es, this message translates to:
  /// **'Juegan casi perfecto: cuidado con sus apuestas.'**
  String get difficultyHardHint;

  /// No description provided for @createRoomTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear Sala'**
  String get createRoomTitle;

  /// No description provided for @gameMode.
  ///
  /// In es, this message translates to:
  /// **'Modo de juego'**
  String get gameMode;

  /// No description provided for @roomName.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la sala'**
  String get roomName;

  /// No description provided for @howTexas1.
  ///
  /// In es, this message translates to:
  /// **'Recibes 2 cartas; en la mesa salen 5 comunitarias (flop, turn y river).'**
  String get howTexas1;

  /// No description provided for @howTexas2.
  ///
  /// In es, this message translates to:
  /// **'En cada ronda puedes retirarte (FOLD), igualar (CALL/CHECK) o subir (RAISE).'**
  String get howTexas2;

  /// No description provided for @howTexas3.
  ///
  /// In es, this message translates to:
  /// **'Gana la mejor jugada de 5 cartas entre tus 2 y las 5 de la mesa.'**
  String get howTexas3;

  /// No description provided for @howDice1.
  ///
  /// In es, this message translates to:
  /// **'Como Texas Hold\'em, pero antes de cada acción lanzas 2 dados.'**
  String get howDice1;

  /// No description provided for @howDice2.
  ///
  /// In es, this message translates to:
  /// **'Suma 7: el bote crece un 30 %.'**
  String get howDice2;

  /// No description provided for @howDice3.
  ///
  /// In es, this message translates to:
  /// **'Doble 1: ¡INTERCAMBIO! Las manos de todos se mezclan y se reparten de nuevo.'**
  String get howDice3;

  /// No description provided for @howDice4.
  ///
  /// In es, this message translates to:
  /// **'Doble 6: ¡ALL-IN! · Doble 3: espías una carta · 6 y 1: carta extra.'**
  String get howDice4;

  /// No description provided for @howBj1.
  ///
  /// In es, this message translates to:
  /// **'Apuesta y acércate a 21 sin pasarte. El As vale 1 u 11.'**
  String get howBj1;

  /// No description provided for @howBj2.
  ///
  /// In es, this message translates to:
  /// **'PEDIR toma carta, PLANTAR se queda, DOBLAR duplica la apuesta con una carta más, DIVIDIR separa una pareja.'**
  String get howBj2;

  /// No description provided for @howBj3.
  ///
  /// In es, this message translates to:
  /// **'Blackjack paga 3 a 2, el crupier se planta en 17 y 5 cartas sin pasarte (5-Card Charlie) ganan.'**
  String get howBj3;

  /// No description provided for @sound.
  ///
  /// In es, this message translates to:
  /// **'Sonido'**
  String get sound;

  /// No description provided for @soundSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Cartas, fichas y dados'**
  String get soundSubtitle;

  /// No description provided for @updateCheck.
  ///
  /// In es, this message translates to:
  /// **'Avisar de versiones nuevas'**
  String get updateCheck;

  /// No description provided for @updateCheckSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Revisa GitHub una vez al día'**
  String get updateCheckSubtitle;

  /// No description provided for @scene.
  ///
  /// In es, this message translates to:
  /// **'Ambiente'**
  String get scene;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In es, this message translates to:
  /// **'Automático'**
  String get languageSystem;

  /// No description provided for @themeClasico.
  ///
  /// In es, this message translates to:
  /// **'Clásico'**
  String get themeClasico;

  /// No description provided for @themeClasicoDesc.
  ///
  /// In es, this message translates to:
  /// **'Verde y simple'**
  String get themeClasicoDesc;

  /// No description provided for @themeCantina.
  ///
  /// In es, this message translates to:
  /// **'Cantina mexicana'**
  String get themeCantina;

  /// No description provided for @themeCantinaDesc.
  ///
  /// In es, this message translates to:
  /// **'Papel picado y tequila'**
  String get themeCantinaDesc;

  /// No description provided for @themeGarito.
  ///
  /// In es, this message translates to:
  /// **'Garito clandestino'**
  String get themeGarito;

  /// No description provided for @themeGaritoDesc.
  ///
  /// In es, this message translates to:
  /// **'Mafia y dinero sucio'**
  String get themeGaritoDesc;

  /// No description provided for @cockTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Pelea de gallos!'**
  String get cockTitle;

  /// No description provided for @cockPrompt.
  ///
  /// In es, this message translates to:
  /// **'Apuesta a tu favorito'**
  String get cockPrompt;

  /// No description provided for @cockFavorite.
  ///
  /// In es, this message translates to:
  /// **'Favorito'**
  String get cockFavorite;

  /// No description provided for @cockUnderdog.
  ///
  /// In es, this message translates to:
  /// **'Sorpresa'**
  String get cockUnderdog;

  /// No description provided for @cockPays.
  ///
  /// In es, this message translates to:
  /// **'Paga x{mult}'**
  String cockPays(String mult);

  /// No description provided for @cockPass.
  ///
  /// In es, this message translates to:
  /// **'Paso'**
  String get cockPass;

  /// No description provided for @cockYourBet.
  ///
  /// In es, this message translates to:
  /// **'Apostaste {chips} a {name}'**
  String cockYourBet(String chips, String name);

  /// No description provided for @cockYouPassed.
  ///
  /// In es, this message translates to:
  /// **'No apostaste esta vez'**
  String get cockYouPassed;

  /// No description provided for @cockNoChips.
  ///
  /// In es, this message translates to:
  /// **'No tienes fichas para apostar'**
  String get cockNoChips;

  /// No description provided for @cockWaiting.
  ///
  /// In es, this message translates to:
  /// **'Esperando apuestas…'**
  String get cockWaiting;

  /// No description provided for @cockWins.
  ///
  /// In es, this message translates to:
  /// **'¡Gana {name}!'**
  String cockWins(String name);

  /// No description provided for @cockYouWon.
  ///
  /// In es, this message translates to:
  /// **'¡Ganaste +{chips}!'**
  String cockYouWon(String chips);

  /// No description provided for @cockYouLost.
  ///
  /// In es, this message translates to:
  /// **'Perdiste {chips}'**
  String cockYouLost(String chips);

  /// No description provided for @cockNextHand.
  ///
  /// In es, this message translates to:
  /// **'La partida sigue…'**
  String get cockNextHand;

  /// No description provided for @themeCasino.
  ///
  /// In es, this message translates to:
  /// **'Casino de lujo'**
  String get themeCasino;

  /// No description provided for @themeCasinoDesc.
  ///
  /// In es, this message translates to:
  /// **'Candelabros y neón'**
  String get themeCasinoDesc;

  /// No description provided for @updateTitle.
  ///
  /// In es, this message translates to:
  /// **'Hay una versión nueva'**
  String get updateTitle;

  /// No description provided for @updateBody.
  ///
  /// In es, this message translates to:
  /// **'Ya salió la versión {newVersion} (tienes la {current}). Descárgala en GitHub e instálala encima: no pierdes tus fichas ni tus ajustes.\n\nPara jugar en red, todos deben tener la misma versión.'**
  String updateBody(String newVersion, String current);

  /// No description provided for @notNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get notNow;

  /// No description provided for @download.
  ///
  /// In es, this message translates to:
  /// **'Descargar'**
  String get download;

  /// No description provided for @browserFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el navegador: el enlace quedó copiado.'**
  String get browserFailed;

  /// No description provided for @leaveGameTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Abandonar partida?'**
  String get leaveGameTitle;

  /// No description provided for @leaveGameBody.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro que quieres salir de la partida?'**
  String get leaveGameBody;

  /// No description provided for @leaveTableBody.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro que quieres salir de la mesa?'**
  String get leaveTableBody;

  /// No description provided for @roomClosedByHost.
  ///
  /// In es, this message translates to:
  /// **'El anfitrión cerró la sala.'**
  String get roomClosedByHost;

  /// No description provided for @connectionLostHost.
  ///
  /// In es, this message translates to:
  /// **'Se perdió la conexión con el anfitrión.'**
  String get connectionLostHost;

  /// No description provided for @rollDice.
  ///
  /// In es, this message translates to:
  /// **'Lanzar Dados'**
  String get rollDice;

  /// No description provided for @startGame.
  ///
  /// In es, this message translates to:
  /// **'Iniciar Partida'**
  String get startGame;

  /// No description provided for @actingAs.
  ///
  /// In es, this message translates to:
  /// **'Actuando como: {name}'**
  String actingAs(String name);

  /// No description provided for @continueAction.
  ///
  /// In es, this message translates to:
  /// **'CONTINUAR'**
  String get continueAction;

  /// No description provided for @raiseTitle.
  ///
  /// In es, this message translates to:
  /// **'Subir apuesta'**
  String get raiseTitle;

  /// No description provided for @raiseCallTotal.
  ///
  /// In es, this message translates to:
  /// **'Igualas {call} · Total {total}'**
  String raiseCallTotal(String call, String total);

  /// No description provided for @raiseTotal.
  ///
  /// In es, this message translates to:
  /// **'Total {total}'**
  String raiseTotal(String total);

  /// No description provided for @matchWonLocal.
  ///
  /// In es, this message translates to:
  /// **'¡Ganaste la partida!'**
  String get matchWonLocal;

  /// No description provided for @matchWonBy.
  ///
  /// In es, this message translates to:
  /// **'¡{name} gana la partida!'**
  String matchWonBy(String name);

  /// No description provided for @matchWonLocalBody.
  ///
  /// In es, this message translates to:
  /// **'Te quedaste con todas las fichas de la mesa.'**
  String get matchWonLocalBody;

  /// No description provided for @matchWonByBody.
  ///
  /// In es, this message translates to:
  /// **'Se quedó con todas las fichas de la mesa.'**
  String get matchWonByBody;

  /// No description provided for @waitingHostRestart.
  ///
  /// In es, this message translates to:
  /// **'Esperando a que el anfitrión empiece otra partida...'**
  String get waitingHostRestart;

  /// No description provided for @playAgain.
  ///
  /// In es, this message translates to:
  /// **'Jugar otra vez'**
  String get playAgain;

  /// No description provided for @resultTie.
  ///
  /// In es, this message translates to:
  /// **'¡Empate!'**
  String get resultTie;

  /// No description provided for @resultYouWon.
  ///
  /// In es, this message translates to:
  /// **'¡Ganaste!'**
  String get resultYouWon;

  /// No description provided for @resultWins.
  ///
  /// In es, this message translates to:
  /// **'¡{name} gana!'**
  String resultWins(String name);

  /// No description provided for @resultWith.
  ///
  /// In es, this message translates to:
  /// **'Con {hand}'**
  String resultWith(String hand);

  /// No description provided for @resultOthersFolded.
  ///
  /// In es, this message translates to:
  /// **'Los demás se retiraron'**
  String get resultOthersFolded;

  /// No description provided for @amountEach.
  ///
  /// In es, this message translates to:
  /// **'+{amount} c/u'**
  String amountEach(String amount);

  /// No description provided for @pot.
  ///
  /// In es, this message translates to:
  /// **'BOTE'**
  String get pot;

  /// No description provided for @winOdds.
  ///
  /// In es, this message translates to:
  /// **'Probabilidad de ganar la mano'**
  String get winOdds;

  /// No description provided for @diceLucky.
  ///
  /// In es, this message translates to:
  /// **'¡SUERTE! +30%'**
  String get diceLucky;

  /// No description provided for @diceSwap.
  ///
  /// In es, this message translates to:
  /// **'¡INTERCAMBIO!'**
  String get diceSwap;

  /// No description provided for @diceAllIn.
  ///
  /// In es, this message translates to:
  /// **'¡ALL-IN!'**
  String get diceAllIn;

  /// No description provided for @diceSpy.
  ///
  /// In es, this message translates to:
  /// **'¡ESPÍA!'**
  String get diceSpy;

  /// No description provided for @diceExtraCard.
  ///
  /// In es, this message translates to:
  /// **'¡CARTA EXTRA!'**
  String get diceExtraCard;

  /// No description provided for @chaosTitle.
  ///
  /// In es, this message translates to:
  /// **'¡CAOS!'**
  String get chaosTitle;

  /// No description provided for @chaosSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Intercambio de manos activado'**
  String get chaosSubtitle;

  /// No description provided for @rebuy.
  ///
  /// In es, this message translates to:
  /// **'RECOMPRAR'**
  String get rebuy;

  /// No description provided for @winnerBadge.
  ///
  /// In es, this message translates to:
  /// **'GANADOR +{amount}'**
  String winnerBadge(String amount);

  /// No description provided for @betAmount.
  ///
  /// In es, this message translates to:
  /// **'Apuesta: \${amount}'**
  String betAmount(String amount);

  /// No description provided for @msgLuckySeven.
  ///
  /// In es, this message translates to:
  /// **'Dados de la suerte. El Pot aumenta un 30%'**
  String get msgLuckySeven;

  /// No description provided for @msgDoubleSix.
  ///
  /// In es, this message translates to:
  /// **'¡Doble 6! {name} va ALL-IN'**
  String msgDoubleSix(String name);

  /// No description provided for @msgSpy.
  ///
  /// In es, this message translates to:
  /// **'¡Espía! {name} ve una carta de {target}'**
  String msgSpy(String name, String target);

  /// No description provided for @msgExtraCard.
  ///
  /// In es, this message translates to:
  /// **'¡Carta extra! {name} se queda con sus dos mejores cartas'**
  String msgExtraCard(String name);

  /// No description provided for @msgWinsByFold.
  ///
  /// In es, this message translates to:
  /// **'¡{name} gana por abandono!'**
  String msgWinsByFold(String name);

  /// No description provided for @msgSplitPot.
  ///
  /// In es, this message translates to:
  /// **'¡Empate! Bote dividido con {hand}'**
  String msgSplitPot(String hand);

  /// No description provided for @msgWinsWith.
  ///
  /// In es, this message translates to:
  /// **'¡{name} gana con {hand}!'**
  String msgWinsWith(String name, String hand);

  /// No description provided for @msgNoWinner.
  ///
  /// In es, this message translates to:
  /// **'¡Showdown! No hay ganador'**
  String get msgNoWinner;

  /// No description provided for @msgChaos.
  ///
  /// In es, this message translates to:
  /// **'¡MODO CAOS! Intercambio de cartas'**
  String get msgChaos;

  /// No description provided for @handHighCard.
  ///
  /// In es, this message translates to:
  /// **'Carta Alta'**
  String get handHighCard;

  /// No description provided for @handOnePair.
  ///
  /// In es, this message translates to:
  /// **'Par'**
  String get handOnePair;

  /// No description provided for @handTwoPair.
  ///
  /// In es, this message translates to:
  /// **'Doble Par'**
  String get handTwoPair;

  /// No description provided for @handThreeOfAKind.
  ///
  /// In es, this message translates to:
  /// **'Trío'**
  String get handThreeOfAKind;

  /// No description provided for @handStraight.
  ///
  /// In es, this message translates to:
  /// **'Escalera'**
  String get handStraight;

  /// No description provided for @handFlush.
  ///
  /// In es, this message translates to:
  /// **'Color'**
  String get handFlush;

  /// No description provided for @handFullHouse.
  ///
  /// In es, this message translates to:
  /// **'Full House'**
  String get handFullHouse;

  /// No description provided for @handFourOfAKind.
  ///
  /// In es, this message translates to:
  /// **'Póker'**
  String get handFourOfAKind;

  /// No description provided for @handStraightFlush.
  ///
  /// In es, this message translates to:
  /// **'Escalera de Color'**
  String get handStraightFlush;

  /// No description provided for @handRoyalFlush.
  ///
  /// In es, this message translates to:
  /// **'Escalera Real'**
  String get handRoyalFlush;

  /// No description provided for @noticeHeirTakingOver.
  ///
  /// In es, this message translates to:
  /// **'El anfitrión salió. {name} se queda con la mesa…'**
  String noticeHeirTakingOver(String name);

  /// No description provided for @noticeReconnecting.
  ///
  /// In es, this message translates to:
  /// **'Conexión perdida, reconectando…'**
  String get noticeReconnecting;

  /// No description provided for @noticeNewHost.
  ///
  /// In es, this message translates to:
  /// **'Ahora el anfitrión es {name}'**
  String noticeNewHost(String name);

  /// No description provided for @noticeYouAreHost.
  ///
  /// In es, this message translates to:
  /// **'El anfitrión salió: ahora tú tienes la mesa'**
  String get noticeYouAreHost;

  /// No description provided for @turnClockMine.
  ///
  /// In es, this message translates to:
  /// **'Te quedan {seconds} s para jugar'**
  String turnClockMine(String seconds);

  /// No description provided for @turnClockOther.
  ///
  /// In es, this message translates to:
  /// **'{name} tiene {seconds} s'**
  String turnClockOther(String name, String seconds);

  /// No description provided for @rulesPays.
  ///
  /// In es, this message translates to:
  /// **'BLACKJACK PAGA 3 A 2'**
  String get rulesPays;

  /// No description provided for @rulesDealer.
  ///
  /// In es, this message translates to:
  /// **'CRUPIER SE PLANTA EN 17  •  5-CARD CHARLIE'**
  String get rulesDealer;

  /// No description provided for @shoeCount.
  ///
  /// In es, this message translates to:
  /// **'Mazo: {count}'**
  String shoeCount(String count);

  /// No description provided for @dealer.
  ///
  /// In es, this message translates to:
  /// **'CRUPIER'**
  String get dealer;

  /// No description provided for @handShort.
  ///
  /// In es, this message translates to:
  /// **'M{number}'**
  String handShort(String number);

  /// No description provided for @ready.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get ready;

  /// No description provided for @bettingEllipsis.
  ///
  /// In es, this message translates to:
  /// **'Apostando...'**
  String get bettingEllipsis;

  /// No description provided for @outcomeBlackjack.
  ///
  /// In es, this message translates to:
  /// **'BLACKJACK'**
  String get outcomeBlackjack;

  /// No description provided for @outcomeCharlie.
  ///
  /// In es, this message translates to:
  /// **'CHARLIE'**
  String get outcomeCharlie;

  /// No description provided for @outcomeWin.
  ///
  /// In es, this message translates to:
  /// **'GANA'**
  String get outcomeWin;

  /// No description provided for @outcomePush.
  ///
  /// In es, this message translates to:
  /// **'EMPATE'**
  String get outcomePush;

  /// No description provided for @outcomeInsured.
  ///
  /// In es, this message translates to:
  /// **'SEGURO'**
  String get outcomeInsured;

  /// No description provided for @outcomeBust.
  ///
  /// In es, this message translates to:
  /// **'BUST'**
  String get outcomeBust;

  /// No description provided for @outcomeLose.
  ///
  /// In es, this message translates to:
  /// **'PIERDE'**
  String get outcomeLose;

  /// No description provided for @statusInProgress.
  ///
  /// In es, this message translates to:
  /// **'Partida en curso...'**
  String get statusInProgress;

  /// No description provided for @statusDealing.
  ///
  /// In es, this message translates to:
  /// **'Repartiendo cartas...'**
  String get statusDealing;

  /// No description provided for @statusInsurance.
  ///
  /// In es, this message translates to:
  /// **'El crupier muestra un As... esperando el seguro'**
  String get statusInsurance;

  /// No description provided for @statusDealerTurn.
  ///
  /// In es, this message translates to:
  /// **'🎩 Turno del Crupier... jugando mano'**
  String get statusDealerTurn;

  /// No description provided for @statusBotTurn.
  ///
  /// In es, this message translates to:
  /// **'🤖 Turno de {name}... pensando jugada'**
  String statusBotTurn(String name);

  /// No description provided for @statusAway.
  ///
  /// In es, this message translates to:
  /// **'{name} se desconectó... se planta en breve'**
  String statusAway(String name);

  /// No description provided for @statusTurnOf.
  ///
  /// In es, this message translates to:
  /// **'Turno de {name}...'**
  String statusTurnOf(String name);

  /// No description provided for @statusWaitingBets.
  ///
  /// In es, this message translates to:
  /// **'Esperando apuestas de los jugadores...'**
  String get statusWaitingBets;

  /// No description provided for @insuranceOffer.
  ///
  /// In es, this message translates to:
  /// **'El crupier muestra un As. ¿Seguro por \${cost}?'**
  String insuranceOffer(String cost);

  /// No description provided for @insuranceExplain.
  ///
  /// In es, this message translates to:
  /// **'Si tiene blackjack, el seguro paga 2 a 1 y recuperas tu apuesta.'**
  String get insuranceExplain;

  /// No description provided for @noThanks.
  ///
  /// In es, this message translates to:
  /// **'No, gracias'**
  String get noThanks;

  /// No description provided for @insure.
  ///
  /// In es, this message translates to:
  /// **'Asegurar \${cost}'**
  String insure(String cost);

  /// No description provided for @betLabel.
  ///
  /// In es, this message translates to:
  /// **'APUESTA:'**
  String get betLabel;

  /// No description provided for @placeBet.
  ///
  /// In es, this message translates to:
  /// **'APOSTAR'**
  String get placeBet;

  /// No description provided for @hit.
  ///
  /// In es, this message translates to:
  /// **'PEDIR'**
  String get hit;

  /// No description provided for @stand.
  ///
  /// In es, this message translates to:
  /// **'PLANTAR'**
  String get stand;

  /// No description provided for @double.
  ///
  /// In es, this message translates to:
  /// **'DOBLAR'**
  String get double;

  /// No description provided for @split.
  ///
  /// In es, this message translates to:
  /// **'DIVIDIR'**
  String get split;

  /// No description provided for @bjYouBlackjack.
  ///
  /// In es, this message translates to:
  /// **'¡Blackjack! Ganas +{net}'**
  String bjYouBlackjack(String net);

  /// No description provided for @bjYouCharlie.
  ///
  /// In es, this message translates to:
  /// **'¡5-Card Charlie! Ganas +{net}'**
  String bjYouCharlie(String net);

  /// No description provided for @bjYouWin.
  ///
  /// In es, this message translates to:
  /// **'¡Ganaste +{net}!'**
  String bjYouWin(String net);

  /// No description provided for @bjYouPush.
  ///
  /// In es, this message translates to:
  /// **'Empate: recuperas tu apuesta'**
  String get bjYouPush;

  /// No description provided for @bjYouInsured.
  ///
  /// In es, this message translates to:
  /// **'Blackjack del crupier: el seguro te cubrió'**
  String get bjYouInsured;

  /// No description provided for @bjYouInsuredNet.
  ///
  /// In es, this message translates to:
  /// **'Blackjack del crupier: el seguro te cubrió ({net})'**
  String bjYouInsuredNet(String net);

  /// No description provided for @bjYouBust.
  ///
  /// In es, this message translates to:
  /// **'Te pasaste de 21 ({net})'**
  String bjYouBust(String net);

  /// No description provided for @bjDealerBlackjack.
  ///
  /// In es, this message translates to:
  /// **'¡Blackjack del crupier! ({net})'**
  String bjDealerBlackjack(String net);

  /// No description provided for @bjDealerWins.
  ///
  /// In es, this message translates to:
  /// **'Gana el crupier ({net})'**
  String bjDealerWins(String net);

  /// No description provided for @bjRoundOver.
  ///
  /// In es, this message translates to:
  /// **'Ronda finalizada'**
  String get bjRoundOver;

  /// No description provided for @hostDealsSoon.
  ///
  /// In es, this message translates to:
  /// **'El anfitrión reparte en breve...'**
  String get hostDealsSoon;

  /// No description provided for @newRound.
  ///
  /// In es, this message translates to:
  /// **'Nueva Ronda'**
  String get newRound;

  /// No description provided for @waitingPlayersCount.
  ///
  /// In es, this message translates to:
  /// **'Esperando jugadores... ({count})'**
  String waitingPlayersCount(String count);

  /// No description provided for @wrongPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña incorrecta'**
  String get wrongPassword;

  /// No description provided for @roomFull.
  ///
  /// In es, this message translates to:
  /// **'La sala está llena'**
  String get roomFull;

  /// No description provided for @joinError.
  ///
  /// In es, this message translates to:
  /// **'Error al unirse'**
  String get joinError;

  /// No description provided for @enterRoom.
  ///
  /// In es, this message translates to:
  /// **'Entrar a {name}'**
  String enterRoom(String name);

  /// No description provided for @noIpFound.
  ///
  /// In es, this message translates to:
  /// **'No encontré una IP en lo que copiaste. Copia la IP que muestra la sala.'**
  String get noIpFound;

  /// No description provided for @directIpTitle.
  ///
  /// In es, this message translates to:
  /// **'Conexión Directa por IP'**
  String get directIpTitle;

  /// No description provided for @pasteIp.
  ///
  /// In es, this message translates to:
  /// **'Pegar IP copiada'**
  String get pasteIp;

  /// No description provided for @hostIpHint.
  ///
  /// In es, this message translates to:
  /// **'IP del Host (ej: 192.168.1.50)'**
  String get hostIpHint;

  /// No description provided for @portHint.
  ///
  /// In es, this message translates to:
  /// **'Puerto (ej: 54321)'**
  String get portHint;

  /// No description provided for @invalidIpPort.
  ///
  /// In es, this message translates to:
  /// **'Por favor ingresa una IP y puerto válidos'**
  String get invalidIpPort;

  /// No description provided for @cannotConnect.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar al Host. Verifica la IP y el Firewall.'**
  String get cannotConnect;

  /// No description provided for @helpTitle.
  ///
  /// In es, this message translates to:
  /// **'Ayuda de Conexión'**
  String get helpTitle;

  /// No description provided for @help1Title.
  ///
  /// In es, this message translates to:
  /// **'1. Misma Red Wi-Fi'**
  String get help1Title;

  /// No description provided for @help1Body.
  ///
  /// In es, this message translates to:
  /// **'Todos los dispositivos deben estar conectados al mismo Wi-Fi o punto de acceso (zona Wi-Fi móvil).'**
  String get help1Body;

  /// No description provided for @help2Title.
  ///
  /// In es, this message translates to:
  /// **'2. Firewall en Windows / PC'**
  String get help2Title;

  /// No description provided for @help2Body.
  ///
  /// In es, this message translates to:
  /// **'Si la PC es el Host, asegúrate de permitir que la app acceda a la red a través del Firewall de Windows.'**
  String get help2Body;

  /// No description provided for @help3Title.
  ///
  /// In es, this message translates to:
  /// **'3. Conexión por IP Directa'**
  String get help3Title;

  /// No description provided for @help3Body.
  ///
  /// In es, this message translates to:
  /// **'Si el descubrimiento automático no encuentra la sala, el Host verá su IP en pantalla. Usa el botón \"Por IP\" para conectarte directamente.'**
  String get help3Body;

  /// No description provided for @roomsTitle.
  ///
  /// In es, this message translates to:
  /// **'Salas disponibles'**
  String get roomsTitle;

  /// No description provided for @help.
  ///
  /// In es, this message translates to:
  /// **'Ayuda'**
  String get help;

  /// No description provided for @notInList.
  ///
  /// In es, this message translates to:
  /// **'¿No ves la sala en la lista?'**
  String get notInList;

  /// No description provided for @notInListSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Conéctate escribiendo la IP del Host'**
  String get notInListSubtitle;

  /// No description provided for @byIp.
  ///
  /// In es, this message translates to:
  /// **'Por IP'**
  String get byIp;

  /// No description provided for @connectingRoom.
  ///
  /// In es, this message translates to:
  /// **'Conectando a la sala...'**
  String get connectingRoom;

  /// No description provided for @searchingRooms.
  ///
  /// In es, this message translates to:
  /// **'Buscando salas automáticamente...\nAsegúrate de que ambos dispositivos estén en la misma red Wi-Fi'**
  String get searchingRooms;

  /// No description provided for @roomInGame.
  ///
  /// In es, this message translates to:
  /// **'En juego'**
  String get roomInGame;

  /// No description provided for @roomWaiting.
  ///
  /// In es, this message translates to:
  /// **'Esperando jugadores'**
  String get roomWaiting;

  /// No description provided for @roomPlayers.
  ///
  /// In es, this message translates to:
  /// **'{count}/{max} jugadores'**
  String roomPlayers(String count, String max);

  /// No description provided for @roomWithPassword.
  ///
  /// In es, this message translates to:
  /// **' • CON CONTRASEÑA'**
  String get roomWithPassword;

  /// No description provided for @roomIp.
  ///
  /// In es, this message translates to:
  /// **'IP de la sala'**
  String get roomIp;

  /// No description provided for @copiedAddress.
  ///
  /// In es, this message translates to:
  /// **'Copiado: {address}. Pégalo en WhatsApp y los demás lo pegan en «Por IP».'**
  String copiedAddress(String address);

  /// No description provided for @copy.
  ///
  /// In es, this message translates to:
  /// **'Copiar'**
  String get copy;

  /// No description provided for @backToMenu.
  ///
  /// In es, this message translates to:
  /// **'Volver al menú'**
  String get backToMenu;

  /// No description provided for @options.
  ///
  /// In es, this message translates to:
  /// **'Opciones'**
  String get options;

  /// No description provided for @leaveTable.
  ///
  /// In es, this message translates to:
  /// **'Salir de la mesa'**
  String get leaveTable;

  /// No description provided for @fastGame.
  ///
  /// In es, this message translates to:
  /// **'Juego rápido'**
  String get fastGame;

  /// No description provided for @fastGameSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Los bots piensan y el crupier reparte más rápido'**
  String get fastGameSubtitle;

  /// No description provided for @showOdds.
  ///
  /// In es, this message translates to:
  /// **'Mostrar mi probabilidad'**
  String get showOdds;

  /// No description provided for @showOddsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ayuda: tu % de ganar la mano en tu asiento'**
  String get showOddsSubtitle;

  /// No description provided for @keepAwake.
  ///
  /// In es, this message translates to:
  /// **'Pantalla siempre encendida'**
  String get keepAwake;

  /// No description provided for @keepAwakeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'No se apaga mientras estás en la mesa'**
  String get keepAwakeSubtitle;

  /// No description provided for @notifRoomOpen.
  ///
  /// In es, this message translates to:
  /// **'Tu sala está abierta: la partida sigue aunque uses otras apps'**
  String get notifRoomOpen;

  /// No description provided for @notifLanActive.
  ///
  /// In es, this message translates to:
  /// **'Partida en red activa'**
  String get notifLanActive;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
