extends SceneTree
## 生成三个 Boss 的待机图集（横向条，帧大小按 Boss 分别指定）：
##   boss_king.png  骨架剑士（2D Pixel Dungeon 图集，32x32 帧）
##   boss_mage.png  机械术士（E:\素材\2D素材\boss2 精灵表，64x64 帧）
##   boss_tide.png  巨树精（E:\素材\2D素材\树精模型\Large_Treants，64x64 帧）
##
## 用法：godot --headless --path . --script res://tools/build_boss_assets.gd

const OUT_DIR := "res://assets/characters/"
## 骨架剑士：图集里 16x16 的小人，放大 2 倍 → 32x32
const KING_SRC := "E:/素材/2D素材/1892ab477ce615ac/2D Pixel Dungeon Asset Pack/Character_animation/monsters_idle/skeleton2/v1/skeleton2_v1_%d.png"
const KING_FRAME := 32
## 机械术士（boss2）：整张精灵表，90x90 一帧，取前 8 帧
const MAGE_SHEET := "E:/素材/2D素材/boss2/Machine_guy_sprite_sheet.png"
const MAGE_SRC_FRAME := 90
const MAGE_FRAMES := 8
const FRAME_64 := 64
## 巨树精：12 张 256x256 的独立帧
const TREANT_DIR := "E:/素材/2D素材/树精模型/Large_Treants/Large_Treant_%02d.png"
const TREANT_FRAMES := 8
## 小树精（普通怪素材）
const SMALL_TREANT := "E:/素材/2D素材/树精模型/Treant_%02d.png"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build_king()
	_build_mage()
	_build_tide()
	_build_treant_monster()
	quit(0)


func _save(frames: Array, out_name: String, frame_size: int) -> void:
	if frames.is_empty():
		printerr("没有可用帧：%s" % out_name)
		return
	var strip := Image.create(frame_size * frames.size(), frame_size, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	for i in frames.size():
		strip.blit_rect(frames[i], Rect2i(0, 0, frame_size, frame_size), Vector2i(i * frame_size, 0))
	var path := ProjectSettings.globalize_path(OUT_DIR + out_name)
	print("  %s  %d 帧 %dx%d  → %s" % [out_name, frames.size(), frame_size, frame_size, str(strip.save_png(path))])


func _fit(img: Image, frame_size: int) -> Image:
	## 等比缩放到 frame_size 见方（像素画用最近邻，避免糊）
	img.convert(Image.FORMAT_RGBA8)
	var scale := float(frame_size) / float(maxi(img.get_width(), img.get_height()))
	var w := maxi(1, int(round(float(img.get_width()) * scale)))
	var h := maxi(1, int(round(float(img.get_height()) * scale)))
	img.resize(w, h, Image.INTERPOLATE_NEAREST)
	var canvas := Image.create(frame_size, frame_size, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	canvas.blit_rect(img, Rect2i(0, 0, w, h),
		Vector2i((frame_size - w) / 2, frame_size - h))     # 底部对齐：脚踩地
	return canvas


func _build_king() -> void:
	var frames: Array = []
	for i in range(1, 5):
		var img := Image.load_from_file(KING_SRC % i)
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		img.resize(16 * 2, 16 * 2, Image.INTERPOLATE_NEAREST)
		frames.append(img)
	_save(frames, "boss_king.png", KING_FRAME)


func _build_mage() -> void:
	var sheet := Image.load_from_file(MAGE_SHEET)
	if sheet == null:
		printerr("读不到 boss2 精灵表")
		return
	sheet.convert(Image.FORMAT_RGBA8)
	var frames: Array = []
	for i in mini(MAGE_FRAMES, sheet.get_width() / MAGE_SRC_FRAME):
		var cell := sheet.get_region(Rect2i(i * MAGE_SRC_FRAME, 0, MAGE_SRC_FRAME, MAGE_SRC_FRAME))
		frames.append(_fit(cell, FRAME_64))
	_save(frames, "boss_mage.png", FRAME_64)


func _build_tide() -> void:
	var frames: Array = []
	for i in TREANT_FRAMES:
		var img := Image.load_from_file(TREANT_DIR % i)
		if img == null:
			continue
		frames.append(_fit(img, FRAME_64))
	_save(frames, "boss_tide.png", FRAME_64)


func _build_treant_monster() -> void:
	## 小树精（普通怪）：用同一套树精素材的小尺寸版，32x32 帧、12 帧待机
	var frames: Array = []
	for i in 12:
		var img := Image.load_from_file(SMALL_TREANT % i)
		if img == null:
			continue
		frames.append(_fit(img, 64))
	_save(frames, "monster_treant.png", 64)



