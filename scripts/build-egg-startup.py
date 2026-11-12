#!/usr/bin/env python3
"""Write egg-startup.sh into the "startup" command of egg-java-build-runner.json.

Run after every change to egg-startup.sh:  python3 scripts/build-egg-startup.py
Comment lines at the top of egg-startup.sh are dropped. The JSON keeps the panel export
format (4-space indent, escaped slashes, no newline at the end).
"""
import json
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parent.parent
lines = (root / "egg-startup.sh").read_text(encoding="utf-8").splitlines()
while lines and lines[0].startswith("#"):
    lines.pop(0)
startup = "\n".join(lines).strip()

if "{{" in startup:
    sys.exit("egg-startup.sh must not contain two opening curly braces in a row")

egg_file = root / "egg-java-build-runner.json"
egg = json.loads(egg_file.read_text(encoding="utf-8"))
egg["startup"] = startup
egg_file.write_text(json.dumps(egg, indent=4).replace("/", "\\/"), encoding="utf-8")
print(f"startup updated ({len(startup)} characters)")
