# 0007 — Portable review of the encoded Story

Status: implemented locally for review.
Date: 2026-11-12.

## Context

A completed render needs a practical way to inspect scenes, captions and cover.
The existing MP4, validated job and SRT conversion contain the necessary data.
Searches covered HTML/video review surfaces, `toSrt`, `result.json`, caption
quantization and the reuse map. There is no existing review page to extend.

## Decision

Export a static `review.html` and `captions.srt` beside the MP4 and cover before
staging is exposed as the final directory. Freeze the already validated job,
profile, template and schema text into a private capture snapshot. Capture reads
that snapshot; review and SRT use the same in-memory job. Rebase resolved media
paths against the real temporary directory path to preserve relative references
through symbolic links. Media contents themselves are not snapshotted. Streamed SHA-256 digests retained
at validation are checked before capture and before exposing output, rejecting
persistent media changes. A temporarily replaced and restored file can evade
these checks; they do not claim filesystem snapshot isolation. Play the encoded MP4 through native
browser controls. Reuse job scene durations and the shared caption-frame
conversion for seek points; the page never re-renders or edits a composition.
The manifest follows the new canonical result schema in `spec/desktop-story`.

Reuse: existing MP4, cover, SRT conversion, job validation and atomic staging.
Create: one HTML/CSS/JavaScript document and a small typed template compiler.
Caption text is HTML-escaped into text nodes; single-pass slot substitution
keeps template-like caption content literal. Input paths are never exported.
A restrictive content policy and fixed local media links support offline use.
No JavaScript package, remote font, network API or server is required.

The interface centers the portrait video with scene and caption navigation
beside it. Its blue-grey paper/ink/sea palette, local system typography and
numbered scene sequence describe a review workspace. Native controls, keyboard
buttons, focus indicators and a narrow-layout flow provide the interaction.

## Alternatives and consequences

A live editor would require persistence, preview/render equivalence and an app
host. It is a separate increment. A second Flutter preview would reproduce
composition state and would not prove what the encoded MP4 contains. This page
reviews the actual output; browser codec support is required. The directory
must remain together. It includes supplied caption content, so consumers retain
responsibility for choosing authorized material and recipients.

## Evidence

`test/story_review_test.dart` protects frame navigation, single-photo jobs and
caption escaping. Browser and export checks are recorded in the desktop
verification document. No native mobile playback or sharing is certified.
