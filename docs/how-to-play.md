# How to play Dacian Scrolls

Dacia, year 101. Fifteen-metre giants from a 1953 séance book have landed. You have a party of
three, a narrator who will not stop talking, and a scroll with pages missing. A run is about
20 to 30 minutes.

## Getting the game

- **Browser (no install):** open the GitHub Pages link from the latest `slice-*` release. Chrome,
  Edge or Firefox on a desktop work best. Click the page once if the keyboard does nothing.
- **Desktop:** download the zip for your system from the GitHub release and unzip it.
  - Windows: run `DacianScrolls.exe`. SmartScreen may warn that the app is unsigned: "More info",
    then "Run anyway".
  - macOS: open `Dacian Scrolls.app`. It is not notarised, so the first time right-click it, choose
    "Open", then "Open" again (or System Settings > Privacy & Security > "Open Anyway").
  - Linux: `chmod +x DacianScrolls.x86_64 && ./DacianScrolls.x86_64`.

## Controls

| Where | Do this | Keys and mouse |
|---|---|---|
| Menus | Move, pick, go back | Arrows and Enter, or the mouse. Esc goes back. |
| Town and dungeons | Walk | Click a tile, or WASD / arrow keys one step at a time |
| | Talk to someone, search a chest, use an exit | Stand next to it and press E |
| | Pause menu | Esc |
| Dialogue | Show the whole line / skip | Click, Space or Enter |
| | Answer | 1 to 9, or click the answer |
| World map | Plan a trip | Click a place: it shows the cost in hours and food. Click again to go. |
| | Look around | WASD / arrows, move the mouse to the screen edge, or drag |
| | Party, Scroll | The buttons at the top right |
| Combat | Pick an action | 1 to 8 (the buttons at the bottom), then click a target tile |
| | Move or attack | Click a tile or an enemy |
| | Cancel the selected action | Esc or right-click |
| | End your turn | Space |
| | Fast animations on/off | Tab or F |
| | Pan the camera | WASD / arrows, or drag with the middle mouse button |
| | After the battle | Enter, Space or click to continue |
| Scroll | Read found pages, save and load | Click the tabs; Esc goes back |
| Party screen | Gear and abilities | Click gear to take it off, tick up to four abilities. Esc closes. |

Saving happens in the Scroll (three slots, plus an autosave). Every encounter on the road lets you
fight or flee, and some have a third way out. You do not get experience for killing things; you
get it for getting through. Gore level is in Settings and changes only what you see.

## Feedback

Tell us what broke, what confused you and what made you laugh (or should have).

- Post in the project thread, or
- open an issue at <https://github.com/MinuneIonel/Dacian-Scrolls/issues>.

Please include: browser or OS, what you were doing, and a screenshot if you can. Saves live in the
browser's storage (Web) or the Godot user folder (`%APPDATA%\Godot\app_userdata\Dacian Scrolls` on
Windows, `~/Library/Application Support/Godot/app_userdata/Dacian Scrolls` on macOS,
`~/.local/share/godot/app_userdata/Dacian Scrolls` on Linux); attaching one helps.
