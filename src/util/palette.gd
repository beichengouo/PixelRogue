class_name Palette
extends RefCounted
## 全局配色。想换整体风格，改这一个文件就够了。

const BG_TOP := Color("1b1f2e")
const BG_BOTTOM := Color("0c0e15")
const BG_FAR := Color("232a3d")
const BG_NEAR := Color("2c3549")
const STAR := Color("4a5470")

const TERRAIN := Color("39435c")
const TERRAIN_TOP := Color("55658a")
const TERRAIN_EDGE := Color("151922")

const PLAYER_BODY := Color("2f7fd0")
const PLAYER_SKIN := Color("f4c89a")
const PLAYER_HAIR := Color("2a2f45")
const PLAYER_ACCENT := Color("ffd166")
const PLAYER_BLADE := Color("d8e6ff")

const WALKER := Color("e0576b")
const FLYER := Color("9b7bff")
const CHARGER := Color("e8944a")

const COIN := Color("ffcc4d")
const COIN_DARK := Color("c9932a")

const HP_OK := Color("5ad07a")
const HP_LOW := Color("e0576b")
const ALLY_HEALTH := Color("7ad86f")
const ENEMY_HEALTH := Color("e0576b")

const UI_PANEL := Color("171b28")
const UI_PANEL_BORDER := Color("3a4560")
const UI_TEXT := Color("e8edf7")
const UI_TEXT_DIM := Color("8b97b3")
const UI_ACCENT := Color("ffd166")
const UI_DANGER := Color("e0576b")
const UI_GOOD := Color("5ad07a")

## 木质 / 羊皮纸界面（背包、商店这些"实物面板"用的一套）
const WOOD_TEXT := Color("4a3418")
const WOOD_TEXT_DIM := Color("8a7040")
const WOOD_DARK := Color("e0d2b0")
const GOLD := Color("c8951a")

## 「写在浅色面板上的金色文字」专用色。
##
## 亮金（GOLD #c8951a / UI_ACCENT #ffd166）当**描边、图标、边框**很好看，
## 但直接当正文压在米色面板上时对比度只有 1.5~3:1 ——
## 画面自查连续三轮把"金币 0""流浪商人""稀有"评为"几乎看不清"。
## 所以正文改用这个压深过的暗金（在米色上约 4.6:1），
## 而边框/图标/发光继续用亮金，两套各管各的不冲突。
const INK_GOLD := Color("8a6414")
const INK_GOLD_DIM := Color("a98232")
const PARCHMENT_TEXT := Color("4a2f16")
const PARCHMENT_TEXT_DIM := Color("8a6a45")
const PARCHMENT_RULE := Color("c9a878")

const RARITY := [
	Color("8b97b3"), # 普通
	Color("72c997"), # 精良 · 与青绿品质艺术字一致
	Color("c07bff"), # 稀有
	Color("ffb703"), # 传说
]
