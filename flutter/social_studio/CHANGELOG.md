# Unreleased

- Pin desktop rendering to the maintained Fluvie Git tag `v0.3.1-socialstudio.2`.

- Add the versioned crafted Story template with pinned handcrafted_flutter
  materials, cut edges and thread, preserving the existing Fluvie capture/encode
  pipeline and strict version-1 inputs. Freeze material recipes with snapshots.

- Return typed, content-free errors for malformed JSON input.
- Cover snapshot replay/rebasing, JPEG input, fractional scene review and real signal delivery.
- Handle desktop SIGINT/SIGTERM by stopping worker groups before cleaning export workspaces.
- Require local Python 3 for POSIX render process isolation.
- Protect the production capture HTTP boundary with a persistent injected-request regression.
- Block new Dart HTTP connections during desktop capture, including real-async work.
- Verify synthetic source metadata is absent from encoded video and cover in CLI regression tests.
- Keep capture caching disabled so raw frames stay in the job workspace.
- Advance the desktop scheduler at the video's FPS, with frame zero at zero
  and no accumulated rounding drift. Test native ticker elapsed time in the
  actual raw-frame capture pipeline.

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
