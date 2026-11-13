"""Builds the character panel's slot textures from geometry.

    python Tools/quality-outline.py          write AeonUI/Media/Textures/QualityOutline2.tga, QualityOutline3.tga,
                                             QualityShadow.tga and IconShade.tga
    python Tools/quality-outline.py --check  change nothing; fail if a texture is missing or stale

Each texture is white, an uncompressed 32-bit TGA with a top-left origin, antialiased by 4x4 supersampling, drawn at
1.6 texels per unit around a 40-unit slot icon: a rounded square of half size 20 units and corner radius 6.

- QualityOutline2, QualityOutline3: 64x64 for the 40-unit icon, a ring along the square's edge, 2 or 3 units thick.
- QualityShadow: 128x128 for 80 units, the square filled and a soft falloff over 4 units outside it.
- IconShade: 64x64 for the icon, clear in the middle and opaque at the edge over 6 units inside it.

Needs only the standard library.
"""

import math
import pathlib
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEXTURES = ROOT / "AeonUI" / "Media" / "Textures"
SCALE = 1.6
SAMPLES = 4
HALF = 20
RADIUS = 6
SHADOW = 4
SHADE = 6
SHADOW_CANVAS = 80


def distance(x, y):
    """Signed distance in units from the rounded square's edge; negative inside."""
    qx = abs(x) - (HALF - RADIUS)
    qy = abs(y) - (HALF - RADIUS)
    outside = math.hypot(max(qx, 0), max(qy, 0))

    return outside + min(max(qx, qy), 0) - RADIUS


def outline(thickness):
    return lambda d: 1 if -thickness <= d <= 0 else 0


def shadow(d):
    if d <= 0:
        return 1

    return max(0, 1 - d / SHADOW) ** 2


def shade(d):
    if d > 0:
        return 0

    return max(0, 1 + d / SHADE) ** 2


def build(units, profile):
    size = round(units * SCALE)
    middle = size / 2
    pixels = bytearray()

    for y in range(size):
        for x in range(size):
            total = 0

            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    ux = (x + (sx + 0.5) / SAMPLES - middle) / SCALE
                    uy = (y + (sy + 0.5) / SAMPLES - middle) / SCALE
                    total += profile(distance(ux, uy))

            alpha = round(255 * total / (SAMPLES * SAMPLES))
            pixels += bytes((255, 255, 255, alpha))

    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)

    return header + bytes(pixels)


def main():
    check = "--check" in sys.argv[1:]
    textures = {
        "QualityOutline2.tga": (40, outline(2)),
        "QualityOutline3.tga": (40, outline(3)),
        "QualityShadow.tga": (SHADOW_CANVAS, shadow),
        "IconShade.tga": (40, shade),
    }
    problems = []

    for name, (units, profile) in textures.items():
        data = build(units, profile)
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

    print(f"quality outline: {len(textures)} textures {'current' if check else 'written'}")


if __name__ == "__main__":
    main()
