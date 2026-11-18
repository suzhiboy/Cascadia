# Cascadia

**English** · [简体中文](README.zh-CN.md)

An unofficial desktop adaptation of Cascadia, built with Godot 4.7.2, GDScript, and the Compatibility renderer. The in-game interface is in Simplified Chinese; solo and same-device play work offline.

## Getting Started

On Windows x64, run `build/windows/Cascadia.exe`. Keep `Cascadia.pck` in the same folder as the executable. No Godot installation or internet connection is required. The minimum window size is 1280×720; 1920×1080 is recommended.

To edit the game, import the root `project.godot` in Godot 4.7.2 and press F5 to run the project or F6 to run the current scene.

## How to Play

- **New to Cascadia?** Choose **First Turn Practice** (首回合练习) from the main menu. Follow the highlights to draft a pair, rotate and connect a wetland tile, place a salmon, and see how the turn scored. You can quit or replay without touching your regular save. The **Light Animations** (轻量动画) setting controls hint fades.
- Choose **Start a New Journey** (开始新的旅程) for solo play or 2–4 players taking turns on the same device. Enter player names before starting.
- Choose **LAN Multiplayer** (局域网联机) to host or join a 2–4 player room on the same local network. The default game port is UDP `35721`.
- Pick a scoring card (A–D) for each of the five wildlife species, use all A cards, or randomize the selection.
- Select a habitat tile and wildlife token pair from the market on the left, then click **Confirm Draft** (确认选取).
- Click an open space on the board to place the tile. Use Q/E or the on-screen buttons to rotate it in 60° increments.
- Choose **Place Wildlife** (放动物) and click a legal space marked with a white ring, or use **Release Wildlife** (放归动物) to return the token to the bag. You can place the tile and token in either order.
- Click again to adjust a preview, or choose **Undo Placement** (撤回摆放). Once both components are handled, click **Finish Turn** (完成回合).
- Scroll to zoom, drag with the middle mouse button to pan, or choose **Center Board** (居中版图) to reset the view. Use the player tabs at the top to inspect other boards.

Spend nature tokens to draft across different pairs or replace any number of wildlife tokens. You can spend more than one nature token per turn. If three market tokens show the same species, you may replace them for free once per turn. Four matching tokens are replaced automatically, repeating if needed. A refresh cannot be undone once the new tokens are revealed. In solo play, the bottom remaining component in each market column is also removed at the end of the turn before the columns are refilled from the top.

The game ends after 20 turns per player. Your final score includes wildlife points, the largest connected corridor of each of the five habitat types, habitat bonuses, and unused nature tokens. Click a wildlife or habitat score to highlight the contributing spaces in gold. The **Rules** (规则) menu and the wildlife cards on the right explain scoring in Chinese.

## Saves and Settings

Offline games autosave after drafting, placing pieces, refreshing the market, and confirming a turn. **Continue Last Journey** (继续上次旅程) restores both the game and its random state. Starting a new regular game overwrites the autosave.

The save file is at `%APPDATA%/Godot/app_userdata/卡斯卡迪亚之旅/autosave.json`. The same folder contains `settings.json`, which stores audio, fullscreen, and accessibility preferences. Press Esc to open settings during a game or close a dialog.

## Project Layout

- `scripts/core/`: Game state, component definitions, hex coordinates, scoring, and saves.
- `scripts/ui/`: Menus, market, board, scoring highlights, and audio.
- `data/tiles.json`: Definitions for 85 base habitat tiles and five three-hex starter tiles.
- `assets/`: Bundled fonts, original illustrations, icons, and audio.
- `tests/`: Headless rules tests, UI regression tests, and rendered end-to-end playtests.
- [Sources and credits](docs/SOURCES.md): Rules, component references, and asset sources.

## Testing and Export

Run these commands from the project root. Replace `godot` with the path to your Godot 4.7.2 executable if needed.

```powershell
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/run_tests.gd
godot --headless --path . --script tests/ui_smoke.gd --quit-after 60
godot --headless --path . --script tests/tutorial_test.gd
godot --path . --resolution 1280x720 -- --playtest
godot --headless --path . --export-release "Windows Desktop" build/windows/Cascadia.exe
```

The rendered playtest completes the first-turn practice, 20 solo turns, and 80 turns in a four-player game. It checks save restoration, player switching, layout, and endgame scoring, and writes screenshots to `build/screenshots`. It backs up and restores any existing autosave. You can also run the exported executable with `-- --playtest`; screenshots then appear in a `screenshots` folder next to the executable. The rules tests cover full games for one to four players. See the [test records](docs/TESTING.md) for details.

LAN play uses host-authoritative synchronization. Guests have up to 120 seconds to reconnect after a disconnect; if the host leaves, the room ends. See the [LAN multiplayer guide](docs/LAN_MULTIPLAYER.md) for setup and troubleshooting. The game does not include public internet relays, AI opponents, expansions, the family variant, challenges, or achievements.

This is an unofficial recreation with original artwork, not scanned board-game cards. Where the printed rules and later designer clarifications differ, this project follows the documented rulebook interpretation. See [rule interpretations](docs/RULE_INTERPRETATIONS.md) for examples such as branching salmon runs and Elk D.

## Playability Features

- The LAN lobby shows seats, names, and readiness. If the host changes the scoring cards, guests must ready up again. Everyone must be ready before the game can start.
- The placement preview displays the score change for wildlife, habitats, current habitat bonuses, and any new nature tokens. It compares the preview to the committed board without applying the move or advancing random draws. Nature tokens already spent while drafting are not deducted again.
- Scoring diagrams are interactive: click a token to remove it and an empty space to restore it, or click **Reset Example** (重置图例). Changes affect only the example.
- While waiting in a LAN match, you can inspect other boards, open scoring cards, or press Tab to check scores. Remote updates do not force you away from the board you are viewing.
- Settings include light animations, larger text, wildlife names on hover, and habitat text labels. Preferences are saved locally.
- LAN protocol version 2 requires the host and guests to use compatible builds; older versions cannot join.

## Background Music

Music plays across the menus, the game, and the results screen. The playlist loops with a ten-second pause between tracks, including when it returns to the first track. It includes *Beyond Evergreen Sea*, *雨幕鸦语*, and *Crow Calls over Rain* (Mix).

Music and sound effects have separate volume controls. Music defaults to 35%; set it to zero to mute it. Your settings are saved when you exit.

To add music, place OGG or MP3 files in `assets/audio/`, add their preload paths to `TRACKS` and their names to `TITLES` in `scripts/ui/music.gd`, then import and re-export in Godot. The bundled game does not need access to the original audio files.
