# Phase 0 evaluation

Status of this document:

- **Criteria locked:** 2026-11-11, before any package was fetched, any source tree was opened for this evaluation, or any probe was run.
- **Results:** not filled yet. Sections under "Results" stay empty until the probes and source checks below have been run. Filling them is a later change.
- **What this is:** an evaluation proposal and, once filled, an evidence record. It does not by itself adopt a dependency. Adopting one is a later decision, recorded in `docs/decisions/` when it is made.

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

Not collected. The criteria above are the whole evaluation so far.
