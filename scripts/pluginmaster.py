#!/usr/bin/env python3
"""Generate pluginmaster.json, the file Dalamud actually reads.

A dalamud custom repository is not a github repository. The URL you paste into
the settings has to serve this file: a JSON array of manifests, each carrying the
download links on top of the fields the plugin ships in its own manifest.

Everything except the links and the timestamp is copied straight out of
autobhop/autobhop.json, so there is one place to edit and no way for the two to
drift apart. Run this after bumping the version, and commit the result.

    ./scripts/pluginmaster.py            write pluginmaster.json
    ./scripts/pluginmaster.py --check    exit non-zero if it is out of date
"""

import json
import pathlib
import sys
import time

REPO = "https://github.com/d12frosted/ffxiv_autobhop"
# The download link deliberately names no version. Github resolves /latest/ on
# every request, so a new release needs no edit here at all.
DOWNLOAD = f"{REPO}/releases/latest/download/autobhop.zip"

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "autobhop" / "autobhop.json"
PLUGINMASTER = ROOT / "pluginmaster.json"


def build(last_update: int) -> list[dict]:
    entry = json.loads(MANIFEST.read_text())
    entry.update(
        {
            "IsHide": False,
            "IsTestingExclusive": False,
            "DownloadLinkInstall": DOWNLOAD,
            "DownloadLinkUpdate": DOWNLOAD,
            "DownloadLinkTesting": DOWNLOAD,
            "DownloadCount": 0,
            "LastUpdate": last_update,
        }
    )
    return [entry]


def main() -> int:
    check = "--check" in sys.argv

    # LastUpdate is only a display value in the installer, so on a check it is taken
    # from whatever is already committed. Otherwise every run would look like a change.
    last_update = int(time.time())
    if PLUGINMASTER.exists():
        existing = json.loads(PLUGINMASTER.read_text())
        if check and existing:
            last_update = existing[0].get("LastUpdate", last_update)

    rendered = json.dumps(build(last_update), indent=2) + "\n"

    if check:
        current = PLUGINMASTER.read_text() if PLUGINMASTER.exists() else ""
        if current != rendered:
            print("pluginmaster.json is out of date, run ./scripts/pluginmaster.py", file=sys.stderr)
            return 1
        print("pluginmaster.json is up to date")
        return 0

    PLUGINMASTER.write_text(rendered)
    print(f"wrote {PLUGINMASTER.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
