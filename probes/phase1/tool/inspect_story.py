#!/usr/bin/env python3
"""Inspect one phase 1 Story file and measure flash-to-tone offset.

Reuses probes/phase0/tool/inspect_story15.py for the container reading.
The offset is tone start minus flash start, in milliseconds. A positive
offset means the tone is later than the white flash.

The tone time is the start PTS of the first audio frame whose overall
RMS reaches the threshold. `astats` `reset=1` resets once per audio
frame. `length` sets the peak and valley window, not that frame and not
the `Overall.RMS_level` window. The printed spacing is the measured
frame delta. The onset is somewhere inside that frame. This is not a
platform tolerance.

Measurement uses ffprobe's sibling ffmpeg when FLUVIE_FFMPEG is set,
otherwise ffmpeg on PATH, always as a separate process.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

YAVG_THRESHOLD = 200.0
RMS_THRESHOLD_DB = -50.0
FPS = 30.0
# Fixture detector for the synthetic swatch (gold 0xF2C14E), not a
# general quality score. Counts decoded RGB pixels.
STILL_MIN = 1000
CAPTION_MIN = 20
CENTER_CHANGE_MIN = 100
STILL_AT_SECONDS = (3.0, 8.0)

PHASE0_INSPECTOR = (
    Path(__file__).resolve().parents[2] / "phase0" / "tool" / "inspect_story15.py"
)


def av_offset_ms(flash_start_ms: int, tone_start_ms: int) -> int:
    """Return how many milliseconds the tone lags the flash."""
    return tone_start_ms - flash_start_ms


def payload(line: str) -> str:
    """Drop the filter-address prefix ffmpeg prints on metadata lines."""
    marker = "] "
    index = line.rfind(marker)
    if index == -1:
        return line.strip()
    return line[index + len(marker) :].strip()


def first_yavg_ms(text: str, threshold: float, fps: float) -> int | None:
    """Return the first frame whose average luma reaches [threshold]."""
    frame: int | None = None
    for line in text.splitlines():
        body = payload(line)
        if body.startswith("frame:"):
            frame = int(body.split()[0].split(":", 1)[1])
            continue
        if frame is None or "signalstats.YAVG=" not in body:
            continue
        value = float(body.split("=", 1)[1])
        if value >= threshold:
            return round(frame * 1000 / fps)
    return None


def first_rms_ms(text: str, threshold_db: float) -> int | None:
    """Return the start PTS of the first audio frame at [threshold_db]."""
    pts_ms: int | None = None
    for line in text.splitlines():
        body = payload(line)
        if body.startswith("frame:"):
            pts_ms = None
            for part in body.split():
                if part.startswith("pts_time:"):
                    pts_ms = round(float(part.split(":", 1)[1]) * 1000)
            continue
        if pts_ms is None or "astats.Overall.RMS_level=" not in body:
            continue
        raw = body.split("=", 1)[1].strip()
        if raw in {"-inf", "inf", "nan"}:
            continue
        if float(raw) >= threshold_db:
            return pts_ms
    return None


def audio_frame_ms(text: str) -> float | None:
    """Return the first positive audio-frame spacing, in milliseconds."""
    times: list[float] = []
    for line in text.splitlines():
        body = payload(line)
        if not body.startswith("frame:"):
            continue
        for part in body.split():
            if part.startswith("pts_time:"):
                times.append(float(part.split(":", 1)[1]))
    for earlier, later in zip(times, times[1:]):
        delta = later - earlier
        if delta > 0:
            return round(delta * 1000, 2)
    return None


def self_check() -> int:
    # The prefix is what `metadata=print` writes. A parser that only accepts
    # a bare `frame:` line fails on a real ffmpeg log.
    flash_text = (
        "[Parsed_metadata_1 @ 0x1] frame:0    pts:0       pts_time:0\n"
        "[Parsed_metadata_1 @ 0x1] lavfi.signalstats.YAVG=30\n"
        "[Parsed_metadata_1 @ 0x1] frame:30   pts:15360   pts_time:1.0\n"
        "[Parsed_metadata_1 @ 0x1] lavfi.signalstats.YAVG=235\n"
    )
    tone_text = (
        "[Parsed_metadata_1 @ 0x1] frame:0    pts:0       pts_time:0\n"
        "[Parsed_metadata_1 @ 0x1] lavfi.astats.Overall.RMS_level=-inf\n"
        "[Parsed_metadata_1 @ 0x1] frame:43   pts:44032   pts_time:1.0\n"
        "[Parsed_metadata_1 @ 0x1] lavfi.astats.Overall.RMS_level=-17.0\n"
    )
    flash = first_yavg_ms(flash_text, YAVG_THRESHOLD, FPS)
    tone = first_rms_ms(tone_text, RMS_THRESHOLD_DB)
    if flash != 1000 or tone != 1000 or av_offset_ms(1000, 1000) != 0:
        print(f"self-check failed flash={flash} tone={tone}", file=sys.stderr)
        return 1
    if av_offset_ms(1000, 1040) != 40:
        print("self-check offset failed", file=sys.stderr)
        return 1
    rounded = first_rms_ms(
        "[Parsed_metadata_1 @ 0x1] frame:43   pts:44032   pts_time:0.998458\n"
        "[Parsed_metadata_1 @ 0x1] lavfi.astats.Overall.RMS_level=-17.3\n",
        RMS_THRESHOLD_DB,
    )
    if rounded != 998:
        print(f"self-check rounding failed tone={rounded}", file=sys.stderr)
        return 1
    spacing = audio_frame_ms(
        "[Parsed_metadata_1 @ 0x1] frame:0    pts:0       pts_time:0\n"
        "[Parsed_metadata_1 @ 0x1] frame:1    pts:1024    pts_time:0.0232199546\n"
    )
    if spacing != 23.22:
        print(f"self-check frame spacing failed spacing={spacing}", file=sys.stderr)
        return 1
    gold = bytes((0xF2, 0xC1, 0x4E)) * 4 + bytes((0x22, 0x44, 0x66)) * 4
    blue = bytes((0x22, 0x44, 0x66)) * 8
    if sentinel_pixels(gold) != 4 or sentinel_pixels(blue) != 0:
        print("self-check sentinel failed", file=sys.stderr)
        return 1
    print("self-check ok")
    return 0


def ffmpeg_bin() -> str | None:
    sibling = os.environ.get("FLUVIE_FFMPEG")
    if sibling:
        return sibling
    return shutil.which("ffmpeg")


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


def print_audio_stream(path: Path) -> int:
    """Print sample rate and channel count. The phase 0 inspector does not."""
    probe = ffprobe_bin()
    if probe is None:
        print("audio_sample_rate unavailable")
        print("audio_channels unavailable")
        return 1
    completed = subprocess.run(
        [
            probe,
            "-hide_banner",
            "-select_streams",
            "a:0",
            "-show_entries",
            "stream=sample_rate,channels",
            "-of",
            "default=noprint_wrappers=1",
            str(path),
        ],
        check=False,
        text=True,
        capture_output=True,
    )
    if completed.returncode != 0:
        print("audio stream probe failed", file=sys.stderr)
        if completed.stderr:
            print(completed.stderr, file=sys.stderr)
        return completed.returncode if completed.returncode > 0 else 1
    fields = {}
    for line in completed.stdout.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        fields[key] = value
    print(f"audio_sample_rate {fields.get('sample_rate', 'absent')}")
    print(f"audio_channels {fields.get('channels', 'absent')}")
    if "sample_rate" not in fields or "channels" not in fields:
        return 1
    return 0


def run_ffmpeg(binary: str, args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [binary, "-hide_banner", *args],
        check=False,
        text=True,
        capture_output=True,
    )


def run_ffmpeg_bytes(binary: str, args: list[str]) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [binary, "-hide_banner", *args],
        check=False,
        capture_output=True,
    )


def sentinel_pixels(rgb: bytes) -> int:
    """Count swatch-gold pixels. [rgb] is packed RGB24."""
    count = 0
    for index in range(0, len(rgb) - 2, 3):
        red, green, blue = rgb[index], rgb[index + 1], rgb[index + 2]
        if red > 180 and green > 120 and blue < 140:
            count += 1
    return count


def caption_ink(rgb: bytes, width: int, height: int) -> int:
    """Count near-white pixels in the lower band, where the cues sit."""
    start = int(height * 0.6) * width * 3
    count = 0
    for index in range(start, len(rgb) - 2, 3):
        red, green, blue = rgb[index], rgb[index + 1], rgb[index + 2]
        if red > 220 and green > 220 and blue > 220:
            count += 1
    return count


def changed_pixels(
    left: bytes,
    right: bytes,
    width: int,
    height: int,
    *,
    band: str,
) -> int:
    """Count pixels that differ inside one band of the two frames."""
    if band == "center":
        # Middle of the centered still. The lower edge stays above the
        # lower-third caption, so a caption change is not counted as motion.
        y0, y1 = (height * 3) // 8, (height * 11) // 20
        x0, x1 = width // 4, (width * 3) // 4
    else:
        y0, y1 = (height * 3) // 5, height
        x0, x1 = 0, width
    count = 0
    for y in range(y0, y1):
        row = y * width * 3
        for x in range(x0, x1):
            index = row + x * 3
            if left[index : index + 3] != right[index : index + 3]:
                count += 1
    return count


def video_size(path: Path) -> tuple[int, int] | None:
    probe = ffprobe_bin()
    if probe is None:
        return None
    completed = subprocess.run(
        [
            probe,
            "-hide_banner",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height",
            "-of",
            "csv=p=0:s=x",
            str(path),
        ],
        check=False,
        text=True,
        capture_output=True,
    )
    if completed.returncode != 0 or "x" not in completed.stdout:
        return None
    width_text, height_text = completed.stdout.strip().split("x", 1)
    return int(width_text), int(height_text)


def decode_rgb(binary: str, path: Path, seconds: float, width: int, height: int) -> bytes | None:
    """Decode the frame at [seconds]. `-ss` is after `-i` so the seek is exact."""
    completed = run_ffmpeg_bytes(
        binary,
        [
            "-i",
            str(path),
            "-ss",
            str(seconds),
            "-frames:v",
            "1",
            "-f",
            "rawvideo",
            "-pix_fmt",
            "rgb24",
            "pipe:1",
        ],
    )
    expected = width * height * 3
    if completed.returncode != 0 or len(completed.stdout) != expected:
        return None
    return completed.stdout


def check_pixels(binary: str, path: Path) -> int:
    size = video_size(path)
    if size is None:
        print("still_pixels_3s absent")
        print("still_pixels_8s absent")
        return 1
    width, height = size
    frames = []
    for seconds in STILL_AT_SECONDS:
        decoded = decode_rgb(binary, path, seconds, width, height)
        label = int(seconds)
        if decoded is None:
            print(f"still_pixels_{label}s absent")
            frames.append(None)
            continue
        print(f"still_pixels_{label}s {sentinel_pixels(decoded)}")
        print(f"caption_ink_{label}s {caption_ink(decoded, width, height)}")
        frames.append(decoded)
    if frames[0] is None or frames[1] is None:
        print("center_changed_pixels absent")
        print("caption_changed_pixels absent")
        return 1
    print(
        "center_changed_pixels "
        f"{changed_pixels(frames[0], frames[1], width, height, band='center')}"
    )
    print(
        "caption_changed_pixels "
        f"{changed_pixels(frames[0], frames[1], width, height, band='caption')}"
    )
    still_3 = sentinel_pixels(frames[0])
    still_8 = sentinel_pixels(frames[1])
    center = changed_pixels(frames[0], frames[1], width, height, band="center")
    ink_3 = caption_ink(frames[0], width, height)
    ink_8 = caption_ink(frames[1], width, height)
    caption = changed_pixels(frames[0], frames[1], width, height, band="caption")
    if (
        still_3 < STILL_MIN
        or still_8 < STILL_MIN
        or center < CENTER_CHANGE_MIN
        or ink_3 < CAPTION_MIN
        or ink_8 < CAPTION_MIN
        or caption < CAPTION_MIN
    ):
        print("story_pixels fail", file=sys.stderr)
        return 1
    print("story_pixels ok")
    return 0


def measure_audio(path: Path) -> int:
    """Measure one audio file. The tone time is a detected frame's PTS."""
    binary = ffmpeg_bin()
    if binary is None:
        print("ffmpeg unavailable")
        print("av_offset_ms not_measured")
        return 1
    audio = run_ffmpeg(
        binary,
        [
            "-i",
            str(path),
            "-vn",
            "-af",
            "astats=metadata=1:reset=1:length=0.02,ametadata=print",
            "-f",
            "null",
            "-",
        ],
    )
    if audio.returncode != 0:
        print("ffmpeg measurement failed", file=sys.stderr)
        if audio.stderr:
            print(audio.stderr, file=sys.stderr)
        return 1
    tone = first_rms_ms(audio.stderr, RMS_THRESHOLD_DB)
    spacing = audio_frame_ms(audio.stderr)
    print(f"tone_start_ms {tone if tone is not None else 'absent'}")
    print(f"audio_frame_ms {spacing if spacing is not None else 'absent'}")
    if tone is None or spacing is None:
        return 1
    return print_audio_stream(path)


def count_sentinel(path: Path, seconds: float) -> int:
    binary = ffmpeg_bin()
    if binary is None:
        print("ffmpeg unavailable")
        return 1
    size = video_size(path)
    if size is None:
        print("sentinel_pixels absent")
        return 1
    decoded = decode_rgb(binary, path, seconds, size[0], size[1])
    if decoded is None:
        print("sentinel_pixels absent")
        return 1
    print(f"sentinel_pixels {sentinel_pixels(decoded)}")
    return 0


def measure(path: Path) -> int:
    if not PHASE0_INSPECTOR.is_file():
        print(f"missing inspector: {PHASE0_INSPECTOR.name}", file=sys.stderr)
        return 1
    container = subprocess.run(
        [sys.executable, str(PHASE0_INSPECTOR), str(path)],
        check=False,
    )
    if container.returncode != 0:
        return container.returncode

    binary = ffmpeg_bin()
    if binary is None:
        print("ffmpeg unavailable")
        print("av_offset_ms not_measured")
        return 1
    video = run_ffmpeg(
        binary,
        [
            "-i",
            str(path),
            "-vf",
            "signalstats,metadata=print",
            "-an",
            "-f",
            "null",
            "-",
        ],
    )
    audio = run_ffmpeg(
        binary,
        [
            "-i",
            str(path),
            "-vn",
            "-af",
            "astats=metadata=1:reset=1:length=0.02,ametadata=print",
            "-f",
            "null",
            "-",
        ],
    )
    if video.returncode != 0 or audio.returncode != 0:
        print("ffmpeg measurement failed", file=sys.stderr)
        if video.stderr:
            print(video.stderr, file=sys.stderr)
        if audio.stderr:
            print(audio.stderr, file=sys.stderr)
        return 1
    # metadata=print writes to stderr.
    flash = first_yavg_ms(video.stderr, YAVG_THRESHOLD, FPS)
    tone = first_rms_ms(audio.stderr, RMS_THRESHOLD_DB)
    spacing = audio_frame_ms(audio.stderr)
    print(f"flash_start_ms {flash if flash is not None else 'absent'}")
    print(f"tone_start_ms {tone if tone is not None else 'absent'}")
    if flash is None or tone is None or spacing is None:
        print("av_offset_ms absent")
        return 1
    print(f"av_offset_ms {av_offset_ms(flash, tone)}")
    print(f"audio_frame_ms {spacing}")
    print("video_frame_ms 33")
    stream = print_audio_stream(path)
    pixels = check_pixels(binary, path)
    if stream != 0:
        return stream
    return pixels


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == "--self-check":
        return self_check()
    if len(sys.argv) == 3 and sys.argv[1] == "--audio":
        path = Path(sys.argv[2])
        if not path.is_file():
            print(f"missing file: {path.name}", file=sys.stderr)
            return 1
        return measure_audio(path)
    if len(sys.argv) == 4 and sys.argv[1] == "--sentinel-at":
        path = Path(sys.argv[2])
        if not path.is_file():
            print(f"missing file: {path.name}", file=sys.stderr)
            return 1
        return count_sentinel(path, float(sys.argv[3]))
    if len(sys.argv) != 2:
        print(
            "usage: inspect_story.py <file.mp4> | --self-check | "
            "--audio <file> | --sentinel-at <file> <seconds>",
            file=sys.stderr,
        )
        return 2
    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"missing file: {path.name}", file=sys.stderr)
        return 1
    return measure(path)


if __name__ == "__main__":
    raise SystemExit(main())
