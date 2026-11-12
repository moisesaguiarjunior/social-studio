#!/usr/bin/env python3
"""Generate synthetic sequence fixtures; reuse the existing PNG chunk writer."""

import runpy
import struct
import zlib
from pathlib import Path


def main() -> None:
    package = Path(__file__).resolve().parents[1]
    generator = runpy.run_path(
        str(package.parents[1] / "probes/phase1/tool/generate_story_assets.py")
    )
    generator["main"]()  # Existing synthetic audio and single-photo example.
    chunk = generator["chunk"]
    target = package / "out/sequence-assets"
    target.mkdir(parents=True, exist_ok=True)
    width, height = 540, 960
    palettes = [
        ((16, 60, 65), (242, 193, 78)),
        ((57, 39, 83), (155, 208, 230)),
        ((235, 225, 205), (194, 71, 53)),
    ]
    for index, (background, foreground) in enumerate(palettes, start=1):
        rows = []
        for y in range(height):
            row = bytearray([0])
            for x in range(width):
                if index == 1:
                    marked = (x - 270) ** 2 + (y - 340) ** 2 < 180 ** 2
                elif index == 2:
                    marked = 100 < x < 440 and 130 < y < 510 and (x + y) % 140 < 70
                else:
                    marked = abs(x - 270) + abs(y - 340) < 220
                row.extend(foreground if marked else background)
                row.append(255)
            rows.append(bytes(row))
        png = (
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
            + chunk(b"IEND", b"")
        )
        (target / f"photo-{index}.png").write_bytes(png)
    print("Generated three synthetic photos in out/sequence-assets.")


if __name__ == "__main__":
    main()
