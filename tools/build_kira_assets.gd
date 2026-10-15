extends SceneTree
## 把 kira 的精灵条处理成游戏可用的图集。
##
## 处理三件事：
##   1. 4 倍降采样（256 -> 64 每格），角色约 48px 高，正好 1.33 格
##   2. 按动画挑帧：待机/走/跑/死亡用全部帧；攻击和受伤帧数太多（86/77），
##      自动截取「动作最剧烈」的一段，否则播完要好几秒，和游戏节奏对不上
##   3. 输出成横向一条，帧数 = 宽度 / 64
##
## 用法：
##   "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" ^
##       --headless --path . --script res://tools/build_kira_assets.gd

const SRC := "E:/素材/2D素材/kira/"   # kira 目前已不用于主角，需要时可重新跑
const OUT_DIR := "res://assets/characters/"
const SHEET_CELL := 256
const DOWNSCALE := 4              # 256 / 4 = 64
const OUT_CELL := SHEET_CELL / DOWNSCALE

## 动画 -> [源文件名, 取帧数(0=全部), 说明]
const ANIMS := {
	"idle":   ["spr_kira_idle_strip24.png", 0],
	"walk":   ["spr_kira_walk_strip24.png", 0],
	"run":    ["spr_kira_run_strip16.png", 0],
	"jump":   ["spr_kira_jump_strip80.png", 20],
	"attack": ["spr_kira_hit_strip86.png", 18],
	"hurt":   ["spr_kira_hurt_strip77.png", 12],
	"death":  ["spr_kira_death_strip64.png", 0],
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for anim: String in ANIMS:
		_build(anim, String(ANIMS[anim][0]), int(ANIMS[anim][1]))
	quit(0)


func _build(anim: String, file: String, wanted: int) -> void:
	var img := Image.load_from_file(SRC + file)
	if img == null:
		printerr("  读取失败：%s" % file)
		return
	var total := img.get_width() / SHEET_CELL

	# 每帧的内容宽度，用来找「动作最剧烈」的一段
	var widths := PackedFloat32Array()
	widths.resize(total)
	for i in total:
		var region := img.get_region(Rect2i(i * SHEET_CELL, 0, SHEET_CELL, SHEET_CELL))
		widths[i] = float(region.get_used_rect().size.x)

	var start := 0
	var count := total
	if wanted > 0 and wanted < total:
		count = wanted
		# 用滑动窗口找内容变化最大的位置（相邻帧宽度差之和）
		var best_score := -1.0
		for s in range(0, total - count + 1):
			var score := 0.0
			for k in range(s + 1, s + count):
				score += absf(widths[k] - widths[k - 1])
			if score > best_score:
				best_score = score
				start = s

	var strip := Image.create(OUT_CELL * count, OUT_CELL, false, Image.FORMAT_RGBA8)
	for i in count:
		var region := img.get_region(Rect2i((start + i) * SHEET_CELL, 0, SHEET_CELL, SHEET_CELL))
		# 高精度原图降采样用双线性，比直接丢像素干净
		region.resize(OUT_CELL, OUT_CELL, Image.INTERPOLATE_BILINEAR)
		strip.blit_rect(region, Rect2i(0, 0, OUT_CELL, OUT_CELL), Vector2i(i * OUT_CELL, 0))

	var path := OUT_DIR + "kira_" + anim + ".png"
	var err := strip.save_png(ProjectSettings.globalize_path(path))
	print("  %-7s 源 %2d 帧 -> 取第 %d..%d 帧（共 %d 帧，单帧 %dx%d）-> %s（%d）"
		% [anim, total, start, start + count - 1, count, OUT_CELL, OUT_CELL, path, err])
