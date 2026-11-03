"""Builds AeonUI's shipped textures that are made from larger sources.

The target classification icons are scaled from Alex's originals in AeonDocs
(design/assets/unit-classification) to 64x64 PNGs in AeonUI/Media/Textures/Classification.

Run from the repository root:  python Tools/media.py
Check that the built files are current:  python Tools/media.py --check
"""

import io
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT.parent / "AeonDocs" / "design" / "assets" / "unit-classification"
TARGET = ROOT / "AeonUI" / "Media" / "Textures" / "Classification"
SIZE = 64

# Built file name: source file name.
ICONS = {
    "Rare.png": "rare-v1.png",
    "Elite.png": "elite-v1.png",
    "RareElite.png": "rare-elite-v1.png",
}


def build(source):
    """Returns the PNG bytes of one icon scaled to SIZE with its transparency kept."""
    with Image.open(source) as image:
        scaled = image.convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)
        buffer = io.BytesIO()
        scaled.save(buffer, format="PNG", optimize=True)
        return buffer.getvalue()


def main():
    check = "--check" in sys.argv[1:]
    stale = []

    TARGET.mkdir(parents=True, exist_ok=True)

    for name, source in ICONS.items():
        data = build(SOURCE / source)
        path = TARGET / name

        if check:
            if not path.exists() or path.read_bytes() != data:
                stale.append(name)
        else:
            path.write_bytes(data)

    if stale:
        print("media: out of date: " + ", ".join(stale) + " (run python Tools/media.py)")
        return 1

    print("media: %d classification icons %s" % (len(ICONS), "current" if check else "built"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
