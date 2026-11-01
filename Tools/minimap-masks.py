"""Builds the minimap's crop masks: white textures whose opaque band is the visible part of the square map.

    python Tools/minimap-masks.py          write every mask into Media/Textures/Masks
    python Tools/minimap-masks.py --check  change nothing; fail if a mask is missing, stale or extra

The map stays square (its terrain and the player arrow assume it), and the engine draws terrain past its parent's
clipping, so the crop comes from the mask. A wide map uses Wide-<rows>.tga: 4 x 256 texels, opaque across the middle
<rows> rows. A tall map uses Tall-<rows>.tga: 256 x 4, opaque down the middle <rows> columns. <rows> runs from 172 to
252 in steps of 4 (Minimap/Map.lua's MASK_STEP and MASK_MIN_ROWS: the map is kept within 3:2); a square map uses
Blizzard's white square instead.

Needs Pillow.
"""

import io
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
TARGET = ROOT / "Media" / "Textures" / "Masks"
SIZE = 256
THIN = 4
STEP = 4
MIN_ROWS = 172


def build(rows, wide):
    width, height = (THIN, SIZE) if wide else (SIZE, THIN)
    image = Image.new("RGBA", (width, height), (255, 255, 255, 0))
    start = (SIZE - rows) // 2
    pixels = image.load()

    for along in range(start, start + rows):
        for across in range(THIN):
            if wide:
                pixels[across, along] = (255, 255, 255, 255)
            else:
                pixels[along, across] = (255, 255, 255, 255)

    buffer = io.BytesIO()
    image.save(buffer, format="TGA")

    return buffer.getvalue()


def masks():
    for rows in range(MIN_ROWS, SIZE, STEP):
        yield f"Wide-{rows}.tga", build(rows, True)
        yield f"Tall-{rows}.tga", build(rows, False)


def main():
    check = "--check" in sys.argv[1:]
    expected = dict(masks())
    problems = []

    if not check:
        TARGET.mkdir(parents=True, exist_ok=True)

    for name, data in expected.items():
        path = TARGET / name

        if check:
            if not path.exists() or path.read_bytes() != data:
                problems.append(f"stale or missing: {name}")
        else:
            path.write_bytes(data)

    if TARGET.exists():
        for path in TARGET.glob("*.tga"):
            if path.name not in expected:
                if check:
                    problems.append(f"extra: {path.name}")
                else:
                    path.unlink()

    if problems:
        for problem in problems:
            print(problem)
        sys.exit(1)

    print(f"masks: {len(expected)} {'current' if check else 'written'}")


if __name__ == "__main__":
    main()
