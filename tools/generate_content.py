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
    "supplier": 20,
}

# Worked examples the documentation points at. Never overwritten.
HAND_AUTHORED = {
    # The worked rules and vectors the documentation and the tests point at.
    "rule/age_21_alcohol.json",
    "rule/age_18_general.json",
    "rule/id_not_expired.json",
    "rule/photo_matches_bearer.json",
    "rule/barcode_agrees_with_front.json",
    "rule/uv_overlay_present.json",
    "rule/microprint_present.json",
    "rule/jurisdiction_typeface.json",
    "rule/seller_id_recorded.json",
    "rule/provenance_plausible.json",
    "rule/holding_period_observed.json",
    "rule/card_layers_correct.json",
    "rule/card_print_pattern.json",
    "rule/card_set_legal.json",
    "rule/card_weight_in_tolerance.json",
    "rule/reporting_threshold.json",
    "rule/document_not_photocopied.json",
    "rule/signature_matches_bearer.json",
    "rule/collector_number_in_range.json",
    "forgery_vector/barcode_mismatch.json",
    "forgery_vector/expiry_precedes_issue.json",
    "forgery_vector/wrong_jurisdiction_typeface.json",
    "forgery_vector/missing_uv_overlay.json",
    "forgery_vector/absent_microprint.json",
    "forgery_vector/photocopy_artifacts.json",
    "forgery_vector/signature_mismatch.json",
    "forgery_vector/unverifiable_provenance.json",
    "forgery_vector/wrong_layer_core.json",
    "forgery_vector/set_out_of_legality_window.json",
    "forgery_vector/collector_number_out_of_range.json",
    "forgery_vector/trimmed_edges.json",
    # The tool tree is referenced by every rule and vector by id; it is not generated.
    "tool/naked_eye.json",
    "tool/date_wheel.json",
    "tool/uv_torch.json",
    "tool/loupe.json",
    "tool/backlight_panel.json",
    "tool/barcode_scanner.json",
    "tool/precision_scale.json",
    "tool/ledger.json",
    "tool/digital_microscope.json",
    "tool/destructive_test.json",
    "tool/reference_binder.json",
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
    "licence/general_retail.json",
    "licence/food_service.json",
    "licence/secondhand_dealer.json",
    "licence/sealed_distribution.json",
    "supplier/metro_wholesale.json",
    # The two pieces of furniture the sealed loop is played on, and the door the stock
    # arrives through.
    "fixture/pack_rack.json",
    "fixture/singles_wall.json",
    "fixture/back_door.json",
    "supplier/nightfreight_discount.json",
    "supplier/harrowgate_distribution.json",
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


# rarity, pull rate, relative share of a pack's expected value
#
# The shape is the mechanic: nearly all of a pack's worth sits in cards you almost never
# pull, so the median pack is a disappointment and the rare one is a story. The absolute
# numbers are then scaled per set so that a pack returns less than it sells for -- see
# EV_FRACTION.
RARITY_SHAPE = [
    ("common", 0.7200, 0.06),
    ("uncommon", 0.2000, 0.10),
    ("rare", 0.0720, 0.24),
    ("mythic", 0.0076, 0.33),
    ("serialised", 0.0004, 0.27),
]

# What a pack's contents are worth, as a fraction of what the pack sells for. Below 1.0
# for every set, because the design says so out loud: opening your own stock is a worse
# deal than selling it, and the ledger is allowed to say that to the player's face.
#
# It varies by set because "which set is worth ripping" should be a real, learnable
# question with a real answer, not a coin toss.
EV_FRACTION = [0.52, 0.58, 0.64, 0.61, 0.55, 0.68, 0.59, 0.63]

# form, packs per unit, retail markup on the packs it contains, footprint, tags, licence
#
# Packs and blisters are ordinary retail: a shop can sell and open those from the first
# morning, because the gamble is a hook and a hook you cannot reach for a fortnight is
# not one. Buying by the box means buying direct from a distributor, which is a licence
# and a standing requirement -- so the loop opens small and grows.
SEALED_FORMS = [
    ("pack", 1, 1.0, [1, 1], ["sealed", "impulse"], "base:general_retail"),
    ("blister", 3, 1.08, [1, 1], ["sealed", "impulse"], "base:general_retail"),
    ("bundle", 8, 0.97, [2, 1], ["sealed", "high_value"], "base:sealed_distribution"),
    (
        "booster_box",
        0,
        0.92,
        [2, 1],
        ["sealed", "high_value", "theft_exposed"],
        "base:sealed_distribution",
    ),
]


def rarity_table(pack_price: float, cards_per_pack: int, ev_fraction: float) -> list[dict]:
    """Values scaled so the pack's expected contents come to `ev_fraction` of its price.

    A pull is worth `base_value + value_spread / 2` on average, which is what this
    inverts. Keeping the arithmetic here rather than in the JSON is what lets the
    validator assert the honest-odds rule against every set the generator emits.
    """
    target = pack_price * ev_fraction
    table = []
    for rarity, pull_rate, value_share in RARITY_SHAPE:
        mean_value = (target * value_share) / (pull_rate * cards_per_pack)
        # Spread is widest at the top: two mythics from the same set are not the same
        # card, and the gap between them is most of what makes a pull worth watching.
        spread = mean_value * (0.5 if rarity in ("common", "uncommon") else 1.6)
        table.append(
            {
                "rarity": rarity,
                "pull_rate": pull_rate,
                "base_value": round(max(0.02, mean_value - spread / 2.0), 3),
                "value_spread": round(spread, 3),
            }
        )
    return table


def gen_card_sets(written: dict) -> None:
    rng = rng_for("card_set")
    for index in range(COUNTS["card_set"]):
        name = SET_NAMES[index % len(SET_NAMES)]
        slug = name.lower().replace(" ", "_")
        released = 30 + index * 84
        pack_price = round(rng.uniform(3.8, 6.5), 2)
        cards_per_pack = rng.choice([9, 10, 12, 15])
        write(
            "card_set",
            slug,
            {
                "id": f"base:{slug}",
                "type": "card_set",
                "name": f"loc:card_set.{slug}",
                "released_day": released,
                "rotates_out_day": released + 730,
                "pack_price": pack_price,
                "cards_per_pack": cards_per_pack,
                "packs_per_box": rng.choice([24, 30, 36]),
                "rarities": rarity_table(
                    pack_price, cards_per_pack, EV_FRACTION[index % len(EV_FRACTION)]
                ),
                "security_features": ["print_rosette", "foil_response", "layer_core"],
                "tags": ["sealed_product", "authenticated"],
            },
            written,
        )


def card_set_specs() -> list[dict]:
    """The sets this generator produces, for the generators that build on them.

    Regenerated rather than read off disk so that `generate_content.py product` is the
    same as a full run: a sealed box has to describe a set that actually exists.
    """
    scratch: dict[str, str] = {}
    gen_card_sets(scratch)
    specs = [json.loads(text) for name, text in sorted(scratch.items())]
    for path in sorted((DEFINITIONS / "card_set").glob("*.json")):
        if f"card_set/{path.name}" in HAND_AUTHORED:
            specs.append(json.loads(path.read_text(encoding="utf-8")))
    return specs


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


# label, category, the step it removes, cost, what it needs first
#
# Forty-five distinct pieces of equipment rather than fifteen at three tiers. A "Tier 3
# Laminated Checklist" is not a thing anybody wants to buy, and a shop list that is two
# thirds padding is the fastest way to make a catalogue feel generated.
#
# Each one names a real job in a real shop, and the prerequisites make the list read as a
# sequence of decisions instead of a wall of prices.
UPGRADE_SEEDS = [
    # Kitchen and service automation
    ("ticket printer", "automation", "memorising orders", 900, []),
    ("order screen", "automation", "shouting the pass", 1450, ["ticket_printer"]),
    ("condiment dispenser", "automation", "manual portioning", 450, []),
    ("griddle timer array", "automation", "tracking timings by eye", 1250, []),
    ("auto slicer", "automation", "manual slicing", 1600, []),
    ("holding cabinet", "automation", "cooking staples to order", 2100, []),
    ("bean hopper", "automation", "dosing by eye", 780, []),
    ("conveyor pass", "automation", "walking to the window", 3400, ["order_screen"]),
    ("plate warmer", "automation", "plating cold", 640, []),
    ("dishwasher", "automation", "washing up between rushes", 1900, []),
    ("prep fridge", "automation", "fetching from the back", 2350, []),
    ("second griddle", "equipment", "cooking one thing at a time", 4200, ["griddle_timer_array"]),
    # The counter
    ("laminated checklist", "quality_of_life", "remembering the rules", 40, []),
    ("reference binder stand", "quality_of_life", "putting the binder down", 260, []),
    ("counter mat", "quality_of_life", "chasing cards across the counter", 85, []),
    ("task lamp", "quality_of_life", "squinting", 120, []),
    ("magnifier arm", "equipment", "holding the loupe", 540, ["task_lamp"]),
    ("card scales", "equipment", "guessing the weight", 890, []),
    ("light box", "equipment", "holding things up to the strip light", 1150, ["task_lamp"]),
    ("receipt printer", "quality_of_life", "writing receipts out", 320, []),
    ("card reader", "quality_of_life", "counting cash", 410, []),
    ("queue rail", "quality_of_life", "sorting out who was first", 380, []),
    # Security
    ("camera bank", "security", "wondering what happened", 2800, []),
    ("case alarm", "security", "watching the case", 1400, []),
    ("door buzzer", "security", "keeping an eye on the door", 760, []),
    ("stock room lock", "security", "trusting everybody", 540, []),
    ("till audit log", "security", "reconciling by hand", 1180, ["card_reader"]),
    ("shutter", "security", "worrying overnight", 3200, ["door_buzzer"]),
    ("safe", "security", "banking daily", 1650, []),
    ("mirror dome", "security", "blind corners", 290, []),
    # Space
    ("back room extension", "space", "shuffling stock to reach stock", 8200, []),
    ("mezzanine", "space", "storing overflow at home", 15400, ["back_room_extension"]),
    ("event floor", "space", "clearing tables for a tournament", 9800, []),
    ("bar buildout", "space", "serving drinks from the counter", 11200, ["event_floor"]),
    ("shelving run", "space", "double stacking", 1750, []),
    ("pallet space", "space", "breaking down deliveries in the doorway", 2400, []),
    ("cold room", "space", "two fridges and a prayer", 6800, ["back_room_extension"]),
    ("bin store", "space", "walking the waste out front", 980, []),
    ("bike rack", "space", "bikes in the aisle", 310, []),
    ("awning", "space", "the queue standing in the rain", 1520, []),
    # Comfort, which is a real upgrade in a place people sit for six hours
    ("good chairs", "quality_of_life", "customers leaving early", 2200, []),
    ("air handling", "quality_of_life", "the smell of the fryer", 4600, []),
    ("sound baffles", "quality_of_life", "shouting over the room", 1380, []),
    ("water station", "quality_of_life", "fetching tap water", 260, []),
    ("staff room", "quality_of_life", "breaks taken standing up", 3900, ["back_room_extension"]),
]


def gen_upgrades(written: dict) -> None:
    rng = rng_for("upgrade")
    for label, category, removes, cost, prerequisites in UPGRADE_SEEDS[: COUNTS["upgrade"]]:
        slug = label.lower().replace(" ", "_")
        data = {
            "id": f"base:{slug}",
            "type": "upgrade",
            "name": f"loc:upgrade.{slug}",
            "description": f"loc:upgrade.{slug}.description",
            "cost": float(cost),
            "prerequisites": [f"base:{name}" for name in prerequisites],
            "unlocks": [slug],
            "category": category,
            "costs_space": rng.choice([0, 1, 1, 2]) if category != "space" else 0,
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


# --------------------------------------------------------------------------- verification
#
# Documents, the rules that check them and the forgeries that beat them are generated
# from ONE table on purpose. The fairness rule -- every forgery is catchable with a tool
# the player can own -- is then true by construction rather than by inspection, and the
# CI gate that checks it becomes a safety net instead of a tripwire.

JURISDICTIONS = [
    "northvale",
    "port_alder",
    "saltmere",
    "kingsferry",
    "westcairn",
    "elmgate",
    "harrow_bay",
    "low_fenn",
]

# check op -> (tool that reveals it, which fields or features it needs)
CHECKS = {
    "not_expired": (None, {"fields": ["expiry"]}),
    "age_at_least": (None, {"fields": ["dob"]}),
    "matches_person": (None, {"fields": ["photo"]}),
    "field_plausible": (None, {"fields": ["signature"]}),
    "fields_match": ("base:barcode_scanner", {"fields": ["barcode", "dob"]}),
    "feature_uv": ("base:uv_torch", {"features": ["uv_seal"]}),
    "feature_microprint": ("base:loupe", {"features": ["microprint_border"]}),
    "feature_carbon": ("base:loupe", {"features": ["carbon_impression"]}),
    "feature_layers": ("base:backlight_panel", {"features": ["layer_core"]}),
    "physically_intact": ("base:loupe", {}),
    "typeface_matches": ("base:reference_binder", {}),
    "within_threshold": ("base:precision_scale", {"fields": ["weight"]}),
    "value_at_most": ("base:loupe", {"fields": ["collector_number"]}),
}

# family -> fields, security features, transaction tags, and which checks apply
FAMILIES = {
    "identity": {
        "fields": [
            "surname",
            "given_names",
            "dob",
            "issued",
            "expiry",
            "height",
            "photo",
            "barcode",
        ],
        "features": ["uv_seal", "microprint_border"],
        "tags": ["id_required", "age_restricted"],
        "checks": [
            "not_expired",
            "age_at_least",
            "matches_person",
            "fields_match",
            "feature_uv",
            "feature_microprint",
            "typeface_matches",
        ],
        "count": 10,
    },
    "payment": {
        "fields": ["cardholder", "pan_last_four", "expiry", "issuer", "signature"],
        "features": ["uv_seal"],
        "tags": ["payment"],
        "checks": ["not_expired", "field_plausible", "feature_uv", "physically_intact"],
        "count": 4,
    },
    "entitlement": {
        "fields": ["holder", "programme", "categories", "balance", "expiry", "certificate_number"],
        "features": ["uv_seal", "microprint_border"],
        "tags": ["entitlement", "reconciliation"],
        "checks": ["not_expired", "feature_uv", "feature_microprint", "typeface_matches"],
        "count": 4,
    },
    "commercial": {
        "fields": [
            "seller_name",
            "seller_id_number",
            "item_description",
            "declared_provenance",
            "date",
            "holding_period_ends",
            "signature",
        ],
        # A carbon copy, like the hand-authored trade-in record: the second sheet is
        # what makes a photocopy obvious under a loupe.
        "features": ["carbon_impression"],
        "tags": ["trade_in", "resale"],
        "checks": ["field_plausible", "physically_intact", "feature_carbon", "not_expired"],
        "count": 5,
    },
    "credential": {
        "fields": ["officer_name", "badge_number", "agency", "issued", "expiry", "photo"],
        "features": ["uv_seal", "microprint_border"],
        "tags": ["official_visit"],
        "checks": [
            "not_expired",
            "matches_person",
            "feature_uv",
            "feature_microprint",
            "typeface_matches",
        ],
        "count": 3,
    },
    "collectible": {
        "fields": [
            "title",
            "set_symbol",
            "collector_number",
            "rarity",
            "copyright_line",
            "layer_structure",
            "weight",
        ],
        "features": ["print_rosette", "foil_response", "layer_core"],
        "tags": ["authentication", "trade_in"],
        "checks": [
            "feature_layers",
            "feature_microprint",
            "within_threshold",
            "value_at_most",
            "typeface_matches",
            "physically_intact",
        ],
        "count": 2,
    },
}

FIELD_SOURCES = {
    "surname": "person.surname",
    "given_names": "person.given_names",
    "dob": "person.dob",
    "issued": "derived.issued",
    "expiry": "derived.expiry",
    "height": "person.height",
    "photo": "person.portrait",
    "barcode": "encoded.all_fields",
    "cardholder": "person.full_name",
    "pan_last_four": "person.id_number",
    "issuer": "world.issuer",
    "signature": "person.signature",
    "holder": "person.full_name",
    "programme": "world.programme",
    "categories": "world.categories",
    "balance": "world.balance",
    "certificate_number": "person.id_number",
    "seller_name": "person.full_name",
    "seller_id_number": "person.id_number",
    "item_description": "transaction.items",
    "declared_provenance": "person.claim",
    "date": "world.date",
    "holding_period_ends": "derived.holding_end",
    "officer_name": "person.full_name",
    "badge_number": "person.id_number",
    "agency": "world.agency",
    "title": "card.title",
    "set_symbol": "card.set",
    "collector_number": "card.number",
    "rarity": "card.rarity",
    "copyright_line": "card.copyright",
    "layer_structure": "physical.layers",
    "weight": "physical.mass",
}

FEATURE_TOOLS = {
    "uv_seal": "base:uv_torch",
    "microprint_border": "base:loupe",
    "carbon_impression": "base:loupe",
    "print_rosette": "base:loupe",
    "foil_response": "base:uv_torch",
    "layer_core": "base:backlight_panel",
}

FIELD_TOOLS = {
    "barcode": "base:barcode_scanner",
    "layer_structure": "base:backlight_panel",
    "weight": "base:precision_scale",
}

TOOL_TIERS = {
    None: 0,
    "base:naked_eye": 0,
    "base:uv_torch": 1,
    "base:loupe": 1,
    "base:backlight_panel": 1,
    "base:barcode_scanner": 2,
    "base:precision_scale": 2,
    "base:reference_binder": 3,
    "base:ledger": 3,
    "base:digital_microscope": 3,
}


def gen_document_types(written: dict) -> None:
    rng = rng_for("document_type")
    for family, spec in FAMILIES.items():
        for index in range(spec["count"]):
            if family == "identity":
                jurisdiction = JURISDICTIONS[index % len(JURISDICTIONS)]
                slug = f"state_id_{jurisdiction}"
            else:
                slug = f"{family}_form_{index + 1}"
                jurisdiction = ""
            data = {
                "id": f"base:{slug}",
                "type": "document_type",
                "name": f"loc:doc.{slug}",
                "family": family,
                "layout": "res://content/layouts/%s.tres"
                % ("id_landscape_a" if family == "identity" else "form_a4_carbon"),
                "fields": [_field(key) for key in spec["fields"]],
                "security_features": [
                    {"id": feature, "revealed_by": FEATURE_TOOLS[feature]}
                    for feature in spec["features"]
                ],
                "typeface": f"base:font_{jurisdiction or family}_official",
            }
            if jurisdiction:
                data["jurisdiction"] = jurisdiction
                data["variants"] = {
                    "under21": {"orientation": "portrait", "banner": "loc:doc.under21"}
                }
            write("document_type", slug, data, written)
            _ = rng


def _field(key: str) -> dict:
    spec = {"key": key, "source": FIELD_SOURCES.get(key, f"world.{key}"), "face": "front"}
    if key in FIELD_TOOLS:
        spec["face"] = "back" if key == "barcode" else "edge"
        spec["revealed_by"] = FIELD_TOOLS[key]
    if key in {"dob", "issued", "expiry", "date", "holding_period_ends"}:
        spec["format"] = "MM/DD/YYYY"
    return spec


def gen_rules(written: dict) -> None:
    """One rule per (family, check). These are the checklist the player carries, and the
    binder is generated from the same objects -- so it cannot drift from what is enforced."""
    for family, spec in FAMILIES.items():
        for check_name in spec["checks"]:
            tool, needs = CHECKS[check_name]
            # A rule that checks for a feature the family's documents do not carry fails
            # on every genuine one, which quietly turns honest customers into forgeries.
            if any(feature not in spec["features"] for feature in needs.get("features", [])):
                continue
            if any(field not in spec["fields"] for field in needs.get("fields", [])):
                continue
            slug = f"{family}_{check_name}"
            data = {
                "id": f"base:{slug}",
                "type": "rule",
                "name": f"loc:rule.{slug}",
                "explanation": f"loc:rule.{slug}.explanation",
                "applies_to": {
                    "document_families": [family],
                    "transaction_tags": spec["tags"],
                },
                "check": _check_body(check_name),
                # Partial is meant to be the most-used verdict in skilled play: approve
                # the basket minus the flagged items. That only works if some failures
                # are item-scoped rather than refusing the whole transaction -- which is
                # exactly what an entitlement or a holding period is.
                "severity": _severity_for(family, check_name),
                "tier": TOOL_TIERS.get(tool, 0),
            }
            if tool:
                data["requires_tool"] = tool
            write("rule", slug, data, written)


def _severity_for(family: str, check_name: str) -> str:
    if check_name == "typeface_matches":
        return "advisory"
    if family == "entitlement":
        return "item_scoped"
    if family == "commercial" and check_name in {"not_expired", "field_plausible"}:
        return "item_scoped"
    return "blocking"


def _check_body(check_name: str) -> dict:
    match check_name:
        case "not_expired":
            return {"op": "not_expired", "field": "expiry"}
        case "age_at_least":
            return {"op": "age_at_least", "field": "dob", "value": 21}
        case "matches_person":
            return {"op": "matches_person", "field": "photo"}
        case "field_plausible":
            return {"op": "field_plausible", "field": "signature"}
        case "fields_match":
            return {"op": "fields_match", "fields": ["barcode.dob", "dob"]}
        case "feature_uv":
            return {"op": "feature_present", "feature": "uv_seal"}
        case "feature_microprint":
            return {"op": "feature_present", "feature": "microprint_border"}
        case "feature_carbon":
            return {"op": "feature_present", "feature": "carbon_impression"}
        case "feature_layers":
            return {"op": "feature_present", "feature": "layer_core"}
        case "physically_intact":
            return {"op": "physically_intact"}
        case "typeface_matches":
            return {"op": "typeface_matches", "field": "typeface"}
        case "within_threshold":
            return {"op": "within_threshold", "field": "weight", "threshold": 0.12}
        case _:
            return {"op": "value_at_most", "field": "collector_number", "value": 999}


# check -> the transforms that defeat it, as (suffix, class, op, target, method)
VECTOR_TEMPLATES = {
    "not_expired": [("expired", "internal_inconsistency", "set_field", "expiry", "before")],
    "age_at_least": [
        ("dob_altered", "internal_inconsistency", "perturb_field", "dob", "shift_years")
    ],
    "matches_person": [
        ("photo_substituted", "physical_defect", "perturb_field", "photo", "swapped")
    ],
    "field_plausible": [
        ("different_hand", "internal_inconsistency", "perturb_field", "signature", "different_hand")
    ],
    "fields_match": [
        (
            "barcode_disagrees",
            "internal_inconsistency",
            "perturb_field",
            "barcode.dob",
            "shift_years",
        )
    ],
    "feature_uv": [("no_uv_overlay", "physical_defect", "remove_feature", "uv_seal", "")],
    "feature_microprint": [
        ("no_microprint", "physical_defect", "remove_feature", "microprint_border", ""),
        (
            "blurred_microprint",
            "physical_defect",
            "degrade_feature",
            "microprint_border",
            "raster_blur",
        ),
    ],
    "feature_carbon": [
        ("no_carbon_impression", "physical_defect", "remove_feature", "carbon_impression", ""),
    ],
    "feature_layers": [
        ("single_layer_core", "physical_defect", "substitute_stock", "layer_core", "single_layer")
    ],
    "physically_intact": [
        (
            "photocopied",
            "physical_defect",
            "apply_process",
            "whole_artifact",
            "photocopy_generation",
        )
    ],
    "typeface_matches": [
        (
            "near_miss_typeface",
            "external_inconsistency",
            "substitute_typeface",
            "all_text",
            "near_miss_face",
        )
    ],
    "within_threshold": [("trimmed", "physical_defect", "resize", "card_edges", "trim_mm")],
    "value_at_most": [
        (
            "number_out_of_range",
            "internal_inconsistency",
            "perturb_field",
            "collector_number",
            "exceed_print_run",
        )
    ],
}

TELLS = [
    ("volunteers_information", 0.4),
    ("looks_at_door", 0.3),
    ("rehearsed_line", 0.35),
    ("response_latency_high", 0.45),
    ("over_explains", 0.5),
    ("presses_for_speed", 0.4),
    ("watches_your_hands", 0.3),
    ("apologises_unprompted", 0.35),
]


def gen_forgery_vectors(written: dict) -> None:
    """Every vector is generated against a rule that catches it, with the tool that rule
    requires. A forgery nobody can catch is not difficulty; it is a coin flip."""
    rng = rng_for("forgery_vector")
    for family, spec in FAMILIES.items():
        for check_name in spec["checks"]:
            tool, needs = CHECKS[check_name]
            if any(feature not in spec["features"] for feature in needs.get("features", [])):
                continue
            if any(field not in spec["fields"] for field in needs.get("fields", [])):
                continue
            for suffix, vector_class, op, target, method in VECTOR_TEMPLATES[check_name]:
                slug = f"{family}_{suffix}"
                transform = {"op": op, "target": target}
                if method:
                    transform["method"] = method
                if method == "shift_years":
                    transform["range"] = [2, 6]
                if method == "trim_mm":
                    transform["range"] = [0.2, 0.6]
                if method == "before":
                    transform["reference"] = "issued"
                if method == "photocopy_generation":
                    transform["generations"] = 2
                tell_behaviour, tell_weight = TELLS[rng.randrange(len(TELLS))]
                base_tier = TOOL_TIERS.get(tool, 0)
                applies: dict = {"document_types": ["*"]}
                # Wildcard plus a requirement is what makes vectors combinatorial: one
                # definition covers every document with that field, including a mod's.
                needs = CHECKS[check_name][1]
                if needs.get("fields"):
                    applies["requires_field"] = needs["fields"][0]
                elif needs.get("features"):
                    applies["requires_feature"] = needs["features"][0]
                # Three subtleties of the same forgery: the same lie, told more or
                # less loudly. It is how the late game sends you something you have seen
                # before, done better -- and the tier never drops below the tool that
                # catches it, because subtlety is not an excuse for a coin flip.
                for grade, tier_bump, difficulty_bump, tell_bump in [
                    ("", 0, 0, 0.0),
                    ("_blatant", 0, -1, 0.2),
                    ("_subtle", 1, 1, -0.15),
                ]:
                    write(
                        "forgery_vector",
                        slug + grade,
                        {
                            "id": f"base:{slug}{grade}",
                            "type": "forgery_vector",
                            "applies_to": applies,
                            "class": vector_class,
                            "tier": min(4, base_tier + tier_bump),
                            "difficulty": max(
                                1,
                                min(
                                    5,
                                    1 + base_tier + difficulty_bump + (1 if "degrade" in op else 0),
                                ),
                            ),
                            "detectable_by": [tool] if tool else ["base:naked_eye"],
                            "transform": transform,
                            "tell": {
                                "behaviour": tell_behaviour,
                                "weight": round(max(0.05, min(1.0, tell_weight + tell_bump)), 2),
                            },
                        },
                        written,
                    )


# --------------------------------------------------------------------------- shop content

CAFE_ITEMS = [
    ("cold_brew", "cold_beverages", "chilled", 0.9, 3.4, 21, ["impulse"]),
    ("flat_white_beans", "hot_beverages", "ambient", 14.5, 0.0, 180, ["ingredient", "staple"]),
    ("oat_milk", "chilled", "chilled", 1.4, 0.0, 30, ["ingredient"]),
    ("sourdough", "bakery", "ambient", 1.6, 4.0, 3, ["ingredient", "perishable"]),
    ("cheddar", "chilled", "chilled", 5.2, 0.0, 45, ["ingredient", "slicer"]),
    ("butter", "chilled", "chilled", 2.1, 0.0, 60, ["ingredient"]),
    ("tomato", "chilled", "chilled", 0.8, 0.0, 10, ["ingredient", "perishable"]),
    ("bacon", "chilled", "chilled", 4.4, 0.0, 14, ["ingredient", "slicer"]),
    ("eggs_dozen", "chilled", "chilled", 3.1, 0.0, 21, ["ingredient"]),
    ("chips", "confectionery", "ambient", 0.5, 1.8, 120, ["impulse", "snack"]),
    ("chocolate_bar", "confectionery", "ambient", 0.6, 2.1, 240, ["impulse"]),
    ("sparkling_water", "cold_beverages", "chilled", 0.45, 2.2, 300, ["impulse"]),
    ("house_lager", "alcohol", "chilled", 1.2, 5.5, 200, ["age_restricted", "impulse"]),
    ("red_wine", "alcohol", "ambient", 6.5, 24.0, 900, ["age_restricted"]),
    ("vape_pod", "nicotine", "ambient", 3.2, 9.5, 400, ["age_restricted", "counter_adjacent"]),
    ("napkins", "household", "ambient", 0.05, 0.0, 0, ["consumable"]),
    ("cups_16oz", "household", "ambient", 0.08, 0.0, 0, ["consumable"]),
    ("card_sleeves", "accessories", "ambient", 1.05, 4.5, 0, ["impulse", "counter_adjacent"]),
    ("deck_box", "accessories", "ambient", 2.1, 7.5, 0, ["counter_adjacent"]),
    ("playmat", "accessories", "ambient", 6.0, 19.0, 0, []),
    ("dice_set", "accessories", "ambient", 3.4, 11.0, 0, ["impulse"]),
    ("toploaders", "accessories", "ambient", 2.2, 6.0, 0, ["counter_adjacent"]),
    (
        "graded_single",
        "singles",
        "ambient",
        140.0,
        310.0,
        0,
        ["high_value", "theft_exposed", "case_only"],
    ),
    ("raw_single", "singles", "ambient", 12.0, 28.0, 0, ["case_only", "buylist_tracked"]),
]

MENU_ITEMS = [
    ("filter_coffee", 2.8, "coffee_bar", [("flat_white_beans", 14, "g")], 2),
    ("flat_white", 3.8, "coffee_bar", [("flat_white_beans", 18, "g"), ("oat_milk", 120, "ml")], 4),
    ("cold_brew_glass", 4.2, "coffee_bar", [("cold_brew", 1, "each")], 2),
    (
        "three_cheese_toastie",
        8.5,
        "griddle",
        [("sourdough", 2, "slice"), ("cheddar", 60, "g"), ("butter", 12, "g")],
        5,
    ),
    ("bacon_roll", 7.0, "griddle", [("sourdough", 1, "roll"), ("bacon", 60, "g")], 4),
    ("loaded_fries", 6.5, "fryer", [("cheddar", 40, "g")], 3),
    (
        "breakfast_plate",
        11.5,
        "griddle",
        [
            ("eggs_dozen", 2, "each"),
            ("bacon", 50, "g"),
            ("sourdough", 2, "slice"),
            ("tomato", 1, "each"),
        ],
        9,
    ),
    (
        "table_platter",
        18.0,
        "prep",
        [("cheddar", 120, "g"), ("sourdough", 4, "slice"), ("chips", 2, "bag")],
        7,
    ),
    ("cold_plate", 9.0, "prep", [("cheddar", 80, "g"), ("tomato", 2, "each")], 5),
    ("milkshake", 5.4, "cold_well", [("oat_milk", 200, "ml"), ("chocolate_bar", 1, "each")], 3),
]

# name, product categories, activities it permits, cost, standing, the scrutiny it drags in
#
# Twenty-one distinct licences rather than tiers of the same one: each has to add a real
# obligation, because a licence that only costs money is a shopping list entry, not a
# decision. Taking none of them is a viable, occasionally correct way to play.
LICENCE_SEEDS = [
    (
        "on_premise_alcohol",
        ["alcohol"],
        ["bar_service"],
        2800,
        2,
        ["ID checks", "Hour restrictions", "Refusal of service", "Intoxication judgement"],
    ),
    ("counter_nicotine", ["nicotine"], ["vape_counter"], 700, 1, ["ID checks on every sale"]),
    (
        "sanctioned_event_organiser",
        ["board_games"],
        ["tournaments", "prize_payouts"],
        1600,
        2,
        ["Event legitimacy", "Prize payout ceilings", "Age divisions", "Guardian consent"],
    ),
    (
        "high_value_transaction",
        ["singles"],
        ["large_payouts"],
        2200,
        3,
        ["Identity capture above a threshold", "Reporting"],
    ),
    (
        "late_hours_permit",
        [],
        ["late_hours_door"],
        1900,
        3,
        ["Carding at the door after the cutoff"],
    ),
    ("table_service", [], ["table_service"], 900, 1, ["Allergen handling", "Table hygiene"]),
    ("music_licence", [], ["shop_radio"], 420, 0, []),
    ("outdoor_seating", [], ["frontage"], 1100, 1, ["Occupancy limits", "Noise restrictions"]),
    (
        "prop_and_replica_sales",
        ["accessories"],
        ["prop_sales"],
        1500,
        3,
        ["Age checks", "Logged sales"],
    ),
    ("catering_offsite", [], ["offsite_catering"], 2400, 3, ["Transport temperature logs"]),
    (
        "charity_gaming",
        [],
        ["charity_events"],
        600,
        2,
        ["Prize limits", "Records for the regulator"],
    ),
    (
        "membership_scheme",
        [],
        ["memberships", "library_lending"],
        800,
        1,
        ["Identity tied to borrowing privileges", "Outstanding item records"],
    ),
    (
        "consignment_sales",
        ["singles"],
        ["consignment"],
        1700,
        3,
        ["Owner records", "Payout reconciliation", "Insurance on goods you do not own"],
    ),
    (
        "grading_courier_account",
        [],
        ["grading_submissions"],
        1300,
        2,
        ["Courier credential verification", "Chain of custody"],
    ),
    (
        "organised_play_kits",
        [],
        ["promo_distribution"],
        950,
        2,
        ["Participant lists", "Strict count per head", "Never for sale"],
    ),
    ("waste_and_recycling", [], ["trade_waste"], 380, 0, ["Segregation", "Collection records"]),
    (
        "late_night_food",
        [],
        ["late_kitchen"],
        1450,
        2,
        ["Hot food after the cutoff", "Noise and queue management"],
    ),
    (
        "temporary_event_notice",
        [],
        ["pop_up_events"],
        260,
        1,
        ["Per-event notification", "Attendance ceilings"],
    ),
    ("vending_and_amusement", [], ["machines"], 540, 1, ["Machine registration", "Payout audits"]),
    (
        "secondhand_online_resale",
        ["singles", "board_games"],
        ["online_resale"],
        1250,
        3,
        ["Holding periods apply to online listings too", "Platform records"],
    ),
    (
        "staff_agency_account",
        [],
        ["agency_staff"],
        700,
        2,
        ["Right-to-work checks on every placement"],
    ),
]

CAT_SEEDS = [
    ("tabby_orange", "orange_tabby", {"social": 0.8, "lazy": 0.6, "hunter": 0.4}),
    ("tuxedo_shorthair", "tuxedo", {"vigilant": 0.85, "hunter": 0.7}),
    ("calico", "calico", {"vocal": 0.8, "social": 0.6, "territorial": 0.5}),
    ("black_shorthair", "black", {"nocturnal": 0.9, "hunter": 0.75, "skittish": 0.4}),
    ("grey_longhair", "grey", {"lazy": 0.85, "social": 0.7}),
    ("siamese_cross", "seal_point", {"vocal": 0.95, "vigilant": 0.6}),
    ("ginger_longhair", "ginger", {"social": 0.9, "thief": 0.5}),
    ("tortoiseshell", "tortie", {"territorial": 0.8, "hunter": 0.6}),
    ("white_shorthair", "white", {"skittish": 0.7, "vigilant": 0.5}),
    ("blue_russian", "blue", {"vigilant": 0.9, "skittish": 0.6}),
    ("farm_tabby", "brown_tabby", {"hunter": 0.95, "escape_artist": 0.6}),
    ("three_legged", "patch", {"social": 0.85, "lazy": 0.7}),
]

EXTRA_TOOLS = [
    ("counterfeit_pen", 1, ["paper_composition"], 2.0, "cash volume milestone", []),
    (
        "note_validator",
        2,
        ["note_authenticity"],
        3.5,
        "cash handling upgrade",
        ["Fast, and fallible on a high-quality fake."],
    ),
    (
        "product_authenticator",
        2,
        ["batch_codes", "tamper_seals", "holograms"],
        6.0,
        "supplier trust tier 2",
        [],
    ),
    (
        "camera_bank_dvr",
        3,
        ["recorded_footage", "staff_error", "disputed_transaction"],
        45.0,
        "back_office",
        [],
    ),
    (
        "terminal_fraud_flags",
        4,
        ["card_risk_signals"],
        4.0,
        "late_campaign",
        ["Flags risk, never fraud; the difference costs you a customer either way."],
    ),
    (
        "licensing_hotline",
        4,
        ["credential_verification"],
        240.0,
        "late_campaign",
        ["Ties up a player for four minutes while the queue builds."],
    ),
    ("raking_light", 1, ["surface_scratches", "whitening"], 5.0, "reputation_tier_2", []),
    ("centering_gauge", 2, ["centering"], 8.0, "store_level_3", []),
    (
        "seal_inspector",
        2,
        ["seal_geometry"],
        9.0,
        "base:sealed_distribution",
        ["A professional reseal is why you only find out after you open it."],
    ),
    ("buylist_terminal", 3, ["market_price", "recent_sales"], 12.0, "licence_tier_3", []),
    (
        "network_lookup",
        3,
        ["cross_shop_reputation"],
        30.0,
        "late_campaign",
        ["And the seller can see you doing it."],
    ),
]

SUPPLIER_SEEDS = [
    ("blackwater_dairy", ["chilled"], "standard", 0.93, 0.0, 0.97),
    ("eastgate_bakery", ["bakery"], "premium", 0.96, 0.0, 0.99),
    ("cut_price_cartons", ["ambient", "household"], "discount", 0.68, 0.06, 0.8),
    ("harbour_roasters", ["hot_beverages"], "premium", 0.98, 0.0, 0.99),
    ("penny_lane_wholesale", ["confectionery", "ambient"], "standard", 0.9, 0.01, 0.95),
    ("third_shift_logistics", ["sealed_product", "accessories"], "discount", 0.62, 0.14, 0.72),
    ("meridian_direct", ["sealed_product"], "premium", 0.99, 0.0, 1.0),
    ("cellar_and_vine", ["alcohol"], "standard", 0.94, 0.0, 0.98),
    ("grey_channel_imports", ["sealed_product", "singles"], "grey", 0.55, 0.28, 0.6),
    ("northline_catering", ["chilled", "frozen"], "standard", 0.91, 0.0, 0.96),
    ("paper_and_pulp", ["household"], "discount", 0.85, 0.0, 0.93),
    ("card_barn_trade", ["singles"], "discount", 0.7, 0.18, 0.74),
    ("union_street_produce", ["chilled"], "standard", 0.88, 0.0, 0.95),
    ("kingsferry_brewing", ["alcohol"], "premium", 0.97, 0.0, 0.99),
    ("lastminute_couriers", ["ambient"], "discount", 0.58, 0.03, 0.81),
    ("guild_distribution", ["board_games"], "premium", 0.95, 0.0, 0.98),
    ("backroom_singles", ["singles"], "grey", 0.49, 0.33, 0.55),
]


def gen_sealed_products(written: dict) -> int:
    """One product per (set, form): the thing on the rack that can be sold or opened.

    Deriving these from the sets rather than hand-listing them is what makes the rip
    decision real for every set in the game, including one a mod adds -- the loop reads
    the `sealed` block, never a list of ids.
    """
    made = 0
    for spec in card_set_specs():
        set_slug = spec["id"].split(":", 1)[1]
        pack_price = float(spec["pack_price"])
        for form, packs, markup, footprint, tags, licence in SEALED_FORMS:
            count = int(spec["packs_per_box"]) if packs == 0 else packs
            market = round(pack_price * count * markup, 2)
            slug = f"{set_slug}_{form}"
            write(
                "product",
                slug,
                {
                    "id": f"base:{slug}",
                    "type": "product",
                    "name": f"loc:product.{slug}",
                    "category": "sealed_product",
                    "tags": sorted({*tags, "resealable"}),
                    "storage": "ambient",
                    "shelf_footprint": footprint,
                    "units_per_case": 6 if count > 8 else 24,
                    "sealed": {
                        "card_set": spec["id"],
                        "form": form,
                        "packs": count,
                    },
                    "base_cost": round(market * 0.71, 2),
                    "market_price": market,
                    "price_band": [round(market * 0.85, 2), round(market * 1.6, 2)],
                    "shelf_life_days": 0,
                    "licence": licence,
                    "suppliers": ["base:metro_wholesale"],
                    "adjacency_affinity": ["accessories"],
                    "urgency": "high" if count == 1 else "low",
                },
                written,
            )
            made += 1
    return made


def gen_products(written: dict) -> None:
    rng = rng_for("product")
    licence_for = {
        "alcohol": "base:on_premise_alcohol",
        "nicotine": "base:counter_nicotine",
        "sealed_product": "base:sealed_distribution",
        "singles": "base:secondhand_dealer",
    }
    variants = ["", "large", "small", "house", "seasonal", "premium"]
    made: int = gen_sealed_products(written)
    for variant in variants:
        for base_name, category, storage, cost, price, shelf_life, tags in CAFE_ITEMS:
            if made >= COUNTS["product"]:
                return
            slug = base_name if not variant else f"{base_name}_{variant}"
            multiplier = {
                "": 1.0,
                "large": 1.5,
                "small": 0.7,
                "house": 0.9,
                "seasonal": 1.15,
                "premium": 1.8,
            }[variant]
            market = round(price * multiplier, 2)
            write(
                "product",
                slug,
                {
                    "id": f"base:{slug}",
                    "type": "product",
                    "name": f"loc:product.{slug}",
                    "category": category,
                    "tags": sorted(set(tags + ([storage] if storage != "ambient" else []))),
                    "storage": storage,
                    "shelf_footprint": [2 if variant == "large" else 1, 1],
                    "units_per_case": rng.choice([6, 8, 12, 24, 48]),
                    "base_cost": round(cost * multiplier, 2),
                    "market_price": market,
                    "price_band": [round(market * 0.65, 2), round(market * 1.9, 2)]
                    if market > 0
                    else [0.0, 0.0],
                    "shelf_life_days": shelf_life,
                    "licence": licence_for.get(category, "base:general_retail"),
                    "suppliers": ["base:metro_wholesale"],
                    "urgency": "high" if "impulse" in tags else "low",
                },
                written,
            )
            made += 1


def gen_recipes(written: dict) -> None:
    rng = rng_for("recipe")
    made: int = 0
    for variant in ["", "large", "vegetarian", "to_share", "late_night"]:
        for base_name, price, station, ingredients, steps in MENU_ITEMS:
            if made >= COUNTS["recipe"]:
                return
            slug = base_name if not variant else f"{base_name}_{variant}"
            multiplier = {
                "": 1.0,
                "large": 1.4,
                "vegetarian": 1.0,
                "to_share": 1.9,
                "late_night": 1.1,
            }[variant]
            recipe_steps = []
            for index in range(steps):
                recipe_steps.append(
                    {
                        "station": station if index else "prep",
                        "action": ["prep", "cook", "assemble", "plate", "melt", "slice"][index % 6],
                        "seconds": rng.choice([6, 8, 12, 20, 45, 60, 95]),
                        "tolerance": rng.choice([3, 4, 6, 10, 14]),
                    }
                )
            write(
                "recipe",
                slug,
                {
                    "id": f"base:{slug}",
                    "type": "recipe",
                    "name": f"loc:recipe.{slug}",
                    "price": round(price * multiplier, 2),
                    "station_primary": station,
                    "ingredients": [
                        {
                            "product": f"base:{product}",
                            "qty": round(quantity * multiplier, 2),
                            "unit": unit,
                        }
                        for product, quantity, unit in ingredients
                        if not (variant == "vegetarian" and product == "bacon")
                    ],
                    "steps": recipe_steps,
                    "modifiers_allowed": [
                        "omission",
                        "addition",
                        "substitution",
                        "preparation",
                        "portioning",
                        "quantity",
                    ],
                    # Hot prepared food is excluded from trade-in credit, which turns a
                    # sandwich into a verification encounter.
                    "store_credit_eligible": station in {"coffee_bar", "cold_well"},
                    "unlocked_by": "base:food_service"
                    if station != "coffee_bar"
                    else "base:general_retail",
                },
                written,
            )
            made += 1


def gen_licences(written: dict) -> None:
    for base_name, categories, activities, cost, standing, burden in LICENCE_SEEDS:
        slug = base_name
        write(
            "licence",
            slug,
            {
                "id": f"base:{slug}",
                "type": "licence",
                "name": f"loc:licence.{slug}",
                "unlocks_categories": categories,
                "unlocks_activities": activities,
                "cost": float(cost),
                "renewal_days": 365,
                "standing_required": standing,
                "verification_burden": burden,
                "strike_consequences": {
                    "first": "Fine, and a note on the record.",
                    "second": "Larger fine, and undercover attempts become frequent.",
                    "third": "Suspended for a fixed period. The revenue stops.",
                },
            },
            written,
        )


def gen_tools(written: dict) -> None:
    for slug, tier, reveals, seconds, unlocked_by, failure_modes in EXTRA_TOOLS:
        data = {
            "id": f"base:{slug}",
            "type": "tool",
            "name": f"loc:tool.{slug}",
            "tier": tier,
            "reveals": reveals,
            "inspection_seconds": seconds,
            "unlocked_by": unlocked_by,
            # A tool reveals; it never judges.
            "returns_verdict": False,
        }
        if failure_modes:
            data["failure_modes"] = failure_modes
        write("tool", slug, data, written)


def gen_suppliers(written: dict) -> None:
    for slug, catalogue, tier, reliability, counterfeit, accuracy in SUPPLIER_SEEDS:
        write(
            "supplier",
            slug,
            {
                "id": f"base:{slug}",
                "type": "supplier",
                "name": f"loc:supplier.{slug}",
                "catalogue": catalogue,
                "lead_time_days": [1, 3] if tier != "discount" else [2, 7],
                "minimum_order": 120.0 if tier == "premium" else 60.0,
                "price_tier": tier,
                "reliability": reliability,
                # The cheap supplier is cheap for a reason, and the reason turns up at
                # the back door as a verification encounter.
                "legitimacy": {
                    "counterfeit_rate": counterfeit,
                    "manifest_accuracy": accuracy,
                    "credentials_verifiable": tier != "grey",
                },
            },
            written,
        )


def gen_cats(written: dict) -> None:
    rng = rng_for("cat")
    for slug, coat, traits in CAT_SEEDS:
        full_traits = dict(traits)
        for extra in [
            "vigilant",
            "lazy",
            "skittish",
            "social",
            "territorial",
            "hunter",
            "thief",
            "vocal",
            "nocturnal",
            "escape_artist",
        ]:
            full_traits.setdefault(extra, round(rng.uniform(0.05, 0.5), 2))
        write(
            "cat",
            slug,
            {
                "id": f"base:{slug}",
                "type": "cat",
                "name_pool": "loc:catnames.common",
                "model": f"res://content/scenes/cats/{coat}.tscn",
                "coat": coat,
                "trait_weights": full_traits,
                "base_hunting": round(0.3 + full_traits.get("hunter", 0.3) * 0.7, 2),
                "counter_sensitivity": round(0.2 + full_traits.get("vigilant", 0.3) * 0.7, 2),
                # The cat points attention. It never resolves anything.
                "false_positive_rate": round(0.05 + full_traits.get("skittish", 0.2) * 0.35, 2),
                "customer_appeal": round(0.3 + full_traits.get("social", 0.3) * 0.6, 2),
                "vocalisations": f"res://content/assets/audio/cats/{coat}/",
            },
            written,
        )


# --------------------------------------------------------------------------- people

NPC_SEEDS = [
    ("regular", "steady", ["asks after the cat"]),
    ("regular", "warming", ["brings their own dice"]),
    ("regular", "steady", ["always the same table"]),
    ("repeat_offender", "cooling", ["counts their change twice"]),
    ("repeat_offender", "volatile", ["watches the case, not you"]),
    ("difficult", "volatile", ["argues about the deposit"]),
    ("trade_partner", "steady", ["sleeves everything before it hits the glass"]),
    ("trade_partner", "long_con", ["twenty clean transactions, and then one that is not"]),
    ("official", "steady", ["asks for the temperature log first"]),
    ("staff_candidate", "warming", ["arrives ten minutes early"]),
    ("judge", "steady", ["quotes the policy number from memory"]),
    ("courier", "cooling", ["never has the same paperwork twice"]),
]

# slug, event counted, how many, hidden
#
# Sixty distinct deeds rather than twelve at five tiers. A tier ladder is the laziest
# possible achievement list: it multiplies a number and calls it new content, and a
# player reading "Cat Bonded Tier 4" knows exactly how little thought went into it.
#
# These are named for the thing that happened, and the counts are chosen so that the
# early ones land inside a first session and the late ones mark a real campaign.
ACHIEVEMENT_SEEDS = [
    # The counter, which is the game
    ("first_verdict", "verification_resolved", 1, False),
    ("a_full_shift", "verification_resolved", 40, False),
    ("hundred_hands", "verification_resolved", 100, False),
    ("thousand_hands", "verification_resolved", 1000, False),
    ("the_long_week", "day_ended", 7, False),
    ("a_month_of_it", "day_ended", 30, False),
    ("first_refusal", "customer_left", 1, False),
    ("nobody_walks", "customer_served", 250, False),
    ("five_hundred_served", "customer_served", 500, False),
    ("two_thousand_served", "customer_served", 2000, False),
    ("first_strike", "strike_issued", 1, False),
    ("three_strikes", "strike_issued", 3, True),
    # The case
    ("first_pack", "pack_opened", 1, False),
    ("a_box_of_it", "pack_opened", 36, False),
    ("case_of_cases", "pack_opened", 216, False),
    ("still_ripping", "pack_opened", 500, True),
    ("first_grade_back", "card_graded", 1, False),
    ("graded_ten", "card_graded", 10, False),
    ("graded_fifty", "card_graded", 50, False),
    ("graded_two_hundred", "card_graded", 200, False),
    # The kitchen
    ("first_ticket", "order_taken", 1, False),
    ("first_plate", "order_completed", 1, False),
    ("fifty_plates", "order_completed", 50, False),
    ("three_hundred_plates", "order_completed", 300, False),
    ("thousand_plates", "order_completed", 1000, False),
    ("first_burnt_one", "order_failed", 1, False),
    ("the_bad_night", "order_failed", 25, True),
    # The library
    ("first_return", "component_check_resolved", 1, False),
    ("counted_a_hundred", "component_check_resolved", 100, False),
    ("counted_five_hundred", "component_check_resolved", 500, False),
    ("counted_two_thousand", "component_check_resolved", 2000, False),
    ("first_loan", "game_returned", 1, False),
    ("lending_library", "game_returned", 200, False),
    # The cat
    ("first_feed", "cat_fed", 1, False),
    ("fed_it_a_week", "cat_fed", 7, False),
    ("fed_it_a_season", "cat_fed", 90, False),
    ("cat_of_the_house", "cat_fed", 365, True),
    ("first_reaction", "cat_reacted", 1, False),
    ("the_cat_knows", "cat_reacted", 50, False),
    ("mouse_sighted", "pest_sighted", 1, False),
    ("infestation", "pest_sighted", 100, True),
    # Money, standing and the paperwork
    ("first_licence", "licence_granted", 1, False),
    ("licensed_to_trade", "licence_granted", 5, False),
    ("fully_papered", "licence_granted", 12, False),
    ("every_permission", "licence_granted", 25, True),
    ("first_hire", "staff_error_made", 1, True),
    ("delegated", "shift_started", 30, False),
    ("open_a_year", "shift_started", 365, True),
    # Trade
    ("first_trade_in", "trade_in_attempted", 1, False),
    ("buylist_regular", "trade_in_attempted", 100, False),
    ("first_delivery", "delivery_accepted", 1, False),
    ("hundred_deliveries", "delivery_accepted", 100, False),
    ("first_sale", "sale_attempted", 1, False),
    ("five_hundred_sales", "sale_attempted", 500, False),
    # The slow ones
    ("a_quiet_fortnight", "day_ended", 14, False),
    ("a_season", "day_ended", 90, False),
    ("half_a_year", "day_ended", 180, False),
    ("the_full_year", "day_ended", 365, True),
    ("reputation_noticed", "reputation_changed", 500, False),
    ("reputation_established", "reputation_changed", 5000, False),
]


def gen_npcs(written: dict) -> None:
    """Forty faces the ledger can remember. Most of them are exactly who they appear to
    be, which is the point: if long cons were common the mechanic would curdle."""
    rng = rng_for("npc")
    for index in range(40):
        role, arc, tells = NPC_SEEDS[index % len(NPC_SEEDS)]
        given = GIVEN_NAMES[index % len(GIVEN_NAMES)]
        # The second lap through the given names needs different surnames, or the
        # slugs collide and the cast is half the size it claims to be.
        surname = NPC_SURNAMES[(index * 7 + index // len(GIVEN_NAMES)) % len(NPC_SURNAMES)]
        slug = f"{given}_{surname}".lower()
        write(
            "npc",
            slug,
            {
                "id": f"base:{slug}",
                "type": "npc",
                "name": f"loc:npc.{slug}",
                "role": role,
                "age": rng.randint(19, 74),
                "first_appears_day": rng.choice([1, 1, 2, 3, 5, 8, 12, 20, 30]),
                "visit_weight": round(rng.uniform(0.4, 2.5), 2),
                # long_con is rare on purpose, and the seeds are weighted to keep it that way.
                "trust_arc": arc,
                "tells": tells,
                "notes": f"loc:npc.{slug}.notes",
                "tags": [role],
            },
            written,
        )


def gen_achievements(written: dict) -> None:
    for slug, event, count, hidden in ACHIEVEMENT_SEEDS:
        write(
            "achievement",
            slug,
            {
                "id": f"base:{slug}",
                "type": "achievement",
                "name": f"loc:achievement.{slug}",
                "description": f"loc:achievement.{slug}.description",
                "hidden": hidden,
                "condition": {"event": event, "count": count},
                "tags": ["hidden"] if hidden else [],
            },
            written,
        )


GIVEN_NAMES = [
    "Ada",
    "Bo",
    "Cleo",
    "Dev",
    "Esme",
    "Fen",
    "Gus",
    "Hana",
    "Ines",
    "Jo",
    "Kit",
    "Lev",
    "Mira",
    "Nils",
    "Ora",
    "Pax",
    "Quinn",
    "Rae",
    "Sol",
    "Tam",
]
NPC_SURNAMES = [
    "Abara",
    "Bhatt",
    "Calder",
    "Duarte",
    "Eze",
    "Fontaine",
    "Grover",
    "Haddad",
    "Ibori",
    "Jelinek",
    "Kowal",
    "Lindqvist",
    "Moreau",
    "Nakamura",
    "Osei",
    "Petrov",
    "Quaye",
    "Rosales",
    "Stavros",
    "Tsai",
]


GENERATORS = {
    "npc": gen_npcs,
    "achievement": gen_achievements,
    "product": gen_products,
    "recipe": gen_recipes,
    "licence": gen_licences,
    "tool": gen_tools,
    "supplier": gen_suppliers,
    "cat": gen_cats,
    "document_type": gen_document_types,
    "rule": gen_rules,
    "forgery_vector": gen_forgery_vectors,
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

    # Remove what this run no longer generates, so the tree is exactly what the
    # generator says it is. Hand-authored files are never touched.
    stale: list[str] = []
    for type_name in selected:
        for path in sorted((DEFINITIONS / type_name).glob("*.json")):
            relative = f"{type_name}/{path.name}"
            if relative in HAND_AUTHORED or relative in written:
                continue
            stale.append(relative)
            if not args.check:
                path.unlink()

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
    print(
        f"{len(written)} definition(s) generated; {verb} {len(changed)}; "
        f"{'would remove' if args.check else 'removed'} {len(stale)} stale"
    )
    if args.check and (changed or stale):
        for relative in (changed + stale)[:20]:
            print(f"  {relative}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
