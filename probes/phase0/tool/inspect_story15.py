#!/usr/bin/env python3
"""Inspect one encoded story file. Does not render and does not download.

Prints the file size and whether the top-level `moov` box precedes `mdat`.
When `ffprobe` is on PATH, or `FFPROBE` / `FLUVIE_FFMPEG` is set, also prints
container, codec, pixel format, and color tags. `FLUVIE_FFMPEG` may point at
an ffmpeg binary; the script looks for `ffprobe` beside it.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path


def top_level_boxes(path: Path) -> list[str]:
    boxes = []
    with path.open("rb") as handle:
        while True:
            header = handle.read(8)
            if len(header) < 8:
                break
            size = int.from_bytes(header[:4], "big")
            box_type = header[4:8].decode("latin1")
            if size == 1:
                large = handle.read(8)
                if len(large) < 8:
                    break
                size = int.from_bytes(large, "big")
                payload = size - 16
            elif size == 0:
                boxes.append(box_type)
                break
            else:
                payload = size - 8
            boxes.append(box_type)
            if payload < 0:
                break
            handle.seek(payload, os.SEEK_CUR)
    return boxes


def ffprobe_bin() -> str | None:
    chosen = os.environ.get("FFPROBE")
    if chosen:
        return chosen
    sibling = os.environ.get("FLUVIE_FFMPEG")
    if sibling:
        candidate = Path(sibling).resolve().parent / "ffprobe"
        if candidate.is_file():
            return str(candidate)
    return shutil.which("ffprobe")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: inspect_story15.py <file.mp4>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"missing file: {path}", file=sys.stderr)
        return 1
    boxes = top_level_boxes(path)
    moov = boxes.index("moov") if "moov" in boxes else None
    mdat = boxes.index("mdat") if "mdat" in boxes else None
    print(f"size_bytes {path.stat().st_size}")
    print(f"top_level_boxes {' '.join(boxes)}")
    if moov is None:
        print("moov_before_mdat absent")
    elif mdat is None:
        print("moov_before_mdat no_mdat")
    else:
        print(f"moov_before_mdat {str(moov < mdat).lower()}")

    probe = ffprobe_bin()
    if probe is None:
        print("ffprobe unavailable")
        return 0
    try:
        completed = subprocess.run(
            [
                probe,
                "-hide_banner",
                "-show_entries",
                "stream=codec_name,codec_type,profile,pix_fmt,"
                "color_space,color_transfer,color_primaries,width,height,"
                "avg_frame_rate",
                "-show_entries",
                "format=format_name,duration,size",
                "-of",
                "default=noprint_wrappers=0",
                str(path),
            ],
            check=False,
        )
    except OSError as error:
        print(f"ffprobe failed to start: {error}", file=sys.stderr)
        return 1
    if completed.returncode != 0:
        print(
            f"ffprobe failed with exit status {completed.returncode}",
            file=sys.stderr,
        )
        return completed.returncode if completed.returncode > 0 else 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
