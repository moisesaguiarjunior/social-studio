# Desktop privacy checks

Local checks for roadmap step 2 on the desktop Story path. These checks do not
revise the phase 0 network row and do not certify a phone.

## What the checks execute

A local photo, WAVE file, font file and transcript path are accepted. Remote
image, video and audio references are rejected before the job opens a file.
That includes `https` redirect URLs and `http` redirect URLs. An unknown video
field is rejected by the schema before file access. Remote font and transcript
paths are rejected before the font is read and before the caption file is
handed to the renderer. The socket client is not created for those rejections.

The desktop capture path uses Fluvie's existing resolver with an empty network
allowlist. An intentional image, video, audio or redirect fetch throws before
a request. The reported failure names the disallowed host or scheme. It does
not report a completed fetch.

A synthetic file carries location `+00.0000+000.0000/` and device tags
`make`, `model` and `device`, each set to `PrivacyFixture`. Re-encoding while
metadata copying stays on keeps the location tag, and keeping device metadata
tags keeps `PrivacyFixture`. The same re-encode with the desktop metadata
arguments removes both. Removing those arguments makes the check fail. The
desktop video and cover commands include the same arguments. The encoder can
still write its own library identifier. That identifier is not a location or
device tag. Extracting a cover PNG from the tagged video did not retain those
tags in the PNG probe, so the video file is the control that can fail.

## Native paths not observed

These desktop checks did not run:

- iOS Photos or PHAsset location, or AVAssetWriter metadata
- Android MediaStore, ExifInterface or MediaMuxer metadata
- a platform HTTP stack that accepts a first host and then follows a redirect
- network filesystems
- an on-device font download
- a speech or transcript upload service
- native plugin network calls outside this desktop resolver
- a phone or emulator encode

The desktop job has no video input slot. A video URL in the job is rejected as
an unknown field or, in an image or audio path, as a remote path. A network
video source passed to the existing resolver is detected before fetch. Native
video import was not run.
