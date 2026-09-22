#!/usr/bin/env python3
"""Read-only macOS process measurement. Use a release build and leave its UI untouched."""
import argparse
import json
import re
import subprocess
import time


def snapshot(pid):
    output = subprocess.check_output(
        ["ps", "-p", str(pid), "-o", "time=,rss="], text=True
    ).split()
    fields = [float(value) for value in output[0].split(":")]
    cpu_seconds = 0
    for value in fields:
        cpu_seconds = cpu_seconds * 60 + value
    return cpu_seconds, int(output[1])


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("pid", type=int)
parser.add_argument("--seconds", type=float, default=30)
parser.add_argument("--label", default="running, menu closed")
args = parser.parse_args()
if args.seconds <= 0:
    parser.error("--seconds must be positive")
cpu_before, _ = snapshot(args.pid)
started = time.monotonic()
time.sleep(args.seconds)
cpu_after, rss = snapshot(args.pid)
elapsed = time.monotonic() - started
memory = subprocess.check_output(["vmmap", "-summary", str(args.pid)], text=True)
footprint = re.search(r"Physical footprint:\s+([^\n]+)", memory)
peak = re.search(r"Physical footprint \(peak\):\s+([^\n]+)", memory)
print(json.dumps({
    "label": args.label,
    "pid": args.pid,
    "seconds": round(elapsed, 2),
    "cpu_percent_of_one_core": round(100 * (cpu_after - cpu_before) / elapsed, 3),
    "physical_footprint": footprint.group(1).strip() if footprint else None,
    "peak_footprint_since_launch": peak.group(1).strip() if peak else None,
    "resident_mib": round(rss / 1024, 2),
}, indent=2))
