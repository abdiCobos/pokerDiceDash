---
name: lan-networking
description: LAN multiplayer rules for Poker Dice Dash (TCP + mDNS, host-authoritative state, heartbeat, reconnect, seat ownership, hidden cards). Use when touching lib/services/p2p_service.dart, any host/client sync code in the providers, the lobby/room list screens, or when adding multiplayer to a game mode (e.g. Blackjack).
---

# LAN protocol rules

Transport: TCP sockets, newline-delimited JSON, mDNS (`nsd`, `_poker._tcp`) for discovery.
The host is authoritative: clients send intents (`ACTION`), the host validates, mutates
state and broadcasts. A client never mutates shared game state locally.

## Must-haves
- Heartbeat both ways every 4 s (`PING`/`PONG`). A peer silent > 12 s is dead; destroy its socket.
- Wrap every socket write in try/catch; a failed write = disconnect that peer, never crash.
- Every host message carries a monotonically increasing `seq`; clients drop `seq <= lastSeq`.
- Coalesce state broadcasts (max ~10/s, trailing edge). Never broadcast from inside `notifyListeners`.
- Never send other players' hidden cards (poker hole cards, Blackjack dealer hole card):
  each client gets its own hand; others are face-down placeholders until showdown/reveal.
- Identity = `playerToken` (random id in shared_preferences), NOT `ip:port`. Host maps
  token -> seat. A reconnect with a known token reclaims its seat and gets a full `STATE_UPDATE`.
- Client auto-reconnect: backoff 1, 2, 4, 8 s (max ~30 s) while the table screen is open.
- Disconnected seat -> `isAway`. If it is their turn, auto fold / stand after 15 s.
  The host watchdog must guarantee the round always advances (see `game-turn-loop`).
- Players carry explicit `isBot` and `isRemote`/`isLocal` flags. Only `isBot` seats are played
  by AI; a remote human's turn waits for their ACTION (or the away timeout), never for AI.
- Keep the screen awake during a match (`wakelock_plus`).

## Messages
Lobby (GameProvider, every mode): `JOIN_REQUEST` (name, password, token) -> `ASSIGN_SEAT`
(playerId, **gameMode**) or `JOIN_REJECTED`; `LEAVE`; poker: `STATE_UPDATE`, `PLAYER_ACTION`,
`DICE_ROLL`, `NEXT_TURN`, `NEW_ROUND`. Blackjack: `BJ_HELLO` (client asks for a snapshot),
`BJ_STATE` (session, seq, state; dealer hole card masked until dealerTurn), `BJ_ACTION`
(BET value / HIT / STAND / DOUBLE / SPLIT). The host maps sockets to seats with
`GameProvider.seatForEndpoint`; never trust a seat id inside a message.

## Blackjack on top of the lobby
`GameProvider` keeps joins/passwords/tokens/reconnects for every mode and emits
`seatEvents` (joined/back/away/left). `BlackjackProvider.initMultiplayer(p2p:, lobby:)`
listens to them; poker `STATE_UPDATE` and the poker watchdog are off in Blackjack rooms.
Timers: remote turn 40 s, away seat stands after 2 s, betting closes 30 s after the first
bet, next round auto-deals 12 s after the result. Test: `test/blackjack_lan_test.dart`
(real sockets on 127.0.0.1; close a side fully to simulate a dead app, because a client
that only drops its socket auto-reconnects).

## Turn clock (LAN poker)
`GameProvider.turnTimeout` (60 s): the host watchdog plays for a connected human who does not
act (rolls the dice, checks when nothing is owed, folds otherwise). The host numbers turns
(`turnSerial` in `STATE_UPDATE`) so every device restarts its clock together; `TurnClock`
shows the last 15 s. Not in single player. Test: `test/turn_timeout_test.dart`.

## Host migration (the room survives the host)
- Host sends `ROSTER` on every seat change and at match start: `heirs` (connected humans in
  seat order, never bots or the host, each with `host` ip + `port` = the `listenPort` it sent
  in `JOIN_REQUEST`, default 47474), `seats`, `room`, `password`, `hostSeat`. Only the first
  two heirs also get `tokens` (token -> seat).
- Host leaving after the match started with >= 2 heirs sends `ROSTER` + `HOST_LEAVING`
  instead of `ROOM_CLOSED`. Fewer heirs (one player would be left alone) -> `ROOM_CLOSED`.
- Client lost the host: 2 tries on the old host, then each heir in order (6 quick tries).
  When the turn reaches its own seat it becomes host (`_becomeHost`): opens the server on
  `P2PService.preferredPort`, marks every other human away (15 s watchdog grace), calls the
  hand off (every bet refunded: only the old host knew the deck and hidden cards) and
  fires `onBecameHost` so `BlackjackProvider._takeOverTable` refunds bets and starts a new
  betting round. A seat without a known token is reclaimed by name.
- Tests: `test/host_migration_test.dart` (each simulated device has its own
  `preferredPort`, since all of them share 127.0.0.1).

## Phones + PCs
- `getLocalIpAddress` ranks adapters (`scoreAddress`): Wi-Fi/Ethernet private ranges first,
  Hyper-V/WSL/VirtualBox/VMware/Docker/VPN adapters ignored.
- Discovery asks nsd for IPv4 (`ipLookupType: v4`); `parseEndpoint` accepts IPv6.
- nsd has no Linux plugin: Linux hosts/joins by IP only.
- macOS/iOS need `network.client` + `network.server` entitlements and
  `NSBonjourServices: _poker._tcp` + `NSLocalNetworkUsageDescription` (already set).
- Windows: the Wi-Fi profile must be **Private** (or the firewall prompt allowed) or phones
  cannot reach a PC host. Never change that setting for the user; tell them how.

## Adding a mode to multiplayer
Reuse `P2PService` framing and the GameProvider host/client pattern; add the mode's state to
`STATE_UPDATE` with a `toJson`/`fromJson` pair and test it with the fake-socket tests in
`test/p2p_service_test.dart` (split/merged chunks, seq drop, token reclaim).
