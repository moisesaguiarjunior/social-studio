# Platform file requirements

Checked: 2026-11-11.

This is the research input for later platform profiles. It is not a JSON Schema, and it does not adopt a renderer.

A number below is a requirement only when the cited page states it. "Recommended", "can be", and "should" are copied with those words. Where the official page checked on this date does not state a number, the cell says **not published**. Creator blogs, Facebook AI answers, and other restatements were not used to fill those cells.

Page "last updated" dates are the dates those sites show. The check date for every page is 2026-11-11.

## Two Instagram paths

Instagram publishes two different file stories. They are not interchangeable.

- **Share hand-off.** The app gives a local file to the Instagram app. The person publishes. This is the product path in the [README](../README.md): no automatic posting. Phase 1 follows **Sharing to Stories**.
- **Instagram platform publishing API** (`POST /<IG_USER_ID>/media` on the IG User Media reference). This is for professional accounts. Its Story and Reel sections are more specific. They are recorded here so a later profile can use them. They are not the phase 1 gate.

A file can satisfy the share page and still fail the publishing API. The disagreements are listed under each target.

Ads have a separate media-requirements page. Its numbers are not copied here:

<https://developers.facebook.com/docs/instagram/ads-api/reference/media-requirements/>

## What the phase 1 Story must meet

Phase 1, from the repository README, is one Instagram Story: 9:16, 10–15 seconds, with a cover frame. The file has to pass the Stories **sharing** limits. Those limits are the share hand-off, not the publishing API.

| Phase 1 gate | Value | Where it is published |
| --- | --- | --- |
| Piece | One Story, 9:16, 10–15 s, with a cover frame | Repository README, phase 1 spike |
| Video codec | H.264, H.265, or WebM | Sharing to Stories, background video |
| Resolution | Videos can be 1080p. The page does not define the pixel size of "1080p" | Sharing to Stories |
| Minimum dimensions | 720×1280, in the Android background-asset cell that covers image and video. The iOS video row does not repeat this figure | Sharing to Stories |
| Maximum duration | Up to 20 seconds. The 10–15 s spike sits inside that | Sharing to Stories |
| iOS file size | Under 50 MB recommended. The Android section of the same page does not state 50 MB | Sharing to Stories, iOS video row |
| Sticker, only if one is sent | JPG or PNG. Recommended dimensions 640×480 | Sharing to Stories |
| App identity | A Facebook App ID is required. Without it, sharing to Stories fails | Sharing to Stories. The warning cites a requirement beginning January 2023 |

The share page does **not** publish a container, a moov-atom rule, a pixel format, color tags, a frame rate, an audio codec, a sample rate, a channel count, or an H.264 profile. Those are not phase 1 file gates. The publishing-API Story section below is stricter and is not a phase 1 gate.

Sharing to Stories also publishes no cover or thumbnail parameter. The phase 1 cover frame is part of the piece in this repository. It is not a second file the Stories intent documents.

## Instagram Story

### Share to Stories

Source: [Sharing to Stories](https://developers.facebook.com/docs/instagram-platform/sharing-to-stories). Last updated 2026-06-30. Checked 2026-11-11.

The story composer has a background layer and a sticker layer. The app must send a background asset, a sticker asset, or both.

| Field | Published value | Phase 1 Story |
| --- | --- | --- |
| Container | **not published** | not a gate |
| Video codec | H.264, H.265, or WebM | must meet |
| Video profile | **not published** | not a gate |
| Pixel format | **not published** | not a gate |
| Color tags | **not published** | not a gate |
| Frame rate | **not published** | not a gate |
| Resolution and aspect ratio | Minimum dimensions 720×1280 on the Android background-asset cell (image or video). Recommended **image** ratios 9:16 or 9:18. Videos can be 1080p. iOS background image: minimum 720×1280, same recommended image ratios. iOS background video: 1080p, and the video row does not repeat 720×1280 | 9:16 and 1080p-class video must meet the published video lines. 720×1280 is published on the Android background-asset cell |
| Minimum duration | **not published** | the spike is 10–15 s |
| Maximum duration | Up to 20 seconds | must meet; the spike is shorter |
| Maximum file size | iOS video: under 50 MB recommended. Android: **not published** | iOS recommendation applies when the hand-off is iOS. Android size is not a published gate |
| Audio codec | **not published** | not a gate |
| Audio sample rate | **not published** | not a gate |
| Audio channels | **not published** | not a gate |
| Cover or thumbnail | **not published** | the spike still has a cover frame inside the piece |
| UI safe zone | **not published** on this page. See [UI safe zones](#ui-safe-zones) | no numeric inset to meet |

Background colors are hex strings. If a sticker is sent with no colors, the background color is `#222222`. On Android, a background asset is used and the color values are ignored.

**Android.** Intent action `com.instagram.share.ADD_TO_STORY`. The background asset is a content Uri to a local file. The Facebook App ID goes in the `source_application` extra. A sticker Uri goes in `interactive_asset_uri`, and the app grants read permission to `com.instagram.android`. Color extras are `top_background_color` and `bottom_background_color`. The sample on the page uses a JPEG MIME type. The same intent is the documented video hand-off.

**iOS.** Custom URL scheme `instagram-stories`, registered under `LSApplicationQueriesSchemes`. Share URL `instagram-stories://share?source_application=<APP_ID>`. Pasteboard keys shown in the samples: `com.instagram.sharedSticker.backgroundImage`, `com.instagram.sharedSticker.stickerImage`, `com.instagram.sharedSticker.backgroundTopColor`, `com.instagram.sharedSticker.backgroundBottomColor`. The data table lists a background video as `NSData`. The code samples on the page checked do not show the pasteboard key for that video. This document does not invent one.

### Publishing API, Story container

Source: [IG User Media](https://developers.facebook.com/docs/instagram-platform/instagram-graph-api/reference/ig-user/media). Last updated 2026-09-28. Checked 2026-11-11.

This is not the phase 1 gate. `media_type=STORIES`. Stories expire after 24 hours. Publishing stickers (link, poll, location) is not supported. Mentioning users without a sticker is supported.

Story video:

| Field | Published value |
| --- | --- |
| Container | MOV or MP4 (MPEG-4 Part 14), no edit lists, moov atom at the front of the file |
| Video codec | HEVC or H264, progressive scan, closed GOP |
| Video profile | **not published** |
| Pixel format | 4:2:0 chroma subsampling |
| Color tags | **not published** |
| Frame rate | 23–60 FPS |
| Resolution and aspect ratio | Maximum columns (horizontal pixels): 1920. Required aspect ratio between 0.1:1 and 10:1. 9:16 recommended, to avoid cropping or blank space |
| Minimum duration | 3 seconds |
| Maximum duration | 60 seconds |
| Maximum file size | 100 MB |
| Video bitrate | VBR, 25 Mbps maximum |
| Audio codec | AAC |
| Audio sample rate | 48 kHz maximum |
| Audio channels | 1 or 2 (mono or stereo) |
| Audio bitrate | 128 kbps. The page does not say whether this is a maximum, a target, or a constant rate |
| Cover or thumbnail | **not published** as a Story-specific field. `thumb_offset` is documented for videos and Reels, in milliseconds, default 0. The Story container examples do not include it |
| UI safe zone | **not published** |

Story image, same page: JPEG, 8 MB maximum, 9:16 recommended, sRGB. Other color spaces are converted to sRGB. Minimum and maximum width: **not published** for the Story image (the feed image section on the same page does publish widths).

### Where the Story paths disagree

| Topic | Share hand-off | Publishing API |
| --- | --- | --- |
| Codec / container | H.264, H.265, or WebM. Container not published | MOV or MP4 only. HEVC or H264. WebM is not in this list |
| Duration | Up to 20 seconds. No published minimum | 3 seconds minimum, 60 seconds maximum |
| File size | iOS under 50 MB recommended. Android not published | 100 MB maximum |
| Pixels | 1080p, plus Android minimum 720×1280 | Maximum 1920 horizontal pixels. Aspect 0.1:1 to 10:1. 4:2:0, closed GOP, 23–60 FPS |
| Audio | not published | AAC, 48 kHz maximum, 1 or 2 channels, 128 kbps as written |

Phase 1 follows the share column.

## Instagram Reel

### Share to Reels, Android

Source: [Instagram Sharing to Reels from Android](https://developers.facebook.com/docs/android/sharing-to-reels-instagram). Last updated 2024-03-18. Checked 2026-11-11.

The composer has a background video layer and an optional sticker layer. The Meta app must be live before users can share.

| Field | Published value |
| --- | --- |
| Container | The accepted-format list mixes codecs and containers: `H.264`, `H.265`, `MOV`, `MP4`, and `WebM` |
| Video codec | H.264 and H.265 are in that same list |
| Video profile | **not published** |
| Pixel format | **not published** |
| Color tags | **not published** |
| Frame rate | **not published** |
| Resolution and aspect ratio | Videos should be 1080p. Dimensions should be device fullscreen or smaller. The page does not define "1080p" or "device fullscreen" in pixels |
| Minimum duration | Should be at least 3 seconds |
| Maximum duration | Should be at most 60 seconds |
| Maximum file size | **not published** |
| Audio codec, sample rate, channels | **not published** |
| Cover or thumbnail | **not published** |
| UI safe zone | **not published** on this page |
| Sticker | Optional. JPG or PNG. Recommended 640×480 |

Intent `com.instagram.share.ADD_TO_REEL`. Package `com.instagram.android`. App ID extra `com.instagram.platform.extra.APPLICATION_ID`. Media is a content Uri to a local file. Sticker extra `interactive_asset_uri`. Several local files use `com.instagram.share.ADD_TO_REEL_MULTIPLE`. An image (JPG or PNG) can be sent in place of a video. The page says "should" for 1080p, duration, and dimensions.

### Share to Reels, iOS

Source: [Instagram Sharing to Reels from iOS](https://developers.facebook.com/docs/ios/sharing-to-reels-instagram/). Last updated 2026-04-06. Checked 2026-11-11.

| Field | Published value |
| --- | --- |
| Container | **not published** as a container name |
| Video codec | H.264, H.265, and WebM |
| Video profile | **not published** |
| Pixel format | **not published** |
| Color tags | **not published** |
| Frame rate | **not published** |
| Resolution | Videos can be 1080p. Pixel dimensions of "1080p": **not published** |
| Minimum duration | Should be at least 3 seconds |
| Maximum duration | Should be at most 60 seconds |
| Maximum file size | Under 50 MB is recommended |
| Audio codec, sample rate, channels | **not published** |
| Cover or thumbnail | **not published** |
| UI safe zone | **not published** on this page |
| Sticker | Optional. JPG or PNG. Recommended 640×480. A local file |

Scheme `instagram-reels`, registered under `LSApplicationQueriesSchemes`. Share URL `instagram-reels://share`. Pasteboard keys: `com.instagram.sharedSticker.backgroundVideo`, `com.instagram.sharedSticker.appID`, and optionally `com.instagram.sharedSticker.stickerImage`. The Meta app must be live. The iOS list does not include the MOV and MP4 names that the Android page puts in its format list.

### Publishing API, Reel container

Source: [IG User Media](https://developers.facebook.com/docs/instagram-platform/instagram-graph-api/reference/ig-user/media), Reel Specifications. Last updated 2026-09-28. Checked 2026-11-11.

`media_type=REELS`. Reels cannot appear in carousels. This is the professional publishing API, not the share hand-off.

| Field | Published value |
| --- | --- |
| Container | MOV or MP4 (MPEG-4 Part 14), no edit lists, moov atom at the front of the file |
| Video codec | HEVC or H264, progressive scan, closed GOP |
| Video profile | **not published** |
| Pixel format | 4:2:0 chroma subsampling |
| Color tags | **not published** |
| Frame rate | 23–60 FPS |
| Resolution and aspect ratio | Maximum columns (horizontal pixels): 1920. Required aspect ratio between 0.01:1 and 10:1. 9:16 recommended |
| Minimum duration | 3 seconds |
| Maximum duration | 15 minutes |
| Maximum file size | 300 MB |
| Video bitrate | VBR, 25 Mbps maximum |
| Audio codec | AAC |
| Audio sample rate | 48 kHz maximum |
| Audio channels | 1 or 2 (mono or stereo) |
| Audio bitrate | 128 kbps, with no published maximum or minimum wording |
| Cover or thumbnail | JPEG, 8 MB maximum, sRGB. 9:16 recommended. If the image is not 9:16, the middle 9:16 rectangle is the Reel cover. If the Reel is shared to the feed, the middle 1:1 square is the feed cover. `cover_url` is a public image URL. `thumb_offset` is a frame time in milliseconds, default 0. If both are set, `cover_url` is used and `thumb_offset` is ignored |
| UI safe zone | **not published** |

`share_to_feed` says whether the Reel may also appear in the feed. The page warns that the flag does not by itself place the Reel in the Reels tab.

The share pages say a Reel should be 3–60 seconds and 1080p. The publishing API allows 15 minutes, 300 MB, and up to 1920 horizontal pixels. Phase 1 is a Story, so neither Reel column is a phase 1 gate.

## Instagram feed image

### Share to Feed

Source: [Sharing to Feed](https://developers.facebook.com/docs/instagram-platform/sharing-to-feed). Last updated 2026-06-30. Checked 2026-11-11.

| Field | Android shareable-content table | iOS document interaction |
| --- | --- | --- |
| Format | JPEG, GIF, or PNG | PNG or JPEG (preferred). Save the file with extension `.ig` (UTI `com.instagram.photo`, conforms to public JPEG and PNG) or `.igo` (`com.instagram.exclusivegram`, so the chooser can show Instagram only) |
| Resolution | **not published** in that table | For best results, Instagram prefers a JPEG that is 640×640. A larger image is resized |
| Maximum file size | **not published** | **not published** |
| Color tags | **not published** | **not published** |
| UI safe zone | **not published** on this page | **not published** on this page |

**Android.** `Intent.ACTION_SEND` with `EXTRA_STREAM` and a chooser. The sample MIME type for an image is `image/*`. The sample builds the Uri from a file path. This is a general send intent, not `ADD_TO_STORY`.

**iOS.** Universal links on this page launch the app (`https://www.instagram.com`, `/create/story`, a post, a username, a location, or a tag). They do not document attaching an image file. The file hand-off on the page is document interaction, for photos.

### Publishing API, image container

Source: [IG User Media](https://developers.facebook.com/docs/instagram-platform/instagram-graph-api/reference/ig-user/media), Image Specifications. Last updated 2026-09-28. Checked 2026-11-11.

This section is separate from Story Image Specifications on the same page.

| Field | Published value |
| --- | --- |
| Format | JPEG |
| Maximum file size | 8 MB |
| Aspect ratio | Within 4:5 to 1.91:1 |
| Minimum width | 320. Scaled up if necessary |
| Maximum width | 1440. Scaled down if necessary |
| Height | Varies with width and aspect ratio |
| Color | sRGB. Other color spaces are converted to sRGB |
| UI safe zone | **not published** |

The share hand-off allows GIF and PNG. The publishing API image specification says JPEG. Caption limit on this endpoint: 2200 characters, 30 hashtags, 20 @ tags. Alternative text is up to 1000 characters, for a single image or an image in a carousel, and is not supported on Reels or Stories. A carousel can hold up to 20 images, videos, or a mix. Those caption and carousel figures are publishing-API limits, not share-intent limits.

## Instagram feed video

### Share to Feed

Same page as feed images. Last updated 2026-06-30. Checked 2026-11-11.

The numbered video limits are in the **Android** shareable-content table. The overview says iOS can pass videos. The iOS section does not publish a video file table.

| Field | Android table | iOS on this page |
| --- | --- | --- |
| Container | MKV, MP4 | **not published** |
| Video codec | **not published** | **not published** |
| Video profile | **not published** | **not published** |
| Pixel format | **not published** | **not published** |
| Color tags | **not published** | **not published** |
| Frame rate | **not published** | **not published** |
| Resolution | Minimum dimensions 640×640. The page spells this "Minimum dimentions" | **not published** |
| Minimum duration | 3 seconds | **not published** |
| Maximum duration | 10 minutes | **not published** |
| Maximum file size | **not published** | **not published** |
| Audio codec, sample rate, channels | **not published** | **not published** |
| Cover or thumbnail | **not published** | **not published** |
| UI safe zone | **not published** on this page | **not published** on this page |

Android hand-off: `ACTION_SEND`, MIME type `video/*`, `EXTRA_STREAM`, chooser.

### Publishing API

The IG User Media page has specification sections for feed images, Reels, Story images, and Story videos. It has no feed-video specification section. Checked 2026-11-11.

`media_type=VIDEO` appears for a resumable upload of a carousel item. The page does not attach a container, codec, duration, or size to that value. `thumb_offset` is documented for videos and Reels: milliseconds, default 0. Carousel videos are allowed (up to 20 children, mixed with images). Reels cannot be carousel children.

Feed-video container, codec, profile, pixel format, color tags, frame rate, audio, duration, and file size on the publishing API: **not published** on the page checked. Reel specifications are not copied into this row. A 60-minute feed-video figure appears on non-official summaries and is not used here. The official Android share table says 10 minutes for that hand-off.

## TikTok

The file rules below are from the Content Posting API. No official share-intent table, of the Instagram Stories kind, was found for TikTok on 2026-11-11. The path that matches this project's hand-off (the person finishes the post) is **Upload**, which puts the video in the creator's inbox. Direct Post publishes for the user and is a different endpoint.

### File restrictions

Source: [Content Posting API, Media Transfer Guide](https://developers.tiktok.com/doc/content-posting-api-media-transfer-guide). Last updated 2026-08-04. Checked 2026-11-11.

| Field | Published value |
| --- | --- |
| Container | MP4 (recommended), WebM, MOV |
| MIME type, on the upload request | `video/mp4`, `video/quicktime`, or `video/webm`. Source: [Upload](https://developers.tiktok.com/doc/content-posting-api-reference-upload-video), last updated 2026-08-04 |
| Video codec | H.264 (recommended), H.265, VP8, VP9 |
| Video profile | **not published** |
| Pixel format | **not published** |
| Color tags | **not published** |
| Frame rate | Minimum 23 FPS. Maximum 60 FPS |
| Resolution | Minimum 360 pixels for both height and width. Maximum 4096 pixels for both height and width |
| Aspect ratio | **not published** |
| Minimum duration | **not published** |
| Maximum duration | Every creator can post 3-minute videos. Some creators can post 5-minute or 10-minute videos. The longest video a developer can send via the initialize Upload Video endpoint is 10 minutes. The user may trim the video in the TikTok app to fit that account's maximum. Query Creator Info returns `max_video_post_duration_sec` per account. The example value on that page is 300, which is an example, not a universal maximum. Direct Post clients must stop a video that exceeds the returned value |
| Maximum file size | 4 GB |
| Audio codec, sample rate, channels | **not published** |
| Cover or thumbnail | **not published** on the inbox Upload init body. Direct Post accepts `video_cover_timestamp_ms`: the cover frame in milliseconds. If omitted or invalid, the cover is the first frame. Source: [Direct Post](https://developers.tiktok.com/doc/content-posting-api-reference-direct-post), checked 2026-11-11 |
| UI safe zone | **not published** on these pages |

Image posts, same media guide: WebP or JPEG, maximum 1080p (the page does not define that in pixels), maximum 20 MB each.

Upload chunks are a transfer rule, not a property of a postable file: chunks of 5–64 MB, final chunk up to 128 MB, files under 5 MB uploaded whole, at most 1000 chunks, in order.

### Hand-off

Inbox upload, so the person finishes in TikTok:

- `POST /v2/post/publish/inbox/video/init/`
- Scope `video.upload`
- The app tells the user to open the inbox notification and finish in TikTok
- `upload_url` is valid for one hour
- At most 5 pending shares in any 24-hour period (`spam_risk_too_many_pending_share`)

Direct Post is `POST /v2/post/publish/video/init/`, scope `video.publish`. It requires explicit user consent before the video is sent. Unaudited clients are limited to private viewing. That endpoint posts. It is not the phase 1 path, and it is outside the README non-goal of posting automatically.

Creator duration comes from `POST /v2/post/publish/creator_info/query/`, field `max_video_post_duration_sec`. Source: [Query Creator Info](https://developers.tiktok.com/doc/content-posting-api-reference-query-creator-info), checked 2026-11-11.

## YouTube

YouTube's encoding page is recommendations, not a list of reject limits. Its first line is: "These features are only available to partners who use YouTube Studio Content Manager." The settings below are still what that page recommends. Checked 2026-11-11. The help pages do not show an updated date.

Source: [YouTube recommended upload encoding settings](https://support.google.com/youtube/answer/1722171?hl=en).

Shorts do not publish a second codec. The same recommended encoding applies, plus the Shorts duration and aspect rules in the next section.

| Field | Recommended value |
| --- | --- |
| Container | MP4. No edit lists. moov atom at the front of the file (Fast Start) |
| Video codec | H.264. Progressive scan. High Profile. 2 consecutive B frames. Closed GOP of half the frame rate. CABAC. Variable bitrate. Chroma subsampling 4:2:0 |
| Video profile | High Profile |
| Pixel format | 4:2:0 |
| Color tags, SDR | BT.709 transfer, primaries, and matrix. The page gives H.273 value 1 for each. Unspecified transfer is assumed BT.709. Unknown or unspecified matrix and primaries are assumed BT.709. Full range is converted to limited range. RGB matrix is not recommended. HDR is a separate article on the same help site |
| Frame rate | Match the recording. Common rates: 24, 25, 30, 48, 50, 60. Other frame rates are also acceptable. Interlaced content should be deinterlaced before upload |
| Video bitrate | No bitrate limit is required. SDR recommendations are in the table below |
| Audio codec | AAC-LC, Opus, or Eclipsa Audio |
| Audio sample rate | 48 kHz |
| Audio channels | The codec section says Stereo, or Stereo + 5.1, or Stereo + Eclipsa Audio. The bitrate table also lists Mono |
| Audio bitrate | Mono 128 kbps. Stereo 384 kbps. 5.1 512 kbps. Eclipsa Audio: 128 kbps per channel |
| Maximum resolution | **not published** as a reject limit. The bitrate table names 8K, 2160p, 1440p, 1080p, 720p, 480p, and 360p |
| Minimum duration | **not published** |
| Maximum duration | Default upload length is 15 minutes. Verified accounts can upload longer videos. Maximum file size is 256 GB or 12 hours, whichever is less. Source: [Upload videos longer than 15 minutes](https://support.google.com/youtube/answer/71673?hl=en) |
| UI safe zone | **not published** on these pages |

Recommended SDR video bitrates, standard frame rate (24, 25, 30) and high frame rate (48, 50, 60):

| Type | Standard frame rate | High frame rate |
| --- | --- | --- |
| 8K | 80–160 Mbps | 120–240 Mbps |
| 2160p (4K) | 35–45 Mbps | 53–68 Mbps |
| 1440p (2K) | 16 Mbps | 24 Mbps |
| 1080p | 8 Mbps | 12 Mbps |
| 720p | 5 Mbps | 7.5 Mbps |
| 480p | 2.5 Mbps | 4 Mbps |
| 360p | 1 Mbps | 1.5 Mbps |

HDR recommendations are a second table on the same page. 1080p HDR is 10 Mbps at standard frame rate and 15 Mbps at high frame rate. 480p and 360p HDR are not supported. The rest of the HDR table is on that page and is not repeated here.

Aspect ratio, same encoding page: the standard aspect ratio for YouTube on a computer is 16:9. For other aspect ratios, including vertical and square, the player adapts.

### Custom thumbnail

Source: [Add custom thumbnails](https://support.google.com/youtube/answer/72431?hl=en). Checked 2026-11-11. The page does not show an updated date.

A custom thumbnail requires a verified account. Custom thumbnails for Shorts can be added in YouTube Studio on a computer.

| Field | Recommended value |
| --- | --- |
| Resolution | 3840×2160 for videos, with a minimum width of 640 pixels. 2160×3840 for Shorts, with a minimum height of 640 pixels |
| Format | JPG or PNG |
| File size | Depends on the device used to upload the thumbnail. Mobile: 2 MB for video thumbnails, or 10 MB for podcasts. Desktop: 50 MB for video, Shorts, and podcast thumbnails |
| Aspect ratio | 16:9 for videos. 9:16 for Shorts. 1:1 for podcast playlists |

Vertical videos that use a 16:9 custom thumbnail are shown with an auto-generated 4:5 thumbnail on the home, explore, and subscription pages. The custom thumbnail still appears on the watch feed, watch history, and non-mobile platforms.

There is a daily custom-thumbnail upload limit. The page says the limit may vary by country or region and by channel history, and it does not publish a single number.

## YouTube Shorts

Sources, checked 2026-11-11, no updated date shown:

- [Understand three-minute YouTube Shorts](https://support.google.com/youtube/answer/15424877?hl=en)
- [Upload YouTube Shorts](https://support.google.com/youtube/answer/12779649?hl=en)

| Field | Published value |
| --- | --- |
| Container, codec, profile, pixel format, color, frame rate, audio | **not published** as a Shorts-only spec. The recommended upload encoding above is the YouTube encoding page |
| Aspect ratio | Square or vertical |
| Minimum duration | **not published** |
| Maximum duration | Up to 3 minutes |
| Maximum file size | **not published** separately from the YouTube upload limit (256 GB or 12 hours, whichever is less) |
| Cover or thumbnail | See the custom thumbnail section. Shorts recommendation: 9:16, 2160×3840, minimum height 640 pixels |
| UI safe zone | **not published** |

Categorization, standard channels: a square or vertical video of up to three minutes uploaded on or after 2024-10-15 is categorized as a Short. Videos uploaded before that date stay long-form. Official Artist Channels use 2025-12-08 for the same rule.

Upload path published on these pages: the YouTube app and YouTube Studio. A third-party share-intent file table: **not published** on the pages checked.

A 15-second "recommended for reach" figure is not on these pages and is not recorded as a limit.

## YouTube horizontal

The horizontal target uses the YouTube encoding and upload limits above.

| Field | Published value |
| --- | --- |
| Aspect ratio | 16:9 is the standard aspect ratio for YouTube on a computer. The player also adapts to other aspect ratios. A required horizontal reject line: **not published** |
| Duration and file size | Default 15 minutes until the account is verified. Then longer, up to 256 GB or 12 hours, whichever is less |
| Thumbnail | 16:9 recommended, 3840×2160, minimum width 640 pixels, JPG or PNG, size limit by device as above |
| Codec and color | The recommended encoding table, including H.264 High Profile, 4:2:0, BT.709 for SDR, moov atom at the front |
| UI safe zone | **not published** |

To keep a video from being categorized as a Short, the three-minute Shorts page says to use a wider aspect ratio such as 16:9.

## UI safe zones

Numeric insets (pixels or percentages of the frame, other than the ads disclaimer note below) for organic Stories, Reels, feed, TikTok, and YouTube: **not published** on the pages checked on 2026-11-11.

Meta's business help page is about **ads**, and it does not publish a pixel inset for the general case:

<https://www.facebook.com/business/help/980593475366490>

Checked 2026-11-11. The page does not show an updated date in the text retrieved.

What that page does say:

- The safe zone is the area where text overlays and logos are not cropped or covered by the interface.
- For 9:16 ads in Stories, Reels, Feed, and Facebook in-stream reels, keep the top, bottom, and side edges free of key creative elements, text, and logos.
- For Instagram feed ads that are not 9:16 (the examples given are 1:1 and 4:5), keep the bottom and side edges free of those elements.
- 9:16 video ads in Instagram feed use the same safe-zone guidance as Reels and Stories.
- Meta Ads Manager has a **Safe zone guardrail** drawn as a yellow overlay.
- If a Reels **ad** includes a disclaimer, leave the bottom 40% free of text, logos, and other key creative elements.

The English page says the safe zone is the area inside the yellow overlay. The UK English page of the same article says the safe zones are outside the yellow area. This document does not choose between those two sentences, and it does not turn either sentence into an organic pixel inset.

Phase 1 has no published numeric safe-zone inset to meet.

## Sources checked on 2026-11-11

| Page | Last updated on the site | Used for |
| --- | --- | --- |
| [Sharing to Stories](https://developers.facebook.com/docs/instagram-platform/sharing-to-stories) | 2026-06-30 | Phase 1 Story hand-off |
| [Sharing to Feed](https://developers.facebook.com/docs/instagram-platform/sharing-to-feed) | 2026-06-30 | Feed image and feed video hand-off |
| [IG User Media](https://developers.facebook.com/docs/instagram-platform/instagram-graph-api/reference/ig-user/media) | 2026-09-28 | Publishing-API image, Reel, Story image, Story video. Feed video spec absent |
| [Sharing to Reels, Android](https://developers.facebook.com/docs/android/sharing-to-reels-instagram) | 2024-03-18 | Reel share hand-off |
| [Sharing to Reels, iOS](https://developers.facebook.com/docs/ios/sharing-to-reels-instagram/) | 2026-04-06 | Reel share hand-off |
| [TikTok Media Transfer Guide](https://developers.tiktok.com/doc/content-posting-api-media-transfer-guide) | 2026-08-04 | TikTok file restrictions |
| [TikTok Upload](https://developers.tiktok.com/doc/content-posting-api-reference-upload-video) | 2026-08-04 | Inbox hand-off and MIME types |
| [TikTok Direct Post](https://developers.tiktok.com/doc/content-posting-api-reference-direct-post) | 2026-10-27 | Cover timestamp and the posting endpoint |
| [TikTok Query Creator Info](https://developers.tiktok.com/doc/content-posting-api-reference-query-creator-info) | 2026-10-27 | Per-account maximum duration |
| [YouTube recommended upload encoding](https://support.google.com/youtube/answer/1722171?hl=en) | not shown | Encoding recommendations |
| [YouTube uploads longer than 15 minutes](https://support.google.com/youtube/answer/71673?hl=en) | not shown | Duration and file size |
| [Three-minute YouTube Shorts](https://support.google.com/youtube/answer/15424877?hl=en) | not shown | Shorts duration and categorization |
| [Upload YouTube Shorts](https://support.google.com/youtube/answer/12779649?hl=en) | not shown | Shorts aspect ratio and upload path |
| [YouTube custom thumbnails](https://support.google.com/youtube/answer/72431?hl=en) | not shown | Thumbnail recommendations |
| [Meta ads safe zone](https://www.facebook.com/business/help/980593475366490) | not shown | Ads guidance only. No organic pixel inset |
