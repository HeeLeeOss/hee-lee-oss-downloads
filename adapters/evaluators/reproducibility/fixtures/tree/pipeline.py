"""Fixture pipeline: counts the words in data/words.txt.

Writes out/counts.csv (the result) and out/run-info.txt (a note with the time of the run, which differs
on every run and so is the task's one benign output). Uses only the standard library.
"""
import os
import time
from pathlib import Path

words = Path("data/words.txt").read_text(encoding="utf-8").split()
counts = {}
for word in words:
    counts[word] = counts.get(word, 0) + 1
Path("out").mkdir(exist_ok=True)
rows = ["word,count"] + [f"{word},{n}" for word, n in sorted(counts.items())]
Path("out/counts.csv").write_text("\n".join(rows) + "\n", encoding="utf-8")
seed = os.environ.get("HLO_SEED", "0")
Path("out/run-info.txt").write_text(f"seed={seed} finished={int(time.time())}\n", encoding="utf-8")
