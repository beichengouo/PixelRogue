extends SceneTree
## 把主角和怪物素材处理成游戏能直接用的图集。
##
## 处理三件事：
##   1. 主角精灵表被放大了 10 倍（实测），先缩回原生分辨率，否则在游戏里再缩小会毁掉像素
##   2. 按所有动画的公共范围统一裁剪，保证各动画之间不抖动、脚底对齐
##   3. 每个动画拼成一条横向图集（帧数 = 宽度 / 单帧宽）
##
## 用法：
##   "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" ^
##       --headless --path . --script res://tools/build_character_assets.gd

const MONSTER_SRC := "E:/素材/2D素材/1892ab477ce615ac/2D Pixel Dungeon Asset Pack/Character_animation/monsters_idle/"
const OUT_DIR := "res://assets/characters/"

## 怪物：来源目录 → 输出名（取 v1 配色的 4 帧待机动画）
const MONSTERS := {
	"skeleton": "skeleton1",
	"skull": "skull",
	"vampire": "vampire",
	"skeleton2": "skeleton2",
}
const MONSTER_CELL := 16
const MONSTER_SCALE := 2         # 放大 2 倍，和地形（2 倍显示）的像素大小一致

## Tiny Dungeon 的人形角色（编号 96-100 是全身立绘那一行），用于替换主角形象
const TINY_DUNGEON_SHEET := "E:/素材/2D素材/kenney_tiny-dungeon/Tilemap/tilemap_packed.png"
const TINY_DUNGEON_COLUMNS := 12
const PLAYER_CANDIDATES: Array[int] = [96, 97, 98, 99, 100]
## 商店商人的立绘（84 号：戴尖帽的老法师，最像商人）
const NPC_TILE := 84

## 女巫 Eleonore（当前主角）：原生 64x64，角色约 46x49，不需要缩放
const WITCH_DIR := "E:/素材/2D素材/4dd1bef00696066f/EleonoreAndJoanna/Sprites/Eleonore/Idle/"
const WITCH_FRAMES := 9


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build_monsters()
	_build_player_candidates()
	_build_npc()
	_build_witch()
	_build_weapon_placeholder()
	quit(0)


func _build_witch() -> void:
	## 女巫只有待机动画（9 帧），没有走/跳/攻击帧，
	## 所以移动和攻击靠程序化位移 + 火球表现（见 player.gd）。
	print("========== 主角：女巫 Eleonore ==========")
	var cell := 64
	var strip := Image.create(cell * WITCH_FRAMES, cell, false, Image.FORMAT_RGBA8)
	var placed := 0
	for i in range(1, WITCH_FRAMES + 1):
		var img := Image.load_from_file(WITCH_DIR + "Idle%d.png" % i)
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(img, Rect2i(0, 0, cell, cell), Vector2i(placed * cell, 0))
		placed += 1
	var path := OUT_DIR + "witch_idle.png"
	var err := strip.save_png(ProjectSettings.globalize_path(path))
	print("  待机 %d 帧 %dx%d -> %s（%d）" % [placed, cell, cell, path, err])


func _build_npc() -> void:
	print("========== 商店商人 ==========")
	var sheet := Image.load_from_file(TINY_DUNGEON_SHEET)
	if sheet == null:
		printerr("  读取失败：%s" % TINY_DUNGEON_SHEET)
		return
	var col := NPC_TILE % TINY_DUNGEON_COLUMNS
	var row := NPC_TILE / TINY_DUNGEON_COLUMNS
	var tile := sheet.get_region(Rect2i(col * 16, row * 16, 16, 16))
	tile.resize(32, 32, Image.INTERPOLATE_NEAREST)
	var path := OUT_DIR + "npc_merchant.png"
	tile.save_png(ProjectSettings.globalize_path(path))
	print("  编号 %d（%dx%d 放大 2 倍）-> %s" % [NPC_TILE, 32, 32, path])


func _build_player_candidates() -> void:
	## 从 Tiny Dungeon 里抠出人形角色，放大 2 倍（和地形/怪物同一像素密度）。
	## 用哪一个由 CharacterSprites.PLAYER_TEXTURE 决定。
	print("========== 主角候选（Tiny Dungeon 人形角色）==========")
	var sheet := Image.load_from_file(TINY_DUNGEON_SHEET)
	if sheet == null:
		printerr("  读取失败：%s" % TINY_DUNGEON_SHEET)
		return
	var out_size := 16 * 2
	for index: int in PLAYER_CANDIDATES:
		var col := index % TINY_DUNGEON_COLUMNS
		var row := index / TINY_DUNGEON_COLUMNS
		var tile := sheet.get_region(Rect2i(col * 16, row * 16, 16, 16))
		var used := tile.get_used_rect()
		tile.resize(out_size, out_size, Image.INTERPOLATE_NEAREST)
		var path := OUT_DIR + "player_%d.png" % index
		tile.save_png(ProjectSettings.globalize_path(path))
		print("  编号 %-3d 内容范围 %s（%dx%d）-> %s"
			% [index, str(used), used.size.x, used.size.y, path])


func _build_weapon_placeholder() -> void:
	## 占位武器：一把简单的像素剑，用来验证「武器独立挂在手上」这套机制。
	## 以后有正式武器素材，把同样的图放进 assets/characters/ 再改道具表里的路径就行。
	## 按 2 倍尺寸生成，和地形/怪物/主角的像素密度保持一致
	var img := Image.create(40, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(8, 38):
		for dy in 2:
			img.set_pixel(x, 6 + dy, Color("d8e6ff") if dy == 0 else Color("9fb6d8"))
	for dy in 2:
		img.set_pixel(38, 6 + dy, Color("ffffff"))
	for y in range(2, 14):
		for dx in 2:
			img.set_pixel(8 + dx, y, Color("ffd166"))
	for x in range(0, 8):
		for dy in 2:
			img.set_pixel(x, 6 + dy, Color("8a6240") if dy == 0 else Color("6b4a2f"))
	var path := OUT_DIR + "weapon_sword.png"
	img.save_png(ProjectSettings.globalize_path(path))
	print("  占位武器 -> %s" % path)


func _build_monsters() -> void:
	print("========== 怪物 ==========")
	var out_size := MONSTER_CELL * MONSTER_SCALE
	for out_name: String in MONSTERS:
		var dir_path: String = MONSTER_SRC + String(MONSTERS[out_name]) + "/v1"
		var dir := DirAccess.open(dir_path)
		if dir == null:
			printerr("  打不开：%s" % dir_path)
			continue
		var files := dir.get_files()
		files.sort()
		var strip := Image.create(out_size * files.size(), out_size, false, Image.FORMAT_RGBA8)
		for i in files.size():
			var img := Image.load_from_file(dir_path + "/" + files[i])
			if img == null:
				continue
			img.resize(out_size, out_size, Image.INTERPOLATE_NEAREST)
			strip.blit_rect(img, Rect2i(0, 0, out_size, out_size), Vector2i(i * out_size, 0))
		var path := OUT_DIR + "monster_" + out_name + ".png"
		var err := strip.save_png(ProjectSettings.globalize_path(path))
		print("  %-10s %d 帧 -> %s（%d）" % [out_name, files.size(), path, err])
