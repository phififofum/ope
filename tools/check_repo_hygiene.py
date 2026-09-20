#!/usr/bin/env python3
"""Repository hygiene checks -- the rules from the spec that are cheap to enforce and
expensive to discover late.

    · Godot scenes and resources are TEXT, always, so every diff is reviewable.
    · Line endings are LF, so a Windows contributor does not rewrite the world.
    · Content carries no TODOs. An unfinished definition is a stub with a tested
      not-implemented path, not a comment nobody reads.
    · Every definition folder has a schema, and every schema has somewhere to put data.

Usage:
    python3 tools/check_repo_hygiene.py

Exit codes:
    0  clean
    1  at least one problem
"""

from __future__ import annotations

import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TEXT_SCENE_SUFFIXES = {".tscn", ".tres", ".godot"}
SKIP_DIRS = {".git", ".godot", "build", "export", "__pycache__", ".venv", "venv"}


def walk() -> list[Path]:
    out: list[Path] = []
    for path in REPO_ROOT.rglob("*"):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.is_file():
            out.append(path)
    return out


def rel(path: Path) -> str:
    return str(path.relative_to(REPO_ROOT))


def main() -> int:
    problems: list[str] = []
    files = walk()

    for path in files:
        if path.suffix in TEXT_SCENE_SUFFIXES:
            head = path.read_bytes()[:64]
            if b"\x00" in head or head.startswith(b"RSRC") or head.startswith(b"GDSC"):
                problems.append(
                    f"{rel(path)}: binary Godot resource. Text formats only -- "
                    f"every diff must be reviewable."
                )

    for path in files:
        if path.suffix in {
            ".gd",
            ".json",
            ".md",
            ".yml",
            ".yaml",
            ".py",
            ".cfg",
            ".tscn",
            ".tres",
            ".godot",
            ".sh",
        }:
            try:
                if b"\r\n" in path.read_bytes():
                    problems.append(
                        f"{rel(path)}: CRLF line endings; this repository is LF only "
                        f"(see .gitattributes)"
                    )
            except OSError as exc:
                problems.append(f"{rel(path)}: unreadable: {exc}")

    for path in files:
        if path.suffix == ".json":
            try:
                json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                problems.append(f"{rel(path)}: invalid JSON at line {exc.lineno}: {exc.msg}")
            except OSError as exc:
                problems.append(f"{rel(path)}: unreadable: {exc}")

    content = REPO_ROOT / "content"
    for path in (content / "definitions").glob("*/*.json"):
        text = path.read_text(encoding="utf-8")
        for marker in ("TODO", "FIXME", "XXX"):
            if marker in text:
                problems.append(
                    f"{rel(path)}: contains {marker}. Shipped content carries no "
                    f"placeholders -- finish it or leave it out."
                )

    schema_types = {
        p.name.removesuffix(".schema.json") for p in (content / "schemas").glob("*.schema.json")
    }
    folder_types = {p.name for p in (content / "definitions").iterdir() if p.is_dir()}
    for missing in sorted(folder_types - schema_types):
        problems.append(f"content/definitions/{missing}/: no schema for this type")
    for unused in sorted(schema_types - folder_types):
        problems.append(
            f"content/schemas/{unused}.schema.json: no definitions folder for this type"
        )

    print(f"Repository hygiene: {len(files)} file(s) checked, {len(problems)} problem(s)")
    for problem in problems:
        print(f"  ERROR    {problem}")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
