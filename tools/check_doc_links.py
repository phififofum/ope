#!/usr/bin/env python3
"""Check that every relative link in the documentation resolves to something that exists.

Navigability is a feature. A reader who lands mid-document should be one click from
context -- which only works if the click lands somewhere.

External links (http, https, mailto) are not fetched: CI should not fail because someone
else's server is down. Anchors are checked against the target document's headings.

Usage:
    python3 tools/check_doc_links.py [paths...]

Exit codes:
    0  every relative link resolves
    1  at least one broken link
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {".git", ".godot", "build", "export", "__pycache__", ".venv", "venv", "LICENSES"}

LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
HEADING = re.compile(r"^#{1,6}\s+(.*?)\s*$", re.MULTILINE)
HTML_COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)
FENCED = re.compile(r"```.*?```", re.DOTALL)


def slugify(heading: str) -> str:
    # Backticks and emphasis markers vanish; underscores survive, as on GitHub.
    text = re.sub(r"[`*]", "", heading).strip().lower()
    text = re.sub(r"[^\w\s-]", "", text)
    # GitHub replaces each whitespace character with a hyphen without collapsing runs,
    # so "a -- b" and "a — b" produce different anchors. Match that exactly.
    return re.sub(r"\s", "-", text)


def anchors(path: Path) -> set[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return set()
    text = FENCED.sub("", text)
    found = {slugify(h) for h in HEADING.findall(text)}
    found |= set(re.findall(r'<a\s+(?:id|name)="([^"]+)"', text))
    return found


def markdown_files(paths: list[str]) -> list[Path]:
    if paths:
        return [Path(p).resolve() for p in paths]
    return sorted(
        p for p in REPO_ROOT.rglob("*.md") if not any(part in SKIP_DIRS for part in p.parts)
    )


def main() -> int:
    problems: list[str] = []
    files = markdown_files(sys.argv[1:])
    anchor_cache: dict[Path, set[str]] = {}
    checked = 0

    for path in files:
        text = HTML_COMMENT.sub("", path.read_text(encoding="utf-8"))
        text = FENCED.sub("", text)
        here = str(path.relative_to(REPO_ROOT))

        for target in LINK.findall(text):
            if target.startswith(("http://", "https://", "mailto:", "#")):
                if target.startswith("#"):
                    checked += 1
                    have = anchor_cache.setdefault(path, anchors(path))
                    if target[1:] not in have:
                        problems.append(f"{here}: no heading matches anchor `{target}`")
                continue

            checked += 1
            file_part, _, anchor = target.partition("#")
            resolved = (path.parent / file_part).resolve() if file_part else path

            if not resolved.exists():
                problems.append(f"{here}: `{target}` does not exist")
                continue
            if anchor and resolved.suffix == ".md":
                have = anchor_cache.setdefault(resolved, anchors(resolved))
                if anchor not in have:
                    problems.append(
                        f"{here}: `{target}` -- the file exists, but it has no heading `#{anchor}`"
                    )

    print(
        f"Documentation links: {checked} relative link(s) in {len(files)} file(s), "
        f"{len(problems)} problem(s)"
    )
    for problem in problems:
        print(f"  ERROR    {problem}")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
