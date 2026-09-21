#!/usr/bin/env python3
"""Every test suite must be run by exactly one CI shard.

CI splits the suite across runners because three policy comparisons were most of a
twenty-minute pipeline. Splitting by hand introduces a quiet failure mode: add a suite
file, forget to add it to a shard, and it simply stops being run -- green pipeline,
untested code, and nothing says so.

This reads the shards out of the workflow and compares them against the suite files on
disk. A file in no shard fails; a file in two shards fails as well, because paying twice
for the same test is how a split gets slower than what it replaced.

    python3 tools/check_test_shards.py
"""

from __future__ import annotations

import sys
from itertools import pairwise
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = REPO_ROOT / ".github" / "workflows" / "ci.yml"
TESTS = REPO_ROOT / "tests"
# A suite is a script gdUnit4 will discover and run. Helpers and fixtures are not.
SUITE_GLOB = "test_*.gd"


def shard_targets(workflow: dict) -> list[str]:
    """The -a arguments of every matrix leg, in order."""
    targets: list[str] = []
    for job in workflow.get("jobs", {}).values():
        for leg in job.get("strategy", {}).get("matrix", {}).get("include", []):
            words = str(leg.get("targets", "")).split()
            targets += [word for previous, word in pairwise(words) if previous == "-a"]
    return targets


def covered_by(target: str) -> set[Path]:
    path = REPO_ROOT / target
    if path.is_dir():
        return {p.relative_to(REPO_ROOT) for p in sorted(path.rglob(SUITE_GLOB))}
    return {path.relative_to(REPO_ROOT)} if path.is_file() else set()


def main() -> int:
    workflow = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    targets = shard_targets(workflow)
    if not targets:
        print("error: no test shards found in the workflow", file=sys.stderr)
        return 2

    on_disk = {p.relative_to(REPO_ROOT) for p in sorted(TESTS.rglob(SUITE_GLOB))}

    seen: dict[Path, list[str]] = {}
    missing_targets: list[str] = []
    for target in targets:
        files = covered_by(target)
        if not files:
            missing_targets.append(target)
        for file in files:
            seen.setdefault(file, []).append(target)

    problems = 0
    for target in missing_targets:
        print(f"  ERROR    shard target '{target}' matches no test suite", file=sys.stderr)
        problems += 1
    for file in sorted(on_disk - set(seen)):
        print(f"  ERROR    {file} is in no CI shard, so it never runs", file=sys.stderr)
        problems += 1
    for file, shards in sorted(seen.items()):
        if len(shards) > 1:
            print(f"  ERROR    {file} runs in {len(shards)} shards: {', '.join(shards)}")
            problems += 1

    print(
        f"Test shards: {len(on_disk)} suite(s) across {len(targets)} shard(s), {problems} problem(s)"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
