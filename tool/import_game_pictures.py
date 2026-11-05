"""Copies the game card pictures into the app at a phone-friendly size.

The originals are 900x1200 PNGs named like "01_word_battle.png". The number
is dropped, so that one becomes assets/images/games/word_battle.webp. On a
phone a card is at most about 600 pixels wide, so they're resized to 600x800
WebP. The source folder is only read.

    py -3 tool/import_game_pictures.py "C:\\path\\to\\game_cards"

Needs Pillow.
"""

import os
import re
import sys

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "images",
                   "games")
SIZE = (600, 800)
NAME = re.compile(r"^\d+_([a-z0-9_]+)\.png$")


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)

    found = 0
    for file_name in sorted(os.listdir(source)):
        match = NAME.match(file_name)
        if not match:
            continue
        game = match.group(1)
        with Image.open(os.path.join(source, file_name)) as image:
            picture = image.convert("RGB").resize(SIZE, Image.LANCZOS)
            out = os.path.join(OUT, f"{game}.webp")
            picture.save(out, "WEBP", quality=86, method=6)
        found += 1
        print(f"{file_name} -> {game}.webp "
              f"{os.path.getsize(out) // 1024} KB")

    if found == 0:
        sys.exit(f"No pictures named like 01_word_battle.png in {source}")


if __name__ == "__main__":
    main()
