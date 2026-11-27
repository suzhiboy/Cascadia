# 潮痕群岛 · Tidetrace Isles

[English](README.md)

《潮痕群岛》是一款以潮间带调查为主题的数字策略桌游。从海岸市集选取六角岛块和动物，拼接生境，为招潮蟹、帽贝、弹涂鱼、燕鸥和水獭留下栖身之处。每位玩家调查 20 回合，每局从 20 张观察卡中为五个物种各选一张。

## 运行当前版本

下载 [Windows x64 ZIP](https://github.com/suzhiboy/Cascadia/releases/download/v1.2.0/TidetraceIsles-Windows-x64.zip)，完整解压后运行 `TidetraceIsles.exe`。请将同名的 PCK 文件保留在同一目录。桌面端最低窗口为 1280×720。

从源码运行时，在 Godot 4.7.2 中打开 `project.godot`，按 F5。自行打包请参照[导出说明](build/README.md)。

[Cascadia v1.1.0 发布页](https://github.com/suzhiboy/Cascadia/releases/tag/v1.1.0)保留早期 Windows 版本。

- **首回合练习**演示选组、旋转岛块、连接泥滩和安置弹涂鱼。练习独立运行，保留正式存档。
- **登岛调查**时，从市集选一组岛块与动物。岛块接在地图边缘，动物可以安置或放归。完成回合前可以调整或撤回试摆。Q/E 旋转，滚轮缩放，中键或 WASD 平移。游戏也支持键盘和手柄导航。
- **查看计分**时，可先在版图上比较试摆分差，再点观察卡操作交互图例。观察卡、各生境的最大连片、面积奖励和剩余自然标记共同决定终局分数。结算后可打开「调查轨迹」，查看每轮分数、各席最佳一步和终局地图。

## 游玩模式和存档

- 支持单人、同机 2–4 人。每席可选真人、简单电脑或标准电脑。桌面版还支持[局域网联机](docs/LAN_MULTIPLAYER.md)，2–4 人需使用相同版本。
- 每日挑战按本机日期固定起始海湾、观察卡、市集和抽取顺序，可重复挑战当日最佳。「调查记录」显示离线完成局数、各人数最高分、本版卡均分和每日最佳。
- 开始新的离线旅程或每日挑战都会覆盖共用的自动存档。当前对局存档为格式 3，局域网协议为 4。尝试读取不兼容的对局时会保留原文件。旧版《潮痕群岛》的调查记录可保留完成数、个人最佳和每日成绩，旧卡均分单独保存。
- 设置可切换简体中文和英语。存档与设置位于 Godot 的 `user://`，Windows 默认目录为 `%APPDATA%/Godot/app_userdata/潮痕群岛/`。

## 项目文档

- [地块目录](docs/TILES.md)与[观察卡规则](docs/RULE_INTERPRETATIONS.md)
- [计分平衡和模拟](docs/BALANCE.md)
- [导出说明](build/README.md)与[测试命令](docs/TESTING.md)
- [素材来源与署名](docs/SOURCES.md)
