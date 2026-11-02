"""Builds AeonUI's logo from Alex's artwork.

    python Tools/logo.py          write AeonUI/Media/Textures/Logo.png
    python Tools/logo.py --check  change nothing; fail if the logo is missing or stale

The source (Tools/Art/Logo.png, supplied by Alex on 2026-11-02) is an 898x886 image on a transparent background. It is
cropped to its drawing, centered on a square with a margin and scaled to 64 pixels, the same size as the clock's icons.
The margin is LibDBIcon's: its button trims 5% from each side of an icon, which would cut the logo's points.

Needs Pillow.
"""

import io
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Tools" / "Art" / "Logo.png"
TARGET = ROOT / "AeonUI" / "Media" / "Textures" / "Logo.png"
SIZE = 64
MARGIN = 0.05


def logo():
    image = Image.open(SOURCE).convert("RGBA")
    image = image.crop(image.getchannel("A").getbbox())
    side = round(max(image.size) / (1 - 2 * MARGIN))
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(image, ((side - image.width) // 2, (side - image.height) // 2))
    square = square.resize((SIZE, SIZE), Image.LANCZOS)

    buffer = io.BytesIO()
    square.save(buffer, format="TGA")

    return buffer.getvalue()


def main():
    data = logo()

    if "--check" in sys.argv[1:]:
        if not TARGET.exists() or TARGET.read_bytes() != data:
            print(f"stale or missing: {TARGET.name}")
            sys.exit(1)

        print("logo: current")
    else:
        TARGET.write_bytes(data)
        print("logo: written")


if __name__ == "__main__":
    main()
