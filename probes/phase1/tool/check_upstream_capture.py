#!/usr/bin/env python3
"""Check draft patches in disposable copies of the pinned hosted packages.

Never changes the package cache or the consuming application's dependency graph.
Run `flutter pub get --enforce-lockfile` first to locate the hosted sources.
"""

import json
import shutil
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import unquote, urlparse

PROBE = Path(__file__).resolve().parents[1]
PACKAGES = ("fluvie", "fluvie_mobile_encoder")
TEST = "upstream/capture_contract_test.dart"


def run(args: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(args, cwd=cwd, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, check=False)
    return result


def require_success(result: subprocess.CompletedProcess[str], label: str) -> None:
    if result.returncode:
        # Temporary paths and SDK diagnostics remain local, not committed evidence.
        raise RuntimeError(f"{label} failed:\n{result.stdout}")


def main() -> None:
    config_path = PROBE / ".dart_tool/package_config.json"
    config = json.loads(config_path.read_text())
    with tempfile.TemporaryDirectory(prefix="capture-patch-") as temporary:
        root = Path(temporary)
        for package in PACKAGES:
            entry = next(p for p in config["packages"] if p["name"] == package)
            uri = urlparse(entry["rootUri"])
            source = Path(unquote(uri.path))
            if not source.is_absolute():
                source = config_path.parent / source
            manifest = (source / "pubspec.yaml").read_text()
            if "version: 0.3.1\n" not in manifest:
                raise RuntimeError(f"{package}: expected the pinned version 0.3.1")
            shutil.copytree(source, root / package)
            # Published workspace members must be detached for a path override.
            (root / package / "pubspec.yaml").write_text(
                manifest.replace("resolution: workspace\n", "")
            )
        shutil.copytree(PROBE, root / "probe", ignore=shutil.ignore_patterns(
            ".dart_tool", "build", ".fluvie", "out"))
        probe = root / "probe"
        (probe / "pubspec_overrides.yaml").write_text(
            "dependency_overrides:\n"
            "  fluvie:\n    path: ../fluvie\n"
            "  fluvie_mobile_encoder:\n    path: ../fluvie_mobile_encoder\n"
        )
        require_success(run(["flutter", "pub", "get", "--offline"], probe), "setup")
        baseline = run(["flutter", "test", TEST, "--reporter", "expanded"], probe)
        # A compiler/setup failure must not count as reproducing these defects.
        expected = (
            "The animated child must be visible in captured frame zero.",
            "Caption ink must reach the encoded-input frames.",
            "disposing the offscreen host unmounts its tree [E]",
        )
        if baseline.returncode == 0 or not all(x in baseline.stdout for x in expected):
            raise RuntimeError(f"Baseline did not reproduce all three defects:\n{baseline.stdout}")
        print("baseline: motion, captions and unmount controls rejected", flush=True)
        for patch in ("captions.patch", "capture-lifecycle.patch"):
            require_success(run(["git", "apply", "--check", str(PROBE / "upstream" / patch)], root), patch)
            require_success(run(["git", "apply", str(PROBE / "upstream" / patch)], root), patch)
        require_success(run(["flutter", "test", TEST, "--reporter", "expanded"], probe), "patched capture")
        print("patched: ordinary-binding capture, repeatability, captions and unmount passed", flush=True)


if __name__ == "__main__":
    main()
