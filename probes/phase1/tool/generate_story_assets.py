#!/usr/bin/env python3
"""Write the synthetic swatch and tone used by lib/story_12.dart.

The swatch follows probes/phase0/tool/generate_story15_assets.py. The tone
is its own file because this Story plays it as a one-shot at the flash, not
as the phase 0 bed, and because the phase 0 generator must stay as recorded.
This script does not download anything and it does not write the encoded video.
"""

import math
import struct
import wave
import zlib
from pathlib import Path


def chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def main() -> None:
    root = Path(__file__).resolve().parents[1] / "assets"
    root.mkdir(parents=True, exist_ok=True)

    width = height = 540
    rows = []
    for y in range(height):
        row = bytearray([0])
        for x in range(width):
            # Distinct blocks so a 1.08 scale changes pixels inside the image.
            if 40 <= x < 180 and 40 <= y < 180:
                row += bytes((0x11, 0x22, 0x33, 0xFF))
            elif x > y:
                row += bytes((0xF2, 0xC1, 0x4E, 0xFF))
            else:
                row += bytes((0x3A, 0x7C, 0xA5, 0xFF))
        rows.append(bytes(row))
    raw = b"".join(rows)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    swatch = root / "swatch.png"
    swatch.write_bytes(png)

    rate = 44100
    # Longer than the scene on purpose. fluvie 0.3.1 passes -shortest to
    # ffmpeg, so a one-shot that ends first cuts the video with it. This
    # tone starts one second in and still reaches the end of the scene.
    seconds = 12
    tone = root / "tone.wav"
    with wave.open(str(tone), "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(rate)
        frames = bytearray()
        for i in range(rate * seconds):
            sample = int(0.2 * 32767 * math.sin(2 * math.pi * 440 * i / rate))
            frames += struct.pack("<h", sample)
        handle.writeframes(frames)

    print(f"png {swatch.name} {swatch.stat().st_size}")
    print(f"wav {tone.name} {tone.stat().st_size}")


if __name__ == "__main__":
    main()
