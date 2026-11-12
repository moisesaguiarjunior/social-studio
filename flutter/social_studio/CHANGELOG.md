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
