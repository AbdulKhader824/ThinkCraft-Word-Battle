# ThinkCraft Word Battle

A standalone Flutter multiplayer word game. Tagline: "Think fast. Find unique
words." The audience is ages 7-16, and it should also be fun for adults.
The full briefs are in `docs/spec.md`.

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

The bundled fonts are variable fonts, so a weight must be set through
`AppText` (which sets `fontVariations`). Setting only `fontWeight` won't
reliably change how heavy the text looks.

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
| Letter picker | Host first, then rotating; used letters are greyed out |
| Play Again | Next round in the same room, with running totals |
| Return Home | Clears the room and scores |
| Simulation | 1 human and 1-7 bots, with some deliberately wrong bot answers |
| Join Room | Any valid code joins a room labelled Practice mode, with a bot as host |
| Host ready status | The host is always ready, and starts once everyone else is |
| Bot speed | Bots take 25-80 seconds, or 1-5 seconds once the player locks in |
| Blank answers | Locking in early with blanks asks for confirmation first |
| Hidden answers | `Round.answers` stays empty until results; voters only receive `BallotItem`s, which carry no authors |
| Voting screen | One answer at a time, so each takes one choice; players can skip; each card ignores taps for 350ms to catch double taps |
| Lone voters | Validator points need at least 2 votes cast on an answer, in any game size |
| Voting time | No timer, because the spec sets none; bots vote once the player finishes |
| Bot votes | Bots judge against the word bank and trust unknown words 75% of the time |
| Stars | One for each unique valid answer worth the full 10 points |
| Tied leaderboard | Shared rank with the next rank skipped, so 1, 2, 2, 4 |
| Play Again as a guest | Allowed in practice mode; Phase 5 should make it host-only |
| Every letter used | The used letters reset after 26 rounds |
| Player name | 2-12 letters, numbers or spaces |
| Room code | 6 characters from A-Z and 2-9, without I, O, 0 or 1 |

## Phase status

- [x] Phase 1: foundation (approved)
- [x] Phase 2: lobby and answers (approved)
- [x] Phase 3: voting and scoring (awaiting approval)
- [ ] Phase 4: polish and APK
- Phase 5 needs separate approval.

## Commands

```powershell
flutter analyze
flutter test
flutter run -d chrome
flutter emulators --launch Medium_Phone_API_35
flutter run
flutter build apk --debug
```

`Medium_Phone_API_35` is the default emulator, because the Pixel 9 one uses
about 7.5 GB of RAM.
