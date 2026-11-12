#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Draw a first version of the keyframes of the walk.

The original artwork only shows a cat galloping, and a gallop played slowly
does not look like a walk. This script draws the five keyframes of a walk,
art/walk-0.svg to art/walk-4.svg, in the style of the drawings of the run:
it takes the body of the most upright of them, removes its legs and gives
it four new ones, placed where a walking cat has them at five moments of a
step.

What it writes is a starting point. The files in art/ are drawings like
the others, meant to be retouched by hand, which is why this script does
not replace them unless it is run with --force. After drawing or
retouching them, run tools/generate_sprites.py, having updated WALK_PAWS
there if the paws have moved; this script prints where it put them.

Needs nothing but the Python standard library.
"""

import argparse
import math
from pathlib import Path

from generate_sprites import (RUN, RUN_PAWS, SAMPLES, WALK, Pose, lerp, load_polygons, oriented,
                              resample, signed_area, simplify)

BODY = 4                # the drawing whose body is used: the most upright one
GROUND = 292            # where the paws rest, in that drawing
BELLY = 226             # its legs are cut off below this line
# In that drawing the cat is landing, gathered up: its back is arched and
# its hindquarters tucked in. A walking cat is longer and its back straight.
# What is behind the first point of LENGTHEN moves by its amount, what is
# ahead of the second by its amount, and what is in between is stretched.
# Above the line of BACK, from the tail to the neck, only ARCH of the hump
# is kept, less so near both ends where the back has to join them smoothly.
# Everything after this is given in the lengthened picture.
LENGTHEN = ((150, -6), (270, 20))
BACK = ((112, 153), (258, 139))
ARCH = 0.3

# The gait. A cycle is four footfalls, one per leg. Left and right legs look
# the same in a silhouette, so the picture repeats after half a cycle: the
# five keyframes are five moments of that half, evenly spaced.
STRIDE = 76             # distance a paw covers on the ground
LIFT = 16               # how high a paw rises when it swings forward
STANCE = 0.62           # share of the cycle a paw spends on the ground
# How far ahead of the hind legs the front legs are in the cycle. The two
# legs of a pair cross, one hiding the other, when one is under the body
# and the other at the top of its swing. With this value the hind legs do
# so in the first keyframe and the front legs in the third: a leg can only
# go behind another in a keyframe, not between two.
FRONT_LEAD = 0.3

# The legs. Each is two bones, placed from where its paw is. `joint` is
# where the leg hangs from the body, `bones` their lengths and `radii` half
# the thickness of the leg at the joint, where it bends and at its tip.
# They are thick where they leave the body and taper to a rounded tip, as
# the legs of the drawings do.
HIND = {"joint": (166, 204), "bones": (44, 38), "radii": (31, 17, 10.5)}
FRONT = {"joint": (282, 200), "bones": (30, 60), "radii": (25, 16, 10)}

# The body moves with the steps.
GIRDLE_BOB = 3          # the back rises by this much over the legs that carry it
GIRDLE_SPAN = 45        # and that far around them
NECK = (272, 178)       # the head nods around this point
NOD = 3                 # by that many degrees each way
TAIL_ROOT = (129, 172)  # where the tail joins the body
TAIL_SWAY = 12          # degrees the tip of the tail swings each way
TAIL_LAG = 1.4          # radians the tip trails behind the root: the sway runs along the tail
# The tail does not follow that swing all the way up. It is at its highest
# in the second keyframe and from there goes straight down to where it is
# in the last one: left to the swing, it rose more than twice as high in
# the two keyframes in between. These are the moments of those two ends.
TAIL_HIGH, TAIL_LOW = 0.2, 0.8

# The legs and the body are not drawn side by side but blended, the way
# drops run into each other, which rounds the hollows between them.
AREA = (108, 188, 374, 308)     # left, top, right, bottom of the part of the picture where that is done
GRID = 2                # size of the cells of the grid it is worked out on
BLEND = 20              # how close a leg and the body are when they start to merge
JOINT_BLEND = 12        # the same between the bones of a leg: its bend is a curve
LEG_BLEND = 5           # and between two legs, which should stay two legs
SPECK = 150             # a gap between the legs smaller than this area is filled


# --- The body ----------------------------------------------------------------

def clip_above(polygon, limit):
    """The part of the polygon that lies above the horizontal line y = limit."""
    result = []
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        if a[1] <= limit:
            result.append(a)
        if (a[1] <= limit) != (b[1] <= limit):
            ratio = (limit - a[1]) / (b[1] - a[1])
            result.append((a[0] + (b[0] - a[0]) * ratio, limit))
    return result


def round_off(polygon, limit, reach=22, passes=40):
    """Smooth the polygon near the line y = limit, where a cut left corners."""
    points = resample(polygon, SAMPLES)
    weights = [min(1.0, max(0.0, (y - (limit - reach)) / reach)) for _, y in points]
    for _ in range(passes):
        points = [
            lerp(points[k], lerp(points[k - 1], points[(k + 1) % SAMPLES], 0.5), weights[k] / 2)
            for k in range(SAMPLES)
        ]
    return points


def lengthened(point):
    """A point of the drawing, in the longer and straighter cat."""
    x, y = point
    (back_x, back_y), (neck_x, neck_y) = BACK
    if back_x < x < neck_x:
        along = (x - back_x) / (neck_x - back_x)
        line = back_y + (neck_y - back_y) * along
        if y < line:
            # Fully flattened in the middle, not at all at the ends.
            ease = min(1.0, along / 0.3, (1 - along) / 0.3)
            ease = ease * ease * (3 - 2 * ease)
            y = line - (line - y) * (1 - (1 - ARCH) * ease)
    (rear_x, rear_shift), (front_x, front_shift) = LENGTHEN
    place = min(1.0, max(0.0, (x - rear_x) / (front_x - rear_x)))
    place = place * place * (3 - 2 * place)     # eased at both ends
    return x + rear_shift + (front_shift - rear_shift) * place, y


def rotated_around(point, center, angle):
    dx, dy = point[0] - center[0], point[1] - center[1]
    return (center[0] + dx * math.cos(angle) - dy * math.sin(angle),
            center[1] + dx * math.sin(angle) + dy * math.cos(angle))


# --- The legs ----------------------------------------------------------------

def bend_position(joint, tip, upper, lower):
    """Where a leg of two bones bends between its joint and its tip: toward the tail."""
    dx, dy = tip[0] - joint[0], tip[1] - joint[1]
    distance = math.hypot(dx, dy)
    # A tip out of reach leaves the leg straight.
    reach = min(distance, upper + lower)
    along = (reach ** 2 + upper ** 2 - lower ** 2) / (2 * reach)
    aside = math.sqrt(max(0.0, upper ** 2 - along ** 2))
    ux, uy = dx / distance, dy / distance
    return joint[0] + ux * along - uy * aside, joint[1] + uy * along + ux * aside


def leg(joint, sole, bones, radii):
    """The bones of a leg, as (start, radius there, end, radius there).

    `sole` is where the leg touches the ground, or would if it were not
    lifted.
    """
    joint_radius, bend_radius, tip_radius = radii
    tip = (sole[0], sole[1] - tip_radius)
    bend = bend_position(joint, tip, *bones)
    return [(joint, joint_radius, bend, bend_radius), (bend, bend_radius, tip, tip_radius)]


def sole_position(joint_x, phase):
    """Where the sole of a paw is, `phase` being the place of its leg in its
    own cycle, which starts when the paw lands."""
    phase %= 1
    if phase < STANCE:
        # On the ground, pushed back as the body moves forward.
        return joint_x + STRIDE * (0.5 - phase / STANCE), GROUND
    # In the air, lifted and brought forward.
    swing = (phase - STANCE) / (1 - STANCE)
    forward = (1 - math.cos(math.pi * swing)) / 2
    return joint_x + STRIDE * (forward - 0.5), GROUND - LIFT * math.sin(math.pi * swing)


# --- Blending ----------------------------------------------------------------

def smooth_min(a, b, radius):
    """The smaller of two distances, rounded off where they are close.

    Shapes joined with it run into each other the way drops do, instead of
    meeting at a corner.
    """
    closeness = max(radius - abs(a - b), 0.0) / radius
    return min(a, b) - closeness * closeness * radius / 4


def bone_distance(x, y, bone):
    """Distance from a point to a bone, negative inside it."""
    (ax, ay), radius_a, (bx, by), radius_b = bone
    dx, dy = bx - ax, by - ay
    length = dx * dx + dy * dy
    along = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / length)) if length else 0.0
    return math.hypot(x - ax - along * dx, y - ay - along * dy) - (radius_a + along * (radius_b - radius_a))


def polygon_distance(x, y, polygon):
    """Distance from a point to the edge of a polygon, negative inside it."""
    nearest = math.inf
    inside = False
    for (ax, ay), (bx, by) in zip(polygon, polygon[1:] + polygon[:1]):
        dx, dy = bx - ax, by - ay
        length = dx * dx + dy * dy
        along = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / length)) if length else 0.0
        nearest = min(nearest, math.hypot(x - ax - along * dx, y - ay - along * dy))
        if (ay > y) != (by > y) and x < ax + (y - ay) / (by - ay) * dx:
            inside = not inside
    return -nearest if inside else nearest


def outlines(field, left, top, step):
    """Outlines of the area where a field, sampled on a grid, is negative.

    This is marching squares. The grid is taken to be surrounded by positive
    values, so that every outline is closed.
    """
    rows, columns = len(field), len(field[0])

    def value(node):
        column, row = node
        return field[row][column] if 0 <= row < rows and 0 <= column < columns else 1.0

    def crossing(edge):
        """Where the field is zero between two neighboring nodes."""
        a, b = edge
        ratio = value(a) / (value(a) - value(b))
        return (left + step * (a[0] + (b[0] - a[0]) * ratio),
                top + step * (a[1] + (b[1] - a[1]) * ratio))

    # Each cell an outline goes through links the side it comes in by to the
    # side it leaves by. Going around the cell, the outline comes in where
    # the corners go from outside to inside and leaves where they go from
    # inside to outside: two cells that share a side then agree on it.
    following = {}
    for row in range(-1, rows):
        for column in range(-1, columns):
            corners = [(column, row), (column + 1, row), (column + 1, row + 1), (column, row + 1)]
            inside = [value(corner) < 0 for corner in corners]
            entries = [k for k in range(4) if not inside[k] and inside[(k + 1) % 4]]
            if len(entries) == 2:
                # A saddle: two corners inside, opposite each other. The
                # middle of the cell tells whether they are joined, in which
                # case the outline cuts off the corners that are outside.
                joined = sum(value(corner) for corner in corners) < 0
                exits = [(k - 1) % 4 if joined else (k + 1) % 4 for k in entries]
            else:
                exits = [k for k in range(4) if inside[k] and not inside[(k + 1) % 4]]
            for entry, leave in zip(entries, exits):
                following[tuple(sorted((corners[entry], corners[(entry + 1) % 4])))] = \
                    tuple(sorted((corners[leave], corners[(leave + 1) % 4])))

    result = []
    while following:
        start = next(iter(following))
        outline, edge = [], start
        while True:
            outline.append(crossing(edge))
            edge = following.pop(edge)
            if edge == start:
                break
        result.append(outline)
    return result


# --- A keyframe --------------------------------------------------------------

def draw(pose, moment):
    """The polygons of a keyframe, outline first, and where its paws are.

    `moment` goes from 0 to 1 over the half cycle after which the picture
    repeats; it starts when the hind legs cross.
    """
    turn = 2 * math.pi * moment
    # Place in the full cycle, in which a hind leg lands at 0: the hind
    # legs cross in the middle of the time one of them spends on the ground.
    phase = STANCE / 2 + moment / 2
    hind_x, front_x = HIND["joint"][0], FRONT["joint"][0]

    def raised(x):
        """How far the back, and what hangs from it, is raised at `x`: most
        over the hind legs when they cross, over the front legs half a turn later."""
        over_hind = math.exp(-((x - hind_x) / GIRDLE_SPAN) ** 2)
        over_front = math.exp(-((x - front_x) / GIRDLE_SPAN) ** 2)
        return GIRDLE_BOB * math.cos(turn) * (over_hind - over_front)

    def moved(point):
        """A point of the still, lengthened body, where the walk puts it."""
        x, y = point
        # The tail swings, its tip after its root.
        along = min(1.0, max(0.0, (TAIL_ROOT[0] - x) / TAIL_ROOT[0]))

        def swing(when):
            return math.sin(2 * math.pi * when - TAIL_LAG * along)

        if TAIL_HIGH < moment < TAIL_LOW:
            share = (moment - TAIL_HIGH) / (TAIL_LOW - TAIL_HIGH)
            swung = swing(TAIL_HIGH) + (swing(TAIL_LOW) - swing(TAIL_HIGH)) * share
        else:
            swung = swing(moment)
        x, y = rotated_around((x, y), TAIL_ROOT, math.radians(TAIL_SWAY) * along ** 1.5 * swung)
        # The head nods, lowest when a front paw lands.
        ahead = min(1.0, max(0.0, (x - NECK[0]) / 40))
        nod = math.radians(NOD) * ahead * math.cos(turn - 2 * math.pi * (FRONT_LEAD * 2 - STANCE))
        x, y = rotated_around((x, y), NECK, nod)
        return x, y - raised(x)

    body = [moved(lengthened(p)) for p in round_off(clip_above(pose.outline, BELLY), BELLY)]

    # In order: hind left, hind right, front left, front right.
    legs, soles = [], {"hind": [], "front": []}
    for name, limb, lead in (("hind", HIND, 0), ("front", FRONT, FRONT_LEAD)):
        joint = moved(limb["joint"])
        for side in (0, 0.5):
            sole = sole_position(limb["joint"][0], phase + lead + side)
            legs.append(leg(joint, sole, limb["bones"], limb["radii"]))
            soles[name].append(sole)

    # Blend the legs with the body over the part of the picture where they are.
    left, top, right, bottom = AREA
    columns = [left + GRID * k for k in range((right - left) // GRID + 1)]
    rows = [top + GRID * k for k in range((bottom - top) // GRID + 1)]
    field = []
    for y in rows:
        line = []
        for x in columns:
            to_legs = math.inf
            for bones in legs:
                to_leg = math.inf
                for bone in bones:
                    to_leg = smooth_min(to_leg, bone_distance(x, y, bone), JOINT_BLEND)
                to_legs = smooth_min(to_legs, to_leg, LEG_BLEND)
            line.append(smooth_min(polygon_distance(x, y, body), to_legs, BLEND))
        field.append(line)

    # The outlines all run the same way around what they enclose, so a gap
    # between the legs is wound against the shape that has it.
    shapes = outlines(field, left, top, GRID)
    lower = max(shapes, key=lambda shape: abs(signed_area(shape)))
    gaps = [shape for shape in shapes
            if (signed_area(shape) > 0) != (signed_area(lower) > 0) and abs(signed_area(shape)) >= SPECK]

    # The outline of the keyframe is the body outside that part of the
    # picture and the blend inside it. Both are cut where they meet, on the
    # top side of that part, and put end to end.
    def low(point):
        return point[1] >= top and left <= point[0] <= right

    def run(polygon, wanted):
        """The stretch of a closed polygon whose points are `wanted`, in order."""
        start = next(k for k in range(len(polygon)) if wanted(polygon[k]) and not wanted(polygon[k - 1]))
        turned = polygon[start:] + polygon[:start]
        return [p for p in turned if wanted(p)]

    upper = run(oriented(body, positive=True), lambda p: not low(p))
    outline = upper + run(oriented(lower, positive=True), low)
    # The blend is very slightly wider than the body where they meet: even
    # out the two seams.
    for seam in (0, len(upper)):
        for _ in range(8):
            for k in range(seam - 5, seam + 5):
                k %= len(outline)
                outline[k] = lerp(outline[k], lerp(outline[k - 1], outline[(k + 1) % len(outline)], 0.5), 0.5)

    polygons = [outline] + [oriented(gap, positive=False) for gap in gaps]
    polygons += [oriented([moved(lengthened(p)) for p in hole], positive=False) for hole in pose.holes]

    # The paws, in the order the outline meets them from the chest to the
    # tail; two legs that hide each other count as one.
    paws = {}
    for name, pair in soles.items():
        if abs(pair[0][0] - pair[1][0]) < 1:
            # One leg hides the other: the one on the ground is the one seen.
            pair = [max(pair, key=lambda sole: sole[1])]
        paws[name] = [(round(x), round(y) - 2) for x, y in sorted(pair, reverse=True)]
    return polygons, paws


def write(polygons, index, output):
    data = []
    for polygon in polygons:
        points = simplify(polygon, 0.2)
        data.append("M " + " L ".join(f"{x:.2f},{y:.2f}" for x, y in points) + " Z")
    output.write_text(f'''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
        xmlns:dc="http://purl.org/dc/elements/1.1/"
        xmlns:cc="http://creativecommons.org/ns#"
        xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
        xmlns:svg="http://www.w3.org/2000/svg"
        xmlns="http://www.w3.org/2000/svg"
        version="1.1"
        height="388"
        width="388"
        viewBox="0 0 388 388">
    <defs id="defs3051">
    <style type="text/css" id="current-color-scheme">
      .ColorScheme-Text {{
        color:#232629
      }}
      </style>
  </defs>
    <metadata>
        <rdf:RDF>
            <cc:Work rdf:about="">
                <dc:format>image/svg+xml</dc:format>
                <dc:type rdf:resource="http://purl.org/dc/dcmitype/StillImage"/>
                <dc:title>CatWalk Monitor: Walk {index}</dc:title>
            </cc:Work>
        </rdf:RDF>
    </metadata>
    <title>CatWalk Monitor: Walk {index}</title>
    <path style="fill:currentColor;fill-rule:evenodd"
            d="{" ".join(data)}"
            class="ColorScheme-Text"/>
</svg>
''', encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true", help="replace the keyframes that exist")
    parser.add_argument("--directory", type=Path, help="write the keyframes there instead of in art/")
    args = parser.parse_args()

    targets = [args.directory / path.name for path in WALK] if args.directory else WALK
    existing = [path for path in targets if path.exists()]
    if existing and not args.force:
        parser.error(f"{existing[0]} exists; it may have been retouched by hand. Use --force to replace it.")

    pose = Pose(load_polygons(RUN[BODY]), RUN_PAWS[BODY])
    print("WALK_PAWS = [")
    for index, target in enumerate(targets):
        polygons, paws = draw(pose, index / len(targets))
        write(polygons, index, target)
        print(f'    {{"front": {paws["front"]}, "hind": {paws["hind"]}}},')
    print("]")


if __name__ == "__main__":
    main()
