"""Copies the game card pictures into the app at a phone-friendly size.

The originals are 3:4 PNGs, named either like "01_word_battle.png" (the
number is dropped) or by the game's title, like "Word Battle.png" (see
TITLES). Either way that one becomes assets/images/games/word_battle.webp.
On a phone a card is at most about 600 pixels wide, so they're resized to
600x800 WebP, cropped from the middle if the shape is a little off. A game
whose picture isn't in the folder keeps its own. The source folder is only
read.

    py -3 tool/import_game_pictures.py "C:\\path\\to\\game_cards"

Needs Pillow.
"""

import os
import re
import sys

from PIL import Image, ImageOps

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "images",
                   "games")
SIZE = (600, 800)
NAME = re.compile(r"^\d+_([a-z0-9_]+)\.png$")

# Pictures named by the game's title, as the picture maker saves them.
TITLES = {
    "Bluff It (fake answers).png": "bluff_it",
    "Card game (our own, not UNO).png": "card_game",
    "Complete the Lyrics.png": "complete_the_lyrics",
    "Dumb Charades (Malayalam movies).png": "dumb_charades",
    "Guess the Drawing.png": "guess_the_drawing",
    "Ludo.png": "ludo",
    "Most Likely To....png": "most_likely_to",
    "Pass the Bomb.png": "pass_the_bomb",
    "Tap Tug of War.png": "tap_tug_of_war",
    "Tap Tug-of-War.png": "tap_tug_of_war",
    "The Impostor.png": "the_impostor",
    "Truth or Dare.png": "truth_or_dare",
    "Turtle Elephant Goat.png": "turtle_elephant_goat",
    "Two Truths and One Lie.png": "two_truths_one_lie",
    "Who Am I (Heads Up Style).png": "who_am_i",
    "Word Battle.png": "word_battle",
}


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)

    found = 0
    for file_name in sorted(os.listdir(source)):
        match = NAME.match(file_name)
        game = match.group(1) if match else TITLES.get(file_name)
        if game is None:
            continue
        with Image.open(os.path.join(source, file_name)) as image:
            picture = ImageOps.fit(image.convert("RGB"), SIZE, Image.LANCZOS)
            out = os.path.join(OUT, f"{game}.webp")
            picture.save(out, "WEBP", quality=86, method=6)
        found += 1
        print(f"{file_name} -> {game}.webp "
              f"{os.path.getsize(out) // 1024} KB")

    if found == 0:
        sys.exit(f"No pictures named like 01_word_battle.png or Word Battle.png in {source}")


if __name__ == "__main__":
    main()
