#!/usr/bin/env python3
"""Validate Social Studio schema v0 documents.

The schemas are JSON Schema draft 2020-12. This checker implements the
keywords those documents use. It is not a complete implementation of the
draft. Cross-document rules (which profile a job names, which slots it
fills, which required limits it meets) live here because one schema file
cannot see the profile catalog.

Only a limit whose status is published and whose binding is required can
reject a job. Recommended, should, and can-be values are recorded and are
not reject lines. A not-published limit has no value, binding, or unit;
that shape is rejected by the profile schema.

v0 enforces duration, width, height, frame rate, aspect class
`square_or_vertical`, and the token lists `video_codecs`, `containers`,
and `accepted_formats`. A required token list rejects a job that does not
name one of its fields. Every other required published limit id is a
finished-file check: size, bitrate, audio, color, pixel format, scan,
MIME type, fast start, and an aspect ratio stored as a ratio. An id in
neither group fails the catalog, so a new required limit cannot pass
unnoticed. File size stays in the page's unit and is not a byte gate.
When a path publishes surfaces, the job names one; limits on the path
apply to every surface, and limits on the surface are added.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SPEC = Path(__file__).resolve().parents[1]
SCHEMA_DIR = SPEC / "schemas" / "v0"

# (comparison, measurement key, multiplier from the limit's unit to the measurement)
SCALAR_LIMITS = {
    "maximum_duration_seconds": ("max", "duration_ms", 1000),
    "minimum_duration_seconds": ("min", "duration_ms", 1000),
    "minimum_width": ("min", "width", 1),
    "minimum_height": ("min", "height", 1),
    "maximum_width": ("max", "width", 1),
    "maximum_height": ("max", "height", 1),
    "minimum_frame_rate": ("min", "frame_rate", 1),
    "maximum_frame_rate": ("max", "frame_rate", 1),
}
TOKEN_FIELDS = {
    "video_codecs": ("video_codec",),
    "containers": ("container",),
    "accepted_formats": ("format", "video_codec", "container"),
}
# Job checks are the ids enforce_limit can reject. File checks are required
# facts this version stores and does not apply to the job. A required
# published id in neither set is a catalog error.
JOB_LIMITS = frozenset(SCALAR_LIMITS) | frozenset(TOKEN_FIELDS) | frozenset({"aspect_class"})
FILE_LIMITS = frozenset(
    {
        "aspect_ratio_range",
        "audio_channels",
        "audio_codecs",
        "audio_sample_rate",
        "color_space",
        "fast_start",
        "maximum_file_size",
        "mime_types",
        "pixel_format",
        "scan",
        "video_bitrate",
    }
)
IGNORED_SCHEMA_KEYWORDS = {"$schema", "$id", "$defs", "$comment", "description", "title"}


def load_json(path: Path):
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def _type_ok(instance, expected: str) -> bool:
    if expected == "object":
        return isinstance(instance, dict)
    if expected == "array":
        return isinstance(instance, list)
    if expected == "string":
        return isinstance(instance, str)
    if expected == "boolean":
        return isinstance(instance, bool)
    if expected == "integer":
        return isinstance(instance, int) and not isinstance(instance, bool)
    if expected == "number":
        return isinstance(instance, (int, float)) and not isinstance(instance, bool)
    if expected == "null":
        return instance is None
    return False


def validate_document(instance, schema) -> list[str]:
    """Return schema errors. An empty list means the instance matches."""
    return _validate(instance, schema, schema.get("$defs", {}), "$")


def _validate(instance, schema, defs, path: str) -> list[str]:
    if not isinstance(schema, dict):
        return [f"{path}: schema is not an object"]
    unknown = set(schema) - IGNORED_SCHEMA_KEYWORDS - {
        "$ref",
        "allOf",
        "anyOf",
        "oneOf",
        "not",
        "if",
        "then",
        "else",
        "const",
        "enum",
        "type",
        "properties",
        "required",
        "additionalProperties",
        "items",
        "minItems",
        "minLength",
        "minimum",
        "maximum",
        "pattern",
    }
    if unknown:
        return [f"{path}: unsupported keyword {sorted(unknown)[0]}"]

    if "$ref" in schema:
        # These schemas use $ref alone. A sibling keyword would be applied
        # in the draft and is rejected here until the checker implements it.
        extra = set(schema) - {"$ref"} - IGNORED_SCHEMA_KEYWORDS
        if extra:
            return [f"{path}: unsupported keyword {sorted(extra)[0]}"]
        ref = schema["$ref"]
        prefix = "#/$defs/"
        if not isinstance(ref, str) or not ref.startswith(prefix) or ref == prefix:
            return [f"{path}: unsupported ref"]
        name = ref[len(prefix) :]
        target = defs.get(name)
        if not isinstance(target, dict):
            return [f"{path}: unknown ref {name}"]
        return _validate(instance, target, defs, path)

    errors: list[str] = []
    if "allOf" in schema:
        for sub in schema["allOf"]:
            errors.extend(_validate(instance, sub, defs, path))
    if "anyOf" in schema:
        if not any(not _validate(instance, sub, defs, path) for sub in schema["anyOf"]):
            errors.append(f"{path}: anyOf")
    if "oneOf" in schema:
        matches = [
            sub for sub in schema["oneOf"] if not _validate(instance, sub, defs, path)
        ]
        if len(matches) != 1:
            errors.append(f"{path}: oneOf")
    if "not" in schema and not _validate(instance, schema["not"], defs, path):
        errors.append(f"{path}: not")
    if "if" in schema:
        matched = not _validate(instance, schema["if"], defs, path)
        if matched and "then" in schema:
            errors.extend(_validate(instance, schema["then"], defs, path))
        if not matched and "else" in schema:
            errors.extend(_validate(instance, schema["else"], defs, path))
    if "const" in schema and instance != schema["const"]:
        errors.append(f"{path}: const")
    if "enum" in schema and instance not in schema["enum"]:
        errors.append(f"{path}: enum")
    if "type" in schema:
        expected = schema["type"]
        if isinstance(expected, list):
            matches = any(_type_ok(instance, item) for item in expected)
        else:
            matches = _type_ok(instance, expected)
        if not matches:
            errors.append(f"{path}: type")
            return errors
    if isinstance(instance, str):
        if "minLength" in schema and len(instance) < schema["minLength"]:
            errors.append(f"{path}: minLength")
        if "pattern" in schema and re.fullmatch(schema["pattern"], instance) is None:
            errors.append(f"{path}: pattern")
    if isinstance(instance, (int, float)) and not isinstance(instance, bool):
        if "minimum" in schema and instance < schema["minimum"]:
            errors.append(f"{path}: minimum")
        if "maximum" in schema and instance > schema["maximum"]:
            errors.append(f"{path}: maximum")
    if isinstance(instance, list) and "items" in schema:
        if "minItems" in schema and len(instance) < schema["minItems"]:
            errors.append(f"{path}: minItems")
        for index, item in enumerate(instance):
            errors.extend(_validate(item, schema["items"], defs, f"{path}[{index}]"))
    if isinstance(instance, dict):
        properties = schema.get("properties", {})
        if "required" in schema:
            for key in schema["required"]:
                if key not in instance:
                    errors.append(f"{path}: required {key}")
        if "additionalProperties" in schema:
            rule = schema["additionalProperties"]
            for key in instance:
                if key in properties:
                    continue
                if rule is False:
                    errors.append(f"{path}: additional property {key}")
                elif isinstance(rule, dict):
                    errors.extend(_validate(instance[key], rule, defs, f"{path}.{key}"))
        for key, sub in properties.items():
            if key in instance:
                errors.extend(_validate(instance[key], sub, defs, f"{path}.{key}"))
    return errors


def _documents(folder: Path) -> dict[str, dict]:
    found = {}
    for path in sorted(folder.glob("*.json")):
        document = load_json(path)
        doc_id = document.get("id")
        if not isinstance(doc_id, str) or doc_id in found:
            raise ValueError(f"duplicate or missing id in {path.name}")
        found[doc_id] = document
    return found


def load_catalog():
    profiles = _documents(SPEC / "platform-profiles")
    templates = _documents(SPEC / "template")
    jobs = _documents(SPEC / "render-job")
    return profiles, templates, jobs


def _schema(name: str) -> dict:
    return load_json(SCHEMA_DIR / name)


def enforce_limit(limit: dict, measured: dict, job: dict) -> str | None:
    """Return an error code when a required published limit rejects the job.

    Any other limit, including recommended and not-published, returns None.
    """
    if limit.get("status") != "published" or limit.get("binding") != "required":
        return None
    limit_id = limit.get("id")
    if limit_id in SCALAR_LIMITS:
        kind, key, scale = SCALAR_LIMITS[limit_id]
        if key not in measured:
            return f"limit_missing {limit_id}"
        actual = measured[key]
        bound = limit["value"] * scale
        if kind == "max" and actual > bound:
            return f"limit_exceeded {limit_id}"
        if kind == "min" and actual < bound:
            return f"limit_missed {limit_id}"
        return None
    if limit_id in TOKEN_FIELDS:
        allowed = limit.get("value")
        if not isinstance(allowed, list):
            return f"limit_missing {limit_id}"
        fields = TOKEN_FIELDS[limit_id]
        present = [field for field in fields if field in job]
        # A required list rejects a job that names none of its fields.
        # Naming one allowed token is enough; the page's list is the set.
        if not present:
            return f"limit_missing {limit_id}"
        for field in present:
            if job[field] not in allowed:
                return f"codec_rejected {limit_id}"
        return None
    if limit_id == "aspect_class" and limit.get("value") == "square_or_vertical":
        if measured["height"] < measured["width"]:
            return "aspect_rejected aspect_class"
        return None
    return None


def template_link_errors(template: dict) -> list[str]:
    colors = {item["id"] for item in template["brand_tokens"]["colors"]}
    motions = {item["id"] for item in template["motion_presets"]}
    slots = {item["id"] for item in template["slots"]}
    style = template["caption_style"]["id"]
    errors = []
    for layer in template["layers"]:
        if "color" in layer and layer["color"] not in colors:
            errors.append(f"unknown_color {layer['color']}")
        if "motion" in layer and layer["motion"] not in motions:
            errors.append(f"unknown_motion {layer['motion']}")
        if "slot" in layer and layer["slot"] not in slots:
            errors.append(f"unknown_slot {layer['slot']}")
        if layer.get("kind") == "captions" and layer.get("style") != style:
            errors.append("unknown_caption_style")
    return errors


def _matching_layout(template: dict, job: dict) -> dict | None:
    matches = []
    for layout in template["layouts"]:
        if layout["profile_id"] != job["profile_id"]:
            continue
        if layout["path_id"] != job["path_id"]:
            continue
        layout_surface = layout.get("surface_id")
        job_surface = job.get("surface_id")
        if layout_surface is not None and layout_surface != job_surface:
            continue
        matches.append(layout)
    specific = [layout for layout in matches if "surface_id" in layout]
    if specific:
        return specific[0]
    if matches:
        return matches[0]
    return None


def validate_job(job: dict, profiles: dict[str, dict], templates: dict[str, dict]) -> list[str]:
    """Return every problem that rejects this job. Empty means it validates."""
    errors = [f"schema {item}" for item in validate_document(job, _schema("render-job.schema.json"))]
    if errors:
        return errors
    template = templates.get(job["template_id"])
    if template is None:
        return ["unknown_template"]
    template_errors = validate_document(template, _schema("template.schema.json"))
    if template_errors:
        return errors + [f"schema {item}" for item in template_errors]
    errors.extend(template_link_errors(template))
    profile = profiles.get(job["profile_id"])
    if profile is None:
        return errors + ["unknown_profile"]
    profile_errors = validate_document(profile, _schema("platform-profile.schema.json"))
    if profile_errors:
        return errors + [f"schema {item}" for item in profile_errors]
    path = next((item for item in profile["paths"] if item["id"] == job["path_id"]), None)
    if path is None:
        return errors + ["unknown_path"]
    limits = list(path["limits"])
    surfaces = path.get("surfaces", [])
    surface_id = job.get("surface_id")
    if surface_id is None:
        if surfaces:
            return errors + ["missing_surface"]
    else:
        surface = next((item for item in surfaces if item["id"] == surface_id), None)
        if surface is None:
            return errors + ["unknown_surface"]
        limits.extend(surface["limits"])
    layout = _matching_layout(template, job)
    if layout is None:
        return errors + ["missing_layout"]
    slot_ids = {item["id"] for item in template["slots"]}
    for slot in template["slots"]:
        if slot["required"] and slot["id"] not in job["data"]:
            errors.append(f"slot_unfilled {slot['id']}")
    for key in job["data"]:
        if key not in slot_ids:
            errors.append(f"unknown_slot {key}")
    measured = {
        "duration_ms": job["duration_ms"],
        "width": layout["canvas"]["width"],
        "height": layout["canvas"]["height"],
        "frame_rate": job.get("frame_rate", layout["canvas"]["frame_rate"]),
    }
    for limit in limits:
        problem = enforce_limit(limit, measured, job)
        if problem:
            errors.append(problem)
    return errors


def required_limit_errors(profile_id: str, profile: dict) -> list[str]:
    """Name every required published limit this checker does not classify."""
    errors = []
    for path in profile.get("paths", []):
        groups = [(None, path.get("limits", []))]
        for surface in path.get("surfaces", []):
            groups.append((surface.get("id"), surface.get("limits", [])))
        for surface_id, limits in groups:
            place = path["id"] if surface_id is None else f"{path['id']}/{surface_id}"
            for limit in limits:
                if limit.get("status") != "published" or limit.get("binding") != "required":
                    continue
                limit_id = limit.get("id")
                if limit_id in JOB_LIMITS or limit_id in FILE_LIMITS:
                    continue
                errors.append(f"unclassified_limit {profile_id} {place} {limit_id}")
    return errors


def catalog_errors_for(profiles: dict, templates: dict, jobs: dict) -> list[str]:
    errors = []
    profile_schema = _schema("platform-profile.schema.json")
    template_schema = _schema("template.schema.json")
    for doc_id, profile in profiles.items():
        for item in validate_document(profile, profile_schema):
            errors.append(f"{doc_id} schema {item}")
        errors.extend(required_limit_errors(doc_id, profile))
    for doc_id, template in templates.items():
        for item in validate_document(template, template_schema):
            errors.append(f"{doc_id} schema {item}")
        for item in template_link_errors(template):
            errors.append(f"{doc_id} {item}")
    if not jobs:
        errors.append("catalog has no render job")
    for doc_id, job in jobs.items():
        for item in validate_job(job, profiles, templates):
            errors.append(f"{doc_id} {item}")
    return errors


def catalog_errors() -> list[str]:
    profiles, templates, jobs = load_catalog()
    return catalog_errors_for(profiles, templates, jobs)


def main() -> int:
    errors = catalog_errors()
    if errors:
        for item in errors:
            print(item, file=sys.stderr)
        return 1
    print("schema v0 ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
