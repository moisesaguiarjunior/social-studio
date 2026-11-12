# Phase 0 evaluation

Status of this document:

- **Criteria locked:** 2026-11-11, before any package was fetched, any source tree was opened for this evaluation, or any probe was run. The criteria section below is that locked text.
- **Results filled:** 2026-11-11, in a later commit. Scores use the locked criteria. They were not edited to match the probes.
- **Labels narrowed:** 2026-11-11, after independent review of the results commit. The criteria section was not edited. L1 is no longer labeled pass. The G1 network clause is not verified, so G1 is not an aggregate pass. The recommendation is a candidate for partial adoption, to validate on the phase 1 mobile prototype.
- **What this is:** an evaluation record. It does not adopt a dependency. Adopting one is a later decision, recorded in `docs/decisions/` when it is made.

Base of the branch: local `docs/contribution-standards` at `6f601d7` (itself ahead of published `origin/main` at `8a84e43`). This evaluation does not republish that branch.

## Question

Can the reference renderer use Fluvie for on-device video, with Lottie as the art and motion layer inside a Fluvie composition? If not, do the fallback encoders cover the phase 1 shape (one photo, slow motion, a voice track, burned-in captions, a cover frame)?

The recommendation at the end must be one of: **adopt and contribute**, **adopt partially**, or **fork**.

## Candidates

Evaluate the current published release of each package on the day the results are collected. Record the exact version, publication date, and source revision before running probes. Do not upgrade mid-evaluation.

| Candidate | Role in this evaluation |
| --- | --- |
| `fluvie` | Composition model and frame capture |
| `fluvie_mobile_encoder` | On-device encode, Android and iOS, no bundled FFmpeg |
| `fluvie_cli` | Headless capture and encode; downloads an FFmpeg build |
| `fluvie_web_encoder` | In-browser encode |
| Flutter `lottie`, plus the web and React players that would render the same art | Art and motion layer: dynamic text and images, inside a Fluvie composition |
| `widget_recorder_plus` | Fallback only |
| `flutter_quick_video_encoder` | Fallback only |

Fallbacks get a full render benchmark only if Fluvie fails a blocking criterion or cannot produce the phase 1 shape. Otherwise record license, capability, and maintenance, and stop.

## How a criterion is scored

Each criterion ends as **pass**, **fail**, or **not verified**.

- **Pass** and **fail** require evidence: command, version, and output, or a file and line in the version under test.
- **Not verified** is the result when the environment cannot run the check. It is not a pass. A recommendation must say which blocking criteria are unverified.
- Marketing text, README claims, and "bit-exact" comments are leads, not evidence, until reproduced or confirmed in the source of the pinned version.

Blocking criteria for "adopt and contribute" as the on-device reference path: L1, L2, D1, G1 (the phase 1 shape). A fail on any of those blocks that recommendation. Performance (P1) blocks the on-device default only when a qualifying device was actually measured and missed the reject line.

## Criteria

### L1 — Package licenses

**Pass** when every direct dependency that would ship in a Social Studio package, and every binary a tool downloads, is under a permissive license (MIT, BSD-2-Clause, BSD-3-Clause, Apache-2.0, ISC, or MPL-2.0 with the file-level obligations written down).

**Fail** when a distributed package depends on GPL or AGPL code, or when a required downloaded binary is GPL or AGPL and is linked into an app or a package we ship.

Record the license name, the copyright holder, where it was read (repository `LICENSE` file or the packager's license file), and the date.

### L2 — FFmpeg and other downloaded binaries

The CLI is documented as downloading an FFmpeg build. The web encoder is documented as using ffmpeg.wasm. Treat both as dependencies.

**Pass** for the on-device reference path when the mobile encoder does not bundle FFmpeg or any other encoder binary, and encoding goes through the platform API.

**Pass** for the headless tool when the downloaded FFmpeg is invoked as a separate process, its license is LGPL or a permissive license, and the exact URL, version, and checksum are recorded. LGPL as a separate process is acceptable for a developer tool. It is not acceptable inside an app binary.

**Fail** when the mobile or distributed package path statically links FFmpeg, bundles a GPL build, or the checksum cannot be found in the pinned source.

### D1 — Same machine, same frames

Protocol, fixed before any render:

1. One synthetic composition, authored for the probe: 1080×1920, 30 fps, 2.0 seconds (60 frames). Content is generated in the probe (flat colors, one text run, one moving rectangle). No photograph of a person, no recorded voice, no third-party asset.
2. Render twice on the same machine, same Flutter version, no code change, cache left as the tool leaves it.
3. Compare **raw frames** (PNG or uncompressed pixels), not the MP4. Hardware encoders are not required to be byte-identical.

**Pass:** SHA-256 of every raw frame matches across the two runs.

**Fail:** any frame hash differs.

Encoded output is a separate observation:

- Software encode that claims bit-exact, single-thread flags: record whether the file SHA-256 matches. A mismatch fails file identity and does not, by itself, fail D1 if the raw frames matched.
- Hardware encode: file identity is not required.

### D2 — Headless versus on-device

Run the same 60-frame job headless and on a device. Decode or capture frames and compute the maximum per-channel absolute difference.

**Pass** for a single conformance golden shared by both paths: maximum difference ≤ 2 on flat color regions, and ≤ 16 on text edges with fewer than 0.5% of pixels above 16.

**Fail** for a shared golden when those bounds are exceeded. The engine can still be adopted with separate goldens per path. That outcome is recorded; it does not by itself force a fork.

**Not verified** when no device run exists.

### Q1 — Picture at 1080×1920

On the software (headless) path, for one synthetic frame of the 60-frame job:

- Output size is exactly 1080×1920.
- A probe-drawn rectangle of known sRGB color `#E23D3D` reads back within ±2 per channel at its center.
- A text run containing `Ag` and `Á`, drawn at 64 px inside an 80 px inset, is not a blank region: the inset box contains pixels that differ from the background. The PNG is kept so a reviewer can read the glyphs. There is no subjective beauty score.

**Fail** when the size is wrong, the color is outside tolerance, or the text region is indistinguishable from the background.

On-device quality uses the same checks when a device is available. Otherwise **not verified**.

### P1 — Fifteen seconds on a phone

Reference job, separate from the 60-frame determinism job:

- Duration 15.0 s, 1080×1920, 30 fps (450 frames).
- One synthetic still image (generated gradient), a slow scale from 1.00 to 1.08, burned-in caption text, and a synthetic tone as the voice track (440 Hz, generated in the probe, 15 s). No Lottie in this job, so the number is the engine.

Device classes, fixed before knowing what is attached:

- **Mid-range Android:** a phone in the 2022–2024 mid tier. Examples that qualify: Pixel 6a, Galaxy A54, Moto G84. A flagship (Pixel 8 Pro class and above, Galaxy S23 class and above) does not qualify. Record model, Android version, and whether it was a profile or release build.
- **iPhone:** a non-Pro phone sold as a mainstream model in the last four years. Examples that qualify: iPhone 13, iPhone SE (3rd generation), iPhone 14, iPhone 15, iPhone 16. A Pro or Pro Max does not qualify. Record model and iOS version.

Targets, proposed for this evaluation (maintainers had not published numeric targets; these are not a product decision):

| Wall-clock time for the 15 s job | Meaning |
| --- | --- |
| ≤ 15 s | Preferred. Meets realtime. |
| ≤ 45 s | Acceptable for the on-device default. |
| > 90 s | Reject the on-device path as the default. Partial adoption can still use a shorter preview or a lower resolution. |

Between 45 s and 90 s is a recorded weakness, not a hard fail.

Headless on the developer machine: record the time. **Fail** the contributor-experience check only if the 15 s job does not finish within 10 minutes. No other headless time target.

**Not verified** when the only machine available is a simulator, an emulator, or a flagship outside the classes above. Report those runs as extra evidence, outside P1.

### G1 — Phase 1 shape

The phase 1 spike needs all of the following from the adopted engine. Each is **pass**, **fail**, or **not verified**, with evidence:

| Capability | What counts as pass |
| --- | --- |
| Still image with slow motion | A synthetic image scales over time and two frames at different timestamps differ inside the image region |
| Voice track | The synthetic tone is present in the output media (non-silent audio stream) and the duration stays within one frame of 15.0 s at 30 fps |
| Burned-in captions | Caption text is pixels in the frame, not only a sidecar subtitle file |
| Cover frame | A frame at t = 0 can be exported as an image without a second composition |
| No network during render | The render process makes no network call. A download that happens once at tool install is not a render-time call; record it separately |

### G2 — Known gaps to confirm or refute

Answer from the pinned source first, then with a probe when one can be built. The questions are:

1. Are video clips inside a composition implemented on **iOS on-device**? A desktop or Android implementation does not answer this.
2. What audio mixing exists on-device: multiple tracks, per-track gain, delay, trim, fade, looping beds? Which of those are implemented on Android, on iOS, and headless?
3. Can a Lottie composition supply **dynamic text** and a **dynamic image** at runtime in the Flutter player, and in the web and React players, for one synthetic Lottie JSON authored in this evaluation?
4. Can that Lottie widget sit inside a Fluvie scene and appear in a captured frame, with its animation advanced (frame 0 and a later frame differ inside the Lottie region)?

A gap that phase 1 does not need (video clips, Lottie) does not fail G1. It limits the recommendation to **adopt partially** when the gap is real and unfixed, and to **adopt and contribute** when the gap is localized enough that an upstream patch is the plan.

### H1 — Maintenance and the cost of contributing

Record, with the date checked and the URL:

- publication date of the pinned version, date of the first release, date of the last commit on the default branch;
- number of human committers with commits in the 6 months before the check date;
- whether automated tests exist in the repository, and whether CI is visible;
- whether issues and pull requests are open, and the time to a first human response on the 10 most recent issues (skip bots);
- whether a CONTRIBUTING file exists and an external patch can be tested without private infrastructure.

These thresholds were set with the criteria, before the counts were collected:

- **Risk flag, not a fork by itself:** one committer, and no commit in the 6 months before the check, and an open bug on a capability this project needs.
- **Fork** only if the license blocks use (L1/L2 fail with no permissive alternative), or the project is gone, or a maintainer has refused the change we need and the change cannot live in a thin package beside upstream.
- **Adopt and contribute** when L1, L2, D1, and G1 pass, and any G2 gap we care about is isolated to a module we can patch upstream.
- **Adopt partially** when G1 passes but a G2 gap, D2, or an unverified P1 means we ship phase 1 on a subset (for example still, voice, and burned-in text, without video clips or without a shared golden).

### Out of scope for the probes

- Real photos, voices, or transcripts.
- Posting to a social network.
- A conformance suite, JSON Schemas, or a production renderer. Those are later phases.
- Choosing numeric product targets beyond the table in P1. The P1 numbers are evaluation gates only.

## Results

Collected 2026-11-11. Versions were read from the pub.dev API before the probes and were not upgraded after that.

| Package | Version | Published |
| --- | --- | --- |
| `fluvie`, `fluvie_mobile_encoder`, `fluvie_cli`, `fluvie_web_encoder` | 0.3.1 | 2026-07-16 |
| `lottie` (Flutter) | 3.8.2 | 2026-11-02 |
| `widget_recorder_plus` | 1.0.6 | 2026-09-24 |
| `flutter_quick_video_encoder` | 1.7.2 | 2024-09-20 |

The published 0.3.1 tree is the one under test. The Fluvie default branch had been pushed later (2026-10-07, commit `10e442c1bb` on GitHub). That unreleased tree was not probed.

### Machine and what it is not

- A local development machine (desktop, not a phone).
- Flutter 3.47.9, framework `c197ca5199` (2026-10-29), engine `89c39edfdf` (2026-10-27), Dart 3.13.7, channel stable.
- Headless captures used `flutter_tester` with `--enable-software-rendering --skia-deterministic-rendering --use-test-fonts --disable-asset-fonts`.
- `flutter devices` on 2026-11-11: a desktop target and a browser. No phone. An emulator was listed offline and was not started.

This desktop is not a P1 phone. Numbers below are headless evidence.

Published `main` when these results were written was `59ecc84`.

### L1 — Package licenses — fail clause not met; pass list missed by two licenses

The fail clause is GPL or AGPL in a distributed package, or a GPL/AGPL binary linked into an app or a shipped package. No package LICENSE opened for this evaluation was GPL or AGPL. Missing the fail clause does not prove the pass clause.

The pass clause names MIT, BSD-2-Clause, BSD-3-Clause, Apache-2.0, ISC, and MPL-2.0 with its file-level obligations written down. Two licenses in the inventory are outside that list. They are exceptions, with the reason beside each one. They are not L1 passes.

**Exception: SIL Open Font License 1.1.** `fluvie` 0.3.1 ships JetBrains Mono (`fonts/OFL.txt`, copyright 2020 The JetBrains Mono Project Authors). OFL is not GPL or AGPL. The font may be bundled with software when the license text is kept and the reserved font name is not reused. The package that would ship contains this font, so the exception is inside the candidate, not only in a fallback.

**Exception: Unlicense.** `flutter_quick_video_encoder` 1.7.2 is Unlicense. It is a fallback encoder. It was not benchmarked and it is not a dependency of `fluvie`. It is outside the pass list. It is not GPL or AGPL.

Every other Dart package LICENSE opened for the candidates, their direct dependencies, and the probe lock is MIT, BSD-3-Clause, or Apache-2.0. The file list is `docs/dependencies.md`.

### L2 — FFmpeg and other downloaded binaries — pass on device, fail for the CLI and the web core

**On-device encoder: pass**, from the published 0.3.1 sources. `ios/Classes/FluvieMobileEncoderPlugin.swift` encodes with `AVAssetWriter` and VideoToolbox and states there is no FFmpeg and no bundled codec. `android/.../FluvieMobileEncoderPlugin.kt` encodes with `MediaCodec` and `MediaMuxer` and states the same. The podspec says "No FFmpeg, no bundled codec, no network." No device encode was run, so this pass is a source reading of the package that would ship, not a phone measurement.

**Headless CLI: fail.** The pin in `fluvie_cli` 0.3.1 `lib/src/ffmpeg/ffmpeg_release.dart` is labeled `FFmpeg 8.1 GPL (BtbN 2026-05-31, evermeet, osxexperts)`. That file lists one archive per host. One of those archives was downloaded and checked on 2026-11-11. Its size was 22,547,387 bytes and its SHA-256 was `ebb82529562b71170807bbc6b0e7eb4f0b13af8cbb0e085bb9e8f6fe709598ad`, both matching its pin. `ffmpeg -version` reports FFmpeg 8.1 and `--enable-gpl --enable-libx264` together with `--pkg-config-flags=--static`. The other archives in that file were not downloaded.

The binary is invoked as a separate process. Its license is GPL, not LGPL or a permissive license, so the headless pass condition is not met. The binary was not copied into this repository.

**Web encoder: fail** for the same reason. The package README and `example/web/index.html` load `@ffmpeg/ffmpeg`, which fetches an FFmpeg core. npm registry on 2026-11-11: `@ffmpeg/core` 0.12.10 is `GPL-2.0-or-later`; `@ffmpeg/ffmpeg` 0.12.15 and `@ffmpeg/util` 0.12.2 are MIT. The core was not downloaded and the web encoder was not run. The GPL identifier is the registry license field.

### D1 — Same machine, same frames — pass

Command, from `probes/phase0`, after `flutter pub get`:

```sh
flutter test test/determinism_test.dart --reporter expanded
```

The test calls `renderVideo` twice on one synthetic 1080×1920, 30 fps, 2.0 s composition (flat `#E23D3D`, the text `Ag Á` in Roboto at 64 px, one rectangle moving on a Fluvie `Animation.fromTo`). Host: `tester.runAsync`, `pumpFrame: () => tester.pump()` (zero duration, the same shape as the CLI harness).

Both captures were 497,664,000 bytes (1080 × 1920 × 4 × 60). SHA-256 of each raw buffer:

`14200943e85286bdab40941695b3a2f2ab8e7bb8ae19fc3a5a465e37d474e90a`

The test also requires the center pixel of frame 0 to be `0xE23D3D`, more than 50 non-background pixels in the text box (measured 2600), and frame 0 bytes different from frame 59. It passed in about 50 seconds of test time.

`evidence/frame0.png` and `evidence/frame59.png` are those two frames. The rectangle is on the left in frame 0 and on the right in frame 59. The glyphs `Ag Á` are readable in both.

A separate observation, not the D1 proof: two headless encodes of the 2-second shape job produced byte-identical MP4 files (SHA-256 `13f4a275f9d557a6e962ce3a54c679a7e9fe5dfddbc3bd12f1b7e12030442c4c`). The encode plan includes `libx264` and the bitexact flags in `ffmpeg_args.dart`.

### D2 — Headless versus on-device — not verified

No device run.

### Q1 — Picture at 1080×1920 — pass headless, not verified on device

The D1 capture is 1080×1920. The center pixel reads back as `#E23D3D` (difference 0, inside ±2). The text region is not blank (2600 pixels). The PNGs are in `probes/phase0/evidence/`.

### P1 — Fifteen seconds on a phone — not verified

No Pixel 6a, Galaxy A54, Moto G84, iPhone 13, iPhone SE (3rd generation), iPhone 14, iPhone 15, or iPhone 16 was attached. The desktop timing below is outside P1.

**Headless contributor check: pass.** The 15.0 s job (1080×1920, 30 fps, 450 frames, generated swatch, `Animation.kenBurns(zoom: 1.08)`, caption `Hello`, 440 Hz tone) finished in **13.67 s** wall time (`time -p` real) on 2026-11-11, from 18:52:51Z to 18:53:06Z. The limit is 10 minutes. The command that was timed, from a throwaway project:

```sh
fluvie render lib/story_15.dart --out story15.mp4 --poster 0s
```

That project was deleted after the measurements were written down. The scene is now `probes/phase0/lib/story_15.dart`. The timed copy used absolute paths to the generated swatch and tone. The repository copy uses `assets/swatch.png` and `assets/tone.wav`, written by `probes/phase0/tool/generate_story15_assets.py`. The FFmpeg binary and the MP4 are not in the repository. Container, codecs, color tags, `moov` position, and file size are inspected with `probes/phase0/tool/inspect_story15.py`. Those properties were not re-measured for this note, so they stay not verified. The numbers in this section are from the 2026-11-11 run.

`fluvie` was `dart pub global activate fluvie_cli 0.3.1`. `FLUVIE_FFMPEG` pointed at the verified binary above so the render did not download it again. The output is 15.00 s, 450 frames, 1080×1920 H.264 at 30 fps, AAC mono. `volumedetect` reported mean −17.0 dB and max −13.6 dB.

### G1 — Phase 1 shape — four media checks passed headless; the no-network check is not verified

| Capability | Result | Evidence |
| --- | --- | --- |
| Still image with slow motion | pass | Decoded frame 0 and frame 300 of the 15 s file differ in 71,773 of 490,000 pixels (14.65%) inside the center 700×700. The composition is `Image.file` of a generated 540×540 swatch plus `Animation.kenBurns(zoom: 1.08)`. |
| Voice track | pass | AAC stream present. Duration 15.00 s, inside one frame of 15.0 s at 30 fps. Mean volume −17.0 dB on the 440 Hz tone. |
| Burned-in captions | pass | `Captions.words` with `Hello` at time zero is pixels on the cover. See `evidence/shape-poster.png`. It is not a sidecar file. |
| Cover frame | pass | `--poster 0s` wrote `short.poster.png` from the same composition. The D1 probe also wrote frame 0 as a PNG from the raw capture. |
| No network during render | not verified | During the 2 s encode and the 15 s encode, `lsof` showed no established TCP connection whose command matched flutter, dart, ffmpeg, or fluvie. That sample can miss a short connection, UDP, and a failed attempt. No control job deliberately opened a connection. The FFmpeg download happened earlier, at tool setup, and is recorded under L2. The media-less D1 capture does not build a media resolver (`render_video.dart`). |

The four media rows passed on this headless path. The no-network row did not. G1 requires each row to pass, so G1 is not an aggregate pass.

The first CLI attempt failed in 4.4 s because a hand-written pubspec omitted `flutter_test` and `alchemist` (both are in the `fluvie init` scaffold; the harness imports them) and because `Image` was imported from Flutter and from Fluvie. After those two fixes the 2 s render completed in 8.18 s and wrote the MP4 and the poster.

### G2 — Known gaps

1. **iOS video clips: not implemented.** `FluvieMobileEncoderPlugin.swift` handles only the method `encode`; anything else returns `FlutterMethodNotImplemented`. `native_frame_extraction_service.dart` maps `MissingPluginException` to code `unimplemented` with the message "On-device frame extraction is not available on this platform (Android only)." The README (lines 125–127) says the same. No iPhone was available, so this was not also shown at runtime. Image and text are a separate path and the README says those render on both platforms. That second sentence was not run on a device.
2. **Audio mixing.** iOS `AudioComposer.swift` and Android `AudioMixEncoder.kt` both carry delay, volume, trim, fade-in, fade-out, and loop. The README still says "Looping beds and network sources are not honored on-device yet," which is behind those sources on looping. `BundleAudioMaterializer` throws `unsupported_audio_source` for `http://` and `https://` and tells the caller to use a `NetworkAudioMaterializer` with an allowlist. Headless mixing is the FFmpeg `amix` plan and needs the GPL binary. Runtime evidence is one headless music file, non-silent. Multiple tracks, per-track gain, delay, trim, fade, and loop were not run.
3. **Dynamic Lottie text and image.** Flutter `LottieDelegates.text` changed the painted pixels of a synthetic composition (`label.json`, `BEFORE` to `AFTER`). The test passed. `LottieDelegates.image` was not run. `lottie-web` 5.13.0 and `lottie-react` 3.1.2 are MIT on npm. `lottie-web` 5.13.0 `index.d.ts` declares `updateDocumentData(path, documentData, index)`. Those players were not executed. Dynamic image, and dynamic text on web and React, are **not verified**.
4. **Lottie inside a Fluvie scene.** The published Fluvie 0.3.1 tree has no Lottie integration. A synthetic moving-box composition painted 1600 non-background pixels inside the centered 400×400 box on frame 0 and on frame 20. With `tester.pump()` (zero duration, the CLI harness at `file_harness_template.dart` line 81) the box delta was 0. With `tester.pump(Duration(milliseconds: 33))` the box delta was 3240. The layer can appear in a captured frame. Its own clock does not advance under the current CLI pump, and it does advance when that pump elapses a frame. Open pull request 2 on `SimonErich/fluvie` ("fix(render): advance native Flutter animations during CLI capture", opened 2026-09-08, still open, no comments) describes the same clock gap. It is not merged and it is not a refusal.

### H1 — Maintenance, checked 2026-11-11

| Fact | Value |
| --- | --- |
| Repository | https://github.com/SimonErich/fluvie |
| Created | 2025-11-24 |
| First `fluvie` release | 2026-06-21 (pub.dev) |
| Pinned publish | 2026-07-16 (0.3.1) |
| Default branch pushed | 2026-10-07 |
| Human contributors returned by the GitHub API | 1 (`SimonErich`, 279 contributions) |
| Stars / forks | 10 / 4 |
| License | MIT |
| Open issues | 1, which is pull request 2 |
| Pull request 2 | Open since 2026-09-08, 0 comments, 0 review comments, not merged |
| Tests | The published packages ship tests in the upstream monorepo. This evaluation did not run the upstream suite. The CLI render path did run `flutter test` for its generated harness. |
| CI | Not inspected beyond the public repository metadata. |
| CONTRIBUTING | Fluvie documents contribution on its repository. An external patch does not need private Social Studio infrastructure. Building the unpacked 0.3.1 CLI tarball with `dart pub get` fails because `pubspec.yaml` contains `resolution: workspace`. `dart pub global activate fluvie_cli 0.3.1` succeeds. |

The risk flag needs one committer and no commit in the six months before the check and an open bug on a needed capability. The first and the third are true. The second is not: the default branch was pushed on 2026-10-07. The unanswered pull request is a maintenance signal. It is not a refusal, and it is not a fork trigger.

### Fallbacks

The on-device encoder sources do not bundle FFmpeg, and the four media checks of the phase 1 shape passed headlessly. The fallbacks were not benchmarked.

- `widget_recorder_plus` 1.0.6, MIT, "Copyright (c) 2026 Widget Recorder Contributors". It is a screen recorder (MP4, optional microphone, GIF, screenshot), not a composition engine. Direct dependencies: `path_provider` and `image`. `image` 4.8.0, the version whose LICENSE was read, is MIT, copyright 2013–2022 Brendan Duncan. The package constraint is `^4.1.7`; that dependency was not locked.
- `flutter_quick_video_encoder` 1.7.2, published 2024-09-20, Unlicense. README and the iOS sources use AVFoundation. The Android Gradle file sets a library namespace and does not reference FFmpeg. It encodes raw frames. It is not a scene graph. The repository was last pushed on the publish date.

### Recommendation

**Candidate for partial adoption, to validate on the phase 1 mobile prototype.**

The full phase 1 piece (still, slow scale, voice, burned-in caption, cover) ran on the desktop headless path with FFmpeg. The published mobile-encoder sources use the platform API and do not bundle FFmpeg. That reading is favorable evidence. It does not show the same piece running on a phone. The candidate conclusion is recorded now. A device run is still required before treating on-device rendering as demonstrated.

Use `fluvie` and `fluvie_mobile_encoder` as that candidate: a still, Fluvie-driven motion, a voice file, burned-in captions, and a cover, without a bundled encoder binary. Keep Lottie as a separate art layer. Contribute the capture-clock fix upstream (the open pull request is that fix) so a Lottie controller advances during a headless capture. Leave iOS video clips for a later upstream patch. Do not ship the GPL FFmpeg binary or `@ffmpeg/core` inside an app or a distributed package. GPL FFmpeg with libx264 is accepted only as a separate process in the developer tool (`docs/decisions/0002-ffmpeg-in-developer-tools.md`). L2 stays a fail for the CLI binary and the web core.

The locked "adopt and contribute" label needs L1, L2, D1, and G1 to pass. L1 misses the pass list on two licenses. L2 fails for the CLI binary and the web core. G1 is not an aggregate pass while the network clause is not verified. P1 and D2 are not verified. The Lottie clock and the iOS clip path are real gaps. The four media checks passed on the headless path, and the on-device package does not bundle FFmpeg.

The phase 1 probe adds two on-device gaps in `fluvie` 0.3.1. The aspect path does not pre-resolve captions, so the caption layer throws and the export keeps no file. `OffscreenCaptureHost` does not run the post-frame callback that resolves motion, so an animated child stays at opacity 0. The emulator file that contains the still used a capture host that throws outside `LiveTestWidgetsFlutterBinding`. That host is test-only. Closing either gap is an upstream contribution or a thin package beside `fluvie`. The phase 0 labels in this document stay as recorded.

The locked fork label needs a license that blocks use, a project that is gone, or a refused change that cannot live beside upstream. The engine license is MIT. The default branch was pushed on 2026-10-07. The clock fix is an open pull request, not a refusal. The GPL binary is an encode tool beside the engine.

This evaluation leaves `docs/reuse.md` empty. The probe is evidence, not a product abstraction.

### Not verified

- Any phone or tablet, including every P1 device class. No on-device encode, no on-device quality, no D2 comparison. Peak memory, heating, and backgrounding in the middle of a render are in this group.
- Audio/video sync in milliseconds. The headless file had an AAC stream and a measured loudness. The offset between a marked frame and the tone was not measured.
- Whether the encoded file is postable: pixel format, color tags, `moov` at the start of the file, and size against platform limits. Duration, frame size, H.264, and AAC were read on the 2026-11-11 file. That file was not kept. The inspection command is `probes/phase0/tool/inspect_story15.py`.
- No network call during render. See the G1 row. An established-TCP sample is not that proof.
- iOS runtime of image and text, as distinct from the source reading.
- Multiple audio tracks, gain, delay, trim, fade, and loop at runtime. Loop and the other controls are in the mobile sources.
- `LottieDelegates.image`.
- `lottie-web` and `lottie-react` at runtime.
- The web encoder at runtime. Its core license was read from the npm registry.
- The other FFmpeg archives named in `fluvie_cli` `lib/src/ffmpeg/ffmpeg_release.dart`. One archive was downloaded and matched its pin. The others were not downloaded. Their license follows the GPL build label in that file.
- Upstream Fluvie's own test suite and CI.
- Encoded output on a hardware encoder. The byte-identical MP4 pair is the software path of the desktop headless run.
