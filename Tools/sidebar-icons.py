"""Builds the settings sidebar's page icons from their SVG line glyphs.

    python Tools/sidebar-icons.py          write Media/Textures/Sidebar<Name>.tga for each <Name>.svg
    python Tools/sidebar-icons.py --check  change nothing; fail if an icon is missing or stale

The glyphs are AeonDocs/design/assets/aeonui/sidebar-icons/<Name>.svg: one 24-unit SVG per page, stroked with round
caps and joins (circle, rect with rx, path). Each is drawn white at ALPHA on a SIZE square: a pixel's alpha is the
share of its SAMPLES x SAMPLES samples within half the stroke width of any segment. The settings window tints the
icon with its page title's color.

Needs Pillow and NumPy.
"""

import io
import math
import pathlib
import re
import sys
from xml.etree import ElementTree

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCES = ROOT.parent / "AeonDocs" / "design" / "assets" / "aeonui" / "sidebar-icons"
TEXTURES = ROOT / "Media" / "Textures"

SIZE = 64
SAMPLES = 4  # per axis, for each pixel's coverage of the stroke
ALPHA = 0.85  # the glyph's opacity, a step below the sidebar's white labels
STEPS = 24  # line segments per curve or arc
TOKEN = re.compile(r"[MmLlHhVvCcSsAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE]-?\d+)?")
ARGS = {"M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "A": 7, "Z": 0}


def arc_points(start, rx, ry, rotation, large, sweep, end):
    """Points along an SVG endpoint arc, converted to its center form (SVG 1.1, appendix F.6.5)."""
    (x1, y1), (x2, y2) = start, end
    if rx == 0 or ry == 0 or (x1, y1) == (x2, y2):
        return [end]
    phi = math.radians(rotation)
    cos, sin = math.cos(phi), math.sin(phi)
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    xp, yp = cos * dx + sin * dy, -sin * dx + cos * dy
    rx, ry = abs(rx), abs(ry)
    scale = (xp / rx) ** 2 + (yp / ry) ** 2
    if scale > 1:
        rx, ry = rx * math.sqrt(scale), ry * math.sqrt(scale)
    numerator = rx * rx * ry * ry - rx * rx * yp * yp - ry * ry * xp * xp
    factor = math.sqrt(max(0, numerator / (rx * rx * yp * yp + ry * ry * xp * xp)))
    if large == sweep:
        factor = -factor
    cxp, cyp = factor * rx * yp / ry, -factor * ry * xp / rx
    cx = cos * cxp - sin * cyp + (x1 + x2) / 2
    cy = sin * cxp + cos * cyp + (y1 + y2) / 2
    theta = math.atan2((yp - cyp) / ry, (xp - cxp) / rx)
    delta = math.atan2((-yp - cyp) / ry, (-xp - cxp) / rx) - theta
    if sweep and delta < 0:
        delta += 2 * math.pi
    elif not sweep and delta > 0:
        delta -= 2 * math.pi
    points = []
    for step in range(1, STEPS + 1):
        angle = theta + delta * step / STEPS
        ex, ey = rx * math.cos(angle), ry * math.sin(angle)
        points.append((cos * ex - sin * ey + cx, sin * ex + cos * ey + cy))

    return points


def path_segments(data):
    """Line segments approximating an SVG path's M, L, H, V, C, S, A and Z commands, absolute or relative."""
    tokens = TOKEN.findall(data)
    segments, index = [], 0
    current = start = (0.0, 0.0)
    command, control = None, None
    while index < len(tokens):
        if tokens[index].isalpha():
            command = tokens[index]
            index += 1
        upper, relative = command.upper(), command.islower()
        count = ARGS[upper]
        values = [float(token) for token in tokens[index:index + count]]
        index += count
        ox, oy = current if relative else (0.0, 0.0)
        points, next_control = [], None
        if upper == "M":
            current = start = (values[0] + ox, values[1] + oy)
            command = "l" if relative else "L"
            continue
        if upper == "Z":
            points = [start]
        elif upper == "L":
            points = [(values[0] + ox, values[1] + oy)]
        elif upper == "H":
            points = [(values[0] + ox, current[1])]
        elif upper == "V":
            points = [(current[0], values[0] + oy)]
        elif upper in ("C", "S"):
            if upper == "C":
                first = (values[0] + ox, values[1] + oy)
                rest = values[2:]
            else:
                first = (2 * current[0] - control[0], 2 * current[1] - control[1]) if control else current
                rest = values
            second = (rest[0] + ox, rest[1] + oy)
            end = (rest[2] + ox, rest[3] + oy)
            for step in range(1, STEPS + 1):
                t = step / STEPS
                u = 1 - t
                points.append(tuple(u ** 3 * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t ** 3 * p3
                    for p0, p1, p2, p3 in zip(current, first, second, end)))
            next_control = second
        elif upper == "A":
            points = arc_points(current, values[0], values[1], values[2], values[3] != 0, values[4] != 0,
                (values[5] + ox, values[6] + oy))
        for point in points:
            segments.append((current, point))
            current = point
        control = next_control
        if upper == "Z":
            current = start

    return segments


def svg_segments(path):
    """Every stroked shape of a glyph's SVG (circle, rect with rx, path) as line segments, in its units."""
    segments = []
    for element in ElementTree.parse(path).iter():
        tag = element.tag.rsplit("}", 1)[-1]
        number = lambda name: float(element.get(name, 0))
        if tag == "circle":
            cx, cy, r = number("cx"), number("cy"), number("r")
            segments += path_segments(f"M{cx + r} {cy}A{r} {r} 0 1 1 {cx - r} {cy}A{r} {r} 0 1 1 {cx + r} {cy}")
        elif tag == "rect":
            x, y, w, h, r = number("x"), number("y"), number("width"), number("height"), number("rx")
            segments += path_segments(f"M{x + r} {y}H{x + w - r}A{r} {r} 0 0 1 {x + w} {y + r}V{y + h - r}"
                f"A{r} {r} 0 0 1 {x + w - r} {y + h}H{x + r}A{r} {r} 0 0 1 {x} {y + h - r}V{y + r}"
                f"A{r} {r} 0 0 1 {x + r} {y}Z")
        elif tag == "path":
            segments += path_segments(element.get("d"))

    return segments


def icon(path):
    """The glyph drawn as TGA bytes."""
    offsets = (np.arange(SAMPLES) + 0.5) / SAMPLES
    axis = (np.arange(SIZE)[:, np.newaxis] + offsets).reshape(-1)
    xs, ys = np.meshgrid(axis, axis)
    root = ElementTree.parse(path).getroot()
    scale = SIZE / float(root.get("viewBox").split()[2])
    half = float(root.get("stroke-width")) * scale / 2
    nearest = np.full(xs.shape, np.inf)
    for (ax, ay), (bx, by) in svg_segments(path):
        ax, ay, bx, by = ax * scale, ay * scale, bx * scale, by * scale
        vx, vy = bx - ax, by - ay
        length = vx * vx + vy * vy
        t = np.zeros(xs.shape) if length == 0 else np.clip(((xs - ax) * vx + (ys - ay) * vy) / length, 0, 1)
        nearest = np.minimum(nearest, np.hypot(xs - ax - t * vx, ys - ay - t * vy))
    coverage = (nearest <= half).reshape(SIZE, SAMPLES, SIZE, SAMPLES)
    image = np.zeros((SIZE, SIZE, 4))
    image[:, :, :3] = 255
    image[:, :, 3] = coverage.mean(axis=(1, 3)) * 255 * ALPHA
    buffer = io.BytesIO()
    Image.fromarray(np.round(image).astype(np.uint8), "RGBA").save(buffer, format="TGA", compression=None)

    return buffer.getvalue()


def main():
    check = "--check" in sys.argv[1:]
    files = sorted(SOURCES.glob("*.svg"))
    if not files:
        sys.exit(f"No SVG files in {SOURCES}")
    problems = []

    for source in files:
        data = icon(source)
        path = TEXTURES / f"Sidebar{source.stem}.tga"

        if check:
            if not path.exists() or path.read_bytes() != data:
                problems.append(path.name)
        else:
            path.write_bytes(data)
            print(f"wrote {path.relative_to(ROOT)}")

    if problems:
        sys.exit("stale or missing: " + ", ".join(problems))
    if check:
        print(f"sidebar icons: {len(files)} up to date")


if __name__ == "__main__":
    main()
