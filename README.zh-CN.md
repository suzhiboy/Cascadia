# 潮痕群岛 · Tidetrace Isles

[English](README.md)

在退潮时露出的群岛上扩建调查区，记录招潮蟹、帽贝、弹涂鱼、燕鸥和水獭。每种动物有四张观察卡，开局为每种动物选择一张。

## 开始调查

在 Godot 4.7.2 中导入 `project.godot`，按 F5 运行。Windows 便携包内的 `TidetraceIsles.exe` 与同名 PCK 应放在一起。最低窗口为 1280×720。

- 首回合练习演示旋转岛块、连接泥滩和记录弹涂鱼。练习不会写入正式存档。
- 在海岸市集选一组岛块与动物。将岛块接在地图边缘，用 Q/E 每次旋转 60°。动物可安置在有相应图案的空地块，也可放归。
- 试摆可调整或撤回，点击「完成回合」后才交接。滚轮缩放，中键拖动，顶部名字可切换调查区。
- 每人调查二十回合。观察卡、各生境的最大连片、面积奖励和剩余自然标记共同决定终局分数。
- 单人或同机 2–4 人可离线游玩。联机使用主机权威同步，所有人须使用相同版本。参见 [局域网说明](docs/LAN_MULTIPLAYER.md)。

## 单人目标与电脑玩家

每日挑战按本机日期生成相同的起始区、市集、牌堆和观察卡。可重复挑战当日最佳，开始挑战会使用正式离线自动存档位。「调查记录」显示完成局数、各人数最高分、各观察卡的实测均分和每日最佳。

同机局可逐席选择人类、简单电脑或普通电脑。普通电脑比较候选落子的计分收益，简单电脑在前四个方案中选一个。设置中的电脑快进可缩短步骤之间的等待。

## 数据与验证

自动存档和设置位于 Godot 的 `user://`。旧版调查记录与当前牌库不兼容。Windows 存档默认位于 `%APPDATA%/Godot/app_userdata/潮痕群岛/`。

牌库与起始区见 [地块目录](docs/TILES.md)，观察卡、计分示例和模拟结果见 [平衡记录](docs/BALANCE.md)。[素材来源](docs/SOURCES.md) 记录发行署名事项。

```powershell
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/run_tests.gd
godot --headless --path . --script tests/ui_smoke.gd --quit-after 60
godot --path . --resolution 1280x720 -- --playtest
```

设置中可切换简体中文和英语。终局选择「调查轨迹」查看各轮分数、最佳一步与各人的终局地图。

安装匹配版本的导出模板后，可使用 Windows Desktop、macOS、Linux 和 Web 四个预设。Web 导出目录需通过 HTTP(S) 提供。Web 隐藏联机和更新入口。Linux 与 macOS 发现新版后提供发布页按钮。发行者可在项目设置 `updates/github_repository` 填入自己的 `owner/repo`，留空会关闭更新检查。
