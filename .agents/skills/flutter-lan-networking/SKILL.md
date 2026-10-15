---
name: flutter-lan-networking
description: Use when touching lib/services/p2p_service.dart or any host/client sync code (heartbeat, reconnect, state broadcast, seat ownership) in Poker Dice Dash.
---

# LAN protocol rules

Transport: TCP sockets, newline-delimited JSON, mDNS (`nsd`, `_poker._tcp`) for discovery. Host is authoritative.

## Must-haves
- Heartbeat in BOTH directions every 4 s (`PING`/`PONG`). A peer silent for >12 s is considered dead and its socket destroyed.
- Wrap every socket write in try/catch; a failed write = disconnect that peer, never crash.
- Every host message carries a monotonically increasing `seq`. Clients drop anything with `seq <= lastSeq`.
- Coalesce state broadcasts (max ~10/s, trailing edge). Never broadcast from inside `notifyListeners` directly.
- Never send other players' hidden cards. Send each client its own hand; others as face-down placeholders until showdown.
- Identity = `playerToken` (random id stored client-side in shared_preferences), NOT `ip:port`. Host maps token -> seat. A reconnect with a known token reclaims its seat and gets a full `STATE_UPDATE`.
- Client auto-reconnect: exponential backoff 1,2,4,8 s (max ~30 s) while the table screen is open.
- Disconnected seat -> status `away`. If it is their turn, auto fold/stand after 15 s. The host watchdog must guarantee the round always advances.
- Players have explicit `isBot` and `isRemote` flags. Only `isBot` seats are played by AI.
- Keep the screen awake during a match (`wakelock_plus`).
