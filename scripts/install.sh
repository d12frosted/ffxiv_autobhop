#!/usr/bin/env bash
#
# Install this plugin into a local XIV on Mac setup as a dalamud dev plugin.
#
# Useful while working on it: no release, no repository, no version bump, and with
# automatic reloading on you can install over a running game.
#
# Two things are easy to get wrong, and both fail with dalamud reporting that the
# path does not exist:
#
#   - the registered path must name the assembly, not the folder holding it.
#     Dalamud tests it with FileInfo.Exists, which is false for a directory.
#   - DevMode has to be on. Dev plugin locations are only scanned when it is.
#
# The build is copied under the XIV on Mac data directory rather than registered
# where it sits: XIV on Mac is sandboxed, so a path in your home directory may not
# be readable by the game at all.
#
# The game runs under wine, where / is mounted as Z:, so the registered path is the
# windows shaped one.
#
#   ./scripts/install.sh              build Release and install
#   ./scripts/install.sh --debug      build Debug instead
#   ./scripts/install.sh --no-build   install whatever is already built
#   ./scripts/install.sh --status     show what is built and what is installed
#   ./scripts/install.sh --uninstall  remove the registration and the copy
#
# Override the setup location with XOM_ROOT=/some/path.

set -euo pipefail

PLUGIN="autobhop"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XOM_ROOT="${XOM_ROOT:-$HOME/Library/Application Support/XIV on Mac}"

CONFIG="Release"
ACTION="install"
BUILD=1
FORCE=0

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

while [ $# -gt 0 ]; do
    case "$1" in
        --release) CONFIG="Release" ;;
        --debug) CONFIG="Debug" ;;
        --no-build) BUILD=0 ;;
        --status) ACTION="status" ;;
        --uninstall) ACTION="uninstall" ;;
        --force) FORCE=1 ;;
        -h|--help) awk 'NR>1 && !/^#/ {exit} NR>1 {sub(/^# ?/, ""); print}' "$0"; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

BUILD_DIR="$REPO_ROOT/$PLUGIN/bin/$CONFIG"
INSTALL_DIR="$XOM_ROOT/devPlugins/$PLUGIN"
DALAMUD_CONFIG="$XOM_ROOT/dalamudConfig.json"
BACKUP="$XOM_ROOT/dalamudConfig.json.autobhop-backup"

[ -d "$XOM_ROOT" ] || die "XIV on Mac setup not found at: $XOM_ROOT (set XOM_ROOT to override)"
[ -f "$DALAMUD_CONFIG" ] || die "no dalamud config at: $DALAMUD_CONFIG"

# / is mounted as Z: inside the wine prefix the game runs in
windows_path() { printf 'Z:%s' "$(printf '%s' "$1" | tr '/' '\\')"; }

# Dalamud holds its configuration in memory and writes the whole file out when the
# game exits, so anything edited underneath a running game is thrown away.
assert_game_stopped() {
    if pgrep -f "ffxiv_dx11" >/dev/null 2>&1; then
        [ "$FORCE" -eq 1 ] || die "FFXIV looks like it is running - quit the game first (or pass --force)"
        info "warning: FFXIV appears to be running, dalamud will overwrite this on exit"
    fi
}

config_tool() {
    python3 - "$DALAMUD_CONFIG" "$(windows_path "$INSTALL_DIR/$PLUGIN.dll")" "$1" <<'PYTHON'
import json
import pathlib
import sys

config_path, target, action = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
LIST_TYPE = (
    "System.Collections.Generic.List`1[[Dalamud.Configuration.DevPluginLocationSettings, Dalamud]],"
    " System.Private.CoreLib"
)
ENTRY_TYPE = "Dalamud.Configuration.DevPluginLocationSettings, Dalamud"
SETTINGS_TYPE = (
    "System.Collections.Generic.Dictionary`2[[System.String, System.Private.CoreLib],"
    "[Dalamud.Configuration.Internal.DevPluginSettings, Dalamud]], System.Private.CoreLib"
)
ENTRY_SETTINGS_TYPE = "Dalamud.Configuration.Internal.DevPluginSettings, Dalamud"

config = json.loads(config_path.read_text())
node = config.get("DevPluginLoadLocations")

if isinstance(node, dict):
    values = node.setdefault("$values", [])
elif isinstance(node, list):
    values = node
else:
    node = config["DevPluginLoadLocations"] = {"$type": LIST_TYPE, "$values": []}
    values = node["$values"]


def path_of(entry):
    return entry.get("Path", "").rstrip("\\") if isinstance(entry, dict) else ""


def is_target(entry):
    return path_of(entry) == target.rstrip("\\")


# Any earlier registration of this plugin, wherever it pointed. A stale entry means
# dalamud logs an error about a path that no longer matters on every startup.
def is_ours(entry):
    return "autobhop" in path_of(entry).lower()


def save():
    if isinstance(node, dict):
        node["$values"] = values
    else:
        config["DevPluginLoadLocations"] = values
    config_path.write_text(json.dumps(config, indent=2))


def registered_and_enabled():
    return config.get("DevMode") and any(
        is_target(entry) and entry.get("IsEnabled", True) for entry in values
    )


# Copying a new assembly over an already registered plugin touches no configuration,
# and dalamud picks it up on its own when automatic reloading is on. That is the
# difference between an install that can happen mid-session and one that has to wait.
if action == "needs-change":
    print("no" if registered_and_enabled() else "yes")
    sys.exit(0)

if action == "status":
    dev_mode = "" if config.get("DevMode") else ", but DevMode is off so it will be skipped"
    for entry in values:
        if is_target(entry):
            print(("enabled" if entry.get("IsEnabled", True) else "disabled") + dev_mode)
            break
    else:
        stale = sum(1 for entry in values if is_ours(entry))
        print(f"absent ({stale} stale entr{'y' if stale == 1 else 'ies'})" if stale else "absent")
    sys.exit(0)

if action == "add":
    stale = [entry for entry in values if is_ours(entry) and not is_target(entry)]
    values[:] = [entry for entry in values if entry not in stale]

    notes = []
    if stale:
        notes.append(f"cleared {len(stale)} stale")

    settings = config.setdefault("DevPluginSettings", {"$type": SETTINGS_TYPE})
    if isinstance(settings, dict) and target not in settings:
        settings[target] = {
            "$type": ENTRY_SETTINGS_TYPE,
            "StartOnBoot": True,
            "NotifyForErrors": True,
            "AutomaticReloading": True,
        }
        notes.append("enabled automatic reloading")
    if not config.get("DevMode"):
        config["DevMode"] = True
        notes.append("turned DevMode on")

    for entry in values:
        if is_target(entry):
            already = entry.get("IsEnabled", True) and not notes
            entry["IsEnabled"] = True
            save()
            print("already registered" if already else f"registered ({', '.join(notes)})" if notes else "registered")
            sys.exit(0)

    values.append({"$type": ENTRY_TYPE, "Path": target, "IsEnabled": True})
    save()
    print(f"registered ({', '.join(notes)})" if notes else "registered")
    sys.exit(0)

if action == "remove":
    remaining = [entry for entry in values if not is_ours(entry)]
    if len(remaining) == len(values):
        print("not registered")
        sys.exit(0)
    values[:] = remaining

    note = ""
    # Only give DevMode back if nothing else is relying on it.
    if not remaining and config.get("DevMode"):
        config["DevMode"] = False
        note = " (turned DevMode back off)"
    save()
    print("removed" + note)
PYTHON
}

backup_once() {
    if [ ! -f "$BACKUP" ]; then
        info "backing up dalamud config to $(basename "$BACKUP")"
        cp "$DALAMUD_CONFIG" "$BACKUP"
    fi
}

case "$ACTION" in
status)
    info "setup:      $XOM_ROOT"
    info "build dir:  $BUILD_DIR"
    if [ -f "$BUILD_DIR/$PLUGIN.dll" ]; then
        info "  built:    $(date -r "$BUILD_DIR/$PLUGIN.dll" '+%Y-%m-%d %H:%M')"
    else
        info "  built:    (nothing built yet)"
    fi
    if [ -f "$INSTALL_DIR/$PLUGIN.dll" ]; then
        info "  copied:   $(date -r "$INSTALL_DIR/$PLUGIN.dll" '+%Y-%m-%d %H:%M')"
    else
        info "  copied:   (nothing installed yet)"
    fi
    info "dev plugin: $(config_tool status)"
    info "  path:     $(windows_path "$INSTALL_DIR/$PLUGIN.dll")"
    ;;
install)
    needs_change="$(config_tool needs-change)"
    [ "$needs_change" = "no" ] || assert_game_stopped

    if [ "$BUILD" -eq 1 ]; then
        info "building $CONFIG..."
        dotnet build "$REPO_ROOT/$PLUGIN/$PLUGIN.csproj" -c "$CONFIG" -v q --nologo
    fi

    [ -f "$BUILD_DIR/$PLUGIN.dll" ] || die "no build output at $BUILD_DIR/$PLUGIN.dll"
    [ -f "$BUILD_DIR/$PLUGIN.json" ] || die "no manifest at $BUILD_DIR/$PLUGIN.json"

    info "installing -> $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    # clear first so files dropped between builds do not linger
    find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    cp -R "$BUILD_DIR"/. "$INSTALL_DIR/"

    if [ "$needs_change" = "no" ]; then
        info "dev plugin: already registered, left the config alone"
        info ""
        info "done. dalamud reloads the plugin on its own if automatic reloading is on."
        exit 0
    fi

    backup_once
    info "dev plugin: $(config_tool add)"
    info ""
    info "done. start the game, hold space, and use /autobhop to toggle."
    ;;
uninstall)
    assert_game_stopped
    backup_once
    info "dev plugin: $(config_tool remove)"
    [ -d "$INSTALL_DIR" ] && rm -rf "$INSTALL_DIR" && info "removed $INSTALL_DIR"
    ;;
esac
