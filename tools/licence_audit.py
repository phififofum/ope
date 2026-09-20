#!/usr/bin/env python3
"""Assert that every shipped asset carries a valid licence record, and generate CREDITS.md
from those records so attribution can never drift from what is actually in the repository.

Pillar 5 is "free as in freedom, all the way down", and this is the tool that makes it a
gate rather than an aspiration. "We'll swap it later" is not a plan: assets get embedded,
referenced and forgotten, and by the time anyone notices, the swap costs a release.

Every asset file needs a sidecar beside it named <filename>.license.json:

    content/assets/props/display_case.glb
    content/assets/props/display_case.glb.license.json

Usage:
    python3 tools/licence_audit.py            # audit, report, exit non-zero on problems
    python3 tools/licence_audit.py --check    # the same; what CI runs
    python3 tools/licence_audit.py --write    # audit, then regenerate CREDITS.md

Exit codes:
    0  every asset is accounted for
    1  a missing, malformed or disallowed licence record
    2  the tool could not run
"""

from __future__ import annotations

import argparse
import json
import re
from datetime import date
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
CREDITS_PATH = REPO_ROOT / "CREDITS.md"
SOURCES_PATH = Path(__file__).resolve().parent / "credits_sources.json"

# Asset extensions that must carry a licence record.
ASSET_EXTENSIONS = {
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".svg",
    ".exr",
    ".hdr",
    ".glb",
    ".gltf",
    ".obj",
    ".fbx",
    ".blend",
    ".ogg",
    ".wav",
    ".mp3",
    ".flac",
    ".ttf",
    ".otf",
    ".woff",
    ".woff2",
}

# CC BY-NC cannot ship. CC BY-SA is viral in a way that conflicts with the code licence.
# Anything not on this list is a conversation, not a commit.
ALLOWED_LICENCES = {
    "CC0-1.0",
    "CC-BY-4.0",
    "CC-BY-3.0",
    "OFL-1.1",
    "MIT",
    "Apache-2.0",
}

REQUIRED_FIELDS = ("file", "source", "author", "license", "retrieved")

ASSET_ROOTS = ("content/assets", "ui/assets", "mods")


def rel(path: Path) -> str:
    return str(path.relative_to(REPO_ROOT))


def find_assets() -> list[Path]:
    assets: list[Path] = []
    for root in ASSET_ROOTS:
        base = REPO_ROOT / root
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if path.is_file() and path.suffix.lower() in ASSET_EXTENSIONS:
                assets.append(path)
    return assets


def audit() -> tuple[list[dict[str, Any]], list[str]]:
    records: list[dict[str, Any]] = []
    problems: list[str] = []

    for asset in find_assets():
        sidecar = asset.with_name(asset.name + ".license.json")
        if not sidecar.is_file():
            problems.append(f"{rel(asset)}: no licence record (expected {sidecar.name} beside it)")
            continue
        try:
            record = json.loads(sidecar.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            problems.append(f"{rel(sidecar)}: invalid JSON at line {exc.lineno}: {exc.msg}")
            continue

        missing = [f for f in REQUIRED_FIELDS if not record.get(f)]
        if missing:
            problems.append(f"{rel(sidecar)}: missing required field(s): {', '.join(missing)}")
            continue

        if record["file"] != rel(asset):
            problems.append(
                f"{rel(sidecar)}: `file` says {record['file']!r} but the asset is at {rel(asset)!r}"
            )

        licence = record["license"]
        if licence not in ALLOWED_LICENCES:
            problems.append(
                f"{rel(sidecar)}: licence {licence!r} is not shippable "
                f"(allowed: {', '.join(sorted(ALLOWED_LICENCES))})"
            )
            continue

        records.append(record)

    return records, problems


def render_credits(records: list[dict[str, Any]]) -> str:
    try:
        sources = json.loads(SOURCES_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        sources = {}

    lines: list[str] = []
    lines.append("<!--")
    lines.append("  GENERATED FILE -- do not edit by hand.")
    lines.append("  Asset attribution comes from the .license.json sidecar beside each asset.")
    lines.append("  Everything else comes from tools/credits_sources.json.")
    lines.append("  Regenerate with: python3 tools/licence_audit.py --write")
    lines.append("-->")
    lines.append("")
    lines.append("# Credits")
    lines.append("")
    lines.append(
        f"*Generated {date.today().isoformat()} from {len(records)} asset licence record(s).*"
    )
    lines.append("")
    lines.append(
        "PoggyWoggy is built entirely from free software and freely licensed assets. "
        "Every asset below is shipped under the licence named beside it, and that "
        "record lives next to the file itself, so this page cannot drift from what is "
        "actually in the build. See [LICENSING.md](LICENSING.md)."
    )
    lines.append("")

    lines.append("## Assets")
    lines.append("")
    if not records:
        lines.append(
            "No assets are bundled yet -- the project is in design stage. When the "
            "first one lands it appears here automatically, with its source, author "
            "and licence."
        )
        lines.append("")
    else:
        by_author: dict[str, list[dict[str, Any]]] = {}
        for record in records:
            by_author.setdefault(record["author"], []).append(record)
        for author in sorted(by_author):
            lines.append(f"### {author}")
            lines.append("")
            lines.append("| File | Licence | Source | Modifications |")
            lines.append("| --- | --- | --- | --- |")
            for record in sorted(by_author[author], key=lambda r: r["file"]):
                mods = record.get("modifications") or "unmodified"
                lines.append(
                    f"| `{record['file']}` | {record['license']} | "
                    f"[source]({record['source']}) | {mods} |"
                )
            lines.append("")

    engine = sources.get("engine_and_tooling", [])
    if engine:
        lines.append("## Engine and tooling")
        lines.append("")
        lines.append("| Project | Licence | Notes |")
        lines.append("| --- | --- | --- |")
        for item in engine:
            name = f"[{item['name']}]({item['url']})" if item.get("url") else item["name"]
            version = f" {item['version']}" if item.get("version") else ""
            lines.append(
                f"| {name}{version} | {item.get('license', '?')} | "
                f"{item.get('note', item.get('author', ''))} |"
            )
        lines.append("")

    policy = sources.get("asset_sources_policy", [])
    if policy:
        lines.append("## Approved asset sources")
        lines.append("")
        lines.append(
            "Assets may be drawn from these, and from anywhere else whose licence is "
            "CC0 or CC BY. Each individual file still carries its own record."
        )
        lines.append("")
        for item in policy:
            url = item.get("url", "")
            lines.append(f"- [{item['name']}]({url}) — {item.get('license', '?')}")
        lines.append("")

    contributors = sources.get("contributors", [])
    if contributors:
        lines.append("## Contributors")
        lines.append("")
        for item in contributors:
            suffix = f" — {item['for']}" if item.get("for") else ""
            lines.append(f"- {item['name']}{suffix}")
        lines.append("")
        lines.append(
            "Add yourself to `tools/credits_sources.json` and run "
            "`python3 tools/licence_audit.py --write` in the same pull request as "
            "your change."
        )
        lines.append("")

    return re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).rstrip()


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="audit only (the default); exits non-zero on any problem",
    )
    parser.add_argument(
        "--write", action="store_true", help="regenerate CREDITS.md after a clean audit"
    )
    args = parser.parse_args()

    records, problems = audit()

    print(f"Licence audit: {len(records)} asset(s) with a valid record, {len(problems)} problem(s)")
    for problem in problems:
        print(f"  ERROR    {problem}")

    if problems:
        print(
            "\nEvery asset must carry a .license.json sidecar with an allowed licence. "
            "This is a hard gate, not a warning."
        )
        return 1

    if args.write:
        CREDITS_PATH.write_text(render_credits(records) + "\n", encoding="utf-8")
        print(f"  wrote    {rel(CREDITS_PATH)}")
    else:
        current = CREDITS_PATH.read_text(encoding="utf-8") if CREDITS_PATH.is_file() else ""
        expected = render_credits(records) + "\n"
        if _strip_generated_date(current) != _strip_generated_date(expected):
            print(
                "  ERROR    CREDITS.md is out of date. Run: python3 tools/licence_audit.py --write"
            )
            return 1

    return 0


def _strip_generated_date(text: str) -> str:
    """CREDITS.md carries a generation date; a date-only difference is not drift."""
    return "\n".join(line for line in text.splitlines() if not line.startswith("*Generated "))


if __name__ == "__main__":
    raise SystemExit(main())
