"""Choose an existing compatible simulator; never install or normalize its UDID."""
import json
import os
import re
import subprocess
import sys
import uuid

family = sys.argv[1]
if family not in ("iPhone", "iPad", "Apple TV"):
    raise SystemExit("Unsupported simulator family")
platform = "tvOS" if family == "Apple TV" else "iOS"
sdk = "appletvsimulator" if platform == "tvOS" else "iphonesimulator"
sdk_version = tuple(map(int, subprocess.check_output(
    ["xcrun", "--sdk", sdk, "--show-sdk-version"], text=True).strip().split(".")))
devices = json.loads(subprocess.check_output(
    ["xcrun", "simctl", "list", "devices", "available", "--json"], text=True))["devices"]
candidates = []
for runtime, entries in devices.items():
    match = re.fullmatch(r"com[.]apple[.]CoreSimulator[.]SimRuntime[.]" + platform + r"-(\d+(?:-\d+)*)", runtime)
    if not match:
        continue
    version = tuple(map(int, match.group(1).split("-")))
    if version[0] < 26 or version > sdk_version:
        continue
    for device in entries:
        if device.get("isAvailable") and device["name"].startswith(family):
            identifier = device["udid"]
            if identifier.lower() != str(uuid.UUID(identifier)):
                raise SystemExit("Invalid simulator identifier")
            candidates.append((version, device["name"], identifier))
if not candidates:
    raise SystemExit(f"No existing compatible {family} simulator for SDK {sdk_version}")
preferred = {"iPhone": "iPhone 17 Pro", "iPad": "iPad (A16)", "Apple TV": "Apple TV"}[family]
version, name, identifier = sorted(
    candidates, key=lambda item: (item[0], item[1] == preferred, item[1]), reverse=True
)[0]
print(f"Using existing {name}, {platform} {version}: {identifier}")
with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
    output.write(f"udid={identifier}\n")
