"""Copies the category pictures into the app at a phone-friendly size.

The originals are 1200x800 PNGs. On a phone they appear at most about 860
pixels wide, so they're resized to 900x600 and saved as WebP, which keeps
them sharp at a fraction of the size. The source folder is only read.

    py -3 tool/import_category_pictures.py "C:\\path\\to\\pictures"

Needs Pillow.
"""

import os
import sys

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "images",
                   "categories")
SIZE = (900, 600)

# Source file name -> category name used in the app.
FILES = {
    "Animals.png": "animal",
    "places.png": "place",
    "perosnname.png": "person",
    "movies.png": "movie",
    "foods.png": "food",
    "brand.png": "brand",
}


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)

    for file_name, category in FILES.items():
        path = os.path.join(source, file_name)
        if not os.path.isfile(path):
            sys.exit(f"Missing picture: {path}")
        with Image.open(path) as image:
            picture = image.convert("RGBA").resize(SIZE, Image.LANCZOS)
            out = os.path.join(OUT, f"{category}.webp")
            picture.save(out, "WEBP", quality=88, method=6)
        print(f"{file_name} -> {category}.webp "
              f"{os.path.getsize(out) // 1024} KB")


if __name__ == "__main__":
    main()
