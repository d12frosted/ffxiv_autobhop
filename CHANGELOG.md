# Changelog

## 1.1.0

Fork of spooee/ffxiv_autobhop, brought back to a Dalamud version that exists.

- Target Dalamud API 15. The original declared API 10, which the installer silently
  filters out, so it had become invisible rather than broken.
- Replace the user32 `SendMessage` keypress with a direct `ActionManager` call on general
  action 2 (Jump), and read the jump key from the game's key state instead of polling the
  OS. Everything stays in process, so it works the same under wine.
- Drop the ECommons submodule and `System.Windows.Forms`.
- Hold off while typing, flying, in an event or cutscene, and while zoning. The original
  only checked for flight and for the game window being in front.
- Wait for the landing before jumping again, rather than firing every frame the key is
  held.
- Add `/autobhop` to toggle without unloading.
- Split the decision into `autobhop.Core` and cover it with tests.
- Ship a plugin repository (`pluginmaster.json`) and a release workflow.

## 1.0.0.1

Original release by spooee.
