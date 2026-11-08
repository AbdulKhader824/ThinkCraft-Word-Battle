"""Copies the category pictures into the app at a phone-friendly size.

The originals are wide 3:2 PNGs (about 2528x1696) with their own thick
rounded frame drawn in. On a phone they appear at most about 300 pixels
wide, so they're resized to 900x600 and saved as WebP, which keeps them
sharp at a fraction of the size.

Picture makers can't draw see-through corners, so the white (or cream)
left outside the rounded frame is made transparent here: it's filled in
from each corner, only within a band around the picture's edge, so a pale
background inside the frame is never touched.

File names are matched without regard to capitals, and a few other
spellings are accepted (see FILES). The source folder is only read. A
category whose picture isn't in the folder keeps the one it has.

    py -3 tool/import_category_pictures.py "C:\\path\\to\\pictures"

Needs Pillow.
"""

import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "images",
                   "categories")
SIZE = (900, 600)
MAX_BYTES = 110 * 1024

# How far in from the edge the clean-up may reach, as a share of the
# shorter side. The frame's rounded corners fit well inside this.
CORNER_REACH = 0.14
# How close to white a corner pixel must be to count as background.
WHITE_TOLERANCE = 48

# Source file name (any capitals) -> category name used in the app.
FILES = {
    "Animal.png": "animal",
    "Animal_new.png": "animal",
    "Aniaml_new.png": "animal",
    "Bird.png": "bird",
    "Birds.png": "bird",
    "Birds_new.png": "bird",
    "Cartoon.png": "cartoon",
    "Celebrity.png": "celebrity",
    "Celerbartynew.png": "celebrity",
    "Celebrity_new.png": "celebrity",
    "Flower.png": "flower",
    "Food.png": "food",
    "Game.png": "game",
    "Movie.png": "movie",
    "Person name.png": "person",
    "Place.png": "place",
    "Sport.png": "sport",
    "Things.png": "thing",
    "Thing.png": "thing",
    "Vegetable.png": "vegetable",
    "Vehicle.png": "vehicle",
    "Brand.png": "brand",
}


def clear_corners(picture):
    """Returns the picture with the pale area outside its frame see-through."""
    rgb = picture.convert("RGB")
    width, height = rgb.size
    reach = int(min(width, height) * CORNER_REACH)

    # Flood-fill a marker colour from each corner across near-white pixels.
    marked = rgb.copy()
    marker = (255, 0, 255)
    for x, y in ((0, 0), (width - 1, 0), (0, height - 1),
                 (width - 1, height - 1)):
        if min(rgb.getpixel((x, y))) >= 255 - WHITE_TOLERANCE:
            ImageDraw.floodfill(marked, (x, y), marker,
                                thresh=WHITE_TOLERANCE)

    # Only keep what was filled in the band around the edge, which also
    # catches a white strip where a frame stops short of a side.
    filled = ImageChops.difference(marked, rgb).convert("L").point(
        lambda value: 255 if value else 0)
    band = Image.new("L", rgb.size, 255)
    ImageDraw.Draw(band).rectangle(
        (reach, reach, width - 1 - reach, height - 1 - reach), fill=0)
    cleared = ImageChops.multiply(filled, band)

    # A slight blur softens the cut, so the frame's edge stays smooth.
    alpha = ImageOps.invert(cleared.filter(ImageFilter.GaussianBlur(1.5)))
    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    return result


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)

    present = {name.lower(): name for name in os.listdir(source)}
    done = set()
    for wanted, category in FILES.items():
        file_name = present.get(wanted.lower())
        if file_name is None or category in done:
            continue
        done.add(category)
        with Image.open(os.path.join(source, file_name)) as image:
            # Cropped to 3:2 from the middle first, in case a picture isn't
            # quite that shape, then the corners are cleared.
            picture = ImageOps.fit(image.convert("RGB"), SIZE, Image.LANCZOS)
            picture = clear_corners(picture)
            out = os.path.join(OUT, f"{category}.webp")
            # Busy pictures get a little more compression, so each stays
            # small enough for the splash screen to load quickly.
            for quality in (88, 84, 80, 76, 72, 68):
                picture.save(out, "WEBP", quality=quality, method=6)
                if os.path.getsize(out) <= MAX_BYTES:
                    break
        print(f"{file_name} -> {category}.webp "
              f"{os.path.getsize(out) // 1024} KB")

    for category in sorted(set(FILES.values()) - done):
        print(f"No picture for {category}: it keeps its own")


if __name__ == "__main__":
    main()
