#!/usr/bin/env python3
"""Validate every content definition against its schema, then check the cross-references
and quality gates that a schema cannot express.

This is the tool the whole architecture rests on: content is data, and data that validates
is content a modder can write in a text editor without opening the engine. The base game
goes through exactly this path -- it holds no privileges.

Usage:
    python3 tools/validate_content.py                 # base content + every mod in mods/
    python3 tools/validate_content.py content mods/*  # explicit sources, in load order
    python3 tools/validate_content.py --strict        # warnings become failures

Exit codes:
    0  everything validated
    1  at least one error (or a warning, under --strict)
    2  the tool could not run (missing dependency, unreadable source)
"""

from __future__ import annotations

import argparse
import json
import sys
from collections.abc import Iterable
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
ALLOWED_CLASSES = {"internal_inconsistency", "external_inconsistency", "physical_defect"}
MIN_VECTORS_PER_DOCUMENT = 3


class Report:
    """Collects findings so that one run reports every problem, not just the first."""

    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, where: str, message: str) -> None:
        self.errors.append(f"{where}: {message}")

    def warn(self, where: str, message: str) -> None:
        self.warnings.append(f"{where}: {message}")

    def print(self, strict: bool) -> int:
        for w in self.warnings:
            print(f"  warning  {w}")
        for e in self.errors:
            print(f"  ERROR    {e}")
        failed = bool(self.errors) or (strict and bool(self.warnings))
        print()
        print(f"{len(self.errors)} error(s), {len(self.warnings)} warning(s)")
        return 1 if failed else 0


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def load_json(path: Path, report: Report) -> Any | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        report.error(rel(path), f"invalid JSON at line {exc.lineno} column {exc.colno}: {exc.msg}")
    except OSError as exc:
        report.error(rel(path), f"cannot read file: {exc}")
    return None


def json_pointer(parts: Iterable[Any]) -> str:
    out = "$"
    for part in parts:
        out += f"[{part}]" if isinstance(part, int) else f".{part}"
    return out


def discover_sources(explicit: list[str]) -> list[Path]:
    if explicit:
        return [Path(p).resolve() for p in explicit]
    sources = [REPO_ROOT / "content"]
    mods = REPO_ROOT / "mods"
    if mods.is_dir():
        sources += sorted(
            p for p in mods.iterdir() if p.is_dir() and (p / "manifest.json").is_file()
        )
    return sources


def validate(sources: list[Path], report: Report) -> dict[str, dict[str, Any]]:
    """Schema-validate every definition in every source. Returns the merged registry."""
    try:
        from jsonschema import Draft202012Validator
    except ImportError:
        print(
            "error: jsonschema is not installed.\n       python3 -m pip install --user jsonschema",
            file=sys.stderr,
        )
        raise SystemExit(2) from None

    schemas: dict[str, Any] = {}
    registry: dict[str, dict[str, Any]] = {}
    origin: dict[str, str] = {}

    for source in sources:
        if not source.is_dir():
            report.error(rel(source), "source directory does not exist")
            continue

        manifest_path = source / "manifest.json"
        manifest = load_json(manifest_path, report) if manifest_path.is_file() else None
        if manifest is None:
            report.error(
                rel(source),
                "no readable manifest.json -- every content source is a mod, "
                "including the base game",
            )
            continue
        namespace = manifest.get("id")
        if not isinstance(namespace, str) or not namespace:
            report.error(
                rel(manifest_path),
                "manifest has no string `id`; ids cannot be namespaced without it",
            )
            continue

        # Schemas may be introduced by any source. Later sources may not silently
        # redefine an existing type -- that is an override, and it needs to be deliberate.
        for schema_path in sorted((source / "schemas").glob("*.schema.json")):
            schema = load_json(schema_path, report)
            if schema is None:
                continue
            type_name = schema_path.name.removesuffix(".schema.json")
            if type_name in schemas:
                report.warn(rel(schema_path), f"redefines the schema for `{type_name}`")
            try:
                Draft202012Validator.check_schema(schema)
            except Exception as exc:  # jsonschema raises SchemaError
                report.error(rel(schema_path), f"is not a valid JSON Schema: {exc}")
                continue
            schemas[type_name] = schema

        for definition_path in sorted((source / "definitions").rglob("*.json")):
            definition = load_json(definition_path, report)
            if definition is None:
                continue
            where = rel(definition_path)
            if not isinstance(definition, dict):
                report.error(where, "a definition must be a JSON object")
                continue

            declared_type = definition.get("type")
            folder_type = definition_path.parent.name
            if declared_type != folder_type:
                report.error(
                    where,
                    f"lives in definitions/{folder_type}/ but declares type `{declared_type}`",
                )
                continue
            if declared_type not in schemas:
                report.error(
                    where,
                    f"no schema for type `{declared_type}` "
                    f"(expected {folder_type}.schema.json in a schemas/ folder)",
                )
                continue

            validator = Draft202012Validator(schemas[declared_type])
            for issue in sorted(validator.iter_errors(definition), key=lambda e: list(e.path)):
                report.error(where, f"{json_pointer(issue.absolute_path)} {issue.message}")

            definition_id = definition.get("id")
            if not isinstance(definition_id, str):
                continue
            # A new id must live in this source's namespace. An id in another namespace
            # is an override -- legitimate, and the point of the mechanism -- but only of
            # something that already exists, or a typo squats on a name its real owner
            # may add later.
            if not definition_id.startswith(f"{namespace}:") and definition_id not in registry:
                report.error(
                    where,
                    f"id `{definition_id}` is neither namespaced to this source "
                    f"(`{namespace}:`) nor an override of an existing definition",
                )
            if definition_id in registry:
                previous = origin[definition_id]
                if previous == rel(source):
                    report.error(where, f"duplicate id `{definition_id}` within {previous}")
                else:
                    report.warn(where, f"overrides `{definition_id}` from {previous}")
            registry[definition_id] = definition
            origin[definition_id] = rel(source)

    return registry


def check_references(registry: dict[str, dict[str, Any]], report: Report) -> None:
    """Cross-reference checks. A schema can say "this is an id"; only the registry knows
    whether anything answers to it."""

    def by_type(type_name: str) -> dict[str, dict[str, Any]]:
        return {k: v for k, v in registry.items() if v.get("type") == type_name}

    def require(ref: Any, expected_type: str, where: str, field: str) -> None:
        if not isinstance(ref, str):
            return
        target = registry.get(ref)
        if target is None:
            report.error(where, f"{field} references `{ref}`, which no definition provides")
        elif target.get("type") != expected_type:
            report.error(
                where,
                f"{field} references `{ref}`, which is a "
                f"`{target.get('type')}`, not a `{expected_type}`",
            )

    for pid, product in by_type("product").items():
        require(product.get("licence"), "licence", pid, "licence")
        for supplier in product.get("suppliers", []):
            require(supplier, "supplier", pid, "suppliers")

    for rid, recipe in by_type("recipe").items():
        for index, ingredient in enumerate(recipe.get("ingredients", [])):
            require(ingredient.get("product"), "product", rid, f"ingredients[{index}].product")
        require(recipe.get("unlocked_by"), "licence", rid, "unlocked_by")

    for did, document in by_type("document_type").items():
        for field in document.get("fields", []):
            require(field.get("revealed_by"), "tool", did, f"fields.{field.get('key')}.revealed_by")
        for feature in document.get("security_features", []):
            require(
                feature.get("revealed_by"),
                "tool",
                did,
                f"security_features.{feature.get('id')}.revealed_by",
            )

    for vid, vector in by_type("forgery_vector").items():
        for tool in vector.get("detectable_by", []):
            require(tool, "tool", vid, "detectable_by")
        for target in vector.get("applies_to", {}).get("document_types", []):
            if target != "*":
                require(target, "document_type", vid, "applies_to.document_types")


def applicable_documents(vector: dict[str, Any], documents: dict[str, dict[str, Any]]) -> list[str]:
    """Resolve a vector's wildcard targeting. One vector definition covering every document
    that has a barcode is what makes the vector set combinatorial rather than hand-authored."""
    applies = vector.get("applies_to", {})
    targets = applies.get("document_types", [])
    needs_field = applies.get("requires_field")
    needs_feature = applies.get("requires_feature")

    candidates = documents.keys() if "*" in targets else [t for t in targets if t in documents]
    resolved = []
    for doc_id in candidates:
        document = documents[doc_id]
        if needs_field and needs_field not in {f.get("key") for f in document.get("fields", [])}:
            continue
        if needs_feature and needs_feature not in {
            f.get("id") for f in document.get("security_features", [])
        }:
            continue
        resolved.append(doc_id)
    return resolved


def check_quality_gates(registry: dict[str, dict[str, Any]], report: Report) -> None:
    """The gates from the design spec that can be checked mechanically.

    The load-bearing one is fairness: every forgery must be detectable with a tool the
    player can actually have at the tier it appears. A forgery nobody can catch is a coin
    flip, and the game never demands a coin flip.
    """
    documents = {k: v for k, v in registry.items() if v.get("type") == "document_type"}
    vectors = {k: v for k, v in registry.items() if v.get("type") == "forgery_vector"}
    tools = {k: v for k, v in registry.items() if v.get("type") == "tool"}

    coverage: dict[str, set[str]] = {doc_id: set() for doc_id in documents}
    counts: dict[str, int] = {doc_id: 0 for doc_id in documents}

    for vid, vector in vectors.items():
        resolved = applicable_documents(vector, documents)
        if not resolved:
            report.warn(vid, "applies to no document type -- dead content, or a typo in applies_to")
        for doc_id in resolved:
            coverage[doc_id].add(vector.get("class"))
            counts[doc_id] += 1

        tier = vector.get("tier")
        reachable = [
            t
            for t in vector.get("detectable_by", [])
            if t in tools and isinstance(tier, int) and tools[t].get("tier", 99) <= tier
        ]
        if isinstance(tier, int) and not reachable:
            report.error(
                vid,
                f"appears at tier {tier} but no listed tool is available by then "
                f"-- the player cannot catch it, which the design forbids",
            )

    for doc_id in documents:
        if counts[doc_id] < MIN_VECTORS_PER_DOCUMENT:
            report.error(
                doc_id,
                f"has {counts[doc_id]} applicable forgery vector(s); "
                f"the gate is {MIN_VECTORS_PER_DOCUMENT}",
            )
        missing = ALLOWED_CLASSES - coverage[doc_id]
        if missing:
            report.error(
                doc_id,
                "is missing forgery vectors of class "
                + ", ".join(sorted(missing))
                + " -- a single habit of looking would catch everything it has",
            )

    # A vector is only catchable if some rule checks for it, and that rule's tool is one
    # the vector says reveals it. Without this, "detectable_by" is a claim nobody
    # enforces and the player is asked to spot something no check looks at.
    rules = {k: v for k, v in registry.items() if v.get("type") == "rule"}
    for vid, vector in vectors.items():
        detectable_by = set(vector.get("detectable_by", []))
        families = {documents[d].get("family") for d in applicable_documents(vector, documents)}
        covered = False
        for rule in rules.values():
            rule_families = set(rule.get("applies_to", {}).get("document_families", []))
            if rule_families and not (rule_families & families):
                continue
            required = rule.get("requires_tool")
            if required is None or required in detectable_by:
                covered = True
                break
        if not covered and families:
            report.error(
                vid,
                "no rule checks for it with a tool it claims reveals it -- "
                "`detectable_by` is a promise the checklist does not keep",
            )

    for tid, tool in tools.items():
        if tool.get("returns_verdict"):
            report.error(tid, "returns a verdict. Tools reveal; players judge.")

    licences = {k for k, v in registry.items() if v.get("type") == "licence"}
    used = {p.get("licence") for p in registry.values() if p.get("type") == "product"}
    used |= {r.get("unlocked_by") for r in registry.values() if r.get("type") == "recipe"}
    for licence_id in sorted(licences - used):
        report.warn(licence_id, "unlocks nothing -- no product or recipe references it")

    for pid, product in registry.items():
        if product.get("type") != "product":
            continue
        for string_field in ("name",):
            value = product.get(string_field)
            if isinstance(value, str) and not value.startswith("loc:"):
                report.error(pid, f"{string_field} is a literal, not a loc: key")


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("sources", nargs="*", help="content sources, in load order")
    parser.add_argument("--strict", action="store_true", help="treat warnings as failures")
    args = parser.parse_args()

    sources = discover_sources(args.sources)
    report = Report()

    print("Validating content")
    for source in sources:
        print(f"  source   {rel(source)}")
    print()

    registry = validate(sources, report)
    check_references(registry, report)
    check_quality_gates(registry, report)

    by_type: dict[str, int] = {}
    for definition in registry.values():
        type_name = str(definition.get("type"))
        by_type[type_name] = by_type.get(type_name, 0) + 1
    for type_name in sorted(by_type):
        print(f"  {by_type[type_name]:>4}  {type_name}")
    print(f"  {len(registry):>4}  definitions total")
    print()

    return report.print(args.strict)


if __name__ == "__main__":
    raise SystemExit(main())
