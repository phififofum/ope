#!/usr/bin/env python3
"""Render the game and compare it against approved baselines.

This is the layer that catches what no other test can: a missing material, a black
model, a UI element that has drifted off screen, text too small to read. Nothing else in
the pipeline looks at the screen.

The game does the capturing itself (`-- --screenshot <path>`), so the shots come from the
real boot path with a fixed seed, a fixed frame and a fixed camera. A difference means a
render changed, not that a shift went differently.

Usage:
    python3 tools/visual_regression.py                 # capture and compare
    python3 tools/visual_regression.py --update        # approve what was captured
    python3 tools/visual_regression.py --skip-capture  # compare existing captures

Needs Godot (GODOT env var or `godot` on PATH) and a display; under CI that means xvfb.
"""

from __future__ import annotations

import argparse
import os
import shutil
import struct
import subprocess
import sys
import zlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BASELINE_DIR = REPO_ROOT / "tests" / "baselines"
CAPTURE_DIR = REPO_ROOT / "reports" / "visual"
# Small differences are dithering and driver noise; a real regression moves far more than
# this. Loose enough not to cry wolf, tight enough to catch a black model.
TOLERANCE_PER_PIXEL = 12
MAX_DIFFERING_FRACTION = 0.02


def read_png(path: Path) -> tuple[int, int, bytes]:
    """Decode a PNG to raw bytes without a third-party dependency.

    Only the shapes Godot writes are supported: 8-bit RGB or RGBA, not interlaced.
    """
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")
    pos = 8
    width = height = 0
    channels = 4
    idat = b""
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        kind = data[pos + 4 : pos + 8]
        body = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, colour = struct.unpack(">IIBB", body[:10])
            if depth != 8 or colour not in (2, 6):
                raise ValueError(f"{path}: unsupported PNG ({depth}-bit, colour {colour})")
            channels = 3 if colour == 2 else 4
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break

    raw = zlib.decompress(idat)
    stride = width * channels
    out = bytearray(height * stride)
    previous = bytearray(stride)
    offset = 0
    for row in range(height):
        filter_type = raw[offset]
        offset += 1
        line = bytearray(raw[offset : offset + stride])
        offset += stride
        for index in range(stride):
            left = line[index - channels] if index >= channels else 0
            up = previous[index]
            up_left = previous[index - channels] if index >= channels else 0
            value = line[index]
            if filter_type == 1:
                value += left
            elif filter_type == 2:
                value += up
            elif filter_type == 3:
                value += (left + up) // 2
            elif filter_type == 4:
                delta = left + up - up_left
                options = (abs(delta - left), abs(delta - up), abs(delta - up_left))
                smallest = min(options)
                if smallest == options[0]:
                    value += left
                elif smallest == options[1]:
                    value += up
                else:
                    value += up_left
            line[index] = value & 0xFF
        out[row * stride : (row + 1) * stride] = line
        previous = line
    return width, height, bytes(out)


def compare(baseline: Path, capture_path: Path) -> tuple[bool, str]:
    width_a, height_a, pixels_a = read_png(baseline)
    width_b, height_b, pixels_b = read_png(capture_path)
    if (width_a, height_a) != (width_b, height_b):
        return False, f"size changed: {width_a}x{height_a} -> {width_b}x{height_b}"
    differing = sum(
        1 for a, b in zip(pixels_a, pixels_b, strict=False) if abs(a - b) > TOLERANCE_PER_PIXEL
    )
    fraction = differing / max(1, len(pixels_a))
    if fraction > MAX_DIFFERING_FRACTION:
        return False, f"{fraction:.1%} of the image changed"
    return True, f"{fraction:.2%} differs"


def capture(godot: str, target: Path) -> bool:
    CAPTURE_DIR.mkdir(parents=True, exist_ok=True)
    command = [
        godot,
        "--path",
        str(REPO_ROOT),
        "--rendering-driver",
        "opengl3",
        "--resolution",
        "1280x720",
        "--",
        "--screenshot",
        str(target),
    ]
    if shutil.which("xvfb-run") and not os.environ.get("DISPLAY"):
        command = ["xvfb-run", "-a", *command]
    result = subprocess.run(command, capture_output=True, text=True, timeout=600, check=False)
    if result.returncode != 0:
        print(result.stdout[-2000:], file=sys.stderr)
        print(result.stderr[-2000:], file=sys.stderr)
    return result.returncode == 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--update", action="store_true", help="approve the captured images as the new baselines"
    )
    parser.add_argument(
        "--skip-capture", action="store_true", help="compare images already in reports/visual"
    )
    args = parser.parse_args()

    target = CAPTURE_DIR / "counter.png"
    if not args.skip_capture:
        godot = os.environ.get("GODOT", "godot")
        if not (shutil.which(godot) or Path(godot).exists()):
            print(f"error: no Godot binary at '{godot}'; set GODOT", file=sys.stderr)
            return 2
        if not capture(godot, target):
            print("error: the game did not produce a screenshot", file=sys.stderr)
            return 2

    captures = sorted(CAPTURE_DIR.glob("*.png"))
    if not captures:
        print("error: nothing captured", file=sys.stderr)
        return 2

    if args.update:
        BASELINE_DIR.mkdir(parents=True, exist_ok=True)
        for shot in captures:
            shutil.copy2(shot, BASELINE_DIR / shot.name)
            print(f"approved {shot.name}")
        return 0

    failures = 0
    for shot in captures:
        baseline = BASELINE_DIR / shot.name
        if not baseline.is_file():
            print(f"  NEW      {shot.name} has no approved baseline")
            failures += 1
            continue
        ok, detail = compare(baseline, shot)
        print(f"  {'ok      ' if ok else 'CHANGED '} {shot.name}: {detail}")
        failures += 0 if ok else 1

    print(f"\n{len(captures)} image(s), {failures} needing attention")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
