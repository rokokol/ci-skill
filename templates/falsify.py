#!/usr/bin/env python3
"""Break each guard on purpose and require the tests to notice.

A passing suite proves the code works only if the suite would fail when it does
not. This harness edits one line of the implementation at a time, reruns the
tests, and reports a defect as SURVIVED when they still pass — meaning the
behaviour that line implements is not actually covered by anything.

    python3 tests/falsify.py            # every defect
    python3 tests/falsify.py mask       # only those whose name contains "mask"

Each edit is undone in a finally block, and the file contents are restored from
memory rather than from git, so an interrupted run cannot leave a mutated
working tree behind.

THIS FILE IS A TEMPLATE, AND COPYING IT PROVES NOTHING. The DEFECTS list below
is the part that carries knowledge of *this* repository, and the property that
makes the harness worth running is local: the copy must be falsified in its own
repo — break what it watches, see red, put it back. A harness that has only ever
printed "caught" may simply be matching nothing. Run it before trusting a green
suite, and add a defect for every guard you write.
"""

from __future__ import annotations

import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# >>> EXAMPLE: the files the defects edit, named once so the list below stays readable
IMPL = "src/thing.py"
OTHER = "src/other.py"
# <<<


@dataclass
class Defect:
    name: str
    find: str
    replace: str
    # What the defect does, in the terms whoever operates this would care about.
    # If the tests survive it, this sentence names what nobody checks.
    consequence: str
    file: str = IMPL


# >>> EXAMPLE: one entry per guard the code carries. `find` must match exactly once —
# the harness reports "stale" rather than guessing when it does not, which is how a
# defect list tells you it has drifted away from the code it describes. Prefer edits
# that neuter a behaviour (`if False:`, dropping a filter, widening a comparison) over
# edits that break syntax: a suite that fails on a SyntaxError has not noticed anything
DEFECTS = [
    Defect(
        name="escape/raw-text",
        find="return f\"<p>{html.escape(text)}</p>\"",
        replace="return f\"<p>{text}</p>\"",
        consequence="a label chosen maliciously becomes live HTML in the reader",
    ),
    Defect(
        name="counters/negative-window",
        find="    return new - old if new >= old else new",
        replace="    return new - old",
        consequence="a counter reset turns into a negative window instead of a fresh one",
    ),
    Defect(
        name="alerts/silent-absence",
        file=OTHER,
        find='    for name, reason in data.get("unreachable", []):',
        replace="    for name, reason in []:",
        consequence="something that did not answer reads as healthy and quiet",
    ),
]
# <<<


def run_suite() -> bool:
    result = subprocess.run(
        # >>> EXAMPLE: the repo's own suite, quiet, from the repo root
        [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-q"],
        # <<<
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def main() -> int:
    needle = sys.argv[1] if len(sys.argv) > 1 else ""
    originals = {file: (ROOT / file).read_text() for file in {d.file for d in DEFECTS}}

    # Falsification measures the distance between green and red. Starting red, there
    # is no distance to measure and every "caught" below would be meaningless
    if not run_suite():
        print("the suite is already red; falsification proves nothing here", file=sys.stderr)
        return 2

    survived = []
    for defect in DEFECTS:
        if needle and needle not in defect.name:
            continue
        original = originals[defect.file]
        path = ROOT / defect.file
        if original.count(defect.find) != 1:
            print(f"stale     {defect.name}: its find-pattern no longer matches exactly once")
            survived.append(defect)
            continue
        try:
            path.write_text(original.replace(defect.find, defect.replace))
            if run_suite():
                print(f"SURVIVED  {defect.name}: {defect.consequence}")
                survived.append(defect)
            else:
                print(f"caught    {defect.name}")
        finally:
            path.write_text(original)

    if survived:
        print(f"\n{len(survived)} defect(s) survived the tests.", file=sys.stderr)
        return 1
    print(
        f"\nall {len([d for d in DEFECTS if not needle or needle in d.name])} "
        "defects were caught by the tests."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
