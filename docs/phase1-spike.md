# Phase 1 Story spike

Results from 2026-11-11. This is a measurement record for one synthetic Instagram Story. It does not adopt a dependency, and it does not replace `docs/evaluation.md`.

Packages: `fluvie` 0.3.1, `fluvie_cli` 0.3.1, `fluvie_mobile_encoder` 0.3.1. The scene is `probes/phase1/lib/story_12.dart`.

## The piece

Twelve seconds authored, 1080×1920, 30 fps, 360 frames. A one-second dark lead-in, a 200 ms full-frame white flash, then a synthetic still that scales (`Animation.kenBurns(zoom: 1.08)`). A generated tone is authored to start with the flash. Burned-in captions come from `probes/phase1/assets/transcript.srt`. The cover is the frame at three seconds, inside the first cue.

The still and the tone are produced by `probes/phase1/tool/generate_story_assets.py`. They are gitignored. The tone is twelve seconds because `fluvie` 0.3.1 appends `-shortest` in `lib/src/rendering/encoding/ffmpeg_args.dart`. A one-shot that ends first cuts the video with it. An earlier encode in this same run used an eight-second tone, started at one second, and the file was 9.000 seconds. That misses the 10–15 second spike window. The recorded file is the encode after the tone was lengthened. The short file was not kept.

## Headless encode

From `probes/phase1`, with `fluvie_cli` 0.3.1. `--no-download` was set, and `--ffmpeg` pointed at a local binary, so the CLI did not fetch one. That binary's version line is `ffmpeg version 8.1.2`. Its configuration includes `--enable-gpl` and `--enable-libx264`. It ran as a separate process. This is not the archive whose SHA-256 is in `docs/dependencies.md`, and that SHA was not re-checked against this binary.

```sh
python3 tool/generate_story_assets.py
fluvie render lib/story_12.dart --out out/story12.mp4 --poster 3s --no-download
python3 tool/inspect_story.py out/story12.mp4
```

`fluvie render` reported 360 frames captured. The encoded file and the poster still are gitignored.

Inspector output for the recorded file:

```text
codec_name=h264
profile=High
width=1080
height=1920
pix_fmt=yuv420p
color_space=unknown
color_transfer=unknown
color_primaries=unknown
avg_frame_rate=30/1
codec_name=aac
profile=LC
format_name=mov,mp4,m4a,3gp,3g2,mj2
duration=12.000000
size=306462
size_bytes 306462
top_level_boxes ftyp free mdat moov
moov_before_mdat false
flash_start_ms 1000
tone_start_ms 998
av_offset_ms -2
audio_frame_ms 23.22
video_frame_ms 33
audio_sample_rate 44100
audio_channels 1
still_pixels_3s 138571
caption_ink_3s 1292
still_pixels_8s 148954
caption_ink_8s 1757
center_changed_pixels 13450
caption_changed_pixels 21112
story_pixels ok
```

`ffprobe` also reported the video as H.264 High, `yuv420p` progressive, 30 fps, and the audio as AAC-LC, 44100 Hz, mono. The exit status was 0.

A frame at eight seconds shows the second cue, "from a supplied transcript". The poster still at three seconds shows the first cue, "A synthetic caption". The cover is that frame inside the piece. The share page does not document a second cover file.

## Sharing to Stories

Source for the gates: Sharing to Stories, last updated 2026-06-30, checked 2026-11-11, as recorded in `docs/platform-requirements.md`. Phase 1 follows the share column. The publishing API is not a gate. Neither file was handed to Instagram. A Facebook App ID is a requirement of that hand-off, not a property of the file.

This table is the headless file.

| Check | Published on the share page | Measured | Reading |
| --- | --- | --- | --- |
| Video codec | H.264, H.265, or WebM | H.264 High | Meets the list. H.265 and WebM were not encoded |
| Duration | Up to 20 seconds. The spike window is 10–15 seconds | 12.000 seconds | Meets both |
| Pixels | Videos can be 1080p. The page does not define that pixel size. Android background-asset cell: minimum 720×1280. The iOS video row does not repeat 720×1280 | 1080×1920 | The Android minimum is met. 1080×1920 is a 9:16 frame at a 1920 long edge |
| iOS file size | Under 50 MB recommended | 306,462 bytes | Under 50 MB |
| Android file size | Not published | 306,462 bytes | Not a gate |
| Audio codec, sample rate, channels | Not published | AAC-LC, 44100 Hz, 1 channel | Recorded, not a gate |
| Container, `moov`, pixel format, color tags, frame rate, H.264 profile | Not published | MP4, `moov` after `mdat`, `yuv420p`, color tags `unknown`, 30 fps, High | Recorded, not gates |
| Cover | Not published as a separate file | Frame at 3 seconds | Inside the piece |
| Sticker | Only if one is sent | None | Not sent |
| UI safe zone | Not published | No inset applied | No number to meet |

## Audio and video offset

The inspector reuses the phase 0 container reading, then measures the flash and the tone with `ffmpeg` as a separate process.

The flash time is the first frame whose `signalstats` average luma (`YAVG`) is at least 200, converted with `round(frame * 1000 / 30)`. On the short encode, the dark lead-in measured about 30 and the white frames measured 235, so 200 sits between them. The tone time is the start PTS of the first audio frame whose overall RMS level is at least −50 dB. Silence before the tone measured as `-inf` or about −95 dB. The offset is tone start minus flash start. Positive means the tone's detected frame starts later than the flash.

`astats` is run as `metadata=1:reset=1:length=0.02`. `reset=1` resets the filter once per audio frame. `length=0.02` sets the peak and valley window. It does not set the frame size, and it does not set the `Overall.RMS_level` window. An earlier print from this same estimator labeled the result `audio_window_ms 20`. That label described the `length` parameter. On this file each analyzed frame is 1024 samples at 44100 Hz, and the measured spacing is 23.22 ms. The printed tone time is the start of the frame that crossed the threshold. The onset is somewhere inside that frame, so the uncertainty is one audio frame. Sharing to Stories does not publish a sync tolerance. This row is a measurement, not a pass against a platform limit, and it is not an Instagram tolerance.

On the headless file the flash is at 1000 ms and the tone frame starts at 998 ms. The offset is −2 ms. That is the same estimator as the earlier −2 ms result. The detected frame starts 2 ms before the authored flash. One video frame at 30 fps is about 33 ms.

The same command decodes the frames at three and eight seconds. `still_pixels` counts a fixture sentinel for this swatch, `r>180`, `g>120`, `b<140`. It is not a general quality score. The headless file has 138,571 such pixels at three seconds and 148,954 at eight seconds. `center_changed_pixels` counts pixels that differ in the middle of the centered still, above the lower-third caption, so a caption change is not counted as motion. That band changes by 13,450 pixels. `caption_ink` counts near-white pixels in the lower band. Both cues have ink, and that band changes by 21,112 pixels. `story_pixels ok` means those checks passed.

## On-device functional check

`integration_test/render_story_test.dart` calls `OnDeviceVideoRenderer` from `fluvie_mobile_encoder` 0.3.1 with `Aspect.reels`, a 1920 long edge, and `audio: true`. The default codec in that API is H.264. The host under `probes/phase1/android/` exists so the test can build. It is not a product app.

The run was on an Android emulator. It shows that this path encoded a file. It does not count for P1, D2, or on-device quality. Those stay not verified until phones are available. A result here does not stand in for a phone.

`fluvie` 0.3.1 pre-resolves images on the aspect path and does not pre-resolve captions. The CLI path does. A run without `preResolveCaptions` threw `FluvieRenderException` once per frame (360) while building the caption layer and kept no file. The file below is the run that calls `preResolveCaptions` on a resolver from `resolverScope` and passes that resolver in. That call is part of the test. It does not change `fluvie`. An application on 0.3.1 does not make it, so the aspect path still throws on the caption layer and keeps no file.

The test copies the finished file into the platform temporary directory and into the app cache, then uninstalls the host when it finishes. The measurements below are the cache copy from the encode before the schedule flush, read before uninstall. The file is gitignored.

Inspector output. The container lines below are from the corrected inspector. The command's exit status is 1 because the still check fails:

```text
codec_name=h264
profile=Constrained Baseline
width=1080
height=1920
pix_fmt=yuv420p
color_space=unknown
color_transfer=unknown
color_primaries=unknown
avg_frame_rate=30/1
codec_name=aac
profile=LC
format_name=mov,mp4,m4a,3gp,3g2,mj2
duration=12.051156
size=549126
size_bytes 549126
top_level_boxes ftyp free mdat moov
moov_before_mdat false
flash_start_ms 1000
tone_start_ms 1045
av_offset_ms 45
audio_frame_ms 23.22
video_frame_ms 33
audio_sample_rate 44100
audio_channels 2
still_pixels_3s 0
caption_ink_3s 867
still_pixels_8s 0
caption_ink_8s 1163
center_changed_pixels 0
caption_changed_pixels 7024
```

The corrected inspector exits 1 on this file (`story_pixels fail`). The container and the offset lines are the same estimator as the earlier record. `audio_frame_ms 23.22` replaces the earlier `audio_window_ms 20` label. The tone frame starts at 1045 ms, 45 ms after the flash, and the onset is somewhere inside the following 23.22 ms. The swatch sentinel is 0 at both sampled times, and the still's center band does not change. The caption ink is present and the caption band changes, so the cues are in the file and the still is not. A container header would have accepted this file. It does not meet the phase 1 shape.

`ffprobe` also reported H.264 Constrained Baseline, `yuv420p` progressive, 30 fps, and AAC-LC, 44100 Hz, stereo. The generated tone is mono. The device file has 2 channels.

A frame at three seconds shows "A synthetic caption". A frame at eight seconds shows "from a supplied transcript". The same two times on the headless file also show the synthetic still. Those still colors are absent from the two device frames. The device frames show the scene background and the burned-in cue.

Against the same share page: H.264 meets the codec list. 12.051 seconds meets the 10–15 second spike window and the 20 second maximum. 1080×1920 meets the Android 720×1280 minimum. 549,126 bytes is under 50 MB. Profile, channel count, container, `moov`, pixel format, color tags, and frame rate are recorded and are not gates. No sticker was sent. No safe-zone inset was applied.

The flash is at 1000 ms and the detected tone frame starts at 1045 ms. The offset is +45 ms. That is outside one 33 ms video frame. The uncertainty on the tone is one 23.22 ms audio frame, which does not bring the detected start back to the flash. Sharing to Stories does not publish a sync tolerance. This is a measurement, not a pass against a platform limit.

`fluvie` 0.3.1 resolves motion in a post-frame callback. Until that callback runs, an animated child is painted at opacity 0. `OffscreenCaptureHost` builds and paints without draining the callback, which matches this file: the scene background and the captions are present, and the animated still is not. The file above is that encode.

## On-device encode after the schedule flush

The integration test passes a capture host that drains that callback once after mount. The host throws unless the binding is `LiveTestWidgetsFlutterBinding` and the scheduler is idle, so the drain exists only in this test. It does not change `fluvie`. `OffscreenCaptureHost` in an application still paints an animated child at opacity 0. The test fails when the captured raw frames do not contain the still, when the still's center band does not change, or when either cue leaves no caption ink. A container header is not acceptance.

On the run that drains the callback, the raw frames counted 139,320 swatch-sentinel pixels at three seconds and 149,730 at eight seconds. The center band changed by 5,456 pixels. Caption ink was 889 and 1,180, and the caption band changed by 13,501 pixels. The test passed. Those counts are the frames before the hardware encoder.

The encoded file was read from the app cache before uninstall. It is gitignored. The corrected inspector exits 0:

```text
codec_name=h264
profile=Constrained Baseline
width=1080
height=1920
pix_fmt=yuv420p
color_space=unknown
color_transfer=unknown
color_primaries=unknown
avg_frame_rate=30/1
codec_name=aac
profile=LC
format_name=mov,mp4,m4a,3gp,3g2,mj2
duration=12.051156
size=1555349
size_bytes 1555349
top_level_boxes ftyp free mdat moov
moov_before_mdat false
flash_start_ms 1000
tone_start_ms 1045
av_offset_ms 45
audio_frame_ms 23.22
video_frame_ms 33
audio_sample_rate 44100
audio_channels 2
still_pixels_3s 139117
caption_ink_3s 869
still_pixels_8s 149374
caption_ink_8s 1162
center_changed_pixels 6404
caption_changed_pixels 14970
story_pixels ok
```

`ffprobe` also reported H.264 Constrained Baseline, `yuv420p` progressive, 30 fps, and AAC-LC, 44100 Hz, stereo. The generated tone is mono. Decoding the encoded frames still finds the swatch: 139,117 sentinel pixels at three seconds and 149,374 at eight seconds, against 138,571 and 148,954 on the headless file. The center band changes. Both cues have ink, and the caption band changes.

Against the same share page: H.264 meets the codec list. 12.051 seconds meets the 10–15 second spike window and the 20 second maximum. 1080×1920 meets the Android 720×1280 minimum. 1,555,349 bytes is under 50 MB. Profile, channel count, container, `moov`, pixel format, color tags, and frame rate are recorded and are not gates. No sticker was sent. No safe-zone inset was applied. The file was not handed to Instagram.

The flash is at 1000 ms and the detected tone frame starts at 1045 ms. The offset is +45 ms, the same estimator result as the file that lacked the still. The uncertainty on the tone is one 23.22 ms audio frame. Sharing to Stories does not publish a sync tolerance. This is a measurement, not a pass against a platform limit.

The flushed file has the phase 1 shape: the still, its motion, the burned-in cues, and the tone marker. The schedule flush that put the still on screen runs only inside the Flutter test binding and throws for any other binding. On `fluvie` 0.3.1 an application still exports without the animated still, because `OffscreenCaptureHost` does not drain that callback, and without the burned-in cues, because the aspect path does not pre-resolve captions. Those two gaps are an upstream contribution or a thin package beside `fluvie`. This remains a functional check on an emulator. It does not count for P1, D2, or on-device quality.

## Known limits

The Lottie clock and iOS in-composition video clips were not exercised. `docs/evaluation.md` records both. Peak memory, heat, and backgrounding during a render were not measured. The encode from before the schedule flush does not show the synthetic still. The encode that drains the callback does, and that drain exists only in the test. Neither result is a phone measurement. `fluvie` 0.3.1 on a device still needs the caption pre-resolve and the motion callback drained outside the test binding.
