"""Builds the Forever Minimal art the unit frames and cast bar draw, from the Forever Minimal art.

    python Tools/forever-border.py          write AeonUI/Media/Textures/ForeverMinimalShaded.tga
    python Tools/forever-border.py --check  change nothing; fail if it is missing or stale

The result is an uncompressed 32-bit TGA in the art's own 110-texel layout, for the nine pieces `AUI.Border` places on
whole pixels. The band is white for tinting; 110,89,71 restores its own color. Black stays black. The inner shadow fades
to nothing 4 texels inside the band, and the art's dark middle is not kept.

Needs Pillow.
"""

import io
import pathlib
import sys
from collections import deque

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEXTURES = ROOT / "AeonUI" / "Media" / "Textures"
SHADED = TEXTURES / "ForeverMinimalShaded.tga"

SIZE = 110
NATIVE = (110, 89, 71)
FADE = 4
NEIGHBORS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def fade_depths(full, band):
    """Returns how far each inner shadow texel lies inside the band, 1 for a texel touching it."""
    depths = {}
    queue = deque()

    def is_shadow(x, y):
        return band[x, y][3] == 0 and full[x, y][3] > 0

    for y in range(SIZE):
        for x in range(SIZE):
            if not is_shadow(x, y):
                continue

            for dx, dy in NEIGHBORS:
                near = (x + dx, y + dy)

                if 0 <= near[0] < SIZE and 0 <= near[1] < SIZE and any(band[near][:3]):
                    depths[x, y] = 1
                    queue.append((x, y))
                    break

    while queue:
        x, y = queue.popleft()

        for dx, dy in NEIGHBORS:
            near = (x + dx, y + dy)

            if 0 <= near[0] < SIZE and 0 <= near[1] < SIZE and near not in depths and is_shadow(*near):
                depths[near] = depths[x, y] + 1
                queue.append(near)

    return depths


def tintable_art():
    """Returns the art as a texel lookup, with the band normalized to white and the inner shadow faded."""
    full = Image.open(TEXTURES / "ForeverMinimal.tga").convert("RGBA").load()
    band = Image.open(TEXTURES / "ForeverMinimalBand.tga").convert("RGBA").load()
    depths = fade_depths(full, band)
    art = {}

    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = band[x, y]
            color = tuple(min(255, value * 255 // native) for value, native in zip((r, g, b), NATIVE))

            if (x, y) in depths:
                a = max(0, full[x, y][3] * (FADE - depths[x, y] + 1) // FADE)

            art[x, y] = (*color, a)

    return art


def build_shaded():
    art = tintable_art()
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pixels = image.load()

    for y in range(SIZE):
        for x in range(SIZE):
            pixels[x, y] = art[x, y]

    buffer = io.BytesIO()
    image.save(buffer, format="TGA")

    return buffer.getvalue()


def main():
    data = build_shaded()

    if "--check" in sys.argv[1:]:
        if not SHADED.exists() or SHADED.read_bytes() != data:
            print(f"stale or missing: {SHADED.name}")
            sys.exit(1)

        print("forever border: current")
    else:
        SHADED.write_bytes(data)
        print("forever border: written")


if __name__ == "__main__":
    main()
