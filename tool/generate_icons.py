#!/usr/bin/env python3
"""Draws the Android launcher icon — a mouse face — into the mipmap folders.

Pure standard library: the PNGs are rasterised by hand and encoded with zlib, so
no image toolchain is needed. Re-run after changing the artwork:

    python3 tool/generate_icons.py
"""

import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES_DIR = os.path.join(ROOT, "android", "app", "src", "main", "res")

# Launcher icon sizes per density bucket.
DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

BACKGROUND = (0x4A, 0x35, 0x23, 255)
FUR = (0xB4, 0xAA, 0x9E, 255)
FUR_EDGE = (0x5A, 0x50, 0x48, 255)
SKIN = (0xEA, 0xA8, 0xAF, 255)
NOSE = (0xD0, 0x80, 0x8B, 255)
EYE = (0x2B, 0x26, 0x20, 255)
CRUMB = (0xC7, 0x93, 0x55, 255)

SUPERSAMPLE = 4


def circle(cx, cy, r):
    return lambda x, y: (x - cx) ** 2 + (y - cy) ** 2 <= r * r


# Painter's algorithm: the last matching layer wins.
LAYERS = [
    (BACKGROUND, lambda x, y: True),
    (CRUMB, circle(0.18, 0.84, 0.055)),
    (CRUMB, circle(0.83, 0.86, 0.045)),
    (FUR_EDGE, circle(0.26, 0.31, 0.175)),
    (FUR, circle(0.26, 0.31, 0.155)),
    (SKIN, circle(0.26, 0.31, 0.088)),
    (FUR_EDGE, circle(0.74, 0.31, 0.175)),
    (FUR, circle(0.74, 0.31, 0.155)),
    (SKIN, circle(0.74, 0.31, 0.088)),
    (FUR_EDGE, circle(0.5, 0.56, 0.32)),
    (FUR, circle(0.5, 0.56, 0.30)),
    (EYE, circle(0.39, 0.52, 0.048)),
    (EYE, circle(0.61, 0.52, 0.048)),
    (NOSE, circle(0.5, 0.67, 0.055)),
    (FUR_EDGE, circle(0.5, 0.775, 0.018)),
]


def sample(x, y):
    color = (0, 0, 0, 0)
    for candidate, hit in LAYERS:
        if hit(x, y):
            color = candidate
    return color


def render(size):
    rows = []
    step = 1.0 / (size * SUPERSAMPLE)
    for py in range(size):
        row = bytearray()
        for px in range(size):
            acc = [0, 0, 0, 0]
            for sy in range(SUPERSAMPLE):
                for sx in range(SUPERSAMPLE):
                    x = (px * SUPERSAMPLE + sx + 0.5) * step
                    y = (py * SUPERSAMPLE + sy + 0.5) * step
                    color = sample(x, y)
                    for i in range(4):
                        acc[i] += color[i]
            total = SUPERSAMPLE * SUPERSAMPLE
            row.extend(bytes(value // total for value in acc))
        rows.append(bytes(row))
    return rows


def write_png(path, size, rows):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(png)
    print("wrote %s (%dx%d, %d bytes)" % (path, size, size, len(png)))


def main():
    for bucket, size in DENSITIES.items():
        rows = render(size)
        write_png(os.path.join(RES_DIR, "mipmap-%s" % bucket, "ic_launcher.png"), size, rows)


if __name__ == "__main__":
    main()
