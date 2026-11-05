# PlayPals

A Flutter party-game app, "Play together. Anywhere." It opens on a game hub,
a swipeable shelf of 15 game cards. Word Battle ("Think fast. Find unique
words.") is the first playable game, and the rest show Coming soon until
they're built, one at a time. The audience is ages 7-16, and it should also
be fun for adults. The full Word Battle briefs are in `docs/spec.md`.

The project folder, Dart package (`thinkcraft_word_battle`) and Android
application id keep their old names, so installs update in place.

## Working rules

- Work one phase at a time, and stop for approval at the end of each phase.
- Keep game rules free of Flutter imports: nothing in `lib/services/rules/`
  or `lib/models/` may import `package:flutter`.
- Run `flutter analyze` and `flutter test` before finishing, and fix every
  problem.
- Inspect existing files before overwriting them.
- Explain important Dart and Flutter concepts while building.
- Don't add unnecessary features, paid services, accounts or login.
- Don't push, publish or incur costs without permission.

## Stack

Flutter 3.47, Dart 3.13, Material 3, Riverpod 3 without code generation,
GoRouter 18 and flutter_svg. Fonts are bundled, not downloaded at runtime.

Phase 5 only, not before: ASP.NET Core on the current .NET LTS, SignalR, and
PostgreSQL. The server will own the timer, votes and scoring.

## Folder structure

```text
lib/
  main.dart
  app/                app.dart, router.dart
  core/
    theme/            colours, typography, spacing, theme
    widgets/          shared components such as GameButton and GameCard
    constants/        app text, asset paths and limits
  features/
    hub/              game hub and `GameCatalog`, the list of games
    home/  lobby/  gameplay/  validation/  results/  settings/
  models/             plain immutable data classes
  services/
    rules/            pure Dart rules and scoring
assets/
  fonts/  images/
```

Screens must depend on a `GameService` interface from Phase 2, with
`LocalGameService` as the simulated version. A SignalR version replaces it in
Phase 5, so multiplayer logic never goes inside widgets.

## Design system

Use the tokens in `lib/core/theme/` and shared widgets in `lib/core/widgets/`.
Never hard-code colours or spacing on a screen.

| Token | Value |
| --- | --- |
| Brand | Navy `#1B2A5B`, mint `#3DDC97` |
| Accents | Sky `#4FB8F0`, sunshine `#FFD23F`, coral `#FF8A80`, lavender `#B79CED`, peach `#FFB26B` |
| Voting | Valid `#15803D`, Invalid `#C62828`, with white text and icons |
| Text | Navy on every pastel colour |
| Fonts | Fredoka for headings, Nunito for body text |
| Spacing | 4, 8, 12, 16, 24, 32 |
| Corners | 16 for small items, 24 for cards, fully rounded for buttons |
| Tap targets | At least 56dp, with 64dp for main buttons |
| Motion | 150-400ms, reduced when the phone asks for it |

Playful style: screens sit on a sky background with clouds, a sun and stars
(`GameBackground`). Headers use `RainbowTitle`, with each letter a candy
colour and a navy outline. Cards are cream paper (`GameCard`, optionally with
a folded corner and a sticker). Number and letter choices use `CandyTile`,
which shows white numbers with a navy outline and a crown on the chosen one.
Sticker art is in `assets/images/stickers/`. Each category has an illustrated
3:2 picture (`CategoryPicture`, from `assets/images/categories/`), used on
Create Room, the Lobby, answer cards, voting and How to Play. The animal
characters are still used for player avatars. To replace the pictures, run
`py -3 tool/import_category_pictures.py "<folder of PNGs>"`, which resizes
them to 900x600 WebP.

Motion: screen parts arrive one by one through `Entrance` (give each an
`index`). Outlined letters use `OutlinedText`, a single stroke pass, never
stacks of shadows, which were slow. Wrap anything that animates forever in a
`RepaintBoundary`. The splash screen preloads the category pictures and SVGs.

Game hub: `GameCatalog.games` lists every game with its name, tagline,
devices and card picture (3:4, `assets/images/games/<id>.webp`). A game
becomes playable by giving it a `route`. The middle card wears a bobbing
crown and has two star sparkles (a glow was tried and dropped); side cards shrink,
fade and turn inward like a fan. All of it follows the swipe, and the crown
keeps still with reduced motion. To replace the pictures, run
`py -3 tool/import_game_pictures.py "<folder of PNGs>"`; files are named like
`01_word_battle.png`, and the number is dropped.

The bundled fonts are variable fonts, so a weight must be set through
`AppText` (which sets `fontVariations`). Setting only `fontWeight` won't
reliably change how heavy the text looks.

Logo: two smiling tile pals, coral and mint, high-fiving under a star
(`assets/images/logo.svg`). It is the app icon, the splash and the start of
the in-app splash, where "PlayPals" sits below it as a `RainbowTitle`.

Characters: Tilo is the mascot, a round mint letter tile with a face.
Categories use Fox (Animal), Penguin (Place), Owl (Person Name), Cat (Movie),
Bear (Food) and Parrot (Brand). All artwork is original SVG.

## Game decisions

These settle conflicts and gaps in the briefs.

| Situation | Decision |
| --- | --- |
| Style conflict | The kid-friendly brief wins; navy keeps it from looking too young |
| Shared valid answer | Each player gets 10 divided by the number sharing it |
| Score storage | Whole hundredths, so 3.33 is stored as 333 |
| Everyone gave the same answer | Automatically valid and shared, with no validator points |
| 2-player game | The only voter decides, with no +1 or -1 |
| Tied vote | Disputed: 0 answer points and 0 validator points |
| Wrong starting letter | Warn while typing, then mark invalid without a vote |
| Matching answers | Ignore capitals and extra spaces only |
| Timer runs out | Lock what was typed; blank fields count as empty |
| Skipped vote | Abstains and scores 0 |
| Letter picker | Host first, then rotating; used letters are greyed out. Only the picker sees the letter tiles; everyone else sees the picker's avatar, "<name> is choosing the letter..." and a mystery tile flicking through the letters still in play (a "?" with reduced motion) |
| Next Round | Next round in the same room, with running totals. Every round must be played, so results before the final round have no Return Home: everyone presses Next Round, and faces show who is ready or waiting. The round starts once all are ready, or after 60 seconds (`GameRules.nextRoundWait`) with only the ready players; the rest leave the room and go home. With fewer than 2 left, the room closes. A host who leaves hands over to the first player still there. Bots press it in 1-4 seconds |
| Return Home | Only after the final round (or Leave Game from the back button); clears the room and scores, and goes back to the hub |
| Simulation | 1 human and 1-7 bots, with some deliberately wrong bot answers |
| Join Room | Any valid code joins a room labelled Practice mode, with a bot as host |
| Host ready status | The host is always ready, and starts once everyone else is |
| Bot speed | Bots take 25-80 seconds, or 1-5 seconds once the player locks in |
| Blank answers | Locking in early with blanks asks for confirmation first |
| Answer screen | One category per step, with a progress row of category pictures (tap to jump), Next and Previous, and Lock In on the last step; the keyboard's Next key also moves on; after locking in, all answers show together |
| Hidden answers | `Round.answers` stays empty until results; voters only receive `BallotItem`s, which carry no authors |
| Voting words | Players see Correct and Incorrect (not Valid and Invalid), and results show "Votes" points; code names stay `valid` and `invalid` |
| Voting screen | One answer at a time, so each takes one choice; players can skip; each card ignores taps for 350ms to catch double taps |
| Lone voters | Validator points need at least 2 votes cast on an answer, in any game size |
| Voting time | No timer, because the spec sets none; bots vote once the player finishes |
| Bot votes | Bots judge against the word bank and trust unknown words 75% of the time |
| Stars | One for each unique valid answer worth the full 10 points |
| Tied leaderboard | Shared rank with the next rank skipped, so 1, 2, 2, 4 |
| Play Again as a guest | Allowed in practice mode; Phase 5 should make it host-only |
| Every letter used | The used letters reset after 26 rounds |
| Saved profile | Name and character are kept with shared_preferences; Create and Join fill in the name and save any change |
| Large text | System text size is supported up to 1.6x (`ThinkCraftApp.maxTextScale`); letter tiles ignore it |
| Confetti | Only when the local player is in first place, and never with reduced motion |
| Orientation | Portrait only, set in the Android manifest and in `main.dart` |
| Room settings | The host picks 1, 3, 5 or 10 rounds (default 3), a 30, 60 or 90 second timer (default 90) and any of the six categories (at least 1, default all) on Create Room; `GameSettings` validates them |
| Sound effects | Original tones made by `tool/generate_sounds.py`; on by default with a switch in Settings; they mix with other audio instead of pausing it; votes and Lock In play their own sound instead of the button pop; a card flick plays as each game slides into the middle of the hub |
| Shorter timers | Bot answer times scale with the timer, and the ring turns yellow at a third and red at a ninth of the time left |
| Joined rooms | Guests play by the host's settings; the practice bot host uses the standard 3 rounds and all categories |
| Between rounds | Results shows Next Round, or New Game after the final round; New Game keeps players and settings but clears scores and letters |
| Final round | The banner names the game winner, and confetti only plays for winning the whole game |
| Player name | 2-12 letters, numbers or spaces |
| Room code | 6 characters from A-Z and 2-9, without I, O, 0 or 1 |
| App name | PlayPals; Word Battle is one game inside it |
| Rooms | One game per room. Play on a card opens that game's own start screen with Create and Join |
| One-phone games | Truth or Dare, Dumb Charades, Complete the Lyrics and Who Am I? share one phone and skip rooms |
| Trademarked games | Our UNO-style game is Colour Rush (a placeholder name) and Heads Up is Who Am I?; never use UNO or Heads Up names or looks |

## Phase status

- [x] Phase 1: foundation (approved)
- [x] Phase 2: lobby and answers (approved)
- [x] Phase 3: voting and scoring (approved)
- [x] Phase 4: polish and APK (awaiting approval)
- Phase 5 needs separate approval.

## Commands

```powershell
flutter analyze
flutter test
flutter run -d chrome
flutter emulators --launch Medium_Phone_API_35
flutter run
flutter build apk --debug
flutter build apk --release
```

Tests load the real Fredoka and Nunito fonts in `test/flutter_test_config.dart`,
so layout tests measure text as a phone draws it. Keep that file.

To change a sound effect, edit `tool/generate_sounds.py`, then run
`py -3 tool/generate_sounds.py`. Screens play sounds through `playSound`
in `lib/services/sound_service.dart`, which respects the Settings switch.

To change the app icon or splash, edit `assets/images/logo.svg`, then run:

```powershell
flutter test tool/render_brand_assets_test.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

The release APK is signed with the debug key, which is fine for installing
on test phones but not for the Play Store. Phase 5 needs a real upload key.

`Medium_Phone_API_35` is the default emulator, because the Pixel 9 one uses
about 7.5 GB of RAM. Start it on the graphics card with a cold boot.
Software graphics (`-gpu swiftshader_indirect`) also works, but every
animation lags. A black screen comes from loading a snapshot saved in a
different graphics mode, which `-no-snapshot-load` avoids:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" emu kill
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd Medium_Phone_API_35 -gpu host -no-snapshot-load -no-boot-anim
```

If adb then lists the emulator as `unauthorized`, run `adb kill-server`.
