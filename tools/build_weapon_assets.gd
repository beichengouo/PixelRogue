extends SceneTree
## 从 Kenney「Desert Shooter Pack」里抽出武器贴图，放大 2 倍放进 assets/weapons/。
##
## 原图是 24x24 的俯视武器（横向、枪口朝右），放大到 48x48 后
## 和本作角色（约 64 像素高）比例协调。用 NEAREST 放大，像素块保持方块。
##
## 授权：Kenney Desert Shooter Pack，CC0（可商用、无需署名）。
##
## 用法：
##   "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" ^
##       --headless --path . --script res://tools/build_weapon_assets.gd

const SRC_DIR := "E:/素材/2D素材/kenney_desert-shooter-pack_1.0/PNG/Weapons/Tiles/"
const OUT_DIR := "res://assets/weapons/"
const SCALE := 2

## 输出名 -> 原图 tile 编号（编号是识图 + 逐像素比对确认的）
const WEAPONS := {
	"gun_pistol": "0001",      # 手枪
	"gun_smg": "0002",         # 冲锋枪
	"gun_sniper": "0003",      # 狙击枪
	"gun_rifle": "0004",       # 步枪
	"gun_shotgun": "0006",     # 霰弹枪
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ok := 0
	for name: String in WEAPONS:
		var src := SRC_DIR + "tile_%s.png" % WEAPONS[name]
		if not FileAccess.file_exists(src):
			printerr("[武器素材] 找不到 %s" % src)
			continue
		var img := Image.load_from_file(src)
		if img == null:
			printerr("[武器素材] 读图失败 %s" % src)
			continue
		img.convert(Image.FORMAT_RGBA8)
		img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		var out := ProjectSettings.globalize_path(OUT_DIR + name + ".png")
		if img.save_png(out) != OK:
			printerr("[武器素材] 保存失败 %s" % out)
			continue
		ok += 1
		print("[武器素材] %s <- tile_%s  (%dx%d)" % [name, WEAPONS[name], img.get_width(), img.get_height()])
	print("[武器素材] 完成 %d / %d" % [ok, WEAPONS.size()])
	quit(0)
