"""Builds the Forever Minimal LibSharedMedia border, and the shaded art, from the Forever Minimal art.

    python Tools/forever-border.py          write AeonUI/Media/Borders/ForeverMinimal.tga and
                                            AeonUI/Media/Textures/ForeverMinimalShaded.tga
    python Tools/forever-border.py --check  change nothing; fail if either is missing or stale

The result is a 256x32 backdrop edge file, an uncompressed 32-bit TGA: eight 32-texel cells
holding the left, right, top and bottom edges, then the top-left, top-right, bottom-left and bottom-right corners. The
backdrop never draws the outer 2 texels of a cell, which repeat the nearest drawn texel. One empty texel precedes the
art, so at an edgeSize of 14 the art keeps its scale of 2 texels per UI unit.

The band is white for tinting; 110,89,71 restores its own color. Black stays black. Edges come from the middle of each
side, every row of an edge cell being identical so that it tiles, which drops the color variation along the art's left
and right sides. The inner shadow fades to nothing 4 texels inside the band, and the art's dark middle is not kept.

The shaded art is the same band and shadow in the art's own 110-texel layout, for the nine pieces `AUI.Border` places
on whole pixels.

Needs Pillow.
"""

import io
import pathlib
import sys
from collections import deque

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEXTURES = ROOT / "AeonUI" / "Media" / "Textures"
OUTPUT = ROOT / "AeonUI" / "Media" / "Borders" / "ForeverMinimal.tga"
SHADED = TEXTURES / "ForeverMinimalShaded.tga"

SIZE = 110
MIDDLE = SIZE // 2
NATIVE = (110, 89, 71)
FADE = 4
CELL = 32
CROP = 2
PADDING = 1
CELLS = {"left": 0, "right": 1, "top": 2, "bottom": 3}
CORNERS = (
    (4, False, False),
    (5, True, False),
    (6, False, True),
    (7, True, True),
)
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


def from_outer_edge(position):
    """Returns the art texel for a cell position counted from the cell's outer edge, or a negative one for padding."""
    return min(CELL - CROP - 1, max(CROP, position)) - CROP - PADDING


def build():
    art = tintable_art()
    image = Image.new("RGBA", (CELL * 8, CELL), (0, 0, 0, 0))
    pixels = image.load()

    def texel(x, y):
        return art[x, y] if x >= 0 and y >= 0 else (0, 0, 0, 0)

    # Top and bottom are stored rotated: their cross-section runs along U, as the backdrop's coordinates read them.
    edges = {
        "left": lambda depth: texel(depth, MIDDLE),
        "right": lambda depth: texel(depth, MIDDLE) if depth < 0 else art[SIZE - 1 - depth, MIDDLE],
        "top": lambda depth: texel(MIDDLE, depth),
        "bottom": lambda depth: texel(MIDDLE, depth) if depth < 0 else art[MIDDLE, SIZE - 1 - depth],
    }

    for side, cell in CELLS.items():
        inner_first = side in ("right", "bottom")

        for position in range(CELL):
            color = edges[side](from_outer_edge(CELL - 1 - position if inner_first else position))

            for y in range(CELL):
                pixels[cell * CELL + position, y] = color

    for cell, mirror_x, mirror_y in CORNERS:
        for y in range(CELL):
            for x in range(CELL):
                art_x = from_outer_edge(CELL - 1 - x if mirror_x else x)
                art_y = from_outer_edge(CELL - 1 - y if mirror_y else y)

                if art_x < 0 or art_y < 0:
                    color = (0, 0, 0, 0)
                else:
                    color = art[SIZE - 1 - art_x if mirror_x else art_x, SIZE - 1 - art_y if mirror_y else art_y]

                pixels[cell * CELL + x, y] = color

    buffer = io.BytesIO()
    image.save(buffer, format="TGA")

    return buffer.getvalue()


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
    check = "--check" in sys.argv[1:]

    for path, data in ((OUTPUT, build()), (SHADED, build_shaded())):
        if check:
            if not path.exists() or path.read_bytes() != data:
                print(f"stale or missing: {path.name}")
                sys.exit(1)
        else:
            path.write_bytes(data)

    print(f"forever border: {'current' if check else 'written'}")


if __name__ == "__main__":
    main()
