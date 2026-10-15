extends SceneTree
## 把「Wispstrike 完整法术包」的逐帧图拼成横向图集，放进 assets/fx/。
##
## 为什么自己拼：本作的 OneShotFX 统一吃「横向一条、每帧等宽」的图集，
## 自己按帧文件拼最稳，不用猜素材包给的 sheet 是怎么排的。
##
## 用法：
##   "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" ^
##       --headless --path . --script res://tools/build_skill_fx.gd

const SRC := "E:/素材/技能/Wispstrike-Free-Complete-Spell-v1.1/Wispstrike-Free-Complete-Spell-v1.1/frames/wispstrike/"
const OUT_DIR := "res://assets/fx/"
## 要拼的动画：输出名 -> 源目录
const ANIMS := {
	"skill_cast": "cast",
	"skill_impact": "impact",
	"skill_flight": "flight",
	"skill_fade": "fade",
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for name: String in ANIMS:
		_build(name, str(ANIMS[name]))
	quit(0)


func _build(out_name: String, folder: String) -> void:
	var dir_path := SRC + folder
	var dir := DirAccess.open(dir_path)
	if dir == null:
		printerr("[技能特效] 找不到目录：%s" % dir_path)
		return
	var files: Array[String] = []
	for file in dir.get_files():
		if file.ends_with(".png"):
			files.append(file)
	files.sort()
	if files.is_empty():
		printerr("[技能特效] %s 里没有 png" % folder)
		return
	var first := Image.load_from_file(dir_path + "/" + files[0])
	if first == null:
		printerr("[技能特效] 读图失败：%s" % files[0])
		return
	var fw := first.get_width()
	var fh := first.get_height()
	var strip := Image.create(fw * files.size(), fh, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	for i in files.size():
		var frame := Image.load_from_file(dir_path + "/" + files[i])
		if frame == null:
			continue
		frame.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(frame, Rect2i(0, 0, fw, fh), Vector2i(i * fw, 0))
	var out_path := ProjectSettings.globalize_path(OUT_DIR + out_name + ".png")
	if strip.save_png(out_path) != OK:
		printerr("[技能特效] 保存失败：%s" % out_path)
		return
	print("[技能特效] %s -> %s（%d 帧，每帧 %dx%d）" % [folder, out_name + ".png", files.size(), fw, fh])
