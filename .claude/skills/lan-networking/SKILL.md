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

## Adding a mode to multiplayer
Reuse `P2PService` framing and the GameProvider host/client pattern; add the mode's state to
`STATE_UPDATE` with a `toJson`/`fromJson` pair and test it with the fake-socket tests in
`test/p2p_service_test.dart` (split/merged chunks, seq drop, token reclaim).
