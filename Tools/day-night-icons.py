"""Builds the clock's day and night icons from Alex's artwork.

    python Tools/day-night-icons.py          write AeonUI/Media/Textures/Sun.tga and Moon.tga
    python Tools/day-night-icons.py --check  change nothing; fail if an icon is missing or stale

The sources (Tools/Art/Sun.webp and Moon.webp, supplied by Alex on 2026-10-20) are 1254-pixel images on a transparent
background. Each is cropped to its drawing, centered on a square and scaled to 64 pixels, which keeps it sharp at the
largest Icon Size on high-resolution screens. TGA, because WoW does not load WebP.

Needs Pillow.
"""

import io
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "Tools" / "Art"
TEXTURES = ROOT / "AeonUI" / "Media" / "Textures"
SOURCES = {"Sun.tga": "Sun.webp", "Moon.tga": "Moon.webp"}
SIZE = 64


def icon(path):
    image = Image.open(path).convert("RGBA")
    image = image.crop(image.getchannel("A").getbbox())
    side = max(image.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(image, ((side - image.width) // 2, (side - image.height) // 2))
    square = square.resize((SIZE, SIZE), Image.LANCZOS)

    buffer = io.BytesIO()
    square.save(buffer, format="TGA")

    return buffer.getvalue()


def main():
    check = "--check" in sys.argv[1:]
    problems = []

    for name, source in SOURCES.items():
        data = icon(ART / source)
        path = TEXTURES / name

        if check:
            if not path.exists() or path.read_bytes() != data:
                problems.append(f"stale or missing: {name}")
        else:
            path.write_bytes(data)

    if problems:
        for problem in problems:
            print(problem)
        sys.exit(1)

    print(f"icons: {len(SOURCES)} {'current' if check else 'written'}")


if __name__ == "__main__":
    main()
