"""Source of the game's texts in Spanish and English: writes lib/l10n/app_es.arb and app_en.arb.

    python tool/l10n_strings.py

Each entry: key -> (Spanish, English). Placeholders in braces ({name}); their names are listed
automatically in the Spanish (template) file. Numbers are passed as text by the game.
"""
import json
import os
import re

S = {
    # --- Common -------------------------------------------------------------------------------
    'cancel': ('Cancelar', 'Cancel'),
    'exit': ('Salir', 'Exit'),
    'play': ('Jugar', 'Play'),
    'yourName': ('Tu nombre', 'Your name'),
    'gotIt': ('Entendido', 'Got it'),
    'back': ('Volver', 'Back'),
    'save': ('Guardar', 'Save'),
    'create': ('Crear', 'Create'),
    'enter': ('Entrar', 'Join'),
    'connect': ('Conectar', 'Connect'),
    'close': ('Cerrar', 'Close'),
    'confirm': ('Confirmar', 'Confirm'),
    'password': ('Contraseña', 'Password'),
    'passwordOptional': ('Contraseña (opcional)', 'Password (optional)'),
    'defaultPlayerName': ('Jugador', 'Player'),
    'defaultLocalName': ('Yo', 'Me'),
    'defaultHostName': ('Host', 'Host'),
    'andJoin': (' y ', ' and '),

    # --- Menu ---------------------------------------------------------------------------------
    'tagline': ('CASINO DE BOLSILLO', 'POCKET CASINO'),
    'modeDiceDashSubtitle': ('Póker con dados y caos', 'Poker with dice and chaos'),
    'modeTexasSubtitle': ('El póker clásico', 'Classic poker'),
    'modeBlackjackSubtitle': ('Gánale al crupier', 'Beat the dealer'),
    'playLan': ('Jugar en red', 'Play with friends'),
    'howToPlay': ('Cómo jugar', 'How to play'),
    'settings': ('Ajustes', 'Settings'),
    'quitAppTitle': ('¿Salir del juego?', 'Quit the game?'),
    'quitAppBody': ('¿Estás seguro que quieres salir de la aplicación?', 'Are you sure you want to quit?'),
    'createRoom': ('Crear sala', 'Create a room'),
    'createRoomSubtitle': ('Los demás se unen a tu partida', 'Others join your game'),
    'waitingEllipsis': ('Esperando...', 'Waiting...'),
    'joinRoom': ('Unirse a sala', 'Join a room'),
    'joinRoomSubtitle': ('Busca partidas en tu Wi-Fi o entra por IP', 'Find games on your Wi-Fi or join by IP'),
    'sameWifiNote': ('Todos los dispositivos deben estar en la misma red Wi-Fi.',
                     'All devices must be on the same Wi-Fi network.'),

    # --- Game setup ---------------------------------------------------------------------------
    'setupGame': ('Configurar Partida', 'Game setup'),
    'setupMode': ('Configurar {mode}', '{mode} setup'),
    'botCount': ('Cantidad de bots', 'Number of bots'),
    'botCountRange': ('Cantidad de bots (1 - 6)', 'Number of bots (1 - 6)'),
    'botDifficulty': ('Dificultad de los bots', 'Bot difficulty'),
    'difficultyEasy': ('Fácil', 'Easy'),
    'difficultyNormal': ('Normal', 'Normal'),
    'difficultyHard': ('Difícil', 'Hard'),
    'difficultyEasyHint': ('Juegan a lo loco y cometen errores.', 'They play wild and make mistakes.'),
    'difficultyNormalHint': ('Juegan con cabeza, con algún error de vez en cuando.',
                             'They play smart, with the odd mistake.'),
    'difficultyHardHint': ('Juegan casi perfecto: cuidado con sus apuestas.',
                           'They play almost perfectly: watch their bets.'),
    'createRoomTitle': ('Crear Sala', 'Create a room'),
    'gameMode': ('Modo de juego', 'Game mode'),
    'roomName': ('Nombre de la sala', 'Room name'),

    # --- How to play --------------------------------------------------------------------------
    'howTexas1': ('Recibes 2 cartas; en la mesa salen 5 comunitarias (flop, turn y river).',
                  'You get 2 cards; 5 shared cards come out on the table (flop, turn and river).'),
    'howTexas2': ('En cada ronda puedes retirarte (FOLD), igualar (CALL/CHECK) o subir (RAISE).',
                  'Each round you can FOLD, match the bet (CALL/CHECK) or RAISE.'),
    'howTexas3': ('Gana la mejor jugada de 5 cartas entre tus 2 y las 5 de la mesa.',
                  'The best 5-card hand out of your 2 and the 5 on the table wins.'),
    'howDice1': ("Como Texas Hold'em, pero antes de cada acción lanzas 2 dados.",
                 "Like Texas Hold'em, but you roll 2 dice before every move."),
    'howDice2': ('Suma 7: el bote crece un 30 %.', 'Total 7: the pot grows by 30%.'),
    'howDice3': ('Doble 1: ¡INTERCAMBIO! Las manos de todos se mezclan y se reparten de nuevo.',
                 "Double 1: SWAP! Everyone's cards are shuffled and dealt again."),
    'howDice4': ('Doble 6: ¡ALL-IN! · Doble 3: espías una carta · 6 y 1: carta extra.',
                 'Double 6: ALL-IN! · Double 3: peek at a card · 6 and 1: extra card.'),
    'howBj1': ('Apuesta y acércate a 21 sin pasarte. El As vale 1 u 11.',
               'Bet and get as close to 21 as you can without going over. An ace is 1 or 11.'),
    'howBj2': ('PEDIR toma carta, PLANTAR se queda, DOBLAR duplica la apuesta con una carta más, DIVIDIR separa una pareja.',
               'HIT takes a card, STAND keeps your hand, DOUBLE doubles the bet for one more card, SPLIT separates a pair.'),
    'howBj3': ('Blackjack paga 3 a 2, el crupier se planta en 17 y 5 cartas sin pasarte (5-Card Charlie) ganan.',
               'Blackjack pays 3 to 2, the dealer stands on 17 and 5 cards without busting (5-Card Charlie) win.'),

    # --- Settings -----------------------------------------------------------------------------
    'sound': ('Sonido', 'Sound'),
    'soundSubtitle': ('Cartas, fichas y dados', 'Cards, chips and dice'),
    'updateCheck': ('Avisar de versiones nuevas', 'Tell me about new versions'),
    'updateCheckSubtitle': ('Revisa GitHub una vez al día', 'Checks GitHub once a day'),
    'scene': ('Ambiente', 'Scene'),
    'language': ('Idioma', 'Language'),
    'languageSystem': ('Automático', 'Automatic'),
    'themeClasico': ('Clásico', 'Classic'),
    'themeClasicoDesc': ('Verde y simple', 'Plain green'),
    'themeCantina': ('Cantina mexicana', 'Mexican cantina'),
    'themeCantinaDesc': ('Papel picado y tequila', 'Papel picado and tequila'),
    'themeGarito': ('Garito clandestino', 'Underground den'),
    'themeGaritoDesc': ('Mafia y dinero sucio', 'Mob money and danger'),

    # --- Update notice ------------------------------------------------------------------------
    'updateTitle': ('Hay una versión nueva', 'A new version is out'),
    'updateBody': ('Ya salió la versión {newVersion} (tienes la {current}). Descárgala en GitHub e instálala encima: no pierdes tus fichas ni tus ajustes.\n\nPara jugar en red, todos deben tener la misma versión.',
                   'Version {newVersion} is out (you have {current}). Download it from GitHub and install it over this one: you keep your chips and settings.\n\nTo play together, everyone needs the same version.'),
    'notNow': ('Ahora no', 'Not now'),
    'download': ('Descargar', 'Download'),
    'browserFailed': ('No se pudo abrir el navegador: el enlace quedó copiado.',
                      'Could not open the browser: the link was copied.'),

    # --- Poker table --------------------------------------------------------------------------
    'leaveGameTitle': ('¿Abandonar partida?', 'Leave the game?'),
    'leaveGameBody': ('¿Estás seguro que quieres salir de la partida?', 'Are you sure you want to leave the game?'),
    'leaveTableBody': ('¿Estás seguro que quieres salir de la mesa?', 'Are you sure you want to leave the table?'),
    'roomClosedByHost': ('El anfitrión cerró la sala.', 'The host closed the room.'),
    'connectionLostHost': ('Se perdió la conexión con el anfitrión.', 'Lost the connection to the host.'),
    'rollDice': ('Lanzar Dados', 'Roll dice'),
    'startGame': ('Iniciar Partida', 'Start game'),
    'actingAs': ('Actuando como: {name}', 'Playing as: {name}'),
    'continueAction': ('CONTINUAR', 'CONTINUE'),
    'raiseTitle': ('Subir apuesta', 'Raise'),
    'raiseCallTotal': ('Igualas {call} · Total {total}', 'Call {call} · Total {total}'),
    'raiseTotal': ('Total {total}', 'Total {total}'),
    'matchWonLocal': ('¡Ganaste la partida!', 'You won the match!'),
    'matchWonBy': ('¡{name} gana la partida!', '{name} wins the match!'),
    'matchWonLocalBody': ('Te quedaste con todas las fichas de la mesa.', 'You took every chip on the table.'),
    'matchWonByBody': ('Se quedó con todas las fichas de la mesa.', 'They took every chip on the table.'),
    'waitingHostRestart': ('Esperando a que el anfitrión empiece otra partida...',
                           'Waiting for the host to start another match...'),
    'playAgain': ('Jugar otra vez', 'Play again'),
    'resultTie': ('¡Empate!', 'Split pot!'),
    'resultYouWon': ('¡Ganaste!', 'You won!'),
    'resultWins': ('¡{name} gana!', '{name} wins!'),
    'resultWith': ('Con {hand}', 'With {hand}'),
    'resultOthersFolded': ('Los demás se retiraron', 'Everyone else folded'),
    'amountEach': ('+{amount} c/u', '+{amount} each'),
    'pot': ('BOTE', 'POT'),
    'winOdds': ('Probabilidad de ganar la mano', 'Chance of winning the hand'),
    'diceLucky': ('¡SUERTE! +30%', 'LUCKY! +30%'),
    'diceSwap': ('¡INTERCAMBIO!', 'SWAP!'),
    'diceAllIn': ('¡ALL-IN!', 'ALL-IN!'),
    'diceSpy': ('¡ESPÍA!', 'SPY!'),
    'diceExtraCard': ('¡CARTA EXTRA!', 'EXTRA CARD!'),
    'chaosTitle': ('¡CAOS!', 'CHAOS!'),
    'chaosSubtitle': ('Intercambio de manos activado', 'Hands are being swapped'),
    'rebuy': ('RECOMPRAR', 'REBUY'),
    'winnerBadge': ('GANADOR +{amount}', 'WINNER +{amount}'),
    'betAmount': ('Apuesta: \\${amount}', 'Bet: \\${amount}'),

    # Messages in the middle of the table
    'msgLuckySeven': ('Dados de la suerte. El Pot aumenta un 30%', 'Lucky dice. The pot grows by 30%'),
    'msgDoubleSix': ('¡Doble 6! {name} va ALL-IN', 'Double 6! {name} goes ALL-IN'),
    'msgSpy': ('¡Espía! {name} ve una carta de {target}', "Spy! {name} sees one of {target}'s cards"),
    'msgExtraCard': ('¡Carta extra! {name} se queda con sus dos mejores cartas', 'Extra card! {name} keeps their best two cards'),
    'msgWinsByFold': ('¡{name} gana por abandono!', '{name} wins: everyone else folded!'),
    'msgSplitPot': ('¡Empate! Bote dividido con {hand}', 'Split pot with {hand}!'),
    'msgWinsWith': ('¡{name} gana con {hand}!', '{name} wins with {hand}!'),
    'msgNoWinner': ('¡Showdown! No hay ganador', 'Showdown! No winner'),
    'msgChaos': ('¡MODO CAOS! Intercambio de cartas', 'CHAOS MODE! Cards are swapped'),

    # Hands
    'handHighCard': ('Carta Alta', 'High Card'),
    'handOnePair': ('Par', 'Pair'),
    'handTwoPair': ('Doble Par', 'Two Pair'),
    'handThreeOfAKind': ('Trío', 'Three of a Kind'),
    'handStraight': ('Escalera', 'Straight'),
    'handFlush': ('Color', 'Flush'),
    'handFullHouse': ('Full House', 'Full House'),
    'handFourOfAKind': ('Póker', 'Four of a Kind'),
    'handStraightFlush': ('Escalera de Color', 'Straight Flush'),
    'handRoyalFlush': ('Escalera Real', 'Royal Flush'),

    # Network notices
    'noticeHeirTakingOver': ('El anfitrión salió. {name} se queda con la mesa…', 'The host left. {name} takes over the table…'),
    'noticeReconnecting': ('Conexión perdida, reconectando…', 'Connection lost, reconnecting…'),
    'noticeNewHost': ('Ahora el anfitrión es {name}', '{name} is the host now'),
    'noticeYouAreHost': ('El anfitrión salió: ahora tú tienes la mesa', 'The host left: the table is yours now'),
    'turnClockMine': ('Te quedan {seconds} s para jugar', '{seconds} s left to play'),
    'turnClockOther': ('{name} tiene {seconds} s', '{name} has {seconds} s'),

    # --- Blackjack ----------------------------------------------------------------------------
    'rulesPays': ('BLACKJACK PAGA 3 A 2', 'BLACKJACK PAYS 3 TO 2'),
    'rulesDealer': ('CRUPIER SE PLANTA EN 17  •  5-CARD CHARLIE', 'DEALER STANDS ON 17  •  5-CARD CHARLIE'),
    'shoeCount': ('Mazo: {count}', 'Shoe: {count}'),
    'dealer': ('CRUPIER', 'DEALER'),
    'handShort': ('M{number}', 'H{number}'),
    'ready': ('Listo', 'Ready'),
    'bettingEllipsis': ('Apostando...', 'Betting...'),
    'outcomeBlackjack': ('BLACKJACK', 'BLACKJACK'),
    'outcomeCharlie': ('CHARLIE', 'CHARLIE'),
    'outcomeWin': ('GANA', 'WIN'),
    'outcomePush': ('EMPATE', 'PUSH'),
    'outcomeInsured': ('SEGURO', 'INSURED'),
    'outcomeBust': ('BUST', 'BUST'),
    'outcomeLose': ('PIERDE', 'LOSE'),
    'statusInProgress': ('Partida en curso...', 'Round in progress...'),
    'statusDealing': ('Repartiendo cartas...', 'Dealing...'),
    'statusInsurance': ('El crupier muestra un As... esperando el seguro', 'The dealer shows an ace... waiting for insurance'),
    'statusDealerTurn': ('🎩 Turno del Crupier... jugando mano', "🎩 Dealer's turn... playing the hand"),
    'statusBotTurn': ('🤖 Turno de {name}... pensando jugada', "🤖 {name}'s turn... thinking"),
    'statusAway': ('{name} se desconectó... se planta en breve', '{name} disconnected... stands shortly'),
    'statusTurnOf': ('Turno de {name}...', "{name}'s turn..."),
    'statusWaitingBets': ('Esperando apuestas de los jugadores...', 'Waiting for the players to bet...'),
    'insuranceOffer': ('El crupier muestra un As. ¿Seguro por \\${cost}?', 'The dealer shows an ace. Insurance for \\${cost}?'),
    'insuranceExplain': ('Si tiene blackjack, el seguro paga 2 a 1 y recuperas tu apuesta.',
                         'If the dealer has blackjack, insurance pays 2 to 1 and you get your bet back.'),
    'noThanks': ('No, gracias', 'No, thanks'),
    'insure': ('Asegurar \\${cost}', 'Insure \\${cost}'),
    'betLabel': ('APUESTA:', 'BET:'),
    'placeBet': ('APOSTAR', 'BET'),
    'hit': ('PEDIR', 'HIT'),
    'stand': ('PLANTAR', 'STAND'),
    'double': ('DOBLAR', 'DOUBLE'),
    'split': ('DIVIDIR', 'SPLIT'),
    'bjYouBlackjack': ('¡Blackjack! Ganas +{net}', 'Blackjack! You win +{net}'),
    'bjYouCharlie': ('¡5-Card Charlie! Ganas +{net}', '5-Card Charlie! You win +{net}'),
    'bjYouWin': ('¡Ganaste +{net}!', 'You won +{net}!'),
    'bjYouPush': ('Empate: recuperas tu apuesta', 'Push: you get your bet back'),
    'bjYouInsured': ('Blackjack del crupier: el seguro te cubrió', 'Dealer blackjack: insurance covered you'),
    'bjYouInsuredNet': ('Blackjack del crupier: el seguro te cubrió ({net})', 'Dealer blackjack: insurance covered you ({net})'),
    'bjYouBust': ('Te pasaste de 21 ({net})', 'You went over 21 ({net})'),
    'bjDealerBlackjack': ('¡Blackjack del crupier! ({net})', 'Dealer blackjack! ({net})'),
    'bjDealerWins': ('Gana el crupier ({net})', 'The dealer wins ({net})'),
    'bjRoundOver': ('Ronda finalizada', 'Round over'),
    'hostDealsSoon': ('El anfitrión reparte en breve...', 'The host deals shortly...'),
    'newRound': ('Nueva Ronda', 'New round'),
    'waitingPlayersCount': ('Esperando jugadores... ({count})', 'Waiting for players... ({count})'),

    # --- Rooms --------------------------------------------------------------------------------
    'wrongPassword': ('Contraseña incorrecta', 'Wrong password'),
    'roomFull': ('La sala está llena', 'The room is full'),
    'joinError': ('Error al unirse', 'Could not join'),
    'enterRoom': ('Entrar a {name}', 'Join {name}'),
    'noIpFound': ('No encontré una IP en lo que copiaste. Copia la IP que muestra la sala.',
                  'No IP address in what you copied. Copy the IP the room shows.'),
    'directIpTitle': ('Conexión Directa por IP', 'Join by IP'),
    'pasteIp': ('Pegar IP copiada', 'Paste copied IP'),
    'hostIpHint': ('IP del Host (ej: 192.168.1.50)', 'Host IP (e.g. 192.168.1.50)'),
    'portHint': ('Puerto (ej: 54321)', 'Port (e.g. 54321)'),
    'invalidIpPort': ('Por favor ingresa una IP y puerto válidos', 'Please enter a valid IP and port'),
    'cannotConnect': ('No se pudo conectar al Host. Verifica la IP y el Firewall.',
                      'Could not connect to the host. Check the IP and the firewall.'),
    'helpTitle': ('Ayuda de Conexión', 'Connection help'),
    'help1Title': ('1. Misma Red Wi-Fi', '1. Same Wi-Fi network'),
    'help1Body': ('Todos los dispositivos deben estar conectados al mismo Wi-Fi o punto de acceso (zona Wi-Fi móvil).',
                  'All devices must be on the same Wi-Fi or hotspot.'),
    'help2Title': ('2. Firewall en Windows / PC', '2. Windows / PC firewall'),
    'help2Body': ('Si la PC es el Host, asegúrate de permitir que la app acceda a la red a través del Firewall de Windows.',
                  'If the PC is the host, allow the app through the Windows Firewall.'),
    'help3Title': ('3. Conexión por IP Directa', '3. Join by IP'),
    'help3Body': ('Si el descubrimiento automático no encuentra la sala, el Host verá su IP en pantalla. Usa el botón "Por IP" para conectarte directamente.',
                  'If the room does not show up on its own, the host sees its IP on screen. Use "By IP" to connect directly.'),
    'roomsTitle': ('Salas disponibles', 'Available rooms'),
    'help': ('Ayuda', 'Help'),
    'notInList': ('¿No ves la sala en la lista?', "Can't see the room?"),
    'notInListSubtitle': ('Conéctate escribiendo la IP del Host', "Connect by typing the host's IP"),
    'byIp': ('Por IP', 'By IP'),
    'connectingRoom': ('Conectando a la sala...', 'Connecting to the room...'),
    'searchingRooms': ('Buscando salas automáticamente...\nAsegúrate de que ambos dispositivos estén en la misma red Wi-Fi',
                       'Looking for rooms...\nMake sure both devices are on the same Wi-Fi network'),
    'roomInGame': ('En juego', 'In game'),
    'roomWaiting': ('Esperando jugadores', 'Waiting for players'),
    'roomPlayers': ('{count}/{max} jugadores', '{count}/{max} players'),
    'roomWithPassword': (' • CON CONTRASEÑA', ' • PASSWORD'),

    # --- Widgets ------------------------------------------------------------------------------
    'roomIp': ('IP de la sala', 'Room IP'),
    'copiedAddress': ('Copiado: {address}. Pégalo en WhatsApp y los demás lo pegan en «Por IP».',
                      'Copied: {address}. Send it on WhatsApp and the others paste it in "By IP".'),
    'copy': ('Copiar', 'Copy'),
    'backToMenu': ('Volver al menú', 'Back to menu'),
    'options': ('Opciones', 'Options'),
    'leaveTable': ('Salir de la mesa', 'Leave the table'),
    'fastGame': ('Juego rápido', 'Fast game'),
    'fastGameSubtitle': ('Los bots piensan y el crupier reparte más rápido', 'Bots think and the dealer deals faster'),
    'showOdds': ('Mostrar mi probabilidad', 'Show my odds'),
    'showOddsSubtitle': ('Ayuda: tu % de ganar la mano en tu asiento', 'Help: your % to win the hand on your seat'),
    'keepAwake': ('Pantalla siempre encendida', 'Keep the screen on'),
    'keepAwakeSubtitle': ('No se apaga mientras estás en la mesa', 'It stays on while you are at the table'),
    'notifRoomOpen': ('Tu sala está abierta: la partida sigue aunque uses otras apps',
                      'Your room is open: the game keeps going while you use other apps'),
    'notifLanActive': ('Partida en red activa', 'Network game in progress'),
}


def placeholders(text):
    """Placeholder names in order of appearance (the generated method takes them in this order)."""
    seen = []
    for name in re.findall(r'(?<!\\)\{(\w+)\}', text):
        if name not in seen:
            seen.append(name)
    return seen


def main():
    out = os.path.join(os.path.dirname(__file__), '..', 'lib', 'l10n')
    os.makedirs(out, exist_ok=True)
    es = {'@@locale': 'es'}
    en = {'@@locale': 'en'}
    for key, (s, e) in S.items():
        s, e = s.replace('\\$', '$'), e.replace('\\$', '$')
        assert set(placeholders(s)) == set(placeholders(e)), key
        es[key] = s
        en[key] = e
        ph = placeholders(s)
        if ph:
            es['@' + key] = {'placeholders': {p: {'type': 'String'} for p in ph}}
    for name, data in (('app_es.arb', es), ('app_en.arb', en)):
        with open(os.path.join(out, name), 'w', encoding='utf-8', newline='\n') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')
    print(len(S), 'texts')


if __name__ == '__main__':
    main()
