# Dependencies and licenses

Every dependency of a distributed package, and every binary a tool downloads, with its license and why it is used. GPL/AGPL is not allowed in distributed packages.

Checked 2026-11-11. Package licenses were read from the `LICENSE` file inside the published tarball or the pub cache copy of that version. npm licenses were read from the registry JSON. Versions of the probe's resolved graph are the ones in `probes/phase0/pubspec.lock`.

SIL Open Font License 1.1 and the Unlicense appear in the tables below. Both are outside the L1 pass list in `docs/evaluation.md`. Listing them here is the inventory, not an L1 pass.

## Candidates

| Dependency | Version | License | Used for | Checked on |
| --- | --- | --- | --- | --- |
| `fluvie` | 0.3.1 | MIT, copyright 2026 Simon Auer | Composition and frame capture | 2026-11-11 |
| `fluvie_mobile_encoder` | 0.3.1 | MIT, copyright 2026 Simon Auer | On-device encode through the platform API | 2026-11-11 |
| `fluvie_cli` | 0.3.1 | MIT, copyright 2026 Simon Auer | Headless capture and encode | 2026-11-11 |
| `fluvie_web_encoder` | 0.3.1 | MIT, copyright 2026 Simon Auer | In-browser encode | 2026-11-11 |
| `lottie` | 3.8.2 | MIT. The copyright line is the unfilled template "Copyright (c) [year] [fullname]" | Flutter Lottie player | 2026-11-11 |
| `lottie-web` | 5.13.0 | MIT (npm) | Web player. Not executed | 2026-11-11 |
| `lottie-react` | 3.1.2 | MIT (npm) | React player. Not executed | 2026-11-11 |
| JetBrains Mono, bundled in `fluvie` | files in 0.3.1 | SIL Open Font License 1.1, copyright 2020 The JetBrains Mono Project Authors (`fonts/OFL.txt`) | Code and terminal elements | 2026-11-11 |
| `widget_recorder_plus` | 1.0.6 | MIT, copyright 2026 Widget Recorder Contributors | Fallback recorder. Not benchmarked | 2026-11-11 |
| `flutter_quick_video_encoder` | 1.7.2 | Unlicense | Fallback raw-frame encoder. Not benchmarked | 2026-11-11 |

## Downloaded binaries

These are not Dart packages. They are what the tools fetch.

| Binary | Pin | License | Used for | Checked on |
| --- | --- | --- | --- | --- |
| FFmpeg 8.1, one archive from the pin table in `fluvie_cli` `lib/src/ffmpeg/ffmpeg_release.dart` | SHA-256 `ebb82529562b71170807bbc6b0e7eb4f0b13af8cbb0e085bb9e8f6fe709598ad`, 22,547,387 bytes, matching that pin. Label: `FFmpeg 8.1 GPL (BtbN 2026-05-31, evermeet, osxexperts)` | GPL. `ffmpeg -version` includes `--enable-gpl` and `--enable-libx264` | CLI encode during the headless checks. Not stored in the repo. The other rows in that pin table were not downloaded | 2026-11-11 |
| `@ffmpeg/core` | 0.12.10 | GPL-2.0-or-later (npm) | Browser encode core. Not downloaded | 2026-11-11 |
| `@ffmpeg/ffmpeg` | 0.12.15 | MIT (npm) | Browser wrapper around the core | 2026-11-11 |
| `@ffmpeg/util` | 0.12.2 | MIT (npm) | Browser helper | 2026-11-11 |

## Direct dependencies of `fluvie` 0.3.1

Resolved versions are from the phase 0 probe lock unless noted.

| Dependency | Version | License | Used for | Checked on |
| --- | --- | --- | --- | --- |
| Flutter SDK | 3.47.9 | BSD-3-Clause, copyright 2014 The Flutter Authors | Framework | 2026-11-11 |
| `flutter_svg` | 2.3.3 | MIT, copyright 2018 Dan Field | SVG elements | 2026-11-11 |
| `highlight` | 0.7.0 | MIT, copyright 2019 Rongjian Zhang | Code highlighting | 2026-11-11 |
| `http` | 1.6.0 | BSD-3-Clause, Dart project authors | HTTP client | 2026-11-11 |
| `intl` | 0.20.3 | BSD-3-Clause, Dart project authors | Formatting | 2026-11-11 |
| `markdown` | 7.3.1 | BSD-3-Clause, Dart project authors | Markdown elements | 2026-11-11 |
| `meta` | 1.19.0 | BSD-3-Clause, Dart project authors | Annotations | 2026-11-11 |
| `riverpod` | 3.5.0 | MIT, copyright 2020 Remi Rousselet | State used inside the package | 2026-11-11 |
| `archive` | 4.6.0 | MIT, copyright 2013–2021 Brendan Duncan, plus `LICENSE-other.md` | Transitive. Zip and tar | 2026-11-11 |

`archive` `LICENSE-other.md` adds: zlib.js MIT copyright 2012 imaya; JZlib copyright 2000–2011 ymnk, JCraft (BSD-style); bzip2 copyright 1996–2010 Julian R Seward (BSD-style); zlib-ng crc32 copyright 1995–2024 Jean-loup Gailly and Mark Adler (zlib license). None of those is GPL.

Other permissive packages pulled in by `flutter_svg` and `riverpod` and read the same day: `path_parsing` 1.1.0 MIT (Dan Field, 2018); `petitparser` 7.1.0 and `xml` 7.0.1 MIT (Lukas Renggli); `vector_graphics` 1.2.7, `vector_graphics_codec` 1.2.0, and `vector_graphics_compiler` 1.3.5 BSD-3-Clause (Flutter authors); `vector_math` 2.4.4 BSD-3-Clause (Flutter authors); `state_notifier` 1.0.0 MIT (Remi Rousselet, 2020).

## Direct dependencies of `fluvie_cli` 0.3.1

Resolved by `dart pub global activate fluvie_cli 0.3.1`.

| Dependency | Version | License | Used for | Checked on |
| --- | --- | --- | --- | --- |
| `archive` | 4.6.0 | MIT, plus the other notices above | Unpacking the FFmpeg zip | 2026-11-11 |
| `args` | 2.7.0 | BSD-3-Clause, Dart project authors | CLI flags | 2026-11-11 |
| `crypto` | 3.0.8 | BSD-3-Clause, Dart project authors. The LICENSE file is BSD, not Apache-2.0 | Checksums | 2026-11-11 |
| `dart_style` | 3.1.14 | BSD-3-Clause, Dart project authors | Generated Dart | 2026-11-11 |
| `http` | 1.6.0 | BSD-3-Clause | The FFmpeg download | 2026-11-11 |
| `meta` | 1.19.0 | BSD-3-Clause | Annotations | 2026-11-11 |
| `path` | 1.9.1 | BSD-3-Clause, Dart project authors | Paths | 2026-11-11 |
| `yaml` | 3.1.4 | MIT, Dart project authors and Kirill Simonov | Project files | 2026-11-11 |
| `yaml_edit` | 2.2.4 | BSD-3-Clause, Dart project authors | Project edits | 2026-11-11 |

The generated capture harness also needs `flutter_test` (Flutter SDK, BSD-3-Clause) and `alchemist` 0.14.1 (MIT, copyright 2022 Betterment LLC), which `fluvie init` puts in dev dependencies so the harness can load real fonts. `alchemist` brought `equatable` 3.0.0 (MIT, copyright 2026 Felix Angelov).

## Direct dependencies of `fluvie_web_encoder` 0.3.1

From the published pubspec. The probe did not resolve this package.

| Dependency | Constraint | License | Used for | Checked on |
| --- | --- | --- | --- | --- |
| Flutter and `flutter_web_plugins` | SDK | BSD-3-Clause | Web plugin | 2026-11-11 |
| `fluvie` | ^0.3.1 | MIT | Capture | 2026-11-11 |
| `http` | ^1.5.0 | BSD-3-Clause | Client | 2026-11-11 |
| `web` | ^1.1.0, probe resolved 1.1.2 elsewhere | BSD-3-Clause, Dart project authors | Browser bindings | 2026-11-11 |

The FFmpeg wasm core is listed under downloaded binaries. It is GPL.

## Probe-only

| Dependency | Version | License | Used for | Checked on |
| --- | --- | --- | --- | --- |
| Roboto Regular, copied from the Flutter SDK material fonts | file SHA-256 `79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95` | Apache-2.0 (`assets/Roboto_LICENSE.txt`) | The `Ag Á` glyphs in the determinism probe | 2026-11-11 |
| `flutter_lints` | 6.0.0 | BSD-3-Clause, Flutter authors | Analyzer | 2026-11-11 |
| `crypto` | 3.0.8 | BSD-3-Clause | Frame hashes | 2026-11-11 |

The rest of the probe lock (`async`, `collection`, `fake_async`, `matcher`, `leak_tracker`, `source_span`, `test_api`, and the other SDK test packages) was read from each package `LICENSE`. They are BSD-3-Clause (Dart or Flutter authors) or Apache-2.0 (`clock` 1.1.3, `fake_async` 1.3.3, `material_color_utilities` 0.13.0). None is GPL. The Flutter engine `sky_engine` notice file is a bundle of third-party texts; this evaluation did not re-classify that bundle line by line. The engine is used as the SDK that ships with Flutter 3.47.9.

`image` 4.8.0, read because `widget_recorder_plus` depends on `image: ^4.1.7`, is MIT, copyright 2013–2022 Brendan Duncan. That version was not locked by a `widget_recorder_plus` solve.


## CI-only actions

Pinned by immutable revision in `.github/workflows/quality.yml`, verified from
the upstream repository/tag and LICENSE on 2026-11-11. They are workflow tools,
not app dependencies. SDK versions are configured separately in the workflow.

| Action | Pinned revision | License | Source |
| --- | --- | --- | --- |
| actions/checkout (v5) | `fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09` | MIT | https://github.com/actions/checkout |
| subosito/flutter-action (v2) | `1a449444c387b1966244ae4d4f8c696479add0b2` | MIT | https://github.com/subosito/flutter-action |
| actions/setup-python (v6) | `ece7cb06caefa5fff74198d8649806c4678c61a1` | MIT | https://github.com/actions/setup-python |
