# Desktop library coverage

Run from the repository root:

```sh
bash tool/coverage.sh
```

The script resolves the desktop package's locked dependencies, then runs all of
its existing Flutter tests with `--coverage`. It writes `coverage/lcov.info`
with repository-relative source paths for Codecov. Both package and repository
coverage directories are ignored. A failed test run, missing/empty report or
unexpected source prefix fails collection; stale reports are removed first.
`python3 -m unittest discover -s tool -p test_coverage.py` exercises these failure
controls with a disposable Flutter stub, including the valid control. The shared
`bash tool/check.sh` entry point includes this tooling suite.

## Scope and interpretation

The report measures executed lines in `flutter/social_studio/lib` loaded by the
tests. It is not a coverage threshold or a measure of all repository code.
The historical probes, Python/shell tools, CLI and capture subprocesses, native
plugins and dependencies are outside this report. An integration test may check
an encoded output without adding its subprocess execution to the parent test's
coverage. A percentage is not evidence of mobile, browser or sharing acceptance.

## CI and Codecov setup

The separate [Coverage workflow](../../.github/workflows/coverage.yml) uses the
same pinned SDK and FFmpeg installation as Quality. It collects on pull requests,
main pushes and manual dispatch. Uploads use the pinned Codecov action and GitHub
OIDC (`id-token: write`), without a stored upload token. The repository must be
available to the owner's Codecov account/integration. See the
[action's OIDC documentation](https://github.com/codecov/codecov-action#using-oidc).
External-fork PRs collect locally in CI but skip upload because the job cannot
rely on receiving OIDC write permissions there.

The [Codecov configuration](../../codecov.yml) makes project and patch percentages
informational and disables PR comments. Upload failures still fail the Coverage
job so a broken integration is visible. Quality remains the repository gate.
The README badge points at this repository, not the Fluvie fork. The first
successful upload and the badge's live percentage require remote verification;
a local LCOV file alone cannot establish either.
