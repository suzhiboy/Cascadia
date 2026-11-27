# 验收入口

使用 Godot 4.7.2，在仓库根目录执行。运行界面和整局测试前，可将用户数据目录指向临时位置，与正式存档隔离。在 Windows 上可为测试进程单独设置 `APPDATA`。

```powershell
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/run_tests.gd
godot --headless --path . --script tests/ui_smoke.gd
python tools/test_lan_processes.py "C:\path\to\godot_console.exe" 4
godot --path . --resolution 1280x720 -- --playtest
```

- 规则套件覆盖计分卡、存档和完整回合。界面冒烟检查和其余独立 `tests/*_test.gd` 脚本可通过 `--headless --script` 逐个运行。
- 联机脚本启动四个本机进程，比较终局散列。请将示例中的可执行文件路径替换为实际路径，Windows 可使用 Godot 的控制台可执行文件。`tests/lan_process_test.gd` 由联机脚本通过主场景启动。
- `--playtest` 驱动可渲染的主场景，完成首回合练习、20 回合单人局、80 回合同机四人局和固定计分场景。源码运行的截图保存在 `build/screenshots/`，从导出包运行时截图保存在可执行文件同目录的 `screenshots/`。

已有窗口尺寸和各阶段结果见[开发记录](progress.md)，计分模拟命令见[平衡记录](BALANCE.md)。
