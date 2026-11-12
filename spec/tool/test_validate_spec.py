#!/usr/bin/env python3
"""Tests for schema v0. Every case below is meant to fail if its guard is removed.

Run: python3 spec/tool/test_validate_spec.py
"""

from __future__ import annotations

import copy
import io
import subprocess
import sys
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from unittest import mock

TOOL = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOL))

import validate_spec
from validate_spec import (
    SPEC,
    catalog_errors,
    catalog_errors_for,
    enforce_limit,
    load_catalog,
    load_json,
    template_link_errors,
    validate_document,
    validate_job,
)

SCHEMA_DIR = SPEC / "schemas" / "v0"
FIXTURES = SPEC / "fixtures"
SOURCE = "https://developers.facebook.com/docs/instagram-platform/sharing-to-stories"


def profile_with(limit):
    return {
        "schema_version": "0",
        "id": "probe",
        "paths": [
            {
                "id": "share_hand_off",
                "role": "product_hand_off",
                "limits": [limit],
            }
        ],
    }


def limit(**extra):
    document = {
        "id": "ui_safe_zone",
        "status": "not_published",
        "source": SOURCE,
        "source_updated": "2026-06-30",
        "checked_on": "2026-11-11",
    }
    document.update(extra)
    return document


def find_limit(profile, path_id, surface_id, limit_id):
    found = []
    for path in profile["paths"]:
        if path["id"] != path_id:
            continue
        groups = [(None, path["limits"])]
        for surface in path.get("surfaces", []):
            groups.append((surface["id"], surface["limits"]))
        for surface, limits in groups:
            if surface != surface_id:
                continue
            found.extend(item for item in limits if item["id"] == limit_id)
    if len(found) != 1:
        raise AssertionError((path_id, surface_id, limit_id, len(found)))
    return found[0]


class SpecTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profiles, cls.templates, cls.jobs = load_catalog()
        cls.profile_schema = load_json(SCHEMA_DIR / "platform-profile.schema.json")
        cls.job_schema = load_json(SCHEMA_DIR / "render-job.schema.json")

    def schema_errors(self, document):
        return validate_document(document, self.profile_schema)

    def render(
        self,
        profile_id,
        path_id,
        *,
        surface=None,
        duration_ms=12000,
        width=1080,
        height=1920,
        frame_rate=30,
        data=None,
        leading_layouts=None,
        **extra,
    ):
        layout = {
            "profile_id": profile_id,
            "path_id": path_id,
            "canvas": {"width": width, "height": height, "frame_rate": frame_rate},
        }
        if surface is not None:
            layout["surface_id"] = surface
        layouts = list(leading_layouts or [])
        layouts.append(layout)
        template = {
            "schema_version": "0",
            "id": "probe",
            "slots": [{"id": "photo[0]", "kind": "image", "required": True}],
            "brand_tokens": {
                "colors": [{"id": "scene", "value": "#224466"}],
                "fonts": [],
                "logo": None,
            },
            "motion_presets": [],
            "caption_style": {"id": "subtitle"},
            "layers": [
                {
                    "id": "still",
                    "kind": "shape",
                    "start_ms": 0,
                    "duration_ms": duration_ms,
                    "color": "scene",
                }
            ],
            "layouts": layouts,
        }
        job = {
            "schema_version": "0",
            "id": "probe-job",
            "template_id": "probe",
            "profile_id": profile_id,
            "path_id": path_id,
            "duration_ms": duration_ms,
            "data": {"photo[0]": {"asset_id": "synthetic-swatch"}},
        }
        if data is not None:
            job["data"] = data
        if surface is not None:
            job["surface_id"] = surface
        job.update(extra)
        return validate_job(job, self.profiles, {"probe": template})


class SchemaRules(SpecTest):
    def test_not_published_rejects_a_value(self):
        document = load_json(FIXTURES / "invalid" / "not-published-value.json")
        errors = self.schema_errors(document)
        self.assertTrue(any(item.endswith(": not") for item in errors), errors)

    def test_not_published_rejects_a_binding(self):
        document = load_json(FIXTURES / "invalid" / "not-published-value.json")
        rule = document["paths"][0]["limits"][0]
        del rule["value"]
        rule["binding"] = "required"
        errors = self.schema_errors(document)
        self.assertTrue(any(item.endswith(": not") for item in errors), errors)

    def test_not_published_rejects_a_unit(self):
        document = load_json(FIXTURES / "invalid" / "not-published-value.json")
        rule = document["paths"][0]["limits"][0]
        del rule["value"]
        rule["unit"] = "pixels"
        errors = self.schema_errors(document)
        self.assertTrue(any(item.endswith(": not") for item in errors), errors)

    def test_published_limit_needs_a_binding(self):
        document = profile_with(limit(status="published"))
        errors = self.schema_errors(document)
        self.assertTrue(any("required binding" in item for item in errors), errors)

    def test_required_binding_needs_a_value(self):
        document = profile_with(limit(status="published", binding="required"))
        errors = self.schema_errors(document)
        self.assertTrue(any("required value" in item for item in errors), errors)

    def test_recommended_should_and_can_be_may_omit_a_value(self):
        for binding in ("recommended", "should", "can_be"):
            document = profile_with(
                limit(id="nominal_resolution", status="published", binding=binding, text="No number.")
            )
            self.assertEqual(self.schema_errors(document), [], binding)

    def test_unknown_schema_version_is_rejected(self):
        job = copy.deepcopy(self.jobs["phase1-story-12"])
        job["schema_version"] = "1"
        errors = validate_job(job, self.profiles, self.templates)
        self.assertTrue(any("const" in item for item in errors), errors)
        self.assertFalse(any(item == "unknown_profile" for item in errors))

    def test_an_unknown_field_is_rejected(self):
        job = copy.deepcopy(self.jobs["phase1-story-12"])
        job["extra"] = 1
        errors = validate_document(job, self.job_schema)
        self.assertTrue(any("additional property extra" in item for item in errors), errors)

    def test_a_changed_number_stays_on_schema_version_0(self):
        profile = copy.deepcopy(self.profiles["instagram-story"])
        rule = find_limit(profile, "share_hand_off", None, "maximum_duration_seconds")
        rule["value"] = 30
        self.assertEqual(profile["schema_version"], "0")
        self.assertEqual(validate_document(profile, self.profile_schema), [])
        profiles = dict(self.profiles)
        profiles["instagram-story"] = profile
        job = load_json(FIXTURES / "invalid" / "duration-outside-story-share.json")
        self.assertEqual(validate_job(job, profiles, self.templates), [])

    def test_a_new_profile_field_is_a_schema_change(self):
        profile = copy.deepcopy(self.profiles["instagram-story"])
        profile["note"] = "a new field"
        errors = validate_document(profile, self.profile_schema)
        self.assertTrue(any("additional property note" in item for item in errors), errors)

    def test_checked_on_must_be_a_date(self):
        document = profile_with(limit(checked_on="11/11/2026"))
        errors = self.schema_errors(document)
        self.assertTrue(any("pattern" in item for item in errors), errors)

    def test_type_union_accepts_null_and_rejects_a_number(self):
        schema = {"type": ["string", "null"]}
        self.assertEqual(validate_document(None, schema), [])
        self.assertEqual(validate_document("subtitle", schema), [])
        self.assertTrue(validate_document(1, schema))

    def test_unknown_keyword_fails_loudly(self):
        errors = validate_document([], {"uniqueItems": True})
        self.assertTrue(any("unsupported keyword uniqueItems" in item for item in errors), errors)

    def test_ref_does_not_silently_drop_a_sibling(self):
        schema = {
            "$defs": {"name": {"type": "string"}},
            "$ref": "#/$defs/name",
            "minLength": 2,
        }
        errors = validate_document("a", schema)
        self.assertTrue(any("unsupported keyword minLength" in item for item in errors), errors)

    def test_not_published_is_not_a_reject_line(self):
        problem = enforce_limit(
            {
                "id": "maximum_duration_seconds",
                "status": "not_published",
                "binding": "required",
                "value": 1,
            },
            {"duration_ms": 10**9},
            {},
        )
        self.assertIsNone(problem)

    def test_recommended_maximum_is_not_a_reject_line(self):
        problem = enforce_limit(
            {
                "id": "maximum_duration_seconds",
                "status": "published",
                "binding": "recommended",
                "value": 1,
            },
            {"duration_ms": 10**9},
            {},
        )
        self.assertIsNone(problem)

    def test_file_size_is_not_a_byte_gate(self):
        problem = enforce_limit(
            {
                "id": "maximum_file_size",
                "status": "published",
                "binding": "required",
                "value": 1,
                "unit": "MB",
            },
            {"duration_ms": 1},
            {},
        )
        self.assertIsNone(problem)


class Catalog(SpecTest):
    def test_catalog_matches_the_schemas(self):
        self.assertEqual(catalog_errors(), [])

    def test_every_required_limit_is_classified(self):
        seen = set()
        for profile in self.profiles.values():
            for path in profile["paths"]:
                groups = [path["limits"]]
                groups.extend(surface["limits"] for surface in path.get("surfaces", []))
                for limits in groups:
                    for limit in limits:
                        if limit["status"] == "published" and limit["binding"] == "required":
                            seen.add(limit["id"])
        self.assertEqual(seen - validate_spec.JOB_LIMITS, validate_spec.FILE_LIMITS)

    def test_an_unclassified_required_limit_fails_the_catalog(self):
        profiles = copy.deepcopy(self.profiles)
        profiles["instagram-story"]["paths"][0]["limits"].append(
            {
                "id": "not_classified",
                "status": "published",
                "binding": "required",
                "value": "recorded",
                "source": SOURCE,
                "source_updated": "2026-11-11",
                "checked_on": "2026-11-11",
            }
        )
        self.assertEqual(
            catalog_errors_for(profiles, self.templates, self.jobs),
            ["unclassified_limit instagram-story share_hand_off not_classified"],
        )

    def test_ids_match_file_names(self):
        folders = (
            SPEC / "platform-profiles",
            SPEC / "template",
            SPEC / "render-job",
        )
        for folder in folders:
            for path in folder.glob("*.json"):
                document = load_json(path)
                self.assertEqual(document["id"], path.stem)
                self.assertEqual(document["schema_version"], "0")

    def test_command_accepts_the_catalog(self):
        completed = subprocess.run(
            [sys.executable, str(TOOL / "validate_spec.py")],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(completed.stdout.strip(), "schema v0 ok")

    def test_command_returns_failure(self):
        with mock.patch.object(validate_spec, "catalog_errors", return_value=["broken"]):
            buffer = io.StringIO()
            with redirect_stderr(buffer):
                code = validate_spec.main()
        self.assertEqual(code, 1)
        self.assertIn("broken", buffer.getvalue())

    def test_safe_zones_stay_unpublished(self):
        found = 0
        for profile in self.profiles.values():
            for path in profile["paths"]:
                groups = [path["limits"]]
                groups.extend(surface["limits"] for surface in path.get("surfaces", []))
                for limits in groups:
                    for rule in limits:
                        if rule["id"] != "ui_safe_zone":
                            continue
                        found += 1
                        self.assertEqual(rule["status"], "not_published")
                        self.assertNotIn("value", rule)
                        self.assertNotIn("binding", rule)
                        self.assertNotIn("unit", rule)
        self.assertGreater(found, 0)

    def test_story_share_keeps_the_published_split(self):
        story = self.profiles["instagram-story"]
        ios_size = find_limit(story, "share_hand_off", "ios", "maximum_file_size")
        self.assertEqual(ios_size["binding"], "recommended")
        self.assertEqual(ios_size["value"], 50)
        self.assertEqual(ios_size["unit"], "MB")
        android_size = find_limit(story, "share_hand_off", "android", "maximum_file_size")
        self.assertEqual(android_size["status"], "not_published")
        self.assertNotIn("value", android_size)
        minimum = find_limit(story, "share_hand_off", None, "minimum_duration_seconds")
        self.assertEqual(minimum["status"], "not_published")
        self.assertNotIn("value", minimum)
        maximum = find_limit(story, "share_hand_off", None, "maximum_duration_seconds")
        self.assertEqual(maximum["binding"], "required")
        self.assertEqual(maximum["value"], 20)
        codecs = find_limit(story, "share_hand_off", None, "video_codecs")
        self.assertEqual(codecs["value"], ["h264", "h265", "webm"])
        api_codecs = find_limit(story, "publishing_api", None, "video_codecs")
        self.assertEqual(api_codecs["value"], ["hevc", "h264"])
        story_aspect = find_limit(story, "publishing_api", None, "aspect_ratio_range")
        self.assertEqual(story_aspect["value"]["minimum"], "0.1:1")
        reel_aspect = find_limit(
            self.profiles["instagram-reel"], "publishing_api", None, "aspect_ratio_range"
        )
        self.assertEqual(reel_aspect["value"]["minimum"], "0.01:1")
        story_image_width = find_limit(story, "publishing_api_image", None, "minimum_width")
        self.assertEqual(story_image_width["status"], "not_published")
        self.assertNotIn("value", story_image_width)

    def test_reel_duration_is_should(self):
        reel = self.profiles["instagram-reel"]
        minimum = find_limit(reel, "share_hand_off", None, "minimum_duration_seconds")
        maximum = find_limit(reel, "share_hand_off", None, "maximum_duration_seconds")
        self.assertEqual(minimum["binding"], "should")
        self.assertEqual(minimum["value"], 3)
        self.assertEqual(maximum["binding"], "should")
        self.assertEqual(maximum["value"], 60)

    def test_tiktok_example_duration_is_not_a_limit(self):
        tiktok = self.profiles["tiktok"]
        account = find_limit(tiktok, "inbox_upload", None, "account_maximum_duration_seconds")
        self.assertEqual(account["binding"], "can_be")
        self.assertNotIn("value", account)
        self.assertIn("300", account["text"])
        self.assertIn("example", account["text"])
        developer = find_limit(tiktok, "inbox_upload", None, "maximum_duration_seconds")
        self.assertEqual(developer["binding"], "required")
        self.assertEqual(developer["value"], 600)
        direct = next(path for path in tiktok["paths"] if path["id"] == "direct_post")
        self.assertEqual(direct["role"], "publishing_api")
        self.assertNotIn("maximum_duration_seconds", [item["id"] for item in direct["limits"]])

    def test_youtube_default_length_is_can_be(self):
        horizontal = self.profiles["youtube-horizontal"]
        default = find_limit(horizontal, "upload", None, "unverified_default_duration_seconds")
        self.assertEqual(default["binding"], "can_be")
        self.assertEqual(default["value"], 900)
        ceiling = find_limit(horizontal, "upload", None, "maximum_duration_seconds")
        self.assertEqual(ceiling["binding"], "required")
        self.assertEqual(ceiling["value"], 43200)
        self.assertIsNone(
            next(
                (
                    item
                    for item in horizontal["paths"][0]["limits"]
                    if item["id"] == "minimum_width"
                ),
                None,
            )
        )
        shorts = find_limit(self.profiles["youtube-shorts"], "upload", None, "video_codecs")
        self.assertEqual(shorts["binding"], "recommended")


class Phase1Story(SpecTest):
    def test_one_template_validates_on_story_and_feed(self):
        self.assertEqual(
            validate_job(self.jobs["phase1-story-12"], self.profiles, self.templates),
            [],
        )
        self.assertEqual(
            validate_job(self.jobs["story-12-feed"], self.profiles, self.templates),
            [],
        )

    def test_the_template_is_the_phase_1_scene(self):
        template = self.templates["story-12"]
        self.assertEqual(template["cover_at_ms"], 3000)
        self.assertEqual(
            [(item["id"], item["value"]) for item in template["brand_tokens"]["colors"]],
            [("lead_in", "#101010"), ("flash", "#FFFFFF"), ("scene", "#224466")],
        )
        self.assertIsNone(template["brand_tokens"]["logo"])
        motion = template["motion_presets"][0]
        self.assertEqual(motion["id"], "slow-scale")
        self.assertEqual(motion["zoom"], 1.08)
        layers = {item["id"]: item for item in template["layers"]}
        self.assertEqual(layers["lead-in"]["duration_ms"], 1000)
        self.assertEqual(layers["flash"]["start_ms"], 1000)
        self.assertEqual(layers["flash"]["duration_ms"], 200)
        self.assertEqual(layers["photo"]["start_ms"], 1200)
        self.assertEqual(layers["photo"]["slot"], "photo[0]")
        self.assertEqual(layers["photo"]["motion"], "slow-scale")
        self.assertEqual(layers["voice"]["start_ms"], 1000)
        self.assertEqual(
            layers["captions"]["cues"],
            [
                {"start_ms": 2000, "end_ms": 6000, "text": "A synthetic caption"},
                {"start_ms": 6000, "end_ms": 11000, "text": "from a supplied transcript"},
            ],
        )
        self.assertEqual(
            sum(1 for item in template["layers"] if item["kind"] == "captions"),
            1,
        )
        quote = next(item for item in template["slots"] if item["id"] == "quote")
        self.assertFalse(quote["required"])
        layouts = {(item["profile_id"], item["path_id"]): item for item in template["layouts"]}
        self.assertEqual(layouts[("instagram-story", "share_hand_off")]["canvas"]["width"], 1080)
        self.assertEqual(layouts[("instagram-story", "share_hand_off")]["canvas"]["height"], 1920)
        self.assertNotIn("surface_id", layouts[("instagram-story", "share_hand_off")])
        feed = layouts[("instagram-feed", "share_hand_off_video")]
        self.assertEqual(feed["surface_id"], "android")
        self.assertEqual(feed["canvas"], {"width": 1080, "height": 1350, "frame_rate": 30})

    def test_the_story_job_names_the_android_share_hand_off(self):
        job = self.jobs["phase1-story-12"]
        self.assertEqual(job["profile_id"], "instagram-story")
        self.assertEqual(job["path_id"], "share_hand_off")
        self.assertEqual(job["surface_id"], "android")
        self.assertEqual(job["duration_ms"], 12000)
        self.assertEqual(job["video_codec"], "h264")
        self.assertEqual(job["data"]["voice"], {"asset_id": "synthetic-tone", "at_ms": 1000})
        self.assertNotIn("quote", job["data"])

    def test_an_optional_quote_may_be_filled(self):
        job = copy.deepcopy(self.jobs["phase1-story-12"])
        job["data"]["quote"] = {"text": "A synthetic line"}
        self.assertEqual(validate_job(job, self.profiles, self.templates), [])

    def test_template_links_fail_when_a_name_is_unknown(self):
        template = copy.deepcopy(self.templates["story-12"])
        template["layers"][0]["color"] = "missing"
        self.assertIn("unknown_color missing", template_link_errors(template))
        template = copy.deepcopy(self.templates["story-12"])
        next(item for item in template["layers"] if item["id"] == "photo")["motion"] = "spin"
        self.assertIn("unknown_motion spin", template_link_errors(template))
        template = copy.deepcopy(self.templates["story-12"])
        next(item for item in template["layers"] if item["id"] == "photo")["slot"] = "photo[9]"
        self.assertIn("unknown_slot photo[9]", template_link_errors(template))
        template = copy.deepcopy(self.templates["story-12"])
        next(item for item in template["layers"] if item["id"] == "captions")["style"] = "other"
        self.assertIn("unknown_caption_style", template_link_errors(template))


class RejectLines(SpecTest):
    def test_duration_outside_the_story_share_maximum(self):
        job = load_json(FIXTURES / "invalid" / "duration-outside-story-share.json")
        self.assertEqual(
            validate_job(job, self.profiles, self.templates),
            ["limit_exceeded maximum_duration_seconds"],
        )

    def test_twenty_seconds_is_inside_the_maximum(self):
        job = load_json(FIXTURES / "valid" / "story-share-twenty-seconds.json")
        self.assertEqual(validate_job(job, self.profiles, self.templates), [])
        self.assertEqual(
            self.render(
                "instagram-story",
                "share_hand_off",
                surface="android",
                duration_ms=20001,
                video_codec="h264",
            ),
            ["limit_exceeded maximum_duration_seconds"],
        )

    def test_unknown_profile(self):
        job = load_json(FIXTURES / "invalid" / "unknown-profile.json")
        self.assertEqual(validate_job(job, self.profiles, self.templates), ["unknown_profile"])

    def test_unfilled_slot(self):
        job = load_json(FIXTURES / "invalid" / "unfilled-slot.json")
        self.assertEqual(
            validate_job(job, self.profiles, self.templates),
            ["slot_unfilled voice"],
        )

    def test_two_second_story_share_passes_and_the_api_rejects_it(self):
        share = load_json(FIXTURES / "valid" / "story-share-two-seconds.json")
        self.assertEqual(validate_job(share, self.profiles, self.templates), [])
        api = self.render(
            "instagram-story",
            "publishing_api",
            duration_ms=2000,
            video_codec="h264",
            container="mp4",
        )
        self.assertEqual(api, ["limit_missed minimum_duration_seconds"])

    def test_story_paths_do_not_share_a_codec_token(self):
        self.assertEqual(
            self.render(
                "instagram-story",
                "share_hand_off",
                surface="android",
                video_codec="webm",
            ),
            [],
        )
        self.assertEqual(
            self.render(
                "instagram-story",
                "share_hand_off",
                surface="android",
                video_codec="h265",
            ),
            [],
        )
        self.assertIn(
            "codec_rejected video_codecs",
            self.render(
                "instagram-story",
                "publishing_api",
                duration_ms=5000,
                video_codec="webm",
                container="mp4",
            ),
        )
        self.assertIn(
            "codec_rejected video_codecs",
            self.render(
                "instagram-story",
                "publishing_api",
                duration_ms=5000,
                video_codec="h265",
                container="mp4",
            ),
        )
        self.assertEqual(
            self.render(
                "instagram-story",
                "publishing_api",
                duration_ms=5000,
                video_codec="hevc",
                container="mp4",
            ),
            [],
        )

    def test_a_square_story_is_not_forced_to_nine_by_sixteen(self):
        self.assertEqual(
            self.render(
                "instagram-story",
                "publishing_api",
                duration_ms=5000,
                width=1080,
                height=1080,
                video_codec="h264",
                container="mp4",
            ),
            [],
        )

    def test_a_required_codec_list_rejects_a_job_that_names_no_codec(self):
        self.assertEqual(
            self.render(
                "instagram-story",
                "share_hand_off",
                surface="android",
                duration_ms=12000,
            ),
            ["limit_missing video_codecs"],
        )

    def test_a_layout_for_one_surface_does_not_serve_another(self):
        ios_canvas = {
            "profile_id": "instagram-story",
            "path_id": "share_hand_off",
            "surface_id": "ios",
            "canvas": {"width": 100, "height": 100, "frame_rate": 30},
        }
        self.assertEqual(
            self.render(
                "instagram-story",
                "share_hand_off",
                surface="android",
                width=1080,
                height=1920,
                video_codec="h264",
                leading_layouts=[ios_canvas],
            ),
            [],
        )

    def test_android_minimum_pixels_do_not_apply_to_ios(self):
        self.assertIn(
            "limit_missed minimum_width",
            self.render(
                "instagram-story",
                "share_hand_off",
                surface="android",
                width=100,
                height=100,
                video_codec="h264",
            ),
        )
        self.assertEqual(
            self.render(
                "instagram-story",
                "share_hand_off",
                surface="ios",
                width=100,
                height=100,
                video_codec="h264",
            ),
            [],
        )

    def test_a_story_share_job_names_a_surface(self):
        self.assertEqual(
            self.render("instagram-story", "share_hand_off", video_codec="h264"),
            ["missing_surface"],
        )
        self.assertEqual(
            self.render(
                "instagram-story",
                "share_hand_off",
                surface="desktop",
                video_codec="h264",
            ),
            ["unknown_surface"],
        )

    def test_reel_should_bounds_do_not_reject(self):
        self.assertEqual(
            self.render(
                "instagram-reel",
                "share_hand_off",
                surface="android",
                duration_ms=2000,
                video_codec="h264",
            ),
            [],
        )
        self.assertEqual(
            self.render(
                "instagram-reel",
                "share_hand_off",
                surface="android",
                duration_ms=90000,
                video_codec="h264",
            ),
            [],
        )
        self.assertEqual(
            self.render(
                "instagram-reel",
                "share_hand_off",
                surface="android",
                duration_ms=90000,
                video_codec="h264",
                container="mkv",
            ),
            ["codec_rejected accepted_formats"],
        )
        self.assertEqual(
            self.render(
                "instagram-reel",
                "publishing_api",
                duration_ms=2000,
                video_codec="h264",
                container="mp4",
            ),
            ["limit_missed minimum_duration_seconds"],
        )

    def test_feed_video_uses_only_the_android_table(self):
        self.assertEqual(
            self.render(
                "instagram-feed",
                "share_hand_off_video",
                surface="android",
                duration_ms=2000,
                width=1080,
                height=1350,
                container="mp4",
            ),
            ["limit_missed minimum_duration_seconds"],
        )
        self.assertIn(
            "limit_missed minimum_width",
            self.render(
                "instagram-feed",
                "share_hand_off_video",
                surface="android",
                width=100,
                height=100,
                container="mp4",
            ),
        )
        self.assertEqual(
            self.render(
                "instagram-feed",
                "share_hand_off_video",
                surface="ios",
                duration_ms=1000,
                width=100,
                height=100,
            ),
            [],
        )
        self.assertEqual(
            self.render(
                "instagram-feed",
                "publishing_api",
                duration_ms=3600000,
                video_codec="h264",
                container="mp4",
            ),
            [],
        )

    def test_feed_image_ranges_stay_on_their_path(self):
        self.assertEqual(
            self.render(
                "instagram-feed",
                "publishing_api_image",
                duration_ms=0,
                width=100,
                height=100,
                format="jpeg",
            ),
            ["limit_missed minimum_width"],
        )
        self.assertIn(
            "limit_exceeded maximum_width",
            self.render(
                "instagram-feed",
                "publishing_api_image",
                duration_ms=0,
                width=1441,
                height=1441,
                format="jpeg",
            ),
        )
        self.assertIn(
            "codec_rejected accepted_formats",
            self.render(
                "instagram-feed",
                "publishing_api_image",
                duration_ms=0,
                width=320,
                height=320,
                format="png",
            ),
        )
        self.assertEqual(
            self.render(
                "instagram-feed",
                "share_hand_off_image",
                surface="android",
                duration_ms=0,
                width=100,
                height=100,
                format="gif",
            ),
            [],
        )
        self.assertEqual(
            self.render(
                "instagram-feed",
                "share_hand_off_image",
                surface="ios",
                duration_ms=0,
                width=100,
                height=100,
                format="gif",
            ),
            ["codec_rejected accepted_formats"],
        )
        self.assertEqual(
            self.render(
                "instagram-story",
                "publishing_api_image",
                duration_ms=0,
                width=100,
                height=100,
                format="jpeg",
            ),
            [],
        )

    def test_tiktok_developer_maximum_is_ten_minutes(self):
        common = {"video_codec": "h264", "container": "mp4"}
        self.assertEqual(
            self.render("tiktok", "inbox_upload", duration_ms=360000, **common),
            [],
        )
        self.assertEqual(
            self.render("tiktok", "inbox_upload", duration_ms=600000, **common),
            [],
        )
        self.assertEqual(
            self.render("tiktok", "inbox_upload", duration_ms=601000, **common),
            ["limit_exceeded maximum_duration_seconds"],
        )
        self.assertIn(
            "limit_missed minimum_width",
            self.render("tiktok", "inbox_upload", width=359, height=1920, **common),
        )
        self.assertIn(
            "limit_exceeded maximum_width",
            self.render("tiktok", "inbox_upload", width=4097, height=1920, **common),
        )
        self.assertEqual(
            self.render("tiktok", "inbox_upload", frame_rate=22, **common),
            ["limit_missed minimum_frame_rate"],
        )
        self.assertEqual(
            self.render("tiktok", "direct_post", duration_ms=1200000),
            [],
        )

    def test_youtube_recommendations_are_not_reject_lines(self):
        self.assertEqual(
            self.render(
                "youtube-horizontal",
                "upload",
                duration_ms=1200000,
                width=1920,
                height=1080,
                frame_rate=10,
                video_codec="vp9",
                container="webm",
            ),
            [],
        )
        self.assertEqual(
            self.render(
                "youtube-horizontal",
                "upload",
                duration_ms=43200000,
                width=1920,
                height=1080,
            ),
            [],
        )
        self.assertEqual(
            self.render(
                "youtube-horizontal",
                "upload",
                duration_ms=43201000,
                width=1920,
                height=1080,
            ),
            ["limit_exceeded maximum_duration_seconds"],
        )
        self.assertEqual(
            self.render(
                "youtube-shorts",
                "upload",
                width=1920,
                height=1080,
                video_codec="vp9",
            ),
            ["aspect_rejected aspect_class"],
        )
        self.assertEqual(
            self.render(
                "youtube-shorts",
                "upload",
                width=1080,
                height=1920,
                video_codec="vp9",
            ),
            [],
        )
        self.assertEqual(
            self.render(
                "youtube-shorts",
                "upload",
                duration_ms=180000,
                width=1080,
                height=1920,
            ),
            [],
        )
        self.assertEqual(
            self.render(
                "youtube-shorts",
                "upload",
                duration_ms=181000,
                width=1080,
                height=1920,
            ),
            ["limit_exceeded maximum_duration_seconds"],
        )

    def test_unknown_template_path_layout_and_slot(self):
        job = copy.deepcopy(self.jobs["phase1-story-12"])
        job["template_id"] = "missing"
        self.assertEqual(validate_job(job, self.profiles, self.templates), ["unknown_template"])
        self.assertEqual(
            self.render("instagram-story", "ads", surface="android", video_codec="h264"),
            ["unknown_path"],
        )
        job = copy.deepcopy(self.jobs["phase1-story-12"])
        job["profile_id"] = "tiktok"
        job["path_id"] = "inbox_upload"
        job["container"] = "mp4"
        del job["surface_id"]
        self.assertEqual(validate_job(job, self.profiles, self.templates), ["missing_layout"])
        self.assertEqual(
            self.render(
                "instagram-story",
                "share_hand_off",
                surface="android",
                video_codec="h264",
                data={"photo[0]": {"asset_id": "synthetic-swatch"}, "nope": {"text": "x"}},
            ),
            ["unknown_slot nope"],
        )
        self.assertEqual(
            self.render(
                "instagram-story",
                "share_hand_off",
                surface="android",
                video_codec="h264",
                data={},
            ),
            ["slot_unfilled photo[0]"],
        )


if __name__ == "__main__":
    unittest.main()
