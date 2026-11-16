# Paper and fabric around a photo Story

The crafted template uses the same local job-to-MP4 workflow as the photo
Story. handcrafted_flutter owns the material, cut and thread; Fluvie owns media,
photo motion and captions. No extra animation clock runs in the decoration.

Generate the existing synthetic media, then run from the desktop package:

```sh
python3 probes/phase1/tool/generate_story_assets.py
cd flutter/social_studio
flutter pub get --enforce-lockfile
dart run bin/social_studio.dart validate example/craft.json
dart run bin/social_studio.dart render example/craft.json out/crafted-story
```

Choose a new output directory. The recipe belongs in a version-2 job:

```json
"version": 2,
"template": "story-craft-v1",
"craft": {
  "material": "linen",
  "color": "#F3EADC",
  "seed": 23,
  "grainScale": 1,
  "grainStrength": 0.7,
  "frameInset": 0.08,
  "edge": "torn",
  "stitch": "chain"
}
```

The complete fixture retains the image/audio, authored duration, cover and
caption fields. Photo sequences use the same scene list as version 1.

| Argument | Meaning and supported values |
| --- | --- |
| material | paper, linen, twill, felt or wood |
| color | #RRGGBB or #AARRGGBB, the existing desktop color convention |
| seed | Integer 0..2147483647, constant throughout the export |
| grainScale | Texture scale 0.5..4, independent of photo zoom |
| grainStrength | Texture strength 0..1 |
| frameInset | 0.04..0.18 of the shorter canvas side; an authoring margin |
| edge | cut, torn, deckle or postage silhouette |
| stitch | none, running, backstitch, blanket, chain, cross or basting |

All fields are required, allowlisted and schema-validated. Unknown fields/tools,
unsupported versions and invalid values fail before capture. The canonical
contract is spec/desktop-story/v2/story-job.schema.json. This is not the general
catalog's next schema version. Version 1 still rejects craft; its default visuals
and output artifact contract are preserved.

## Rendering boundary

The photo is clipped inside the authored opening; zoom remains Fluvie's existing
motion. The seam derives from the same outer cut. Punctures and relief are
shading, not needle/cloth physics. Material tiles belong to the mounted surface.
The wrapper exposes its declared photo child through CollectibleChildren so
Fluvie can pre-resolve local media before frame zero. Hiding an image inside an
opaque build callback would miss that pass.

The initial crafted renderer envelope is 64..2048 logical pixels per side, with
width + height at most 3072. These are implementation support limits, not
platform requirements. With stitching enabled, frameInset times the shorter
canvas side must also be at most 256 logical pixels: the centered seam uses
half that margin and the geometry contract caps its inset at 128. Unsupported
combinations fail validation before composition, without clamping the recipe.
The existing authored 1080x1920 canvas fits. Larger
canvases remain available to the unchanged photo template where otherwise valid.
Native-device cost and full-size throughput remain unmeasured.

Frozen jobs retain the recipe and versioned schema/template alongside the
existing profile, timing and media hashes. Capture remains offline and encode
continues stripping source location/device tags. Outputs are the same MP4,
cover, supplied SRT, offline review and manifest; input paths/recipes are not
added to the public result manifest. Apps still decide what content is authorized.
