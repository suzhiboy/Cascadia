# Cascadia implementation

Approved specification: the implementation plan in this chat, 2026-11-10.
Workspace is the explicitly requested empty Cascadia directory, not a Git checkout. No worktree needed.

1. Rules, fixed deck and all 20 scoring cards: complete. Headless rules suite: 725 checks, 0 failures.
2. Godot interface, board, art and persistence: complete. Main menu, setup, all card help, market/nature, reversible placement previews, hotseat boards, score highlights, settings and autosave implemented.
3. Headless integration and 720p visual checks: complete. Rendering/UI-signal test finished solo 20 turns and four-player 80 turns, save/resume, long-board centering and score highlights, 0 failures.
4. Windows export complete. Actual release runtime at 1080p completed solo 20 + hotseat 80 turns, 0 failures and exit 0. Native mouse menu/setup/start verified. Fresh review fixes complete; final packaging complete.

Regression findings verified RED→GREEN: JSON numeric restore and stable frontier/RNG; left/right habitat orientation; pending action-bar layout; integer font variation axis (480 weight); new-game camera reset; long-name/tied-winner results modal bounds.
Final review: original gpt-6-astra reviewer could not start (usage limit). Fresh gpt-6.1-sol review completed; 725 checks independently passed. No implementation was delegated.
Final: fixed menu Q/E changing a pending game, stale restored highlights, and active-player camera on market selection — UI regressions RED→GREEN.
Final: fixed repeated forced-refresh bag exhaustion — deterministic 21-token late-game regression RED→GREEN.
Final: fixed autosave replacement failure — blocked temporary write preserves previous valid save, RED→GREEN; regular repeated save/load also passes.
Final: fixed layout smoke test overwriting autosave — test now restores original file and reports explicit failure exit codes.
Final: fixed adjacent Hawk C sightline scoring — adjacent pair scores zero, RED→GREEN.
Final suite: 734 rule checks, 0 failures; UI smoke 0 failures.
Final: Ruling: retain printed-rulebook salmon, Elk D and Elk C scoring — user's designated rulebook remains authority; later designer variants can produce different scores. Documented in RULE_INTERPRETATIONS.md.
Final: Ruling: when consecutive wipes leave fewer than four tokens, release earlier held batches before withholding the current batch — paper rules do not describe bag exhaustion; continuation is necessary. Only extreme refresh sequences change distribution.
Final: Ruling: minimum hawk sightline distance is two hex steps — clarified definition fills an omission in the book; adjacent Hawk C pairs no longer earn points.
Out-of-scope review exclusions (networking, AI, expansions, family mode, challenges) match the user's explicit boundary. Release/visual QA was completed by the primary implementer; evidence is in docs/TESTING.md and build logs.

Rules authority: AEG base rulebook. Card values and illustrated formations cross-checked against photographed physical cards. Playtest deck is a data reference, not a rules implementation.
Original raster art generated with the built-in imagegen tool. Both selected originals copied into assets/art.

## 2026-11-25 · 阶段 0

- 删除与计分说明争用高度的弹性空白，在两种窗口尺寸下检查全部 20 张卡的图例是否完整落入滚动区。修复前 40/40 截断，修复后 40/40 通过。
- Windows 文件与产品版本统一为 1.1.0.0，并校验前三段与项目版本一致。两个旧值均触发失败，修复后两项通过。
- Godot 4.7.2 导入、734 项规则检查、全部独立测试、720p 渲染练习与单人 20 / 四人 80 回合通过。四进程联机终局散列一致。部分进程退出时引擎仍报告 ObjectDB 与资源占用。
