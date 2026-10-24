<p align="right"><a href="README.md">Español</a> · <b>English</b></p>

<p align="center">
  <img src="fastlane/metadata/android/en-US/images/featureGraphic.png" alt="Poker Dice Dash" width="100%">
</p>

<p align="center">
  <b>A pocket casino:</b> poker with dice, Texas Hold'em and Blackjack.<br>
  Play against bots or with your friends on the same Wi-Fi network. No accounts, no ads, no internet.
</p>

<p align="center">
  <a href="https://github.com/abdiCobos/pokerDiceDash/releases/latest"><img alt="Download" src="https://img.shields.io/github/v/release/abdiCobos/pokerDiceDash?label=download&color=2e7d32"></a>
  <img alt="Android and Windows" src="https://img.shields.io/badge/platforms-Android%20%7C%20Windows-d4af37">
  <a href="LICENSE"><img alt="GPL-3.0 license" src="https://img.shields.io/badge/license-GPL--3.0-blue"></a>
</p>

> The game's interface is in Spanish.

## Screenshots

<table>
  <tr>
    <td width="50%"><img src="fastlane/metadata/android/es-MX/images/phoneScreenshots/2_dicedash.png" alt="Dice Dash"><p align="center">Dice Dash: poker with dice</p></td>
    <td width="50%"><img src="fastlane/metadata/android/es-MX/images/phoneScreenshots/3_texas.png" alt="Texas Hold'em"><p align="center">Texas Hold'em</p></td>
  </tr>
  <tr>
    <td width="50%"><img src="fastlane/metadata/android/es-MX/images/phoneScreenshots/4_blackjack.png" alt="Blackjack"><p align="center">Blackjack</p></td>
    <td width="50%"><img src="fastlane/metadata/android/es-MX/images/phoneScreenshots/5_blackjack_result.png" alt="Blackjack results"><p align="center">Round results</p></td>
  </tr>
</table>

<p align="center">
  <img src="fastlane/metadata/android/es-MX/images/phoneScreenshots/1_menu.png" alt="Menu" width="24%">
  &nbsp;
  <img src="fastlane/metadata/android/es-MX/images/phoneScreenshots/6_lan.png" alt="LAN play" width="24%">
</p>

## Download

| Platform | File |
|---|---|
| **Android** | `PokerDiceDash-<version>.apk` from [Releases](https://github.com/abdiCobos/pokerDiceDash/releases/latest) (F-Droid coming soon) |
| **Windows 10/11** | Installer `PokerDiceDash-<version>-setup.exe` or portable `PokerDiceDash-<version>-windows-x64.zip` from [Releases](https://github.com/abdiCobos/pokerDiceDash/releases/latest) |

> **Windows:** the game has no paid code-signing certificate, so SmartScreen may show "Windows protected your PC". Click **More info → Run anyway**. The first time you host a room, allow access on **private networks**.

## Game modes

### 🎲 Dice Dash: poker with dice
Before each move you roll two dice, and some combinations change the hand:

| Dice | Event |
|---|---|
| 1 + 1 | **Swap**: everyone's cards are shuffled and dealt again |
| 6 + 6 | **All-in**: the roller bets all their chips |
| 3 + 3 | **Spy**: you see one of an opponent's cards |
| 6 + 1 | **Extra card**: you get a third card and keep the best two |
| Sum 7 | **Lucky dice**: the pot grows by 30 % (once per hand) |

### ♠️ Texas Hold'em
Classic poker with blinds, side pots and the full rulebook.

### 🃏 Blackjack
Hit, stand, double down or split. Blackjack pays 3 to 2, the dealer stands on 17, 5-Card Charlie rule, and insurance when the dealer shows an Ace.

### 🤖 Bots with personality
Three levels (easy, normal and hard). They work out their odds, bluff, and each one plays differently.

## Local network multiplayer

- Host a room and join from other phones or Windows PCs on the **same Wi-Fi network**; you can also join by IP.
- Poker and Blackjack over the network, with an optional password.
- Automatic reconnection: if someone loses signal they get their seat back, and the table keeps going meanwhile.
- The host is in charge: each player only receives their own cards until the hand ends.
- No external servers: everything stays inside your network.

## Building from source

You need [Flutter](https://docs.flutter.dev/get-started/install) 3.38 or newer.

```bash
git clone https://github.com/abdiCobos/pokerDiceDash.git
cd pokerDiceDash
flutter pub get
flutter run
```

- **APK:** `flutter build apk --release`
- **Windows (ZIP and installer):** `powershell -ExecutionPolicy Bypass -File windows/packaging/build_release.ps1` (the installer needs [Inno Setup 6](https://jrsoftware.org/isinfo.php))
- **Tests:** `flutter test`

## License

Free software under **GPL-3.0-or-later**. See [LICENSE](LICENSE).
The title font, Alfa Slab One, is distributed under the SIL Open Font License (`assets/fonts/AlfaSlabOne-OFL.txt`).
