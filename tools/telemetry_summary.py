#!/usr/bin/env python3
"""Summarise a bot sweep, and answer the balance questions from data rather than opinion.

The questions this is built to answer are the ones reasoning cannot: is the kitchen worth
opening, is an act too long, does anybody ever buy the expensive tool, does any player
count stall. Everything here is local; telemetry never leaves the machine.

Usage:
    python3 tools/telemetry_summary.py reports/bot/<file>.json
    python3 tools/telemetry_summary.py           # the most recent sweep
"""

from __future__ import annotations

import json
import statistics
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
REPORT_DIR = REPO_ROOT / "reports" / "bot"
# The spec's pace requirement: no player count should finish more than this far from the
# reference, or co-op is quietly a different game from solo.
PACE_TOLERANCE = 0.15


def latest_report() -> Path | None:
    reports = sorted(REPORT_DIR.glob("*.json"))
    return reports[-1] if reports else None


def net_worth(run: dict) -> float:
    """Cash plus both kinds of cardboard.

    Leaving stock out would make opening a box look like it created value, when what it
    did was move value from the shelf into the case and lose some of it in the process.
    """
    return float(run["money"]) + float(run["case_value"]) + float(run.get("stock_value", 0.0))


def report_sealed(runs: list[dict]) -> None:
    """The one number the design promises to print whether or not it flatters anyone.

    A return ratio above 1.0 across a sweep does not mean the bot got lucky; it means the
    pull tables pay more than the shelf does, and the gamble has become the correct way
    to run a card shop.
    """
    ledgers = [run.get("sealed") or {} for run in runs]
    ripped = sum(int(ledger.get("units_ripped", 0)) for ledger in ledgers)
    if ripped == 0:
        return
    forgone = sum(float(ledger.get("retail_forgone", 0.0)) for ledger in ledgers)
    realised = sum(float(ledger.get("realised", 0.0)) for ledger in ledgers)
    unsold = sum(float(ledger.get("unsold_value", 0.0)) for ledger in ledgers)
    sold_sealed = sum(int(ledger.get("units_sold_sealed", 0)) for ledger in ledgers)
    ratio = (realised + unsold) / forgone if forgone else 0.0

    print("\nsealed product")
    print(f"  opened          {ripped:>6} unit(s) worth {forgone:>9.0f} on the shelf")
    print(f"  sold sealed     {sold_sealed:>6} unit(s)")
    print(
        f"  came back       {realised + unsold:>9.0f}  ({ratio:.0%} of what they would have sold for)"
    )
    if ratio >= 1.0:
        print("  note: opening stock is paying better than selling it -- the pull tables are wrong")


def summarise(data: dict) -> int:
    runs: list[dict] = data.get("runs", [])
    if not runs:
        print("no runs in this report", file=sys.stderr)
        return 2

    policy = data.get("policy", "balanced")
    print(f"{len(runs)} run(s) as `{policy}`, {data.get('failures', 0)} needing attention\n")

    print("by player count")
    by_players: dict[int, list[dict]] = {}
    for run in runs:
        by_players.setdefault(int(run["players"]), []).append(run)
    paces: dict[int, float] = {}
    for players in sorted(by_players):
        group = by_players[players]
        net = statistics.mean(net_worth(r) for r in group)
        reputation = statistics.mean(float(r["reputation"]) for r in group)
        licences = statistics.mean(float(r["licences"]) for r in group)
        paces[players] = licences
        print(
            f"  {players}p  net {net:>9.0f}   reputation {reputation:>6.2f}   "
            f"licences {licences:>4.1f}   soft-locks {sum(int(r['soft_lock_ticks']) > 0 for r in group)}"
        )

    print("\nby preset")
    by_preset: dict[str, list[dict]] = {}
    for run in runs:
        by_preset.setdefault(str(run["preset"]), []).append(run)
    for preset in sorted(by_preset):
        group = by_preset[preset]
        net = statistics.mean(net_worth(r) for r in group)
        insolvent = sum(1 for r in group if r["insolvent"])
        print(f"  {preset:<9} net {net:>9.0f}   insolvent {insolvent}/{len(group)}")

    print("\nverdicts")
    verdicts: dict[str, int] = {}
    for run in runs:
        for name, count in (run.get("verdicts") or {}).items():
            verdicts[name] = verdicts.get(name, 0) + int(count)
    total_verdicts = sum(verdicts.values()) or 1
    for name, count in sorted(verdicts.items(), key=lambda pair: -pair[1]):
        print(f"  {name:<12} {count:>6}  ({count / total_verdicts:.0%})")
    # Partial is meant to be the most-used verdict in skilled play. The bot is not
    # skilled, but a zero here across a whole sweep means the option is not reachable.
    if "partial" not in verdicts:
        print("  note: no partial verdicts at all -- check that item-scoped rules can fire")

    # Outcome codes come from Encounter.Outcome; naming them here keeps the report
    # readable without the reader holding the enum in their head.
    outcome_names = {
        "0": "correct",
        "1": "approved something bad",
        "2": "turned away an honest customer",
        "3": "declined rather than guess",
        "4": "missed an escalation",
    }
    outcomes: dict[str, int] = {}
    for run in runs:
        for code, count in (run.get("outcomes") or {}).items():
            outcomes[code] = outcomes.get(code, 0) + int(count)
    if outcomes:
        print("\noutcomes")
        total_outcomes = sum(outcomes.values()) or 1
        for code, count in sorted(outcomes.items(), key=lambda pair: -pair[1]):
            label = outcome_names.get(code, f"outcome {code}")
            print(f"  {label:<32} {count:>6}  ({count / total_outcomes:.0%})")

    report_sealed(runs)

    reasons: dict[str, float] = {}
    for run in runs:
        for reason, amount in (run.get("reputation_by_reason") or {}).items():
            reasons[reason] = reasons.get(reason, 0.0) + float(amount)
    if reasons:
        print("\nreputation, by reason")
        for reason, amount in sorted(reasons.items(), key=lambda pair: pair[1]):
            print(f"  {reason:<24} {amount:>9.1f}")

    print("\nproblems")
    problems = 0
    for run in runs:
        if int(run["soft_lock_ticks"]) > 0:
            print(
                f"  SOFT LOCK  {run['preset']} {run['players']}p seed {run['seed']}: "
                f"{run['soft_lock_ticks']} tick(s) with work nobody could reach"
            )
            problems += 1
        if run["insolvent"]:
            print(f"  INSOLVENT  {run['preset']} {run['players']}p seed {run['seed']}")
            problems += 1

    if len(paces) > 1:
        reference = paces.get(3) or statistics.mean(paces.values())
        for players, pace in paces.items():
            if reference > 0 and abs(pace - reference) / reference > PACE_TOLERANCE:
                print(
                    f"  PACE       {players}p reached {pace:.1f} licences against "
                    f"{reference:.1f} at the design centre"
                )
                problems += 1

    if problems == 0:
        print("  none")
    return 1 if problems else 0


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else latest_report()
    if path is None or not path.is_file():
        print("error: no sweep report found; run tools/nightly_bot.sh", file=sys.stderr)
        return 2
    print(f"{path}\n")
    return summarise(json.loads(path.read_text(encoding="utf-8")))


if __name__ == "__main__":
    raise SystemExit(main())
