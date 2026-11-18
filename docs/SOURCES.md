# 规则与素材来源

## 规则和固定组件

- AEG 官方基础规则书：https://www.alderac.com/wp-content/uploads/2025/04/Cascadia_BaseGame_Rulebook_Optimized.pdf
- 官方规则文本交叉核对：https://www.rulespal.com/cascadia/rulebook
- 20 张基础计分卡的实体照片交叉核对：https://www.geekyhobbies.com/cascadia-rules/
- 试玩版固定组件数据：https://cascadiagame.github.io/js/data.js
- 起始板块位置核对：https://cascadiagame.github.io/js/scripts.js

`data/tiles.json` 保存地形、动物、起始朝向这些组件事实，不复制上述网站的游戏实现。原数据的 desert/swamp/lake 分别映射为 prairie/wetland/river。ID 1–15 是五套起始板块，16–100 是 85 张基础地块。地块地形边和起始板块位置按原版结构核对。

## 原创绘图与声音

- `assets/art/wilderness.png`：内置 imagegen 生成的原创太平洋西北山林水彩插画。提示方向：黎明雪山、冷杉、蜿蜒河流、金色草地，温暖纸纹，留白，无文字。
- `assets/art/wildlife.png`：内置 imagegen 生成的原创五动物插画。五个等宽面板依次为熊、麋鹿、鲑鱼、鹰、狐狸，统一暖象牙底色和博物学水粉笔触，无文字。
- 五个 SVG 动物轮廓、地块图案、自然标记、纸质与木质组件效果由本工程绘制。中文、数值和规则标记由 Godot 实时绘制。
- `scripts/ui/sound.gd`：本工程合成的短促落子和结束音效，无外部音频文件。

`docs/reference/` 中的参考图仅作开发核对，不导出到游戏包。

## 字体与引擎

Noto Sans SC，Google Fonts / Noto 项目，SIL Open Font License 1.1。原始字体随工程提供，授权文本见 `assets/fonts/OFL.txt`。

来源：https://github.com/google/fonts/tree/main/ofl/notosanssc

Godot Engine 使用 MIT 许可证。Windows 包中附有引擎及其第三方组件许可证 `GODOT-LICENSES.txt`，来自 Godot 4.7.2 导出模板的运行时许可证信息。

Cascadia 原桌游的名称、规则及组件设计属于其各自权利人。本工程不是官方发行版本。

## 背景音乐

beyond_evergreen_sea_final.ogg：用户于 2026-11-17 提供的原始音频，未经转码。未另行确认作者或授权条款。

雨幕鸦语（assets/audio/rain_crow_whispers.mp3）：用户于 2026-11-18 提供的 Crow Calls over Rain （混音） (1)(1).mp3，重命名副本，未经转码，原文件保留。

Crow Calls over Rain（混音）（assets/audio/crow_calls_over_rain_mix.mp3）：用户于 2026-11-18 提供的 Crow_Calls_over_Rain_（混音）.mp3。与已收录的雨幕鸦语文件 SHA256 不同，作为第三首追加，未经转码，原文件保留。
