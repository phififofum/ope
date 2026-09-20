#!/usr/bin/env python3
"""Author content in bulk, deterministically, against the shipped schemas.

Hundreds of board games and cards are not hand-written files -- they are a generator
plus a review of the generator. That is only possible because the architecture made
every noun data, and it is the concrete payoff of freezing the schemas first.

Two rules this script keeps:

  * Deterministic. A fixed seed per type, so re-running produces byte-identical files
    and a diff means something changed on purpose.
  * Never clobbers hand-authored content. Files listed in HAND_AUTHORED are left alone;
    they are the worked examples the docs point at.

Usage:
    python3 tools/generate_content.py            # write content, then validate it
    python3 tools/generate_content.py --check    # fail if anything would change
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFINITIONS = REPO_ROOT / "content" / "definitions"

# v1.0 targets, from docs/design/12-content-manifest.md.
COUNTS = {
    "board_game": 250,
    "card_set": 8,
    "customer_archetype": 45,
    "fixture": 75,
    "event": 50,
    "upgrade": 45,
    "staff_role": 7,
    "product": 120,
    "recipe": 45,
    "licence": 25,
    "tool": 22,
    "document_type": 28,
    "cat": 12,
}

# Worked examples the documentation points at. Never overwritten.
HAND_AUTHORED = {
    "product/cold_brew_16oz.json",
    "product/espresso_beans_1kg.json",
    "product/sourdough_loaf.json",
    "product/cheddar_block.json",
    "product/butter_block.json",
    "product/card_sleeves_100.json",
    "product/meridian_booster_box.json",
    "product/harbourline_deluxe.json",
    "product/graded_single_meridian.json",
    "recipe/three_cheese_toastie.json",
    "recipe/flat_white.json",
    "cat/tabby_orange.json",
    "cat/tuxedo_shorthair.json",
    "document_type/state_id_northvale.json",
    "document_type/trade_in_record.json",
    "document_type/collectible_card_meridian.json",
}


def rng_for(type_name: str) -> random.Random:
    """One stream per type, so adding board games cannot shift the fixtures."""
    return random.Random(f"poggywoggy:{type_name}")


def write(type_name: str, file_stem: str, data: dict, written: dict) -> None:
    relative = f"{type_name}/{file_stem}.json"
    if relative in HAND_AUTHORED:
        return
    written[relative] = json.dumps(data, indent=2, ensure_ascii=False) + "\n"


# --------------------------------------------------------------------------- words

TITLE_FIRST = [
    "Harbourline",
    "Saltmarsh",
    "Ironwright",
    "Verdance",
    "Coalfall",
    "Thistlewood",
    "Longshore",
    "Emberdown",
    "Quickstone",
    "Fenwick",
    "Aldermere",
    "Brasshollow",
    "Cindervale",
    "Drakemoor",
    "Elmgate",
    "Foxglove",
    "Gallowmere",
    "Hollowbrook",
    "Kestrel",
    "Lanternwick",
    "Mossgard",
    "Northreach",
    "Oxbow",
    "Pinehaven",
    "Quarrystone",
    "Redfen",
    "Stillwater",
    "Tannery",
    "Umberfield",
    "Vesper",
]
TITLE_SECOND = [
    "Company",
    "Crossing",
    "Exchange",
    "Signal",
    "Reckoning",
    "Almanac",
    "Circuit",
    "Consortium",
    "Dispatch",
    "Engine",
    "Ferry",
    "Gazette",
    "Harvest",
    "Interchange",
    "Junction",
    "Ledger",
    "Manifest",
    "Network",
    "Orchard",
    "Provision",
    "Quorum",
    "Registry",
    "Syndicate",
    "Tramway",
    "Union",
    "Voyage",
    "Waybill",
    "Yard",
]
COMPONENT_PARTS = [
    ("wooden cube", 0.9),
    ("meeple", 0.7),
    ("cardboard token", 0.6),
    ("card", 0.3),
    ("player board", 0.1),
    ("first-player marker", 0.8),
    ("die", 0.85),
    ("resource tile", 0.5),
    ("scoring marker", 0.75),
    ("rulebook", 0.15),
    ("linen bag", 0.4),
    ("plastic stand", 0.65),
]
SET_NAMES = [
    "Meridian Core",
    "Tidefall",
    "Ashen Verdict",
    "Gilded Circuit",
    "Hollow Crown",
    "Saltwind Cycle",
    "Ember Accord",
    "Lantern Rite",
    "Quiet Harvest",
    "Iron Vespers",
]
ARCHETYPE_SEEDS = [
    ("the regular", ["table", "drink", "library"], 0.02),
    ("the teacher", ["table", "library"], 0.01),
    ("the tournament grinder", ["event", "singles"], 0.06),
    ("the collector", ["singles", "sealed"], 0.12),
    ("the browser", ["retail"], 0.03),
    ("the student", ["drink", "table"], 0.08),
    ("the parent", ["retail", "table"], 0.02),
    ("the flipper", ["sealed", "trade_in"], 0.28),
    ("the late shift", ["drink", "food"], 0.10),
    ("the lapsed player", ["library", "retail"], 0.04),
    ("the birthday group", ["table", "food", "drink"], 0.01),
    ("the dealer", ["trade_in", "singles"], 0.22),
    ("the reviewer", ["library", "drink"], 0.02),
    ("the bar crowd", ["drink"], 0.14),
    ("the judge", ["event"], 0.01),
]
FIXTURE_SEEDS = [
    ("two-player table", "table", [2, 2], 240.0, 0.2, 2),
    ("four-player table", "table", [3, 2], 380.0, 0.3, 4),
    ("six-player table", "table", [4, 2], 520.0, 0.45, 6),
    ("library wall section", "shelf", [3, 1], 310.0, -0.2, 40),
    ("retail shelf", "shelf", [2, 1], 210.0, -0.1, 24),
    ("display case", "case", [2, 1], 900.0, 0.0, 60),
    ("chilled cabinet", "cooler", [2, 1], 1450.0, 0.35, 48),
    ("espresso bar", "kitchen", [3, 1], 3200.0, 0.4, 0),
    ("griddle station", "kitchen", [2, 1], 1800.0, 0.5, 0),
    ("fryer", "kitchen", [1, 1], 1200.0, 0.45, 0),
    ("prep bench", "kitchen", [2, 1], 640.0, 0.1, 0),
    ("pass window", "kitchen", [1, 1], 420.0, 0.15, 0),
    ("register counter", "counter", [3, 1], 1100.0, 0.1, 0),
    ("acoustic partition", "decor", [2, 1], 260.0, -0.6, 0),
    ("bookshelf divider", "decor", [2, 1], 180.0, -0.35, 12),
    ("bin station", "utility", [1, 1], 90.0, 0.05, 0),
]


# --------------------------------------------------------------------------- types


def gen_board_games(written: dict) -> None:
    rng = rng_for("board_game")
    seen: set[str] = set()
    for _index in range(COUNTS["board_game"]):
        while True:
            title = f"{rng.choice(TITLE_FIRST)} {rng.choice(TITLE_SECOND)}"
            if title not in seen:
                seen.add(title)
                break
        slug = title.lower().replace(" ", "_")
        weight = round(rng.triangular(1.0, 5.0, 2.4), 1)
        low = rng.choice([1, 2, 2, 2, 3])
        high = low + rng.choice([1, 2, 2, 3, 4])
        play_low = int(15 + weight * rng.uniform(8, 22))
        components = []
        for part, loss in rng.sample(COMPONENT_PARTS, k=rng.randint(3, 7)):
            # Parts that go missing easily come in larger counts: nobody loses the
            # rulebook, and everybody loses a cube.
            pool = [4, 8, 12, 24] if loss < 0.5 else [24, 40, 60, 104, 120]
            count = rng.choice(pool)
            components.append({"part": part, "count": count, "loss_weight": round(loss, 2)})
        write(
            "board_game",
            slug,
            {
                "id": f"base:{slug}",
                "type": "board_game",
                "name": f"loc:board_game.{slug}",
                "designer": f"{rng.choice(TITLE_FIRST)} {rng.choice(['Vance', 'Okoro', 'Lindqvist', 'Baptiste', 'Reyes'])}",
                "player_count": [low, high],
                "play_minutes": [play_low, play_low + int(rng.uniform(15, 90))],
                "weight": weight,
                "teach_minutes": int(3 + weight * rng.uniform(2, 7)),
                "retail_price": round(18 + weight * rng.uniform(6, 14), 2),
                "library_eligible": rng.random() > 0.12,
                "shelf_footprint": [1 + int(weight > 3.2), 1],
                "components": components,
                "tags": sorted(
                    set(
                        ["heavy" if weight > 3.5 else "filler" if weight < 2.0 else "midweight"]
                        + (["component_dense"] if sum(c["count"] for c in components) > 180 else [])
                        + (["teaching_friendly"] if weight < 2.5 else [])
                    )
                ),
            },
            written,
        )


def gen_card_sets(written: dict) -> None:
    rng = rng_for("card_set")
    for index in range(COUNTS["card_set"]):
        name = SET_NAMES[index % len(SET_NAMES)]
        slug = name.lower().replace(" ", "_")
        released = 30 + index * 84
        write(
            "card_set",
            slug,
            {
                "id": f"base:{slug}",
                "type": "card_set",
                "name": f"loc:card_set.{slug}",
                "released_day": released,
                "rotates_out_day": released + 730,
                "pack_price": round(rng.uniform(3.8, 6.5), 2),
                "cards_per_pack": rng.choice([9, 10, 12, 15]),
                "packs_per_box": rng.choice([24, 30, 36]),
                "rarities": [
                    {
                        "rarity": "common",
                        "pull_rate": 0.7,
                        "base_value": 0.08,
                        "value_spread": 0.05,
                    },
                    {
                        "rarity": "uncommon",
                        "pull_rate": 0.2,
                        "base_value": 0.55,
                        "value_spread": 0.4,
                    },
                    {"rarity": "rare", "pull_rate": 0.083, "base_value": 4.2, "value_spread": 6.0},
                    {
                        "rarity": "mythic",
                        "pull_rate": 0.015,
                        "base_value": 38.0,
                        "value_spread": 90.0,
                    },
                    {
                        "rarity": "serialised",
                        "pull_rate": 0.002,
                        "base_value": 420.0,
                        "value_spread": 900.0,
                    },
                ],
                "security_features": ["print_rosette", "foil_response", "layer_core"],
                "tags": ["sealed_product", "authenticated"],
            },
            written,
        )


def gen_customer_archetypes(written: dict) -> None:
    rng = rng_for("customer_archetype")
    shifts = ["morning", "midday", "afternoon", "evening", "event_night", "late_night"]
    for index in range(COUNTS["customer_archetype"]):
        base_name, wants, fraud = ARCHETYPE_SEEDS[index % len(ARCHETYPE_SEEDS)]
        variant = index // len(ARCHETYPE_SEEDS)
        label = (
            base_name
            if variant == 0
            else f"{base_name} {['', 'again', 'in a hurry', 'with friends'][variant % 4]}".strip()
        )
        slug = label.lower().replace(" ", "_").replace("'", "")
        low = round(rng.uniform(4, 25), 2)
        write(
            "customer_archetype",
            slug,
            {
                "id": f"base:{slug}",
                "type": "customer_archetype",
                "name": f"loc:archetype.{slug}",
                "budget": [low, round(low * rng.uniform(2.0, 9.0), 2)],
                "patience": round(rng.uniform(0.6, 1.8), 2),
                "wants": wants,
                "spawn_weight": round(rng.uniform(0.4, 3.0), 2),
                "shifts": sorted(rng.sample(shifts, k=rng.randint(2, 4))),
                "fraud_propensity": round(fraud * rng.uniform(0.6, 1.4), 3),
                "age_range": [rng.choice([16, 18, 21, 24, 30]), rng.choice([38, 45, 55, 70])],
                "tags": ["regular_candidate"] if fraud < 0.05 else ["watchlist_candidate"],
            },
            written,
        )


def gen_fixtures(written: dict) -> None:
    rng = rng_for("fixture")
    for index in range(COUNTS["fixture"]):
        name, category, footprint, cost, noise, capacity = FIXTURE_SEEDS[index % len(FIXTURE_SEEDS)]
        tier = index // len(FIXTURE_SEEDS)
        label = name if tier == 0 else f"{name} mk{tier + 1}"
        slug = label.lower().replace(" ", "_").replace("-", "_")
        write(
            "fixture",
            slug,
            {
                "id": f"base:{slug}",
                "type": "fixture",
                "name": f"loc:fixture.{slug}",
                "category": category,
                "footprint": footprint,
                "cost": round(cost * (1.0 + tier * 0.35), 2),
                "capacity": capacity + tier * (2 if category in {"table", "shelf", "case"} else 0),
                "noise": round(noise, 2),
                "upkeep_hours": round(rng.uniform(0.05, 0.6), 2),
                "zone": {
                    "table": "play",
                    "shelf": "library",
                    "case": "counter",
                    "cooler": "service",
                    "kitchen": "kitchen",
                    "counter": "counter",
                    "decor": "any",
                    "utility": "back",
                }[category],
                "tags": [category] + (["quiet"] if noise < 0 else []),
            },
            written,
        )


def gen_events(written: dict) -> None:
    rng = rng_for("event")
    kinds = [
        ("power cut", "random", ["equipment", "pressure"]),
        ("heat wave", "random", ["equipment", "cooler"]),
        ("set release", "scheduled", ["case", "crowd"]),
        ("set rotation", "scheduled", ["rules_change", "case"]),
        ("health inspection", "conditional", ["compliance", "kitchen"]),
        ("fire marshal visit", "conditional", ["compliance", "event"]),
        ("regional tournament", "scheduled", ["event", "crowd"]),
        ("delivery gone wrong", "random", ["supply", "verification"]),
        ("street closure", "random", ["footfall"]),
        ("local news feature", "random", ["reputation"]),
        ("reporting threshold change", "scheduled", ["rules_change"]),
        ("promo policy change", "scheduled", ["rules_change", "case"]),
        ("rat problem", "conditional", ["pests", "cats"]),
        ("espresso machine failure", "conditional", ["equipment", "kitchen"]),
        ("burst pipe", "random", ["equipment", "closure"]),
    ]
    for index in range(COUNTS["event"]):
        label, kind, tags = kinds[index % len(kinds)]
        wave = index // len(kinds)
        slug = f"{label.lower().replace(' ', '_')}" + (f"_{wave + 1}" if wave else "")
        announced = "rules_change" in tags
        write(
            "event",
            slug,
            {
                "id": f"base:{slug}",
                "type": "event",
                "name": f"loc:event.{slug}",
                "description": f"loc:event.{slug}.description",
                "trigger": {
                    "kind": kind,
                    "weight": round(rng.uniform(0.2, 2.0), 2),
                    "earliest_day": rng.choice([1, 5, 12, 25, 40, 60]),
                    "act": min(5, 1 + wave),
                },
                "effects": [
                    {"op": "modify", "target": tags[0], "amount": round(rng.uniform(-0.4, 0.4), 2)}
                ],
                # Rule changes are always announced and never retroactive: the failure
                # mode is forgetting, not being ambushed.
                "announced": announced,
                "tags": tags,
            },
            written,
        )


def gen_upgrades(written: dict) -> None:
    rng = rng_for("upgrade")
    seeds = [
        ("ticket printer", "automation", "memorising orders", 900),
        ("auto slicer", "automation", "manual slicing", 1600),
        ("holding cabinet", "automation", "cooking staples to order", 2100),
        ("conveyor pass", "automation", "walking to the window", 3400),
        ("condiment dispenser", "automation", "manual portioning", 450),
        ("griddle timer array", "automation", "tracking timings by eye", 1250),
        ("second griddle", "equipment", "serialisation", 4200),
        ("camera bank", "security", "", 2800),
        ("case alarm", "security", "", 1400),
        ("back room extension", "space", "", 8200),
        ("mezzanine", "space", "", 15400),
        ("event floor", "space", "", 9800),
        ("laminated checklist", "quality_of_life", "", 40),
        ("reference binder stand", "quality_of_life", "", 260),
        ("bar buildout", "space", "", 11200),
    ]
    for index in range(COUNTS["upgrade"]):
        label, category, removes, cost = seeds[index % len(seeds)]
        tier = index // len(seeds)
        slug = label.lower().replace(" ", "_") + (f"_tier_{tier + 1}" if tier else "")
        data = {
            "id": f"base:{slug}",
            "type": "upgrade",
            "name": f"loc:upgrade.{slug}",
            "description": f"loc:upgrade.{slug}.description",
            "cost": round(cost * (1.0 + tier * 0.8), 2),
            "prerequisites": [],
            "unlocks": [label.lower().replace(" ", "_")],
            "category": category,
            "costs_space": rng.choice([0, 1, 1, 2]),
        }
        if removes:
            data["removes_step"] = removes
        write("upgrade", slug, data, written)


def gen_staff_roles(written: dict) -> None:
    roles = [
        (
            "library steward",
            ["shelving", "sorting", "component_checks"],
            96.0,
            0.08,
            ["misshelved games", "skipped component checks", "damage not logged"],
            0.62,
        ),
        (
            "counter staff",
            ["transactions", "trade_ins"],
            118.0,
            0.11,
            ["register reconciliation", "camera review", "a fine three days later"],
            0.55,
        ),
        (
            "floor and tables",
            ["resets", "spills", "bins", "litter_tray"],
            88.0,
            0.07,
            ["tables left dirty", "spills not reported"],
            0.7,
        ),
        (
            "kitchen staff",
            ["orders", "prep", "clean_down"],
            132.0,
            0.13,
            ["wrong orders", "waste review", "food to the wrong table"],
            0.6,
        ),
        (
            "floor watch",
            ["deterrence", "incidents"],
            124.0,
            0.09,
            ["shrink on the case", "incidents handled badly"],
            0.5,
        ),
        (
            "night manager",
            ["open_close", "full_shift"],
            176.0,
            0.1,
            ["the morning-after reconciliation"],
            0.68,
        ),
        (
            "game teacher",
            ["teaching", "event_judging", "rulings"],
            128.0,
            0.12,
            ["retention -- you find out by who stops coming back"],
            0.45,
        ),
    ]
    for label, tasks, wage, error, audit, coverage in roles:
        slug = label.lower().replace(" ", "_")
        write(
            "staff_role",
            slug,
            {
                "id": f"base:{slug}",
                "type": "staff_role",
                "name": f"loc:staff_role.{slug}",
                "tasks": tasks,
                "wage_per_shift": wage,
                "base_error_rate": error,
                "training_shifts": 6,
                "audit_surface": audit,
                "permissions": ["handle_age_restricted"] if "transactions" in tasks else [],
                # Never 1.0: no configuration of staff runs the shop without a player.
                "coverage": coverage,
            },
            written,
        )


GENERATORS = {
    "board_game": gen_board_games,
    "card_set": gen_card_sets,
    "customer_archetype": gen_customer_archetypes,
    "fixture": gen_fixtures,
    "event": gen_events,
    "upgrade": gen_upgrades,
    "staff_role": gen_staff_roles,
}


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--check", action="store_true", help="fail if any file would change")
    parser.add_argument("types", nargs="*", help="only these definition types")
    args = parser.parse_args()

    selected = args.types or sorted(GENERATORS)
    written: dict[str, str] = {}
    for type_name in selected:
        if type_name not in GENERATORS:
            print(f"error: no generator for '{type_name}'", file=sys.stderr)
            return 2
        GENERATORS[type_name](written)

    changed: list[str] = []
    for relative, text in sorted(written.items()):
        path = DEFINITIONS / relative
        if path.is_file() and path.read_text(encoding="utf-8") == text:
            continue
        changed.append(relative)
        if not args.check:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")

    verb = "would change" if args.check else "wrote"
    print(f"{len(written)} definition(s) generated; {verb} {len(changed)}")
    if args.check and changed:
        for relative in changed[:20]:
            print(f"  {relative}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
