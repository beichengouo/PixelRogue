extends SceneTree
## 酒馆素材：把 Kenney Tiny Dungeon 的 16x16 小图放大 2 倍（32x32）接到游戏里，
## 和商店的商人（npc_merchant.png，同样是 16x16 放大 2 倍）保持同一像素密度。
##   tile_0096           → tavern_npc.png（酒馆老板）
##   tile_0097 ~ 0100    → merc_1..4.png（特殊佣兵）
##   tile_0103 ~ 0107    → knife_1..5.png（佣兵丢的小刀）
##
## 用法：godot --headless --path . --script res://tools/build_tavern_assets.gd

const SRC := "E:/素材/2D素材/kenney_tiny-dungeon/Tiles/tile_%04d.png"
const OUT := "res://assets/characters/"
## 和商店的商人（16x16 放大 2 倍 = 32x32）保持一致，别再大一倍
const SCALE := 2


func _initialize() -> void:
	_save(96, "tavern_npc.png")
	for i in 4:
		_save(97 + i, "merc_%d.png" % (i + 1))
	for i in 5:
		_save(103 + i, "knife_%d.png" % (i + 1))
	quit(0)


func _save(tile: int, out_name: String) -> void:
	var img := Image.load_from_file(SRC % tile)
	if img == null:
		printerr("读不到 tile_%04d" % tile)
		return
	img.convert(Image.FORMAT_RGBA8)
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	var path := ProjectSettings.globalize_path(OUT + out_name)
	print("  %s ← tile_%04d  %dx%d  %s" % [
		out_name, tile, img.get_width(), img.get_height(), str(img.save_png(path))])

