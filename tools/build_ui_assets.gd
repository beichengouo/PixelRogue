extends SceneTree
## 生成 UI 用到的图片资源。
##
## 1) 钥匙图标：Kenney Desert Shooter Pack 的 Interface 图集 tile_0058（16x16）
##    放大 3 倍 -> assets/ui/icon_key.png（48x48）
## 2) 巫女立绘 / 头像：你放在 E:\素材 的两张 1536x1536 插画
##    · 先缩放（插画用 LANCZOS，比最近邻平滑）
##    · 再从四边做「连通区域抠底」把实色背景变透明
##      —— 只抠和画面边缘连通的部分，所以角色身上的白色衣服不会被误删
##    · 最后裁掉四周空白
##
## 用法：
##   "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" ^
##       --headless --path . --script res://tools/build_ui_assets.gd

const KEY_SRC := "E:/素材/2D素材/kenney_desert-shooter-pack_1.0/PNG/Interface/Tiles/tile_0058.png"
## 关闭按钮（红色 X）和方向箭头，也在同一张 Interface 图集里
const CLOSE_SRC := "E:/素材/2D素材/kenney_desert-shooter-pack_1.0/PNG/Interface/Tiles/tile_0072.png"
const PORTRAIT_SRC := "E:/素材/巫女立绘.png"
const AVATAR_SRC := "E:/素材/巫女头像.png"
## 地牢风格 9 宫格面板（Basement of a Thief 的 GUI 表，左上角那一块）
const PANEL_SRC := "E:/素材/PixelSRPG-Forge/PixelSRPG-Forge-main/Asset_Packs_素材套图/Basement of a Thief/Basement of a Thief/GUI.png"
const PANEL_RECT := Rect2i(7, 8, 65, 26)
const PANEL_LUM_MIN := 0.10
const PANEL_LUM_MAX := 0.85
## 同一块素材「重新上色」出几套 9 宫格：
##   名字 -> [暗部颜色, 亮部颜色, 是否反转明暗, 明暗曲线]
## 反转明暗 = 把「上左亮、下右暗」的凸起边框变成「上左暗、下右亮」的凹槽，
## 用来做背包格子那种「刻进木板里」的凹陷感。
## 明暗曲线 > 1 会把中间调压暗，凹槽内部更深、边缘高光更突出。
const PANEL_SETS := {
	## 圣洁风格：白 + 金，不再用木质/羊皮纸
	"panel_wood": ["ded6c8", "ffffff", false, 1.0],        # 面板外壳（接近纯白）
	"panel_parchment": ["eee6d6", "ffffff", false, 1.0],   # 内层面板（近白）
	"button_gold": ["b8891c", "ffe680", false, 1.0],       # 金色按钮
	"slot_inset": ["d8d2c6", "ffffff", true, 1.5],         # 凹槽格子（偏白的浅灰凹槽）
}

const OUT_DIR := "res://assets/ui/"
const CHAR_DIR := "res://assets/characters/"
const PREVIEW_DIR := "C:/Users/Administrator/Documents/Codex/2026-10-06/wo-xi/work/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHAR_DIR))
	DirAccess.make_dir_recursive_absolute(PREVIEW_DIR)
	_build_key()
	_build_close()
	_build_panel()
	_build_menu_option()
	_build_portrait(PORTRAIT_SRC, "witch_portrait.png", 700)
	_build_portrait(AVATAR_SRC, "witch_avatar.png", 512)
	quit(0)


func _build_panel() -> void:
	## 把素材里的木纹面板「灰度化后重新上色」成几套配色：
	## 边框的高光/阴影结构原样保留，只换颜色。
	if not FileAccess.file_exists(PANEL_SRC):
		printerr("[UI素材] 找不到面板素材：%s" % PANEL_SRC)
		return
	var img := Image.load_from_file(PANEL_SRC)
	if img == null:
		printerr("[UI素材] 面板读图失败")
		return
	img.convert(Image.FORMAT_RGBA8)
	var piece := img.get_region(PANEL_RECT)
	for name: String in PANEL_SETS:
		var spec: Array = PANEL_SETS[name]
		var dark := Color(str(spec[0]))
		var light := Color(str(spec[1]))
		var invert := bool(spec[2])
		var gamma := float(spec[3]) if spec.size() > 3 else 1.0
		var out: Image = piece.duplicate()
		for y in out.get_height():
			for x in out.get_width():
				var c: Color = out.get_pixel(x, y)
				if c.a <= 0.0:
					continue
				var lum := 0.30 * c.r + 0.59 * c.g + 0.11 * c.b
				var t := clampf((lum - PANEL_LUM_MIN) / (PANEL_LUM_MAX - PANEL_LUM_MIN), 0.0, 1.0)
				if invert:
					t = 1.0 - t
				if not is_equal_approx(gamma, 1.0):
					t = pow(t, gamma)
				var recolored: Color = dark.lerp(light, t)
				out.set_pixel(x, y, Color(recolored.r, recolored.g, recolored.b, c.a))
		out.resize(out.get_width() * 2, out.get_height() * 2, Image.INTERPOLATE_NEAREST)
		_save(out, ProjectSettings.globalize_path(OUT_DIR + name + ".png"))
		print("[UI素材] 9宫格 %s -> %s（%dx%d）" % [
			name, OUT_DIR + name + ".png", out.get_width(), out.get_height()])


func _build_key() -> void:
	if not FileAccess.file_exists(KEY_SRC):
		printerr("[UI素材] 找不到钥匙图：%s" % KEY_SRC)
		return
	var img := Image.load_from_file(KEY_SRC)
	img.convert(Image.FORMAT_RGBA8)
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	_save(img, ProjectSettings.globalize_path(OUT_DIR + "icon_key.png"))
	_save_preview(img, PREVIEW_DIR + "ui_key_preview.png")
	print("[UI素材] 钥匙图标 -> %s（%dx%d）" % [OUT_DIR + "icon_key.png", img.get_width(), img.get_height()])


func _build_close() -> void:
	if not FileAccess.file_exists(CLOSE_SRC):
		printerr("[UI素材] 找不到关闭按钮：%s" % CLOSE_SRC)
		return
	var img := Image.load_from_file(CLOSE_SRC)
	if img == null:
		printerr("[UI素材] 关闭按钮读图失败")
		return
	img.convert(Image.FORMAT_RGBA8)
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	_save(img, ProjectSettings.globalize_path(OUT_DIR + "icon_close.png"))
	print("[UI素材] 关闭按钮 -> %s（%dx%d）" % [
		OUT_DIR + "icon_close.png", img.get_width(), img.get_height()])


func _build_menu_option() -> void:
	## 菜单选项的底图：把「菜单UI」那张装饰边框缩到按钮尺寸，
	## 之后当 9 宫格用（四角不拉伸、中间拉伸），按钮变宽变高都不会把花纹拉变形。
	const SRC := "E:/素材/菜单UI.png"
	if not FileAccess.file_exists(SRC):
		printerr("[UI素材] 找不到菜单UI：%s" % SRC)
		return
	var img := Image.load_from_file(SRC)
	if img == null:
		printerr("[UI素材] 菜单UI 读图失败")
		return
	img.convert(Image.FORMAT_RGBA8)
	# 原图四周有一圈近黑底色（四角最厚，实测 82px），
	# 当 9 宫格时这圈会变成按钮外的黑边 —— 直接按 88px 裁掉四边。
	# 注意：这里**只裁不改色**，保留素材本来的样子。
	const CROP := 88
	if img.get_width() > CROP * 3 and img.get_height() > CROP * 3:
		img = img.get_region(Rect2i(
			CROP, CROP, img.get_width() - CROP * 2, img.get_height() - CROP * 2
		))
		print("[UI素材] 菜单UI 裁掉四周 %dpx 黑边 -> %dx%d" % [CROP, img.get_width(), img.get_height()])
	var target_w := 360
	var ratio := float(target_w) / float(img.get_width())
	img.resize(target_w, int(round(float(img.get_height()) * ratio)), Image.INTERPOLATE_LANCZOS)
	_save(img, ProjectSettings.globalize_path(OUT_DIR + "menu_option.png"))
	print("[UI素材] 菜单选项底图 -> %s（%dx%d）" % [
		OUT_DIR + "menu_option.png", img.get_width(), img.get_height()])


func _dark_margins(img: Image) -> Array:
	## 从四条边的中线往里扫，量出「近黑底色」的厚度。
	## 用中线扫是因为装饰花纹都在四边，中线一定穿过底色。
	var w := img.get_width()
	var h := img.get_height()
	var mid_y := h / 2
	var mid_x := w / 2
	var left := 0
	while left < w / 4 and _is_dark(img.get_pixel(left, mid_y)):
		left += 1
	var right := 0
	while right < w / 4 and _is_dark(img.get_pixel(w - 1 - right, mid_y)):
		right += 1
	var top := 0
	while top < h / 4 and _is_dark(img.get_pixel(mid_x, top)):
		top += 1
	var bottom := 0
	while bottom < h / 4 and _is_dark(img.get_pixel(mid_x, h - 1 - bottom)):
		bottom += 1
	return [left, right, top, bottom]


func _is_dark(c: Color) -> bool:
	return c.a > 0.05 and maxf(c.r, maxf(c.g, c.b)) < 0.24


func _build_portrait(src_path: String, out_name: String, target_height: int) -> void:
	## 约定：**只接受已经是透明背景的图**。
	## 不透明（也就是带实色底）的图一律不动、不抠，直接报错跳过 ——
	## 抠图交给你自己用工具做，我只负责缩放和裁边。
	if not FileAccess.file_exists(src_path):
		printerr("[UI素材] 找不到插画：%s" % src_path)
		return
	var img := Image.load_from_file(src_path)
	if img == null:
		printerr("[UI素材] 读图失败：%s" % src_path)
		return
	img.convert(Image.FORMAT_RGBA8)
	if not _has_transparency(img):
		printerr("[UI素材] ⚠ %s 不是透明背景（四角都不透明），已跳过。" % src_path.get_file())
		printerr("[UI素材]    请导出带 alpha 通道的 PNG 后重跑；我不会替你抠图。")
		return
	# 先缩小再抠底：1536x1536 全分辨率做连通填充太慢，缩小后结果一样
	var ratio := float(target_height) / float(img.get_height())
	img.resize(int(round(float(img.get_width()) * ratio)), target_height, Image.INTERPOLATE_LANCZOS)
	var box := _opaque_bounds(img)
	if box.size.x > 0 and box.size.y > 0:
		img = img.get_region(box)
	var out_path := ProjectSettings.globalize_path(CHAR_DIR + out_name)
	_save(img, out_path)
	_save_preview(img, PREVIEW_DIR + "preview_" + out_name)
	print("[UI素材] %s -> %s  尺寸 %dx%d（透明底，未做任何抠图）" % [
		src_path.get_file(), CHAR_DIR + out_name, img.get_width(), img.get_height()])


func _has_transparency(img: Image) -> bool:
	## 四角任意一个透明，就认为素材已经是透明底
	var w := img.get_width()
	var h := img.get_height()
	for point in [Vector2i(2, 2), Vector2i(w - 3, 2), Vector2i(2, h - 3), Vector2i(w - 3, h - 3)]:
		if img.get_pixel(point.x, point.y).a < 0.08:
			return true
	return false


func _opaque_bounds(img: Image) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in h:
		for x in w:
			if data[(y * w + x) * 4 + 3] <= 8:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i()
	# 留一点边距，别切到头发尖
	var pad := 4
	min_x = maxi(0, min_x - pad)
	min_y = maxi(0, min_y - pad)
	max_x = mini(w - 1, max_x + pad)
	max_y = mini(h - 1, max_y + pad)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _save(image: Image, abs_path: String) -> void:
	var err := image.save_png(abs_path)
	if err != OK:
		printerr("[UI素材] 保存失败 %s（错误码 %d）" % [abs_path, err])


func _save_preview(image: Image, abs_path: String) -> void:
	## 预览：把透明图叠在界面面板的深色底上，方便直接看效果
	var canvas := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	canvas.fill(Color("171b28"))
	canvas.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	_save(canvas, abs_path)
