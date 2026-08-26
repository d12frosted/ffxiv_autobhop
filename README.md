# autobhop

Hold the jump key and keep jumping.

FFXIV only jumps on the press, not on the hold, so a held space bar gets you exactly
one hop. This watches for the landing and jumps again.

Fork of [spooee/ffxiv_autobhop](https://github.com/spooee/ffxiv_autobhop), which stopped
at Dalamud API 10 in November 2024. Dalamud hides plugins whose API level does not match
the running version, with no error and no entry in the list, so the original quietly
disappeared from the installer rather than breaking loudly.

## Install

Add this to `/xlsettings` -> Experimental -> Custom Plugin Repositories:

```
https://raw.githubusercontent.com/d12frosted/ffxiv_autobhop/main/pluginmaster.json
```

Save and close, then install `autobhop` from the plugin installer.

## Use

Hold space. That is the whole plugin.

`/autobhop` toggles it off and on, `/autobhop on` and `/autobhop off` are explicit.

It stays quiet while you are typing, flying, in a cutscene or an event, or zoning, and
while the game window is not focused.

## What changed from the original

The original sent `WM_KEYDOWN` and `WM_KEYUP` to the game window through user32, by way
of ECommons and `System.Windows.Forms`. That works on Windows and is a coin toss under
wine, where XIV on Mac and XIVLauncher.Core players live: it depends on the game reading
movement from the window message queue rather than from raw input.

This version asks the client directly instead. It reads the jump key from the game's own
key state, and jumps by calling general action 2 through `ActionManager`. Nothing leaves
the process, so it behaves the same on Windows and under wine. ECommons, the submodule,
and WinForms are all gone with it.

The "should I jump this frame" decision lives in `autobhop.Core` as a pure function over
a snapshot of booleans, so the rules are covered by tests that need no game at all.

## Build

```
dotnet build autobhop/autobhop.csproj -c Release
```

Dalamud is found automatically in XIVLauncher's, XIV on Mac's, or XIVLauncher.Core's dev
directory. Set `DALAMUD_HOME` to override.

```
dotnet test autobhop.Tests/autobhop.Tests.csproj
./scripts/install.sh          # install as a dalamud dev plugin (XIV on Mac)
```

## Release

Bump `AssemblyVersion` in `autobhop/autobhop.json`, run `./scripts/pluginmaster.py`,
commit, then push a `v*` tag. The workflow builds, tests, zips and publishes the release.
`pluginmaster.json` points at `releases/latest/download`, so it needs no edit per release
beyond the version.

## License

AGPL-3.0-or-later, same as the original.
