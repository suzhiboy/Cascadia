# Export directory

Install Godot 4.7.2 export templates, then run the Windows export from the project root.

```powershell
godot --headless --path . --export-release "Windows Desktop" build/windows/TidetraceIsles.exe
```

Other preset names are `macOS`, `Linux` and `Web`. Keep generated Web files together when serving the site, and the Linux executable next to its PCK. Ship the EXE, matching PCK, font license, music credits and engine notices together. Build products and playtest captures stay local.
