# Tidetrace Isles · 潮痕群岛

[简体中文](README.zh-CN.md)

Survey an intertidal archipelago over twenty turns. Draft a tile and an animal, extend a shore, and build habitat for fiddler crabs, limpets, mudskippers, terns and otters. Five field cards score each survey, chosen from twenty original observations.

## Play

Open `project.godot` in Godot 4.7.2 and press F5. A Windows export runs from `TidetraceIsles.exe` alongside its PCK. The minimum window is 1280×720. The guided first turn is separate from your autosave.

Choose a market pair, then place the tile and settle or release its animal in either order. Q/E rotate the tile. The wheel zooms and the middle mouse button pans. Confirm to finish a turn. Solo and local games for two to four players work offline. LAN games use an authoritative host and require matching protocol versions.

Field observations, connected habitats, area bonuses and unused nature tokens determine the final score. [Deck design](docs/TILES.md), [cards and simulation](docs/BALANCE.md), and [asset credits](docs/SOURCES.md) document the edition.

## Build and verify

Import with the matching editor and install its export templates. Use the export panel or `godot --headless --export-release "Windows Desktop" build/windows/TidetraceIsles.exe`. The optional project setting `updates/github_repository` accepts the publisher's GitHub owner/repo. An empty value disables update requests.

Run `tests/run_tests.gd` and the individual test scripts with Godot's headless script runner. Start the rendered practice, solo and four-seat acceptance run with `godot --path . --resolution 1280x720 -- --playtest`. Use `tools/test_lan_processes.py` for the multi-process network test. Saves and preferences live in Godot's per-game user directory.
