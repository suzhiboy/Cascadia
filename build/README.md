# Export Tidetrace Isles

Install the export templates for Godot 4.7.2. Run these commands from the project root.

```powershell
godot --headless --editor --path . --import --quit
New-Item -ItemType Directory -Force build/windows,build/macos,build/linux,build/web | Out-Null
godot --headless --path . --export-release "Windows Desktop" build/windows/TidetraceIsles.exe
godot --headless --path . --export-release "macOS" build/macos/TidetraceIsles.zip
godot --headless --path . --export-release "Linux" build/linux/TidetraceIsles.x86_64
godot --headless --path . --export-release "Web" build/web/index.html
```

- **Windows and Linux.** Keep the executable next to its matching PCK. The playable package includes the font license, music credits, and engine notices. See [asset credits](../docs/SOURCES.md). Run `godot --headless --path . --script tools/write_licenses.gd` to write `build/windows/GODOT-LICENSES.txt`.
- **macOS.** The preset exports an app bundle inside a ZIP. For public distribution, the publisher handles signing and notarization.
- **Web.** Serve the entire output directory over HTTP(S). The Web build omits LAN play and release checks.

Release checks are optional. Set `updates/github_repository` in `project.godot` to the publisher's `owner/repo` to enable them. It is empty in the current source. Windows uses `TidetraceIsles-Windows-x64.zip` from a newer GitHub Release when its SHA-256 digest is available. The extracted package must contain `TidetraceIsles.exe` and `TidetraceIsles.pck` in the same directory. Linux and macOS open the release page.

Build output and playtest screenshots stay local. The [published Cascadia v1.1.0 release](https://github.com/suzhiboy/Cascadia/releases/tag/v1.1.0) contains the legacy Windows package. Its filenames and protocol belong to that build.
