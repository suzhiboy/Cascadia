# Windows Builds

Download `Cascadia-Windows-x64.zip` from the [latest GitHub release](https://github.com/suzhiboy/Cascadia/releases/latest). Extract the ZIP and run `Cascadia.exe`. Keep `Cascadia.pck` beside the executable.

本目录只追踪构建说明。请在 [GitHub Releases](https://github.com/suzhiboy/Cascadia/releases/latest) 下载 Windows x64 压缩包，解压后运行 `Cascadia.exe`，并保留同目录的 `Cascadia.pck`。

## Build Locally

From the repository root, with Godot 4.7.2 and its Windows export templates installed:

```powershell
godot --headless --editor --path . --import --quit
New-Item -ItemType Directory -Force build/windows | Out-Null
godot --headless --path . --export-release "Windows Desktop" build/windows/Cascadia.exe
```

Generated binaries, ZIP files, logs, and screenshots are intentionally ignored by Git.
