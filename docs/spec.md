# ThinkCraft Word Battle: Original Briefs

These are the two original project briefs, saved as written. Where they
conflict, or leave a gap, the decisions in `CLAUDE.md` apply.

---

# Project: ThinkCraft Word Battle – Flutter Multiplayer Game

Act as a senior Flutter developer, multiplayer game architect and UI/UX designer.

Build a standalone mobile word game called **ThinkCraft Word Battle**.

Tagline: **Think fast. Find unique words.**

This application is ONLY for this multiplayer word game. Do not build an educational platform, course catalogue, learning dashboard or unrelated features.

## 1. Technology stack

- Flutter and Dart.
- Material 3.
- Riverpod for state management.
- GoRouter for navigation.
- ASP.NET Core + SignalR for future real-time multiplayer.
- Database for future room, player, answer and score persistence.

Initially, implement the frontend and a local multiplayer simulation. Do not implement the backend yet.

## 2. Branding and design

Brand: ThinkCraft Word Battle.

Design:
- Modern multiplayer party-game appearance.
- Navy blue and mint green brand colours.
- Colourful category cards.
- Smooth animations.
- Large touch-friendly buttons.
- Attractive player avatars.
- Responsive mobile-first UI.
- Professional and playful, not childish.

Create an original vector-style logo.

## 3. Main screens

1. Splash screen.
2. Home screen.
3. Create Room.
4. Join Room.
5. Game Lobby.
6. Letter Selection.
7. Answer Submission.
8. Anonymous Validation.
9. Results and Leaderboard.
10. Settings and How to Play.

Do not add user accounts or authentication in this initial version.

## 4. Game rules

The game is inspired by Name, Place, Animal, Thing and Scattergories.

Each round has six categories:

- Animal
- Place
- Person Name
- Movie
- Food
- Brand

Example letter: M

Animal: Monkey
Place: Malaysia
Person: Michael
Movie: Matrix
Food: Mango
Brand: Microsoft

All answers must start with the selected letter.

## 5. Multiplayer lobby

Support 2–8 players.

Features:
- Create room.
- Join using room code.
- Display players and avatars.
- Host indicator.
- Ready status.
- Host starts the round.
- One player selects the letter.
- All players receive the same letter.

For the first prototype, simulate multiple players locally. Clearly separate this from real online multiplayer.

## 6. Answer submission

- Initial timer: 90 seconds.
- Display selected letter prominently.
- Display all six categories.
- Provide large text input fields.
- Allow early submission.
- Lock answers after submission.
- Handle timer expiration.
- Handle empty answers.

## 7. Anonymous validation

After all players submit:

- Group identical answers together.
- Hide player identities during voting.
- Other players vote Valid or Invalid.
- A player cannot vote on their own answer.
- Prevent duplicate votes.
- Majority determines validity.
- Tie means disputed, with no answer points or validator bonus/penalty.

No automatic dictionary validation in the first version.

## 8. Scoring

Answer scoring:
- Unique valid answer: 10 points.
- Same valid answer by 2 players: 5 points each.
- Same valid answer by 3 players: 3.33 points each.
- Invalid answer: 0 points.
- Empty answer: 0 points.

Validation scoring:
- Correct majority voter: +1.
- Minority voter: -1.
- Tie: 0.

Keep answer points and validation points separate.

## 9. Results

Display:
- Player names.
- Answers.
- Validity results.
- Answer scores.
- Validation scores.
- Total scores.
- Leaderboard.
- Play Again.
- Return Home.

## 10. Architecture

Use a feature-based Flutter structure:

```text
lib/
  app/
  core/
    theme/
    widgets/
    constants/
  features/
    home/
    lobby/
    gameplay/
    validation/
    results/
    settings/
  models/
  services/
  main.dart
```

Keep game rules and scoring independent of UI widgets.

## 11. Development phases

Phase 1:
- Inspect Flutter/Dart/Android environment.
- Create Flutter project.
- Configure branding and navigation.
- Build Home, Create Room and Join Room screens.
- Build and test the initial application.

Phase 2:
- Lobby.
- Player simulation.
- Letter selection.
- Answer entry and timer.

Phase 3:
- Anonymous voting.
- Validation.
- Scoring.
- Leaderboard.

Phase 4:
- UI polish.
- Unit and widget tests.
- Android APK testing.

Phase 5 (future, do not implement now):
- ASP.NET Core backend.
- SignalR real-time multiplayer.
- Persistent rooms and game history.
- Global word validation.
- Google Play Store release.

## 12. Development instructions

- Work one phase at a time.
- Explain important Dart and Flutter concepts as we build.
- Do not implement unnecessary features.
- Do not add paid services.
- Do not publish or incur costs without permission.
- Run flutter analyze and flutter test.
- Fix errors before moving to the next phase.
- Do not overwrite existing files without inspecting them.

---

## Additional UI/UX Requirement – Kid-Friendly Game Design

The entire ThinkCraft Word Battle application must have a fun, colourful, kid-friendly visual identity.

Target audience: Children aged approximately 7–16, while remaining enjoyable for teenagers and adults.

### Visual direction
- Use a playful casual-game aesthetic.
- Use pastel and vibrant colours: mint green, sky blue, sunshine yellow, coral pink and lavender.
- Use rounded cards, friendly illustrations, soft shadows and smooth transitions.
- Use rounded typography such as Nunito or Fredoka.
- Create an original friendly mascot or character for ThinkCraft Word Battle.
- Use playful animal illustrations for categories such as Animal, Place, Food and Movie.
- Avoid overly corporate dashboards and boring form layouts.

### Screen-specific requirements
- Home screen: Big game title, friendly mascot, colourful Create Room and Join Room buttons.
- Lobby: Player avatars, colourful player cards and animated ready indicators.
- Letter selection: Large alphabet tiles with a fun selection animation.
- Gameplay: Colourful category cards, large input fields and a visually engaging countdown timer.
- Validation: Clear green Valid and red Invalid voting controls, with anonymous answers displayed in attractive cards.
- Results: Animated leaderboard, trophies, stars and confetti for achievements.

### Important design rules
- Make every screen mobile-first.
- Support different Android screen sizes.
- Ensure buttons and inputs are easy for children to tap.
- Maintain sufficient text contrast.
- Do not overcrowd screens with excessive animations.
- Use consistent reusable design components.
- Avoid copying any existing game's branding or artwork.

The result should feel like a polished, professionally designed mobile game rather than a basic educational form application.

Before implementation, establish a consistent design system with colours, typography, spacing, button styles, cards and reusable components.
