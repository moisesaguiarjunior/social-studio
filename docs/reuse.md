# Reuse map

One line per need: what to use, where it lives, and one consumer. Update in the same change that adds or removes a reusable solution.

| Need | Use | Where | Example consumer |
| --- | --- | --- | --- |
| Package format, strict analysis and tests | `check_package` | `tool/hooks/lib.sh` | pre-commit, pre-push, `tool/check.sh` |
| Decide whether changed paths affect the hook/CI gates | `hook_checks_required` | `tool/hooks/lib.sh` | staged pre-commit and every unpublished pre-push commit |
| Run the hook regression gate in an isolated Git environment | `check_hook_suite` | `tool/hooks/lib.sh` | hooks and `tool/check.sh` |
| Full checkout checks without depending on installed hooks | `bash tool/check.sh` | `tool/check.sh` | Quality workflow, local verification |
