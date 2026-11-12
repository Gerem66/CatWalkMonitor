#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build the cat sprite sheet from the keyframes drawn in art/.

The run is drawn as five poses. Flipping through five poses looks choppy
at low speed, so this script computes the poses in between once, offline,
and lays every pose out in a single SVG sprite sheet. The widget then only
has to pick a cell of that sheet for each frame it renders.

In-betweens are made by morphing the silhouette of one pose into the next:
both outlines are sampled, matched point to point with a dynamic time
warping (so that ears go to ears), and the matched points are interpolated.
The matching is pinned at the tips of the paws, given below for each
drawing, so that every leg goes to a leg. Eyes and inner ears are matched
by position.

Usage:  tools/generate_sprites.py            (from the repository root)
Needs nothing but the Python standard library.
"""

import argparse
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUN = [ROOT / "art" / f"run-{i}.svg" for i in range(5)]
IDLE = ROOT / "art" / "idle.svg"
OUTPUT = ROOT / "package" / "contents" / "images" / "cat.svg"

# The tips of the paws in each drawing, in the order the outline meets them
# from the chest to the tail. Two legs that hide each other count as one.
RUN_PAWS = [
    {"front": [(255, 272)], "hind": [(208, 283), (175, 305)]},
    {"front": [(362, 235), (336, 254)], "hind": [(122, 302), (72, 275)]},
    {"front": [(376, 238), (362, 278)], "hind": [(135, 280), (82, 250)]},
    {"front": [(358, 255), (312, 302)], "hind": [(163, 278)]},
    {"front": [(265, 292)], "hind": [(208, 270)]},
]

# Poses made from one drawing to the next, that drawing included.
RUN_STEPS = 12

CELL = 388          # size of one pose, in SVG units (the keyframes' canvas)
COLUMNS = 10        # cells per row of the sheet
SAMPLES = 360       # points used to describe a silhouette when matching
HOLE_SAMPLES = 24   # points used for an eye or an inner ear
TOLERANCE = 0.25   # simplification tolerance of the output, in SVG units


# --- SVG path parsing --------------------------------------------------------

def _arc(x1, y1, rx, ry, rotation, large, sweep, x2, y2, step=1.0):
    """Points of an SVG elliptical arc, end point included (SVG 1.1, F.6.5)."""
    if rx == 0 or ry == 0:
        return [(x2, y2)]
    rx, ry = abs(rx), abs(ry)
    phi = math.radians(rotation)
    cos_phi, sin_phi = math.cos(phi), math.sin(phi)
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p = cos_phi * dx + sin_phi * dy
    y1p = -sin_phi * dx + cos_phi * dy
    scale = x1p ** 2 / rx ** 2 + y1p ** 2 / ry ** 2
    if scale > 1:
        rx, ry = rx * math.sqrt(scale), ry * math.sqrt(scale)
    num = rx ** 2 * ry ** 2 - rx ** 2 * y1p ** 2 - ry ** 2 * x1p ** 2
    den = rx ** 2 * y1p ** 2 + ry ** 2 * x1p ** 2
    coef = math.sqrt(max(0.0, num / den)) if den else 0.0
    if large == sweep:
        coef = -coef
    cxp, cyp = coef * rx * y1p / ry, -coef * ry * x1p / rx
    cx = cos_phi * cxp - sin_phi * cyp + (x1 + x2) / 2
    cy = sin_phi * cxp + cos_phi * cyp + (y1 + y2) / 2
    start = math.atan2((y1p - cyp) / ry, (x1p - cxp) / rx)
    end = math.atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx)
    delta = end - start
    if sweep and delta < 0:
        delta += 2 * math.pi
    elif not sweep and delta > 0:
        delta -= 2 * math.pi
    count = max(4, math.ceil(abs(delta) * max(rx, ry) / step))
    points = []
    for i in range(1, count + 1):
        angle = start + delta * i / count
        ex, ey = rx * math.cos(angle), ry * math.sin(angle)
        points.append((cos_phi * ex - sin_phi * ey + cx,
                       sin_phi * ex + cos_phi * ey + cy))
    points[-1] = (x2, y2)
    return points


def _cubic(p0, p1, p2, p3, step=1.0):
    """Points of a cubic Bezier curve, end point included."""
    length = math.dist(p0, p1) + math.dist(p1, p2) + math.dist(p2, p3)
    count = max(4, math.ceil(length / step))
    points = []
    for i in range(1, count + 1):
        t = i / count
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t ** 2, t ** 3
        points.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
                       a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return points


def parse_path(data):
    """Flatten SVG path data into a list of closed polygons."""
    tokens = re.findall(r"[MmLlHhVvCcAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?", data)
    polygons, current = [], []
    x = y = start_x = start_y = 0.0
    command = None
    i = 0

    def numbers(count):
        nonlocal i
        values = [float(v) for v in tokens[i:i + count]]
        i += count
        return values

    while i < len(tokens):
        if tokens[i].isalpha():
            command = tokens[i]
            i += 1
        relative = command.islower()
        kind = command.lower()
        if kind == "z":
            if current:
                polygons.append(current)
            current = []
            x, y = start_x, start_y
            continue
        if kind == "m":
            nx, ny = numbers(2)
            x, y = (x + nx, y + ny) if relative else (nx, ny)
            if current:
                polygons.append(current)
            current = [(x, y)]
            start_x, start_y = x, y
            command = "l" if relative else "L"   # further pairs are line-tos
        elif kind == "l":
            nx, ny = numbers(2)
            x, y = (x + nx, y + ny) if relative else (nx, ny)
            current.append((x, y))
        elif kind == "h":
            (nx,) = numbers(1)
            x = x + nx if relative else nx
            current.append((x, y))
        elif kind == "v":
            (ny,) = numbers(1)
            y = y + ny if relative else ny
            current.append((x, y))
        elif kind == "c":
            x1, y1, x2, y2, nx, ny = numbers(6)
            if relative:
                x1, y1, x2, y2, nx, ny = x + x1, y + y1, x + x2, y + y2, x + nx, y + ny
            current.extend(_cubic((x, y), (x1, y1), (x2, y2), (nx, ny)))
            x, y = nx, ny
        elif kind == "a":
            rx, ry, rotation, large, sweep, nx, ny = numbers(7)
            if relative:
                nx, ny = x + nx, y + ny
            current.extend(_arc(x, y, rx, ry, rotation, bool(large), bool(sweep), nx, ny))
            x, y = nx, ny
        else:
            raise ValueError(f"unsupported path command {command!r}")
    if current:
        polygons.append(current)
    return polygons


def load_polygons(svg_file):
    text = svg_file.read_text(encoding="utf-8")
    paths = re.findall(r"<path\b[^>]*?\sd=\"([^\"]+)\"", text, flags=re.S)
    if len(paths) != 1 or "transform=" in text:
        raise ValueError(f"{svg_file}: expected a single untransformed <path>")
    return parse_path(paths[0])


# --- Geometry ----------------------------------------------------------------

def signed_area(polygon):
    return sum(x1 * y2 - x2 * y1
               for (x1, y1), (x2, y2) in zip(polygon, polygon[1:] + polygon[:1])) / 2


def centroid(polygon):
    return (sum(p[0] for p in polygon) / len(polygon),
            sum(p[1] for p in polygon) / len(polygon))


def perimeter(polygon):
    return sum(math.dist(a, b) for a, b in zip(polygon, polygon[1:] + polygon[:1]))


def oriented(polygon, positive):
    """The polygon wound so that its signed area has the requested sign."""
    return polygon if (signed_area(polygon) > 0) == positive else polygon[::-1]


def resample(polygon, count):
    """`count` points evenly spaced along the closed polygon, starting at its first."""
    closed = polygon + polygon[:1]
    lengths = [math.dist(a, b) for a, b in zip(closed, closed[1:])]
    spacing = sum(lengths) / count
    points, segment, travelled = [], 0, 0.0
    for i in range(count):
        target = i * spacing
        while segment < len(lengths) - 1 and travelled + lengths[segment] < target:
            travelled += lengths[segment]
            segment += 1
        ratio = (target - travelled) / lengths[segment] if lengths[segment] else 0.0
        (ax, ay), (bx, by) = closed[segment], closed[segment + 1]
        points.append((ax + (bx - ax) * ratio, ay + (by - ay) * ratio))
    return points


def rotated(points, offset):
    offset %= len(points)
    return points[offset:] + points[:offset]


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def simplify(polygon, tolerance):
    """Ramer-Douglas-Peucker simplification of a closed polygon."""
    def reduce(points):
        keep = [False] * len(points)
        keep[0] = keep[-1] = True
        stack = [(0, len(points) - 1)]
        while stack:
            first, last = stack.pop()
            (ax, ay), (bx, by) = points[first], points[last]
            length = math.hypot(bx - ax, by - ay)
            worst, index = 0.0, None
            for k in range(first + 1, last):
                px, py = points[k]
                if length:
                    distance = abs((bx - ax) * (ay - py) - (ax - px) * (by - ay)) / length
                else:
                    distance = math.hypot(px - ax, py - ay)
                if distance > worst:
                    worst, index = distance, k
            if index is not None and worst > tolerance:
                keep[index] = True
                stack += [(first, index), (index, last)]
        return [p for p, kept in zip(points, keep) if kept]

    # Split at the point farthest from the first one so both halves are open.
    far = max(range(len(polygon)), key=lambda k: math.dist(polygon[0], polygon[k]))
    return reduce(polygon[:far + 1])[:-1] + reduce(polygon[far:] + polygon[:1])[:-1]


# --- Pose description --------------------------------------------------------

class Pose:
    """A keyframe: the silhouette, its eyes and inner ears, and where its paws are."""

    def __init__(self, polygons, paws):
        self.paws = paws
        polygons = sorted(polygons, key=lambda p: abs(signed_area(p)), reverse=True)
        self.outline = oriented(polygons[0], positive=True)
        holes = polygons[1:]
        if len(holes) != 4:
            raise ValueError(f"expected 2 eyes and 2 inner ears, found {len(holes)} holes")
        # Eyes are the two roundest holes; a circle maximizes area / perimeter^2.
        holes.sort(key=lambda p: abs(signed_area(p)) / perimeter(p) ** 2, reverse=True)
        eyes = sorted(holes[:2], key=lambda p: centroid(p)[0])
        ears = sorted(holes[2:], key=lambda p: centroid(p)[0])
        self.holes = [self._normalized(hole) for hole in eyes + ears]

    @staticmethod
    def _normalized(hole):
        """Wound opposite to the outline, starting from its topmost point."""
        hole = oriented(hole, positive=False)
        top = min(range(len(hole)), key=lambda k: hole[k][1])
        return resample(rotated(hole, top), HOLE_SAMPLES)


# --- Silhouette matching -----------------------------------------------------

def _tangents(points):
    count = len(points)
    result = []
    for k in range(count):
        (ax, ay), (bx, by) = points[k - 2], points[(k + 2) % count]
        length = math.hypot(bx - ax, by - ay) or 1.0
        result.append(((bx - ax) / length, (by - ay) / length))
    return result


def _warp(a, b, ta, tb, scale, best=math.inf):
    """Dynamic time warping of two open point sequences.

    Returns (cost, pairs) or (inf, None) when the cost exceeds `best`.
    """
    n, m = len(a), len(b)
    skip = 0.35           # cost of matching one point to several
    turn = 0.6            # weight of the difference in direction
    inf = math.inf
    previous = [inf] * (m + 1)
    previous[0] = 0.0
    moves = []
    for i in range(1, n + 1):
        ax, ay = a[i - 1]
        tx, ty = ta[i - 1]
        row = [inf] * (m + 1)
        move = bytearray(m + 1)
        low = inf
        for j in range(1, m + 1):
            bx, by = b[j - 1]
            ux, uy = tb[j - 1]
            cost = ((ax - bx) ** 2 + (ay - by) ** 2) / scale + turn * (1 - tx * ux - ty * uy)
            diagonal, up, left = previous[j - 1], previous[j] + skip, row[j - 1] + skip
            if diagonal <= up and diagonal <= left:
                row[j], move[j] = diagonal + cost, 0
            elif up <= left:
                row[j], move[j] = up + cost, 1
            else:
                row[j], move[j] = left + cost, 2
            if row[j] < low:
                low = row[j]
        if low > best:
            return inf, None
        moves.append(move)
        previous = row
    pairs, i, j = [], n, m
    while i > 0 and j > 0:
        pairs.append((i - 1, j - 1))
        step = moves[i - 1][j]
        if step == 0:
            i, j = i - 1, j - 1
        elif step == 1:
            i -= 1
        else:
            j -= 1
    pairs.reverse()
    return previous[m], pairs


def paired(first, second):
    """Pairs of matching paws between two drawings.

    A paw alone where the other drawing shows two stands for both: the two
    legs part from one another, or come together.
    """
    if len(first) == len(second):
        return list(zip(first, second))
    if len(first) == 1:
        return [(first[0], paw) for paw in second]
    return [(paw, second[0]) for paw in first]


def anchors(pose, following):
    """Pairs of points of two drawings that are known to match."""
    pairs = paired(pose.paws["front"], following.paws["front"])
    pairs += paired(pose.paws["hind"], following.paws["hind"])
    # The tip of the tail is the leftmost point of every drawing.
    pairs.append((min(pose.outline), min(following.outline)))
    return pairs


def match_outlines(a, b, known):
    """Pairs of matching points between two closed outlines.

    `known` are pairs of points known to match, one on each outline. The
    outlines are cut at these points and matched piece by piece. Left to
    itself the warping only brings near points together: a leg that the
    next drawing hides behind another would melt into the body instead of
    going behind that other leg.
    """
    a, b = resample(a, SAMPLES), resample(b, SAMPLES)

    def index(points, target):
        return min(range(SAMPLES), key=lambda k: math.dist(points[k], target))

    cuts = [(index(a, p), index(b, q)) for p, q in known]
    # Count from one of the cuts, so that no piece straddles the place where
    # the outlines happen to start.
    start_a, start_b = cuts[0]
    cuts = sorted(((i - start_a) % SAMPLES, (j - start_b) % SAMPLES) for i, j in cuts)
    if any(later[1] < earlier[1] for earlier, later in zip(cuts, cuts[1:])):
        raise ValueError("the known points do not come in the same order on both outlines")
    a, b = rotated(a, start_a), rotated(b, start_b)
    ta, tb = _tangents(a), _tangents(b)
    scale = (perimeter(a) / 12) ** 2

    pairs = []
    for (i0, j0), (i1, j1) in zip(cuts, cuts[1:] + [(SAMPLES, SAMPLES)]):
        # Both ends included; the outlines close on their first point.
        piece_a = [k % SAMPLES for k in range(i0, i1 + 1)]
        piece_b = [k % SAMPLES for k in range(j0, j1 + 1)]
        if len(piece_a) == 1 or len(piece_b) == 1:
            # Two legs in one drawing, one in the other: a whole stretch of
            # outline, the gap between the legs, goes to a single point.
            matched = [(i, j) for i in piece_a for j in piece_b]
        else:
            _, steps = _warp([a[k] for k in piece_a], [b[k] for k in piece_b],
                             [ta[k] for k in piece_a], [tb[k] for k in piece_b], scale)
            matched = [(piece_a[i], piece_b[j]) for i, j in steps]
        # The last pair of a piece is the first of the next one.
        pairs += matched[:-1]
    return [(a[i], b[j]) for i, j in pairs]


# --- Sheet generation --------------------------------------------------------

def build_poses(files, paws, steps):
    """Every pose of a gait: its keyframes and `steps` poses from each to the next."""
    keyframes = [Pose(load_polygons(path), tips) for path, tips in zip(files, paws)]
    poses = []
    for index, pose in enumerate(keyframes):
        following = keyframes[(index + 1) % len(keyframes)]
        outline_pairs = match_outlines(pose.outline, following.outline, anchors(pose, following))
        for step in range(steps):
            t = step / steps
            outline = [lerp(p, q, t) for p, q in outline_pairs]
            holes = [[lerp(p, q, t) for p, q in zip(hole, other)]
                     for hole, other in zip(pose.holes, following.holes)]
            poses.append([outline] + holes)
    return poses


def path_data(polygons, dx, dy):
    parts = []
    for polygon in polygons:
        points = simplify(polygon, TOLERANCE)
        px, py = points[0][0] + dx, points[0][1] + dy
        parts.append(f"M{px:.1f} {py:.1f}")
        for x, y in points[1:]:
            x, y = x + dx, y + dy
            parts.append(f"l{x - px:.1f} {y - py:.1f}")
            # Accumulate the rounded values so errors do not add up.
            px, py = round(px + round(x - px, 1), 1), round(py + round(y - py, 1), 1)
        parts.append("Z")
    return "".join(parts)


def write_sheet(poses, idle_polygons, output):
    cells = poses + [idle_polygons]
    rows = math.ceil(len(cells) / COLUMNS)
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        "<!-- Generated by tools/generate_sprites.py from art/*.svg. Do not edit. -->",
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {COLUMNS * CELL} {rows * CELL}" '
        f'width="{COLUMNS * CELL}" height="{rows * CELL}">',
        "<title>CatWalk Monitor sprite sheet</title>",
        '<g fill="#fff" fill-rule="nonzero">',
    ]
    for index, polygons in enumerate(cells):
        dx, dy = (index % COLUMNS) * CELL, (index // COLUMNS) * CELL
        lines.append(f'<path d="{path_data(polygons, dx, dy)}"/>')
    lines += ["</g>", "</svg>", ""]
    output.write_text("\n".join(lines), encoding="utf-8")
    return len(cells), rows


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("-o", "--output", type=Path, default=OUTPUT)
    args = parser.parse_args()

    run = build_poses(RUN, RUN_PAWS, RUN_STEPS)

    idle = sorted(load_polygons(IDLE), key=lambda p: abs(signed_area(p)), reverse=True)
    # The sleeping cat is drawn as is: body wound one way, everything that
    # lies inside it (inner ears) the other way, the "Zz" like the body.
    body = oriented(idle[0], positive=True)
    left, right = min(p[0] for p in body), max(p[0] for p in body)
    top, bottom = min(p[1] for p in body), max(p[1] for p in body)
    idle_polygons = [body]
    for polygon in idle[1:]:
        cx, cy = centroid(polygon)
        inside = left < cx < right and top < cy < bottom
        idle_polygons.append(oriented(polygon, positive=not inside))

    count, rows = write_sheet(run, idle_polygons, args.output)
    print(f"{args.output}: {count} poses ({len(run)} running, 1 idle), "
          f"{COLUMNS}x{rows} cells, {args.output.stat().st_size // 1024} KiB")


if __name__ == "__main__":
    main()
