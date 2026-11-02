"""Builds the Forever border styles' band-only textures from the full ones.

    python Tools/border-bands.py          write AeonUI/Media/Textures/ForeverBand.tga and ForeverMinimalBand.tga
    python Tools/border-bands.py --check  change nothing; fail if a band texture is missing or stale

Forever.tga and ForeverMinimal.tga are UI-HUD-ActionBar-Frame exports with their own dark middle. Drawn above the
minimap, that middle would darken the map, so the minimap draws a copy with everything inside the band cleared: every
black pixel reachable from the middle without crossing the band's colored pixels becomes transparent. The band and the
shadow outside it are unchanged.

Needs Pillow.
"""

import io
import pathlib
import sys
from collections import deque

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEXTURES = ROOT / "AeonUI" / "Media" / "Textures"
SOURCES = {"ForeverBand.tga": "Forever.tga", "ForeverMinimalBand.tga": "ForeverMinimal.tga"}


def band(path):
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    queue = deque([(width // 2, height // 2)])
    seen = set()

    while queue:
        x, y = queue.popleft()

        if (x, y) in seen or not (0 <= x < width and 0 <= y < height):
            continue

        seen.add((x, y))
        r, g, b, _ = pixels[x, y]

        if r or g or b:
            continue

        pixels[x, y] = (0, 0, 0, 0)
        queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

    buffer = io.BytesIO()
    image.save(buffer, format="TGA")

    return buffer.getvalue()


def main():
    check = "--check" in sys.argv[1:]
    problems = []

    for name, source in SOURCES.items():
        data = band(TEXTURES / source)
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

    print(f"bands: {len(SOURCES)} {'current' if check else 'written'}")


if __name__ == "__main__":
    main()
