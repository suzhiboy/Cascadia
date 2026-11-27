# Tidetrace Isles · 潮痕群岛

[简体中文](README.zh-CN.md)

Tidetrace Isles is a digital strategy board game about surveying a watercolor archipelago at low tide. Draft a hex tile and an animal from the shore market, connect habitats, and find homes for fiddler crabs, limpets, mudskippers, terns, and otters. Each survey lasts 20 turns per player and uses five observation cards from a set of twenty.

## Play the current edition

Open `project.godot` in Godot 4.7.2 and press F5. To make a Windows portable build, follow the [export instructions](build/README.md) and keep `TidetraceIsles.exe` and `TidetraceIsles.pck` together. The minimum desktop window is 1280×720.

The [published Cascadia v1.1.0 download](https://github.com/suzhiboy/Cascadia/releases/tag/v1.1.0) is the earlier Windows edition. Run or build the current source for Tidetrace Isles.

- **First-turn practice.** Learn to draft, rotate a tile, extend a mudflat, and place a mudskipper. Practice uses a separate session and leaves your autosave intact.
- **Survey your island.** Draft a market pair, place the tile, and settle or release the animal. Adjust or undo placements before confirming. Use Q/E to rotate, the wheel to zoom, and middle mouse or WASD to pan. The game also supports keyboard and controller navigation.
- **Read the map.** Try placements to see their score changes. Open an observation card to try its interactive example. At the end, your observation cards, largest connected habitats, area bonuses, and unused nature tokens add up to your score. Survey history shows round scores, each player's best move, and their final map.

## Modes and save data

- Play solo or share one device with up to four players. Each local seat can be human, Easy AI, or Standard AI. The desktop edition also supports [LAN play](docs/LAN_MULTIPLAYER.md) for two to four players on matching builds.
- The daily challenge uses a fixed starting bay, card set, market, and draw order for your local date. Field records track offline completions, best scores by seat count, card averages, and daily bests.
- Starting a new offline game or daily challenge replaces the shared autosave. The current edition uses save format 3 and LAN protocol 4. Opening an incompatible save leaves its file in place. Upgrading older Tidetrace Isles field records preserves completion totals, personal bests, and daily scores, and keeps old card averages separate.
- Switch between English and Simplified Chinese in Settings. The game stores saves and preferences in Godot's `user://` directory. On Windows, this defaults to `%APPDATA%/Godot/app_userdata/潮痕群岛/`.

## Project documentation

- [Tile catalog](docs/TILES.md) and [observation card rules](docs/RULE_INTERPRETATIONS.md)
- [Scoring and balance simulations](docs/BALANCE.md)
- [Export instructions](build/README.md) and [test commands](docs/TESTING.md)
- [Asset sources and credits](docs/SOURCES.md)
