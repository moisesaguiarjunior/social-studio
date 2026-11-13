# Unreleased

- Protect the production capture HTTP boundary with a persistent injected-request regression.
- Block new Dart HTTP connections during desktop capture, including real-async work.
- Verify synthetic source metadata is absent from encoded video and cover in CLI regression tests.
- Explicitly disable capture caching while using the upstream SDK, whose
  cache hits skip the sequential host pump.
- Advance the desktop scheduler at the video's FPS, with frame zero at zero
  and no accumulated rounding drift. Test native ticker elapsed time in the
  actual raw-frame capture pipeline. Keep the current Fluvie dependency.

# 0.1.0

- Add versioned local Story jobs, schema validation and a photo/caption compiler.
- Render desktop MP4 video and a cover from a supplied job through Fluvie.
- Reject remote inputs and unsupported media; preserve authored duration across
  short/long audio, strip copied metadata and clean failed output staging.
- Accept ordered photo scenes with individual durations, preserving single-image jobs.
- Keep captions, audio and cover on the global timeline across hard cuts.
- Export a local review page with scene/caption navigation and separate SRT captions.
- Freeze validated render jobs for capture so concurrent source JSON edits cannot split video, review and subtitles.
- Reject remote font and transcript paths before access, detect an intentional network fetch, and check that synthetic location and device tags are absent from encoded output.
