# PlayPals

A Flutter party-game app, "Play together. Anywhere." It opens on a game hub,
a swipeable shelf of 15 game cards. Word Battle ("Think fast. Find unique
words."), Guess the Drawing, The Impostor, Most Likely To... and Truth or Dare are playable, and the rest show Coming soon
until they're built, one at a time. The audience is ages 7-16, and it should also
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

Online play (Phase 5): a small relay server in `server/`, ASP.NET Core on
.NET 10 (the current LTS) with plain WebSockets and no database. The game
still runs on the host's phone, as in nearby rooms; the relay only passes
messages between phones, grouped by room code, so the games' rules aren't
written twice. A server that owns the rules is only worth it if the app
goes public. The protocol and limits are in `server/README.md`; run
`dotnet test` in `server/`. The .NET 10 SDK on this PC is in
`%LOCALAPPDATA%\Microsoft\dotnet10` (the `dotnet` on PATH is .NET 8).

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
    drawing/          Guess the Drawing's screens and drawing canvas
    impostor/         The Impostor's screens
    most_likely/      Most Likely To...'s screens
    truth_or_dare/    Truth or Dare's screens (one phone)
  models/             plain immutable data classes
  services/
    rules/            pure Dart rules and scoring
    nearby/           Wi-Fi and hotspot rooms: host, guest, finding rooms
    drawing/          Guess the Drawing: engine, host, guest, messages
    impostor/         The Impostor: engine, host, guest, messages
    most_likely/      Most Likely To...: engine, host, guest, messages
    online/           online rooms through the relay (RelayServer, RelayGuestLink)
assets/
  fonts/  images/
server/               the online relay (ASP.NET Core), with its tests
```

Screens must depend on a `GameService` interface from Phase 2, so
multiplayer logic never goes inside widgets. `AppGameService` is the one the
app uses, and hands each room to the right place:

- Practice rooms, and nearby rooms this phone hosts, run in
  `LocalGameService`, which holds the rules, timers and bots. It handles
  several real players: the `...For(playerId)` methods act for guests, and
  `roomFor(playerId)` gives each player their own ballot and votes.
- A hosted nearby room also runs a `NearbyHost`, a small WebSocket server
  (port 47530) on the host's phone, and announces itself with UDP broadcasts
  (port 47531) while in the lobby.
- Joining a friend's room uses `NearbyClientService`, which talks to the
  host's phone and reconnects by itself if the Wi-Fi drops briefly.

Rooms travel between phones as JSON through `RoomCodec`, with timers sent as
time left, because phone clocks differ. The real network code is in
`nearby_io.dart`, picked by a conditional export so the web build still
compiles; tests use `MemoryServer`, `FakeRoomFinder` and `FakeRoomBeacon`
instead of sockets. Online play (Phase 5) swaps the Wi-Fi connection for
one through the relay, behind the same `NearbyServer` and `NearbyLink`:
`RelayServer` on the host's phone (it reconnects with the room's key if its
own connection drops, and completes `lost` if it can't) and
`relayConnector` for guests, both in `lib/services/online/relay.dart`. The
games' hosts and clients don't change. `OnlineRooms`
(`onlineRoomsProvider`) opens a room with a fresh code (another if it's
taken) and makes guests' connectors; each game's App service takes it as
`online`, and the engines accept the relay's `code`. Tests use `MemoryRelay`
(`test/memory_relay.dart`); `relay_live_test.dart` runs against a real
relay when `RELAY_URL` is set. A Dart WebSocket's `done` waits for this
side to close too, so `IoRelaySocket` treats the end of its messages as
the end of the connection.

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
colour and a navy outline, drawn as chunky 3D toy letters by `Title3D`: a
raised side in a darker shade, a glossy shine and a soft shadow. The
PlayPals name and each game's name on the hub use `Title3D` too. Cards are cream paper (`GameCard`, optionally with
a folded corner and a sticker). Number and letter choices use `CandyTile`,
which shows white numbers with a navy outline and a crown on the chosen one.
Sticker art is in `assets/images/stickers/`. Each category has an illustrated
3D picture, wide 3:2, with its own thick rounded frame drawn in, a plain
soft background and the subjects large and centred (`CategoryPicture`,
from `assets/images/categories/`, shown whole),
used on Create Room, the Lobby, answer cards, voting and How to Play. The
animal characters are used for player avatars. To replace the pictures, run
`py -3 tool/import_category_pictures.py "<folder of PNGs>"` with files named
like `Animal.png` and `Person name.png`, which resizes them to 900x600 WebP
and makes the white left outside the frame see-through (picture makers
draw a fake checkerboard when asked for transparency, so ask for plain
white corners instead); a category whose picture isn't in the folder keeps
its own.

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

Characters: Tilo is the mascot, a round mint letter tile with a face. The
animal characters are original SVG.

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
| No votes | An answer that went to the vote but got no votes (everyone skipped it or ran out of time) counts as correct, with full points (or the shared split), and no vote points for anyone. Results say "No votes, so it counts" |
| Wrong starting letter | Warn while typing, then mark invalid without a vote |
| Matching answers | Ignore capitals and extra spaces only |
| Timer runs out | Lock what was typed; blank fields count as empty |
| Skipped vote | Abstains and scores 0 |
| Letter picker | Host first, then rotating; used letters are greyed out. Only the picker sees the letter tiles; everyone else sees the picker's avatar, "<name> is choosing the letter..." and a mystery tile flicking through the letters still in play (a "?" with reduced motion) |
| Next Round | Next round in the same room, with running totals. Every round must be played, so results before the final round have no Return Home: everyone presses Next Round, and faces show who is ready or waiting. The round starts once all are ready, or after 60 seconds (`GameRules.nextRoundWait`) with only the ready players; the rest leave the room and go home. With fewer than 2 left, the room closes. A host who leaves hands over to the first player still there. Bots press it in 1-4 seconds |
| Return Home | Only after the final round (or Leave Game from the back button); clears the room and scores, and goes back to the hub |
| Room types | Create Room asks "Who are you playing with?": Friends nearby (same Wi-Fi or the host's hotspot), Friends online (anywhere, through the relay, joined by typing the code) or Practice (1 human and 1-7 bots). Practice is the default, so the button always starts a game |
| Online rooms | All 3 games. They work like nearby rooms (the host's phone runs the game, guests reconnect, the screen stays on, "Fill empty seats with bots" in Word Battle) but aren't announced and have no address: the lobby shows the code with Share code (the phone's share sheet, `shareTextProvider`), for everyone. Join Room asks "Where is the room?"; online hides the nearby list and the address. While an online room opens, "Connecting to the online server... can take up to a minute" shows, because the free server sleeps. If the host's connection is lost for good, the room closes and a snack bar says why (`roomNoticeProvider`). The relay address is `relayAddress` in `online_rooms.dart`, changed with `--dart-define=RELAY_URL=...` (`ws://10.0.2.2:8080` reaches a relay on this PC from the emulator) |
| Simulation | Practice is 1 human and 1-7 bots, with some deliberately wrong bot answers. Nearby rooms only have bots if the host turns on "Fill empty seats with bots" |
| Join Room | Lists rooms announced on the network, one tap to join; a typed code joins a room found nearby; "Can't see the room?" takes the host's address, which the host's lobby shows. Refusals (full, started, wrong code, not found) explain themselves in a dialog |
| Room size | Create Room asks "How many players?" (2-8) for practice and nearby rooms. In practice it's you plus bots. In a nearby room it's the room's size (`Room.capacity`): friends join until it's full, then are turned away ("That room is full."), and Join Room shows "2 of 4 players" or "Full". A "Fill empty seats with bots" switch (off by default, `Room.fillWithBots`) gives the seats nobody took to bots when the host starts; with it on the host can start alone. With it off, the game is just the friends who joined, and needs at least 2. The lobby shows "2 of 4 players · 2 bots join at start" |
| Nearby rooms | Only the lobby can be joined. A guest who drops out of the lobby leaves it; one who drops mid-game is marked away, the game doesn't wait for them, and they rejoin as the same player if they come back. A phone gets 6 seconds to answer each connection check (about 12 seconds to be marked away), so slow or battery-saving phones aren't dropped; an old connection noticed dying after the player is back doesn't mark them away. A guest's vote shows at once and is resent every 2 seconds, and after a reconnect, until the host has it. A guest picker gets 30 seconds, then a letter is picked for them. When the host leaves, the room closes for everyone. The screen stays on during a nearby room (wakelock_plus), because a sleeping host phone would pause the game |
| Host ready status | The host is always ready, and starts once everyone else is |
| Bot speed | Bots take 25-80 seconds, or 1-5 seconds once the player locks in |
| Blank answers | Locking in early with blanks asks for confirmation first |
| Answer screen | One category per step, with a progress row of category pictures (tap to jump), Next and Previous, and Lock In on the last step; the keyboard's Next key also moves on; after locking in, all answers show together |
| Hidden answers | `Round.answers` stays empty until results; voters only receive `BallotItem`s, which carry no authors |
| Voting words | Players see Correct and Incorrect (not Valid and Invalid), and results show "Votes" points; code names stay `valid` and `invalid` |
| Voting screen | One answer at a time, so each takes one choice; players can skip; each card ignores taps for 350ms to catch double taps |
| Lone voters | Validator points need at least 2 votes cast on an answer, in any game size |
| Answer check | Create Room asks "How are answers checked?" (`GameSettings.answerCheck`): Smart check (default: answers in the word list are correct at once, the rest are voted on), Players vote (every answer is voted on) or Auto only (no voting: listed answers are correct, the rest wrong). Answers the list settles earn no vote points, and results mark them "In the word list" or "Not in the word list". Only the host's phone checks. Until the list has loaded, or if it fails to load, answers are voted on. Rooms from an older app version, which don't say, are voted on |
| Word list | Built-in, offline and free: `assets/words/<category>.txt`, made by `tool/build_word_list.py` from Wikidata (public domain, so no credits screen), with films, brands and foods about alcohol, tobacco, gambling, weapons or adult content left out, and rude words blocked. Wikidata files some everyday things where the queries miss them (a dog is a kind of wolf), so hand-written core lists in `tool/core_words/` add the answers children type most. Big queries are split in 10 by item id, because the free service stops at 60 seconds; a part that still fails is skipped and filled in by running the script again. Famous people (actors, singers, sports stars, comedians, presenters and more, with a lower bar for Indian stars) are in Celebrity and also in Person Name by full name; any other full name counts in Person Name when each of its 2-3 parts is a known first or family name ("Priya Sharma"). The bots' word bank is always included. It loads in the background the first time a room opens. Matching (`WordCheck` in `lib/services/rules/word_check.dart`) ignores capitals, spaces, accents, punctuation, "the" at the start and plurals, treats & as "and", and matches British and American spellings (colour, centre). Typos don't match |
| Voting time | One timer for the whole ballot: 5 seconds per answer (`GameRules.voteTimePerCard`), sized for the biggest ballot, with no per-card timer. Answers not voted on in time are skipped. Voting ends early once every player still here has finished, and bots vote then. The waiting screen shows the faces of players still voting |
| Bot votes | Bots judge against the word bank and trust unknown words 75% of the time, at every bot level |
| Bot level | Create Room asks "How smart are the bots?" when the room has bots (practice, or nearby with "Fill empty seats with bots"): Easy, Medium (default) or Hard (`GameSettings.botLevel`, `BotStyle` in `bot_player.dart`). Easy uses only the everyday word bank and leaves 25% blank; Medium leaves 10% blank and gives a short word from the big word list a quarter of the time; Hard leaves 3% blank, is deliberately wrong half as often, and mostly gives rare word list answers (up to 22 letters, written in Title Case), which are often unique. Until the word list has loaded, every level uses the word bank. Only the level's own answers change, never how bots vote. The lobby shows "Bots: Medium". Rooms from an older app version are Medium |
| Stars | One for each unique valid answer worth the full 10 points |
| Tied leaderboard | Shared rank with the next rank skipped, so 1, 2, 2, 4 |
| Play Again as a guest | New Game after the final round is host-only; guests see it greyed out and can Return Home |
| Every letter used | The used letters reset after 26 rounds |
| Saved profile | Name and character are kept with shared_preferences; Create and Join fill in the name and save any change |
| Large text | System text size is supported up to 1.6x (`ThinkCraftApp.maxTextScale`); letter tiles ignore it |
| Confetti | Only when the local player is in first place, and never with reduced motion |
| Orientation | Portrait only, set in the Android manifest and in `main.dart` |
| Categories | 15: Animal, Bird, Place, Person Name, Celebrity, Movie, Cartoon, Food, Vegetable, Flower, Thing, Vehicle, Sport, Game and Brand, in that order everywhere. Create Room starts with four picked (`Category.startingPicks`: Animal, Bird, Place, Person Name); the standard game, used when a room doesn't say (such as a practice bot host's), is the classic six (`Category.defaults`: Animal, Place, Person Name, Movie, Food, Brand); the rest are picked on Create Room, two to a row. Names travel between phones, so they never change. With more than 7 in a room, the answer screen's step row scrolls and follows the current step. Related categories (Animal and Bird, Person Name and Celebrity, Movie and Cartoon, Food and Vegetable, Sport and Game, Brand and Vehicle) are never used for a bot's deliberately wrong answer. The bots' words for the newer nine are in `lib/services/word_bank_more.dart`; a few letters have none (a vegetable with X), and a bot leaves those blank |
| Room settings | The host picks 1, 3, 5 or 10 rounds (default 3), a 30, 60 or 90 second timer (default 90) and any of the categories (at least 1, default Animal, Bird, Place and Person Name) on Create Room; `GameSettings` validates them |
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

## Guess the Drawing

Its own code, beside Word Battle's rather than inside it:
`DrawingRoom` and `Sketch` in `lib/models/`, `DrawingRules` and
`rude_words.dart` in `lib/services/rules/`, `DrawingWords` (about 370
kid-safe words in Easy, Medium and Hard), and `lib/services/drawing/`:
`DrawingEngine` runs the game on the host's phone, `DrawingHost` and
`DrawingClient` carry it between phones over the shared `NearbyLink` and
`NearbyServer`, and `AppDrawingService` (`drawingServiceProvider`) is what
the screens use. Messages carry `'game': 'guess_the_drawing'`, so a Word
Battle phone and a drawing phone turn each other away. Room announcements
carry the game too, and each game's Join Room lists only its own rooms
(`JoinRoomScreen(game:)`). Strokes are points from 0 to 1000 on a square
canvas, so they land in the same place on every phone; the drawer's phone
shows them at once and sends them in batches every 40ms (`InkBatcher`).

| Situation | Decision |
| --- | --- |
| Rooms | Friends nearby or online. No practice and no bots: bots can't draw or see a drawing. 2-8 players (the room's size), and the host can start with 2 once everyone is ready |
| Room settings | Rounds 1, 2, 3 or 5 (default 2; each round everyone draws once), draw time 60, 80 or 100 seconds (default 80), words Easy (default), Medium, Hard or Mixed |
| Turn order | The host first, then in joining order. Players who are away when their turn comes are skipped |
| Choosing | The drawer alone sees 3 unused words and has 15 seconds; then one is picked for them. Others see "Sam is choosing a word..." |
| Drawing | 8 colours, 3 pen sizes, eraser, Undo and Clear. Guessers see the drawing live and the word as blanks, with one letter shown at half time and another with a quarter left (one hint for 3 letters, none for shorter) |
| Guesses | Match ignoring capitals, spaces and plurals. A wrong guess shows in everyone's feed; a right one shows "Riya got it!" without the word; one letter off (4+ letters) shows "so close!" only to that player. Rude guesses are never shown. 30 characters at most |
| Turn end | When every guesser here has it, or time runs out. Then 6 seconds showing the word and the turn's points |
| Points | Guessers by order: 10, 8, 6, 5, 4, then 3; the first also gets a star. The drawer gets 3 for each player who guessed, plus 2 if everyone did. A drawer who leaves or drops mid-turn ends the turn and nobody scores |
| Between rounds | Leaderboard with Next Round, like Word Battle: starts when everyone here is ready, or after 60 seconds with those who are; the rest leave. Fewer than 2 left closes the room |
| Final round | Winner banner, confetti for the winner, New Game (host only, same players and settings) and Return Home |
| Leaving | A guest who drops is marked away and can rejoin; one who leaves on purpose is gone. The host leaving closes the room |

## The Impostor

Built like Guess the Drawing, beside it: `ImpostorRoom` in `lib/models/`,
`ImpostorRules` in `lib/services/rules/`, `ImpostorWords` (about 300
kid-safe words in 7 topics) and `lib/services/impostor/`: `ImpostorEngine`
runs the game on the host's phone, `ImpostorHost` and `ImpostorClient`
carry it between phones, and `AppImpostorService`
(`impostorServiceProvider`) is what the screens use. Messages and room
announcements carry `'game': 'the_impostor'`. The host's phone keeps the
whole room; `roomFor(playerId)` hides the word from the Impostor, the
Impostor from everyone else until the reveal, and other players' votes
until the reveal.

| Situation | Decision |
| --- | --- |
| Rooms | Friends nearby or online. Online players need a voice call to say clues, which Create Room and the lobby say (typed clues may come later). No practice and no bots: bots can't talk. 3-8 players; the host can start with 3 once everyone is ready |
| Room settings | Rounds 3, 5 or 8 (default 5), 15, 20 or 30 seconds per clue (default 20), 1 or 2 clue turns each (default 2), and topics: Animals, Food, Places, Things, Jobs, Sports, Movies and cartoons (at least 1, default all) |
| Round | Secret word (10s) → clues → talk it over (30s, the host can tap Vote now) → secret vote (20s) → reveal (8s) → the Impostor's guess (15s) → results with Next Round |
| Secret word | Shown only while the card is held down, so nobody can peek. Normal players see the word and topic; the Impostor sees "You are the Impostor!" and the topic. A smaller card lets players check again during clues and talking |
| Clues | Said out loud. Everyone in a random order, never starting with the Impostor, once or twice round. The speaker taps Done, or the timer moves on. Away players are skipped |
| Vote | Tap a face, then Lock vote; no voting for yourself, and a vote can't be changed. Faces show who has voted, never for whom. Ends when everyone here has voted or time is up |
| Caught | Most votes on the Impostor catches them. A tie, or no votes, means not caught |
| Guess | Always, caught or not: the Impostor picks the word from 6 of the same topic. Running out of time counts as wrong. Everyone else sees the choices but can't tap them |
| Points | Voting for the Impostor: 3. Everyone but the Impostor gets 1 more if they're caught. The Impostor: 2 for each player who voted for someone else (players who didn't vote don't count), 3 if not caught, and 3 for the right word, caught or not |
| Picking the Impostor | Random, and anyone can be picked in any round, even twice running, but each time a player has been the Impostor their chance halves (`ImpostorRules.impostorChances`). Counts reset with a new game |
| Words | Never repeat in a room until a topic runs out. Kept free of anything `soundsRude` catches, even inside a word (so no "grapes" or "peacock") |
| Impostor leaves | If the Impostor leaves or drops mid-round, the round ends: "The Impostor left!", nobody scores, and results show Next Round |
| Between rounds | Like the other games: Next Round starts when everyone here is ready, or after 60 seconds with those who are; the rest leave. Fewer than 3 left closes the room, as does the host leaving |
| Final round | Winner banner, confetti for the winner, Best Detective (most right votes) and Master of Disguise (most points as the Impostor), New Game (host only) and Return Home |

## Most Likely To...

Built like The Impostor, beside it: `MostLikelyRoom` in `lib/models/`,
`MostLikelyRules` in `lib/services/rules/` and `MostLikelyQuestions`
(about 200 questions in 4 topics), and `lib/services/most_likely/`:
`MostLikelyEngine` runs the game on the host's phone, `MostLikelyHost` and
`MostLikelyClient` carry it between phones, and `AppMostLikelyService`
(`mostLikelyServiceProvider`) is what the screens use. Each question
finishes "Who is most likely to ...?". Messages and room announcements
carry `'game': 'most_likely_to'`. `roomFor(playerId)` gives each player
only their own vote, and only their own points until the leaderboard.

| Situation | Decision |
| --- | --- |
| Rooms | Friends nearby or online. No practice and no bots. 3-8 players; the host can start with 3 once everyone is ready |
| Room settings | 10, 15 or 20 questions (default 10), and topics: Silly, Future, Adventure, Everyday (at least 1, default all) |
| Question | Vote (20s): tap a face and lock it in; voting for yourself is allowed, and a vote can't be changed. Faces show who has voted, never for whom. Ends when everyone here has voted or time is up. Then the reveal (8s): each player's vote count and a crown on the most likely |
| Votes stay secret | Nobody ever sees who voted for whom, only the counts, so friends don't fall out. Each player sees only their own points until the leaderboard, because points would give votes away |
| Points | Mind-reader: 1 point for voting for the player who got the most votes. On a tie, voting for any of the tied players scores, and they all get the title. No votes, no points |
| Rounds | Every 5 questions a leaderboard with Next Round, like the other games: starts when everyone here is ready, or after 60 seconds with those who are; the rest leave. Fewer than 3 left closes the room, as does the host leaving |
| Final results | Winner banner (most points; ties share), confetti for the winner, each player's titles (the questions they were most likely for), New Game (host only) and Return Home |
| Questions | Funny or nice to be picked for, never mean: nothing about looks, bodies, being clever, money worries or crushes, and kept free of anything `soundsRude` catches. They never repeat in a room until a topic runs out |

## Truth or Dare

One phone passed around the group, so no rooms or networking:
`TodGame` in `lib/models/truth_or_dare_game.dart`, `TruthOrDareRules` in
`lib/services/rules/` (every move returns a new game), the cards in
`TruthOrDareCards` (`lib/services/truth_or_dare_cards.dart`) and
`truthOrDareProvider` (`lib/services/truth_or_dare_providers.dart`), which
holds the game; `truthOrDareRandomProvider` can be seeded.

| Situation | Decision |
| --- | --- |
| Players | 2-12 names typed on the players screen (the saved name is filled in); no duplicates, ignoring capitals. Each gets a character face, different where there are enough |
| Settings | 3, 5 or 10 rounds (default 5) and cards: Kids (default, silly and gentle), Teens (cheekier, still clean) or Mix |
| Turns | A spinner lights the faces and lands on the player (instant with reduced motion). Everyone still in has one turn a round, in a random order, never the same player twice in a row |
| Card | The player picks Truth or Dare and plays the card they get: no swapping, so the only way out is Skip. Cards don't repeat until a deck runs out |
| Done or Skip | Done: 1 point (a truth or a dare). Skip: a life lost. Everyone has 3 lives (hearts); after 3 skips a player is out, keeps their points and gets no more turns. Fewer than 2 players still in ends the game |
| End | After the last round, or End game (asks first). Winner by points (ties share), Bravest (most dares), Most Honest (most truths), confetti when someone scored, Play Again (same players and settings) and Return Home |
| Cards | 60 in each of Kids truths, Kids dares, Teens truths and Teens dares. Dares happen in the room: nothing dangerous, nothing to eat or drink, nothing that costs money, nothing posted online, nothing done to people outside the game. Truths never ask about crushes, bodies, looks or money |

## Phase status

- [x] Phase 1: foundation (approved)
- [x] Phase 2: lobby and answers (approved)
- [x] Phase 3: voting and scoring (approved)
- [x] Phase 4: polish and APK (approved)
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

To rebuild the word lists (for example after changing a query or the
blocklist), run `py -3 tool/build_word_list.py`. Downloads are kept in
`build/word_sources/`; add `--refresh` to download them again.

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
