"""Builds the cursor ring's textures from geometry.

    python Tools/cursor-ring.py          write AeonUI/Media/Textures/CursorRing<Thickness>.tga and CursorDot.tga
    python Tools/cursor-ring.py --check  change nothing; fail if a texture is missing or stale

Each texture is 256x256, white, an uncompressed 32-bit TGA with a top-left origin, antialiased by 4x4 supersampling.
A ring is a soft band centered at 65% of the radius whose alpha falls off as a cosine over its half width on either
side: 9 pixels for Thin, 16 for Normal and 26 for Thick. The dot is a filled circle. The half widths and the band's
center are mirrored in Cursor/Options.lua, which sizes the global cooldown swipe to sit inside the ring.

Needs only the standard library.
"""

import math
import pathlib
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEXTURES = ROOT / "AeonUI" / "Media" / "Textures"
SIZE = 256
SAMPLES = 4
CENTER = SIZE / 2 * 0.65
HALF_WIDTHS = {"Thin": 9, "Normal": 16, "Thick": 26}


def ring(half):
    def profile(distance):
        offset = abs(distance - CENTER)

        return 0.5 + 0.5 * math.cos(math.pi * offset / half) if offset < half else 0

    return profile


def dot(distance):
    return 1 if distance <= SIZE / 2 - 1 else 0


def build(profile):
    middle = SIZE / 2
    pixels = bytearray()

    for y in range(SIZE):
        for x in range(SIZE):
            total = 0

            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    dx = x + (sx + 0.5) / SAMPLES - middle
                    dy = y + (sy + 0.5) / SAMPLES - middle
                    total += profile(math.hypot(dx, dy))

            alpha = round(255 * total / (SAMPLES * SAMPLES))
            pixels += bytes((255, 255, 255, alpha))

    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)

    return header + bytes(pixels)


def main():
    check = "--check" in sys.argv[1:]
    textures = {f"CursorRing{name}.tga": ring(half) for name, half in HALF_WIDTHS.items()}
    textures["CursorDot.tga"] = dot
    problems = []

    for name, profile in textures.items():
        data = build(profile)
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

    print(f"cursor ring: {len(textures)} textures {'current' if check else 'written'}")


if __name__ == "__main__":
    main()
