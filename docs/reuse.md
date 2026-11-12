# Reuse map

One line per need: what to use, where it lives, and one consumer. Update in the same change that adds or removes a reusable solution.

| Need | Use | Where | Example consumer |
| --- | --- | --- | --- |
| Package format, strict analysis and tests | `check_package` (isolated stdin) | `tool/hooks/lib.sh` | pre-commit, pre-push, `tool/check.sh` |
| Decide whether changed paths affect the hook/CI gates | `hook_checks_required` | `tool/hooks/lib.sh` | staged pre-commit and every unpublished pre-push commit |
| Run the hook regression gate in an isolated Git environment | `check_hook_suite` (isolated stdin) | `tool/hooks/lib.sh` | hooks and `tool/check.sh` |
| Full checkout checks without depending on installed hooks | `bash tool/check.sh` | `tool/check.sh` | Quality workflow, local verification |
| Container reading for one encoded Story (size, `moov` before `mdat`, and `ffprobe` when it runs) | Call `probes/phase0/tool/inspect_story15.py` as a subprocess. Do not copy it | `probes/phase1/tool/inspect_story.py` | Phase 1 Story spike |
| Synthetic swatch | The writer in `probes/phase0/tool/generate_story15_assets.py`, copied. Not extracted. The phase 0 generator is recorded evidence, and this tone is a different length | `probes/phase1/tool/generate_story_assets.py` | `probes/phase1/lib/story_12.dart` |
| Validate a platform profile, a template, and a render job | `validate_spec.py` | `spec/tool/validate_spec.py` | `spec/tool/test_validate_spec.py`, `check_spec` |
| Decide whether changed paths need the schema suite | `spec_checks_required` | `tool/hooks/lib.sh` | staged pre-commit and every unpublished pre-push commit |
| Run the schema suite, and fail if schemas exist without it | `check_spec` | `tool/hooks/lib.sh` | hooks and `tool/check.sh` |
