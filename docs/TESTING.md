# 验收入口

使用与项目匹配的 Godot 4.7.2，先执行 headless editor import。规则、计分卡、存档和完整回合通过 `tests/run_tests.gd` 验证。界面通过 `tests/ui_smoke.gd` 和各 `*_test.gd` 验证。使用临时用户数据目录可以隔离测试设置与正式存档。

`tests/lan_process_test.gd` 是节点脚本，由 `python tools/test_lan_processes.py <Godot路径> 4` 启动四个进程并比较终局散列。`-- --playtest` 从主场景驱动窗口、练习、单人和四人整局，截图仅留在本地 build 目录。各阶段实测结果见 [开发记录](progress.md)。
