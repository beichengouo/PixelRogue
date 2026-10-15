class_name UiFactory
extends RefCounted
## 代码构建 UI 的小工具 + 全局主题（含中文字体）。

## 中文字体候选。Godot 自带字体不含汉字，不设置的话所有中文都是方块。
## 用 SystemFont 直接调用系统已装字体，不需要把字体文件打包进项目。
## 优先用用户素材目录中的全体字体，标题与按钮由 GameFonts 分配：
##   assets/fonts/AllSeto.ttf
## 想换字体：把新的 .ttf 丢进 assets/fonts/，改下面 GAME_FONT 一行即可；
## 文件不存在时自动回退到系统字体，不会出现方块字。
const GAME_FONT := "res://assets/fonts/AllSeto.ttf"

const FONT_CANDIDATES := [
	"Microsoft YaHei UI",
	"Microsoft YaHei",
	"Source Han Sans SC",
	"Noto Sans CJK SC",
	"SimHei",
	"sans-serif",
]

## 像素风 9 宫格面板（由 tools/build_ui_assets.gd 从素材重新上色生成）
const PANEL_TEX := "res://assets/ui/panel_wood.png"        # 木质外壳
const PARCHMENT_TEX := "res://assets/ui/panel_parchment.png"  # 羊皮纸（详情面板）
const GOLD_TEX := "res://assets/ui/button_gold.png"        # 金色按钮
const INSET_TEX := "res://assets/ui/slot_inset.png"        # 凹槽格子
## 菜单选项底图（把「菜单UI」那张装饰边框缩成按钮尺寸后当 9 宫格用）
const MENU_OPTION_TEX := "res://assets/ui/menu_option.png"
## 小按钮底图（来自「按钮」素材包：68 = 凸起普通态、67 = 凹陷按下态，金色）
const SMALL_BTN_NORMAL := "res://assets/ui/buttons/68.png"
const SMALL_BTN_PRESSED := "res://assets/ui/buttons/67.png"
## 关闭按钮图标（背包标题栏、天赋树窗口共用同一张）
const ICON_CLOSE := "res://assets/ui/icon_close.png"
const PANEL_MARGIN := 10

## ---------------- 自绘按钮配色（不再用素材包里的按钮图）----------------
## 之前那套「按钮」素材是暗金色 + 木质纹理，和整体白 + 金的圣洁风不搭，
## 所以按钮改成代码自绘：奶油白底 + 金描边，配 Tween 动画（悬停浮起 / 按下回弹）。
const BTN_FILL := Color("fffdf8")
const BTN_FILL_HOVER := Color("ffffff")
const BTN_FILL_PRESS := Color("f1e4cc")
const BTN_FILL_OFF := Color("efeae0")
const BTN_BORDER := Color("d8ae4a")
const BTN_BORDER_HOVER := Color("f3cb66")
const BTN_BORDER_OFF := Color("cfc6b8")
const BTN_TEXT := Color("4a2f16")
## 禁用态的文字色：原来是 #9a9188，压在 #efeae0 上只有约 2.4:1，
## 画面自查时的评价是"看起来像坏了"而不是"被禁用"。压深到约 3.6:1。
const BTN_TEXT_OFF := Color("7d766c")
const BTN_PRIMARY_FILL := Color("f8e0a2")
const BTN_PRIMARY_FILL_HOVER := Color("ffedbe")
const BTN_PRIMARY_FILL_PRESS := Color("e9cd87")
## 主菜单 / 暂停菜单专用的「深色玻璃 + 金线」皮肤。
## 以前这里是一块米白色实心板（#fffdf8），用户明确说过不要米白底 ——
## 现在改成半透明深底：底下的背景画能透出来，文字靠描边保证在亮背景上也读得清。
const MENU_PLATE := Color("141b2b")
const MENU_LINE := Color("d8ae4a")
const MENU_LINE_HOVER := Color("ffd980")
const MENU_LINE_OFF := Color("8f8880")
const MENU_TEXT := Color("f7ecd0")
const MENU_TEXT_HOVER := Color("fff6d8")
const MENU_TEXT_OFF := Color("b3aca0")
## 主菜单按钮换了「亮金」底图之后专用的一组字色：深棕字 + 浅色描边。
## （旧的 MENU_TEXT 是浅奶油色，配深色玻璃底用的，压亮金底会糊成一片。）
const MENU_TEXT_ON_GOLD := Color("3f2a10")
const MENU_TEXT_ON_GOLD_HOVER := Color("2a1a06")
## 按钮左右内边距：以前左右各 20，右边的箭头几乎是贴着金边画的，现在给足呼吸空间
const MENU_SIDE_PAD := 30.0
## AI 画的花饰鎏金按钮三态底图（本地 ComfyUI 生成，见 work/comfy）
const AI_BTN_NORMAL := "res://assets/ui_drawn/menu_btn_normal.png"
const AI_BTN_HOVER := "res://assets/ui_drawn/menu_btn_hover.png"
const AI_BTN_PRESSED := "res://assets/ui_drawn/menu_btn_pressed.png"
## ---------------- AI 画的「白金」皮肤全套（本地 ComfyUI，见 work/comfy）----------------
## 出图流程：我手绘扁平 SVG 底稿 → img2img(denoise 0.72) + ControlNet Tile(0.75)
## 让模型只负责材质和笔触、形状不跑偏 → 再分块放大到游戏里要用的分辨率。
## 4 帧状态**不是**分别画的（那样四张结构会各自漂移），而是拿同一张底图在渲染
## 阶段加不同光照做出来的，所以四帧的结构完全一致，只是明暗/辉光不同。
## 生成脚本：work/comfy/mk_frames.py；重新出图的完整流程见那个文件顶部注释。
const AI_ACTION_FRAMES := [
	"res://assets/ui_drawn/ai_action_1.png",   # 常态
	"res://assets/ui_drawn/ai_action_2.png",   # 悬停（亮 + 金色辉光）
	"res://assets/ui_drawn/ai_action_3.png",   # 按下（压暗 + 内凹）
	"res://assets/ui_drawn/ai_action_4.png",   # 回弹
]
const AI_SLOT_FRAMES := [
	"res://assets/ui_drawn/ai_slot_1.png",
	"res://assets/ui_drawn/ai_slot_2.png",
	"res://assets/ui_drawn/ai_slot_3.png",
	"res://assets/ui_drawn/ai_slot_4.png",
]
const AI_PANEL_FRAMES := [
	"res://assets/ui_drawn/ai_panel_1.png",
	"res://assets/ui_drawn/ai_panel_2.png",
	"res://assets/ui_drawn/ai_panel_3.png",
	"res://assets/ui_drawn/ai_panel_4.png",
]
## 面板九宫格边距：底图是 2048x1400 的 2K 素材（NoobAI 出图 + RealESRGAN 放大），
## 金框 + 角花大约占 112 像素。九宫格边距必须跟着底图分辨率等比走，
## 不然换了大图之后角花只切到一半，边会被拉糊。
## 这个值必须小于「最小面板尺寸 / 2」，否则小面板会被挤变形。
const AI_PANEL_MARGIN := 112
## 小面板（背包右侧详情栏这类 300x400 的竖长条）专用贴图。
## 为什么要单独一张：大面板的角花有 112 像素，铺到 300 宽的面板上两个角就吃掉
## 224 像素，中间只剩一条缝 —— 画面自查里被读成"边框不完整 / 被切掉"。
## 小图是细边框 + 小角饰，九宫格边距只要 48。
const AI_PANEL_SMALL := "res://assets/ui_drawn/ai_panel_small.png"
const AI_PANEL_SMALL_MARGIN := 48


## 素材存在性只查一次就够（每个按钮都去 ResourceLoader.exists 四遍没必要）
static var _ai_ready_cache := {}


static func _ai_ready(frames: Array) -> bool:
	var key := str(frames[0])
	if _ai_ready_cache.has(key):
		return bool(_ai_ready_cache[key])
	var ok := true
	for p in frames:
		if not ResourceLoader.exists(str(p)):
			ok = false
			break
	_ai_ready_cache[key] = ok
	return ok


static func _plate_style(
	path: String, tint := Color.WHITE, pad_side := 20.0, pad_v := 6.0
) -> StyleBoxTexture:
	## 整张拉伸的贴图样式（动作按钮 / 格子用）。
	## 和 _tex_button_style 的区别只有内边距会随控件尺寸变 —— 这两个尺寸
	## 是分开的参数，方便大按钮和小按钮各用一套留白。
	var style := StyleBoxTexture.new()
	style.texture = load(path)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.modulate_color = tint
	style.content_margin_left = pad_side
	style.content_margin_right = pad_side
	style.content_margin_top = pad_v
	style.content_margin_bottom = pad_v
	return style


static func _panel_style(tint: Color, content: float, path: String) -> StyleBoxTexture:
	## 大面板用九宫格：角花不拉伸，中间整片拉伸。
	return _panel_style_margin(tint, content, path, AI_PANEL_MARGIN)


static func _panel_style_margin(
	tint: Color, content: float, path: String, margin: int
) -> StyleBoxTexture:
	## 九宫格边距可调版本：大面板 112、小面板 48。边距必须跟着贴图的分辨率走，
	## 不然换图之后角花会被切一半，或者把中间挤没。
	var style := StyleBoxTexture.new()
	style.texture = load(path)
	style.texture_margin_left = float(margin)
	style.texture_margin_right = float(margin)
	style.texture_margin_top = float(margin)
	style.texture_margin_bottom = float(margin)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.modulate_color = tint
	style.set_content_margin_all(content)
	return style


static func _mild_tint(c: Color) -> Color:
	## 稀有度颜色往白色里兑一点再用来染格子底图：
	## 直接拿稀有度色去乘白金底图会把整块格子染成红的/紫的，很脏。
	var out := Color.WHITE.lerp(c, 0.35)
	out.a = 1.0
	return out


static func _mipmap_filter(node: Control) -> void:
	## UI 底图是按 1/9 甚至 1/17 的比例缩着画的（1344 宽的按钮图贴到 150 宽），
	## 不开 mipmap 的话 GPU 每个像素只采 2x2 的窗口，既锯齿又容易把边缘那圈
	## 半透明像素采进来（画面自查里被读成"按钮边缘一圈脏东西"）。
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func plate_chip(
	text: String, font_size := 17, tint := Color.WHITE,
	text_color := BTN_TEXT
) -> Control:
	## 商品价格这种「一片小标签」：底图用 AI 白金按钮那张，宽度随文字自适应。
	## 以前是深棕底 + 金字的小方块，在亮色面板上像一块补丁（画面自查反馈）。
	var node := PanelContainer.new()
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if _ai_ready(AI_ACTION_FRAMES):
		_mipmap_filter(node)
		node.add_theme_stylebox_override(
			"panel", _plate_style(AI_ACTION_FRAMES[0], tint, 14.0, 3.0))
	else:
		node.add_theme_stylebox_override(
			"panel", panel_style(tint, BTN_BORDER, 6, 2, 4.0))
	var label_node := label(text, font_size, text_color)
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_child(label_node)
	return node


static func _tex_button_style(path: String, tint := Color.WHITE) -> StyleBoxTexture:
	## 整张图拉伸成按钮大小（不是九宫格）：这张图的两端是圆形花纹，
	## 九宫格会把花纹拉成椭圆，所以直接整体缩放更好看。
	var style := StyleBoxTexture.new()
	style.texture = load(path)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.modulate_color = tint
	style.content_margin_left = 34.0
	style.content_margin_right = 34.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func make_theme() -> Theme:
	var theme := Theme.new()
	var font: Font = _load_game_font()
	theme.default_font = font
	theme.default_font_size = 23
	theme.set_stylebox("panel","TooltipPanel",panel_style(Color(0.055,0.09,0.14,0.88),Color.TRANSPARENT,5,0,12))
	theme.set_color("font_color","TooltipLabel",Color("edf3fa"))
	theme.set_font_size("font_size","TooltipLabel",17)
	return theme


static var _font_cache: Font = null


static func game_font() -> Font:
	return GameFonts.get_font()


const EMBOLDEN := 0.7


static func _load_game_font() -> Font:
	if ResourceLoader.exists(GAME_FONT):
		var loaded := load(GAME_FONT)
		if loaded is Font:
			print("[字体] 使用项目字体：%s" % GAME_FONT)
			return loaded
		# 兜底：直接按动态字体读文件（有些情况下导入后的资源不可用）
		var dynamic := FontFile.new()
		if dynamic.load_dynamic_font(GAME_FONT) == OK:
			print("[字体] 使用项目字体（动态加载）：%s" % GAME_FONT)
			return dynamic
	print("[字体] ⚠ 没找到 %s，回退到系统字体" % GAME_FONT)
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray(FONT_CANDIDATES)
	fallback.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	fallback.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return fallback


static func panel_style(
	bg: Color,
	border: Color,
	radius := 10,
	border_width := 2,
	content_margin := 14.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = content_margin
	style.content_margin_right = content_margin
	style.content_margin_top = content_margin
	style.content_margin_bottom = content_margin
	return style


static func tex_style(
	tint := Color.WHITE,
	margin := PANEL_MARGIN,
	content := 12.0,
	path := PANEL_TEX
) -> StyleBoxTexture:
	## 用一张像素图做 9 宫格：四个角不拉伸，中间拉伸。
	## 比 StyleBoxFlat 多了真实的立体边框（高光 + 阴影），界面不会显得"平"。
	var style := StyleBoxTexture.new()
	if ResourceLoader.exists(path):
		style.texture = load(path)
	style.texture_margin_left = float(margin)
	style.texture_margin_right = float(margin)
	style.texture_margin_top = float(margin)
	style.texture_margin_bottom = float(margin)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.modulate_color = tint
	style.content_margin_left = content
	style.content_margin_right = content
	style.content_margin_top = content
	style.content_margin_bottom = content
	return style


static func panel_box(tint := Color.WHITE, margin := PANEL_MARGIN, content := 14.0) -> PanelContainer:
	## 木质面板：外面板贴图 + 内层细金线 + 四角花角（见 UiOrnate）
	var node := UiOrnate.new()
	if _ai_ready(AI_PANEL_FRAMES):
		## 面板是 1024x688 的图铺到几百到一千多像素上，同样是缩着画
		_mipmap_filter(node)
		## 换成 AI 画的白金面板之后，贴图本身就带金框和四角卷草，
		## 所以这里把自绘的三层装饰全关掉，避免"框里再套一条框"。
		node.add_theme_stylebox_override(
			"panel", _panel_style(tint, content, AI_PANEL_FRAMES[0]))
		var plain := node.setup(Palette.GOLD, 8.0, 0.0)
		plain.show_bands = false
		plain.show_inner = false
		plain.show_corners = false
		return plain
	## margin 参数是老接口留下的（木质九宫格用 10 像素边距）。换贴图后边距由
	## AI_PANEL_MARGIN 决定，所以这里不再吃调用方传进来的值 —— 传 10 会把
	## 1024 宽的角花拉成一片糊。
	node.add_theme_stylebox_override("panel", tex_style(tint, margin, content))
	return node.setup(Palette.GOLD, 8.0, 22.0)


static func parchment_box(margin := PANEL_MARGIN, content := 14.0, alpha := 1.0) -> PanelContainer:
	## 「羊皮纸详情框」：现在走**小面板**贴图（细边框 + 小角饰）。
	## 之前它和大面板共用 2K 大图，边距 112 在 300 宽的小框上会把中间挤没。
	var node := UiOrnate.new()
	if ResourceLoader.exists(AI_PANEL_SMALL):
		_mipmap_filter(node)
		node.add_theme_stylebox_override(
			"panel", _panel_style_margin(
				Color(1.0, 1.0, 1.0, alpha), content, AI_PANEL_SMALL,
				AI_PANEL_SMALL_MARGIN))
		var plain := node.setup(Palette.GOLD, 7.0, 0.0)
		plain.show_bands = false
		plain.show_inner = false
		plain.show_corners = false
		return plain
	if _ai_ready(AI_PANEL_FRAMES):
		_mipmap_filter(node)
		node.add_theme_stylebox_override(
			"panel", _panel_style(Color(1.0, 1.0, 1.0, alpha), content, AI_PANEL_FRAMES[0]))
		var plain2 := node.setup(Palette.GOLD, 7.0, 0.0)
		plain2.show_bands = false
		plain2.show_inner = false
		plain2.show_corners = false
		return plain2
	node.add_theme_stylebox_override(
		"panel", tex_style(Color(1.0, 1.0, 1.0, alpha), margin, content, PARCHMENT_TEX)
	)
	return node.setup(Palette.GOLD, 7.0, 20.0)


## 自己画的像素面板框（art_src/ui/panel_frame.svg → assets/ui_drawn/panel_frame_96.png）。
## 素材是 48 逻辑像素、2 倍渲染成 96px，9 宫格边距 = 12 逻辑像素 = 24 像素。
## 用 msw-painter 的渲染链画出来：代码 → SVG → PNG，不依赖任何图像模型，
## 所以配色/线宽/角花都能精确控制，改一个数字重渲染即可。
const DRAWN_PANEL_TEX := "res://assets/ui_drawn/panel_frame_96.png"
const DRAWN_PANEL_MARGIN := 24


static func drawn_frame_box(content := 26.0) -> PanelContainer:
	## 多层金边 + 四角花角的面板：比纯 StyleBoxFlat 明显"有做工"
	var node := UiOrnate.new()
	if _ai_ready(AI_PANEL_FRAMES):
		_mipmap_filter(node)
		node.add_theme_stylebox_override(
			"panel", _panel_style(Color.WHITE, content, AI_PANEL_FRAMES[0]))
		var plain := node.setup(Palette.GOLD, 8.0, 0.0)
		plain.show_bands = false
		plain.show_inner = false
		plain.show_corners = false
		return plain
	# 自己画的素材是像素图，必须关掉线性过滤 —— 否则 9 宫格拉伸时会被插值成糊的，
	# 画面自查里直接被读成"边框模糊、缺乏像素锐度"。
	# （立绘/背景那些高清插画仍然用默认的线性过滤，所以这行只加在像素素材上。）
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var style := StyleBoxTexture.new()
	if ResourceLoader.exists(DRAWN_PANEL_TEX):
		style.texture = load(DRAWN_PANEL_TEX)
	style.texture_margin_left = float(DRAWN_PANEL_MARGIN)
	style.texture_margin_right = float(DRAWN_PANEL_MARGIN)
	style.texture_margin_top = float(DRAWN_PANEL_MARGIN)
	style.texture_margin_bottom = float(DRAWN_PANEL_MARGIN)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.set_content_margin_all(content)
	node.add_theme_stylebox_override("panel", style)
	# 框本身已经够花，装饰层只保留内线，不再叠花角
	var ornate := node.setup(Palette.GOLD, 8.0, 0.0)
	ornate.show_bands = false
	ornate.show_inner = false
	return ornate


static func gold_button(text: String, font_size := 20) -> Button:
	## 主要动作按钮（开始/选择/购买…）：金底深棕字，比普通按钮更"实"一点
	return ui_button(text, font_size, true)


static func frame_button(text: String, font_size := 21) -> Button:
	## 菜单/入口按钮：同一套自绘皮肤，只是尺寸更大、描边更粗
	var node := ui_button(text, font_size, false)
	if _ai_ready(AI_ACTION_FRAMES):
		## 大按钮留白给多一点，文字离两端的花纹远一些
		node.add_theme_stylebox_override("normal", _plate_style(AI_ACTION_FRAMES[0], Color.WHITE, 30.0, 10.0))
		node.add_theme_stylebox_override("hover", _plate_style(AI_ACTION_FRAMES[1], Color.WHITE, 30.0, 10.0))
		node.add_theme_stylebox_override("pressed", _plate_style(AI_ACTION_FRAMES[2], Color.WHITE, 30.0, 10.0))
		node.add_theme_stylebox_override(
			"disabled", _plate_style(AI_ACTION_FRAMES[0], Color(0.72, 0.72, 0.74), 30.0, 10.0))
		## ui_button 里已经挂过动画了，这里不能再挂一次（信号会连两遍，缩放会加倍）
		return node
	node.add_theme_stylebox_override("normal", _btn_style(BTN_FILL, BTN_BORDER, 3, 20.0, 0, 12))
	node.add_theme_stylebox_override("hover", _btn_style(BTN_FILL_HOVER, BTN_BORDER_HOVER, 3, 20.0, 4, 12))
	node.add_theme_stylebox_override("pressed", _btn_style(BTN_FILL_PRESS, BTN_BORDER, 3, 20.0, 0, 12))
	node.add_theme_stylebox_override("disabled", _btn_style(BTN_FILL_OFF, BTN_BORDER_OFF, 2, 20.0, 0, 12))
	# 菜单按钮多一圈内描边，看着更像"游戏 UI"而不是普通圆角按钮
	var inner := Panel.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 6.0
	inner.offset_top = 6.0
	inner.offset_right = -6.0
	inner.offset_bottom = -6.0
	var line := StyleBoxFlat.new()
	line.bg_color = Color(0, 0, 0, 0)
	line.border_color = Color(BTN_BORDER.r, BTN_BORDER.g, BTN_BORDER.b, 0.45)
	line.set_border_width_all(1)
	line.set_corner_radius_all(8)
	inner.add_theme_stylebox_override("panel", line)
	node.add_child(inner)
	return node


static func menu_button(text: String, font_size := 22) -> Button:
	## 主菜单 / 暂停菜单按钮。刻意不垫米白色实心底板：
	## 一层半透明深色玻璃让背景画透出来，靠金色细边和文字描边撑起可读性，
	## 悬停时金边点亮 + 外扩一圈金雾 + 整体放大（见 attach_button_animation）。
	var node := Button.new()
	node.add_theme_font_override("font", GameFonts.get_font("button"))
	node.text = text
	node.add_theme_font_override("font", game_font())
	node.add_theme_font_size_override("font_size", font_size)
	## 主菜单那张花饰按钮也是大图贴到小按钮上，同样要开 mipmap 采样
	_mipmap_filter(node)
	## 三态底图：AI 画的花饰鎏金按钮（本地 ComfyUI 出的），
	## 有就用图，没就退回自绘的半透明深底 —— 换机器/删素材也不会崩。
	if ResourceLoader.exists(AI_BTN_NORMAL):
		node.add_theme_stylebox_override("normal", _tex_button_style(AI_BTN_NORMAL))
		node.add_theme_stylebox_override("hover", _tex_button_style(AI_BTN_HOVER))
		node.add_theme_stylebox_override("pressed", _tex_button_style(AI_BTN_PRESSED))
		node.add_theme_stylebox_override("disabled", _tex_button_style(AI_BTN_NORMAL, Color(0.45, 0.45, 0.5)))
	else:
		node.add_theme_stylebox_override("normal", _menu_plate(0.46, MENU_LINE, 2))
		node.add_theme_stylebox_override("hover", _menu_plate(0.66, MENU_LINE_HOVER, 3, 7))
		node.add_theme_stylebox_override("pressed", _menu_plate(0.78, MENU_LINE_HOVER, 3))
		node.add_theme_stylebox_override("disabled", _menu_plate(0.26, MENU_LINE_OFF, 2))
	## 文字配色跟着底图走：底图换成**亮金**的 AI 按钮之后，原来那套"浅奶油字 +
	## 深色描边"（当年配深色玻璃底用的）变成浅字压亮底，实测被读成"字看不清"。
	## 现在反过来：深棕字 + 浅色描边，压在金色花纹上最清楚。
	if ResourceLoader.exists(AI_BTN_NORMAL):
		node.add_theme_color_override("font_color", MENU_TEXT_ON_GOLD)
		node.add_theme_color_override("font_hover_color", MENU_TEXT_ON_GOLD_HOVER)
		node.add_theme_color_override("font_pressed_color", MENU_TEXT_ON_GOLD_HOVER)
		node.add_theme_color_override("font_focus_color", MENU_TEXT_ON_GOLD_HOVER)
		node.add_theme_color_override("font_disabled_color", MENU_TEXT_OFF)
		node.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.92, 0.92))
	else:
		node.add_theme_color_override("font_color", MENU_TEXT)
		node.add_theme_color_override("font_hover_color", MENU_TEXT_HOVER)
		node.add_theme_color_override("font_pressed_color", MENU_TEXT_HOVER)
		node.add_theme_color_override("font_focus_color", MENU_TEXT_HOVER)
		node.add_theme_color_override("font_disabled_color", MENU_TEXT_OFF)
		node.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.9))
	# 字号越大描边越粗，不然小字会被描边糊成一团（和 HUD 那边同一个思路）
	node.add_theme_constant_override("outline_size", clampi(font_size / 5, 3, 6))
	if ResourceLoader.exists(AI_BTN_NORMAL):
		## 画面自查的第二轮反馈：深字压亮金"明度够但不够锐"，因为字和底同色系、
		## 加上按钮上本身有菱形/卷草花纹，细笔画会和花纹粘在一起。
		## 补两件事：① 字再压深一档 ② 加一层向下偏移的深色柔影（把字从花纹上"抬"起来）
		node.add_theme_color_override("font_color", Color("2b1c08"))
		node.add_theme_color_override("font_hover_color", Color("1d1204"))
		node.add_theme_color_override("font_pressed_color", Color("1d1204"))
		node.add_theme_color_override("font_focus_color", Color("1d1204"))
		node.add_theme_color_override("font_outline_color", Color(1.0, 0.99, 0.95, 0.75))
		node.add_theme_constant_override("outline_size", 3)
		node.add_theme_color_override("font_shadow_color", Color(0.16, 0.09, 0.02, 0.45))
		node.add_theme_constant_override("shadow_offset_x", 0)
		node.add_theme_constant_override("shadow_offset_y", 2)
		node.add_theme_constant_override("shadow_outline_size", 3)
	attach_button_animation(node)
	return node


static func menu_plate_box(content_pad := 12.0) -> PanelContainer:
	## 同一套皮：给「当前角色：xxx」这类浮在背景画上的小字垫一块半透明底
	var box := PanelContainer.new()
	box.add_theme_stylebox_override(
		"panel", _menu_plate(0.42, MENU_LINE, 2, 0, content_pad, content_pad)
	)
	return box


static func small_button(text: String, font_size := 16) -> Button:
	## 背包 / 弹窗里的小按钮：奶油白底 + 金描边，悬停浮起、按下回弹
	return ui_button(text, font_size, false)


static func ui_button(text: String, font_size := 18, primary := false) -> Button:
	## 自绘按钮：不依赖任何按钮素材，状态色写在下面的常量里，想换配色改常量即可
	var node := Button.new()
	node.add_theme_font_override("font", GameFonts.get_font("button"))
	node.text = text
	node.add_theme_font_override("font", game_font())
	node.add_theme_font_size_override("font_size", font_size)
	node.focus_mode = Control.FOCUS_NONE
	var fill := BTN_PRIMARY_FILL if primary else BTN_FILL
	var fill_hover := BTN_PRIMARY_FILL_HOVER if primary else BTN_FILL_HOVER
	var fill_press := BTN_PRIMARY_FILL_PRESS if primary else BTN_FILL_PRESS
	var use_ai := _ai_ready(AI_ACTION_FRAMES)
	if use_ai:
		_mipmap_filter(node)
		## 主要按钮（购买/确定）把底图往暖色里染一点，和次要按钮（取消/关闭）区分开
		var base := Color("ffe6a8") if primary else Color.WHITE
		node.add_theme_stylebox_override("normal", _plate_style(AI_ACTION_FRAMES[0], base))
		node.add_theme_stylebox_override("hover", _plate_style(AI_ACTION_FRAMES[1], base))
		node.add_theme_stylebox_override("pressed", _plate_style(AI_ACTION_FRAMES[2], base))
		node.add_theme_stylebox_override(
			"disabled", _plate_style(AI_ACTION_FRAMES[0], Color(0.70, 0.70, 0.72)))
	else:
		node.add_theme_stylebox_override("normal", _btn_style(fill, BTN_BORDER, 3, 14.0, 0))
		node.add_theme_stylebox_override("hover", _btn_style(fill_hover, BTN_BORDER_HOVER, 3, 16.0, 4))
		node.add_theme_stylebox_override("pressed", _btn_style(fill_press, BTN_BORDER, 3, 16.0, 0))
		node.add_theme_stylebox_override("disabled", _btn_style(BTN_FILL_OFF, BTN_BORDER_OFF, 2, 14.0, 0))
	node.add_theme_color_override("font_color", BTN_TEXT)
	node.add_theme_color_override("font_hover_color", Color("2f1b08"))
	node.add_theme_color_override("font_pressed_color", Color("2f1b08"))
	node.add_theme_color_override("font_disabled_color", BTN_TEXT_OFF)
	if not use_ai:
		# 立体感：顶端一条高光、底端一条暗线，按钮不再是"一张平纸"。
		# 换成 AI 底图后不需要这两条 —— 图里已经有高光和底阴影了，
		# 再叠上去会变成"按钮上下各多一条白线/褐线"。
		var highlight := ColorRect.new()
		highlight.color = Color(1.0, 1.0, 1.0, 0.65)
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		highlight.set_anchors_preset(Control.PRESET_TOP_WIDE)
		highlight.offset_left = 9.0
		highlight.offset_right = -9.0
		highlight.offset_top = 3.0
		highlight.offset_bottom = 5.0
		node.add_child(highlight)
		var shade := ColorRect.new()
		shade.color = Color(0.72, 0.58, 0.32, 0.22)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		shade.offset_left = 9.0
		shade.offset_right = -9.0
		shade.offset_top = -5.0
		shade.offset_bottom = -3.0
		node.add_child(shade)
	attach_button_animation(node)
	return node


static func _btn_style(
	bg: Color, border: Color, border_width: int, margin: float,
	shadow := 0, radius := 10
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	if shadow > 0:
		# 悬停时外扩一圈金雾，按钮"浮"起来
		style.shadow_color = Color(border.r, border.g, border.b, 0.30)
		style.shadow_size = shadow
		style.shadow_offset = Vector2(0.0, 2.0)
	return style


static func _menu_plate(
	alpha: float,
	border: Color,
	border_width: int,
	shadow := 0,
	pad := 10.0,
	side_pad := MENU_SIDE_PAD
) -> StyleBoxFlat:
	## 主菜单按钮 / 小字底衬共用的样式：半透明深底 + 金线。
	## 左右内边距单独抽成参数：按钮要宽（给文字和箭头留位置），小字底衬只要一点点。
	var style := StyleBoxFlat.new()
	style.bg_color = Color(MENU_PLATE.r, MENU_PLATE.g, MENU_PLATE.b, alpha)
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(10)
	style.content_margin_left = side_pad
	style.content_margin_right = side_pad
	style.content_margin_top = pad
	style.content_margin_bottom = pad
	if shadow > 0:
		style.shadow_color = Color(border.r, border.g, border.b, 0.32)
		style.shadow_size = shadow
		style.shadow_offset = Vector2(0.0, 2.0)
	return style


static func attach_button_animation(node: Button) -> void:
	## 按钮动画：悬停放大一点点、按下缩小回弹、松开弹回。
	## 用 Tween（补间）实现，和 JS 里写动画一个思路，但不用逐帧计算。
	node.pivot_offset = node.size * 0.5
	node.resized.connect(func() -> void: node.pivot_offset = node.size * 0.5)
	node.mouse_entered.connect(func() -> void: _btn_scale(node, 1.035))
	node.mouse_exited.connect(func() -> void: _btn_scale(node, 1.0))
	node.button_down.connect(func() -> void: _btn_scale(node, 0.965))
	node.button_up.connect(func() -> void: _btn_scale(node, 1.035 if node.is_hovered() else 1.0))


static func _btn_scale(node: Control, target: float) -> void:
	if not is_instance_valid(node) or node.disabled:
		node.scale = Vector2.ONE
		return
	var tween := node.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(node, "scale", Vector2.ONE * target, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## ---------------- 界面零件（自绘，配合代码构建的页面）----------------

static func ornament(shape: UiOrnament.Shape, box := 12.0, color := Palette.GOLD, line := 2.0) -> UiOrnament:
	## 菱形 / 箭头 / 角标
	var node := UiOrnament.new()
	node.setup(shape, color, box, line)
	return node


## ---------------- 装饰外壳：让面板不再是一块平底 ----------------
##
## 「朴素」的根源是：面板只有一条 1~3 像素的边框，里面一整片平色。
## 这里补的是专业 UI 通用的四件事（成本极低、观感立竿见影）：
##   1. 内层细金线 —— 和已有外框构成"双线"，这是最省事的精致信号；
##   2. 四角花角   —— L 形小装饰，把矩形"框"住，视线有落点；
##   3. 顶部层次带 —— 顶部一条渐变压暗，标题区和内容区自动分层；
##   4. 底部渐亮   —— 底部一点点反光，面板像有厚度而不是贴纸。
## 全部 MOUSE_FILTER_IGNORE，纯装饰，不吃点击、不影响布局。

static func ornament_layer(accent := Palette.GOLD, inset := 7.0, arm := 24.0) -> Control:
	var layer := Control.new()
	layer.name = "Ornate"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 顶部 / 底部渐变带：贴着面板边，宽度撑满
	layer.add_child(_edge_band(true, 62.0, 0.20))
	layer.add_child(_edge_band(false, 46.0, 0.10))

	# 内层细金线
	var line := Panel.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = inset
	line.offset_top = inset
	line.offset_right = -inset
	line.offset_bottom = -inset
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	line.add_theme_stylebox_override("panel", sb)
	layer.add_child(line)

	# 四角花角：亮金主笔 + 深色底衬，压在背景上也看得清
	var corners := [
		[UiOrnament.Shape.CORNER_TOP_LEFT, true, true],
		[UiOrnament.Shape.CORNER_TOP_RIGHT, true, false],
		[UiOrnament.Shape.CORNER_BOTTOM_LEFT, false, true],
		[UiOrnament.Shape.CORNER_BOTTOM_RIGHT, false, false],
	]
	for entry in corners:
		var top: bool = entry[1]
		var left: bool = entry[2]
		var o := inset + 1.0
		var shade := ornament(entry[0], arm + 3.0, Color(0.06, 0.05, 0.03, 0.5), 3.5)
		var mark := ornament(entry[0], arm, accent, 2.0)
		for node: UiOrnament in [shade, mark]:
			node.anchor_left = 0.0 if left else 1.0
			node.anchor_right = node.anchor_left
			node.anchor_top = 0.0 if top else 1.0
			node.anchor_bottom = node.anchor_top
			node.offset_left = o if left else -(o + arm + 3.0)
			node.offset_right = node.offset_left + arm + 3.0
			node.offset_top = o if top else -(o + arm + 3.0)
			node.offset_bottom = node.offset_top + arm + 3.0
			layer.add_child(node)
	return layer


static func _edge_band(top: bool, height: float, alpha: float) -> TextureRect:
	## 用渐变纹理做一条"从面板边缘往里逐渐透明"的带子。ColorRect 没有渐变，
	## 而 GradientTexture2D 是引擎自带资源，不用美术素材。
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.04, 0.03, alpha))
	grad.set_color(1, Color(0.05, 0.04, 0.03, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 8
	tex.height = 32
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	var node := TextureRect.new()
	node.texture = tex
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
	if top:
		node.offset_bottom = height
		node.flip_v = false
	else:
		node.offset_top = -height
		node.flip_v = true
	return node


static func framed(panel: Control, accent := Palette.GOLD, inset := 7.0) -> Control:
	## 把做好的面板套进装饰外壳。**必须在面板的子节点都加完之后再调用**
	## （外壳的最小尺寸是照面板算的，先套壳再加内容会导致尺寸不更新）。
	## 外壳是普通 Control（不是容器），所以面板内部原有的锚点布局不受影响。
	var wrap := Control.new()
	wrap.name = "Framed"
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.size_flags_horizontal = panel.size_flags_horizontal
	wrap.size_flags_vertical = panel.size_flags_vertical
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(panel)
	wrap.add_child(ornament_layer(accent, inset))
	var sync := func() -> void:
		wrap.custom_minimum_size = panel.get_combined_minimum_size()
	wrap.custom_minimum_size = panel.get_combined_minimum_size()
	panel.minimum_size_changed.connect(sync)
	return wrap


static func card_panel(
	fill := Color(1.0, 0.996, 0.976, 0.95), border := Palette.GOLD,
	radius := 18, border_width := 3
) -> PanelContainer:
	## 页面用的大卡片：奶油白底 + 金描边 + 柔和投影
	var node := UiOrnate.new()
	var style := panel_style(fill, border, radius, border_width, 20.0)
	style.shadow_color = Color(border.r, border.g, border.b, 0.26)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 4.0)
	node.add_theme_stylebox_override("panel", style)
	return node.setup(border, 9.0, 26.0)


static func card_inset(alpha := 0.55, radius := 14) -> PanelContainer:
	## 卡片里的次级区块（比卡片稍暗一点，用来分组）
	## 嵌套区块里再画四角花角会太吵，所以只留内层细线
	var node := UiOrnate.new()
	node.add_theme_stylebox_override(
		"panel", panel_style(Color(1.0, 0.972, 0.916, alpha), Color(Palette.GOLD, 0.32), radius, 1, 14.0))
	var ornate := node.setup(Palette.GOLD, 5.0, 0.0)
	ornate.show_corners = false
	ornate.show_bands = false
	return ornate


static func title_bar(text: String, font_size := 34, color := Palette.GOLD) -> Control:
	## 标题条：左边一颗菱形 + 标题 + 右边一条渐变金线
	var row := hbox(10)
	row.add_child(ornament(UiOrnament.Shape.DIAMOND, float(font_size) * 0.42, color))
	row.add_child(label(text, font_size, color))
	var line := ColorRect.new()
	line.color = Color(color.r, color.g, color.b, 0.55)
	line.custom_minimum_size = Vector2(0.0, 3.0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	return row


static func divider(color := Palette.GOLD, alpha := 0.45) -> Control:
	## 分隔线：细线中间穿一颗小菱形
	var row := hbox(6)
	var left := ColorRect.new()
	left.color = Color(color.r, color.g, color.b, alpha)
	left.custom_minimum_size = Vector2(0.0, 2.0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	row.add_child(ornament(UiOrnament.Shape.DIAMOND, 8.0, Color(color.r, color.g, color.b, 0.8)))
	var right := ColorRect.new()
	right.color = Color(color.r, color.g, color.b, alpha)
	right.custom_minimum_size = Vector2(0.0, 2.0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	return row


static func pill(text: String, color := Palette.GOLD, font_size := 15) -> Control:
	## 小圆角标签（职业、稀有度这种短标签）
	var node := PanelContainer.new()
	var style := panel_style(Color(color.r, color.g, color.b, 0.16), color, 12, 1, 10.0)
	node.add_theme_stylebox_override("panel", style)
	var text_node := label(text, font_size, color)
	node.add_child(text_node)
	return node


static func framed_portrait(path: String, box := Vector2(240.0, 380.0)) -> Control:
	## 立绘框：金色双描边 + 四角角标，立绘本身透明底直接放里面
	var holder := Control.new()
	holder.custom_minimum_size = box
	holder.size = box
	# 立绘框跟着右边的资料卡一起撑满高度，两个框的上下边才对得齐。
	# （之前写死 SHRINK_CENTER，结果左框比右框短一截、上下都错开。）
	holder.size_flags_vertical = Control.SIZE_FILL

	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style := panel_style(Color(1.0, 0.99, 0.95, 0.82), Palette.GOLD, 16, 3, 0.0)
	bg_style.shadow_color = Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.30)
	bg_style.shadow_size = 8
	bg.add_theme_stylebox_override("panel", bg_style)
	holder.add_child(bg)

	var inner := Panel.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 8.0
	inner.offset_top = 8.0
	inner.offset_right = -8.0
	inner.offset_bottom = -8.0
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color(0, 0, 0, 0)
	inner_style.border_color = Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.40)
	inner_style.set_border_width_all(1)
	inner_style.set_corner_radius_all(10)
	inner.add_theme_stylebox_override("panel", inner_style)
	holder.add_child(inner)

	var portrait := texture_icon(path, box.y)
	# 注意：texture_icon 会给控件一个 (box.y, box.y) 的最小尺寸，
	# 比立绘框还宽，会把立绘顶到框外面去 —— 这里必须清掉，靠锚点铺满内框。
	portrait.custom_minimum_size = Vector2.ZERO
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	## 内边距：图片本身是居中的（STRETCH_KEEP_ASPECT_CENTERED），上下留白在几何上
	## 本来就相等；但立绘顶部是尖帽、底部是宽裙摆，视觉上"上方空得更厉害"。
	## 所以这里故意把图往上顶 10 像素（上 22 / 下 42）来抵消这种视觉错觉。
	portrait.offset_left = 26.0
	portrait.offset_top = 26.0
	portrait.offset_right = -26.0
	portrait.offset_bottom = -38.0
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	holder.add_child(portrait)

	# 四角小角标：锚点要分别贴在对应的角上，否则右下两个会跑到框外面
	for corner in [
		[UiOrnament.Shape.CORNER_TOP_LEFT, Control.PRESET_TOP_LEFT, 6.0, 6.0],
		[UiOrnament.Shape.CORNER_TOP_RIGHT, Control.PRESET_TOP_RIGHT, -22.0, 6.0],
		[UiOrnament.Shape.CORNER_BOTTOM_LEFT, Control.PRESET_BOTTOM_LEFT, 6.0, -22.0],
		[UiOrnament.Shape.CORNER_BOTTOM_RIGHT, Control.PRESET_BOTTOM_RIGHT, -22.0, -22.0],
	]:
		var mark := ornament(corner[0], 16.0, Palette.GOLD, 2.0)
		mark.set_anchors_preset(corner[1])
		mark.offset_left = corner[2]
		mark.offset_top = corner[3]
		mark.offset_right = corner[2] + 16.0
		mark.offset_bottom = corner[3] + 16.0
		holder.add_child(mark)
	return holder


static func animate_in(container: Node, step := 0.05, from_scale := 0.96) -> void:
	## 容器里的控件依次淡入 + 轻微放大，做出"菜单展开"的观感
	if container.is_inside_tree():
		# 等一帧让容器把子控件排版好，缩放的轴心才是正中间
		await container.get_tree().process_frame
	var i := 0
	for child in container.get_children():
		if not (child is Control):
			continue
		var node := child as Control
		node.pivot_offset = node.size * 0.5
		node.modulate.a = 0.0
		node.scale = Vector2.ONE * from_scale
		var tween := node.create_tween()
		tween.set_parallel(true)
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(node, "modulate:a", 1.0, 0.20).set_delay(step * float(i))
		tween.tween_property(node, "scale", Vector2.ONE, 0.26) \
			.set_delay(step * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1



static func close_button(size := 36.0, tooltip := "关闭") -> Button:
	## 关闭按钮：底图用 AI 白金格子（和背包格同一套皮），叉号是两条旋转矩形自己画的。
	## 以前用的是素材包里那张 16x16 的红色像素 X，放大到 36px 之后在画面自查里
	## 被读成"低分辨率的系统按钮，和周围的雕花边框完全不搭" —— 换成代码画的叉，
	## 任何尺寸都是锐的，颜色也跟白金主题一致。
	var node := Button.new()
	node.add_theme_font_override("font", GameFonts.get_font("button"))
	node.custom_minimum_size = Vector2(size, size)
	node.focus_mode = Control.FOCUS_NONE
	node.tooltip_text = tooltip
	if _ai_ready(AI_SLOT_FRAMES):
		_mipmap_filter(node)
		node.add_theme_stylebox_override("normal", _plate_style(AI_SLOT_FRAMES[0], Color.WHITE, 4.0, 4.0))
		node.add_theme_stylebox_override("hover", _plate_style(AI_SLOT_FRAMES[1], Color.WHITE, 4.0, 4.0))
		node.add_theme_stylebox_override("pressed", _plate_style(AI_SLOT_FRAMES[2], Color.WHITE, 4.0, 4.0))
	else:
		node.add_theme_stylebox_override("normal", _btn_style(BTN_FILL, BTN_BORDER, 2, 4.0, 0, 8))
		node.add_theme_stylebox_override("hover", _btn_style(BTN_FILL_HOVER, BTN_BORDER_HOVER, 2, 4.0, 4, 8))
		node.add_theme_stylebox_override("pressed", _btn_style(BTN_FILL_PRESS, BTN_BORDER, 2, 4.0, 0, 8))
	var arm := size * 0.40
	var thick := maxf(3.0, size * 0.095)
	for i in 2:
		## 先垫一条深色再压红的：白底、金底上都看得清
		for layer in 2:
			var bar := ColorRect.new()
			bar.color = Color(0.24, 0.13, 0.06, 0.85) if layer == 0 else Color("b8443c")
			bar.size = Vector2(arm, thick + (2.0 if layer == 0 else 0.0))
			bar.pivot_offset = bar.size * 0.5
			bar.position = (Vector2(size, size) - bar.size) * 0.5
			bar.rotation = deg_to_rad(45.0 if i == 0 else -45.0)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_child(bar)
	attach_button_animation(node)
	return node


static func tab_button(text: String, active: bool, font_size := 17) -> Button:
	## 背包页签：扁平标签 + 选中时底部一条金色指示条（比一整块按钮干净）
	var node := Button.new()
	node.add_theme_font_override("font", GameFonts.get_font("button"))
	node.text = text
	node.add_theme_font_override("font", game_font())
	node.add_theme_font_size_override("font_size", font_size)
	node.focus_mode = Control.FOCUS_NONE
	# 选中指示条：一直挂着，靠 apply_tab_style 控制显隐（页签切换时不用重建节点）
	var underline := ColorRect.new()
	underline.name = "Underline"
	underline.color = Palette.GOLD
	underline.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	underline.offset_top = -4.0
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(underline)
	apply_tab_style(node, active)
	return node


static func apply_tab_style(node: Button, active: bool) -> void:
	## 页签的选中态样式。切换页签时对每个按钮重新调一次即可刷新。
	# 选中态要一眼看得出来：底色明显更亮更暖、金色描边、底部金色指示条
	var bg := Color(1.0, 0.97, 0.86, 0.94) if active else Color(1.0, 1.0, 1.0, 0.10)
	var hover := Color(1.0, 0.99, 0.92, 0.97) if active else Color(1.0, 1.0, 1.0, 0.32)
	var border := Palette.GOLD if active else Color(0.0, 0.0, 0.0, 0.0)
	node.add_theme_stylebox_override("normal", panel_style(bg, border, 6, 3 if active else 0, 6.0))
	node.add_theme_stylebox_override("hover", panel_style(hover, border, 6, 3 if active else 2, 6.0))
	node.add_theme_stylebox_override("pressed", panel_style(bg, border, 6, 3, 6.0))
	node.add_theme_stylebox_override("disabled", panel_style(bg, border, 6, 3 if active else 0, 6.0))
	node.add_theme_color_override("font_color", Palette.GOLD if active else Palette.PARCHMENT_TEXT_DIM)
	node.add_theme_color_override("font_hover_color", Palette.GOLD)
	node.add_theme_color_override("font_pressed_color", Palette.GOLD)
	node.add_theme_color_override("font_disabled_color", Palette.GOLD if active else Palette.PARCHMENT_TEXT_DIM)
	var underline := node.get_node_or_null("Underline") as ColorRect
	if underline != null:
		underline.visible = active


static func slot_button(border_tint := Color.WHITE, size := 64.0, margin := 8) -> Button:
	## 背包格 / 装备格：用「凹槽」那张做小尺寸 9 宫格，边距小一点才像挖出来的坑
	var node := Button.new()
	node.add_theme_font_override("font", GameFonts.get_font("button"))
	node.custom_minimum_size = Vector2(size, size)
	node.focus_mode = Control.FOCUS_NONE
	if _ai_ready(AI_SLOT_FRAMES):
		_mipmap_filter(node)
		var tint := _mild_tint(border_tint)
		node.add_theme_stylebox_override("normal", _plate_style(AI_SLOT_FRAMES[0], tint, 4.0, 4.0))
		node.add_theme_stylebox_override("hover", _plate_style(AI_SLOT_FRAMES[1], tint, 4.0, 4.0))
		node.add_theme_stylebox_override("pressed", _plate_style(AI_SLOT_FRAMES[2], tint, 4.0, 4.0))
		node.add_theme_stylebox_override(
			"disabled", _plate_style(AI_SLOT_FRAMES[0], Color(0.72, 0.72, 0.74), 4.0, 4.0))
	else:
		node.add_theme_stylebox_override("normal", tex_style(border_tint, margin, 4.0, INSET_TEX))
		node.add_theme_stylebox_override("hover", tex_style(border_tint.lightened(0.3), margin, 4.0, INSET_TEX))
		node.add_theme_stylebox_override("pressed", tex_style(border_tint.darkened(0.2), margin, 4.0, INSET_TEX))
		node.add_theme_stylebox_override("disabled", tex_style(Color(0.62, 0.58, 0.52), margin, 4.0, INSET_TEX))
	return node


static func ring(content: Control, color: Color, width := 2) -> Control:
	## 给任意控件套一圈纯色描边（稀有度、选中状态用）。
	## 底色透明，所以不会盖掉里面像素面板的立体感。
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override(
		"panel",
		panel_style(Color.TRANSPARENT, color, 3, width, 0.0)
	)
	wrap.add_child(content)
	return wrap


static func label(text: String, size := 20, color := Palette.UI_TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", game_font())
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func outlined_label(text: String, size := 48, color := Palette.UI_TEXT, outline := 8) -> Label:
	var node := label(text, size, color)
	node.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	node.add_theme_constant_override("outline_size", outline)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node


static func button(text: String, size := 20) -> Button:
	var node := Button.new()
	node.add_theme_font_override("font", GameFonts.get_font("button"))
	node.text = text
	node.add_theme_font_override("font", game_font())
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_stylebox_override("normal", panel_style(Palette.UI_PANEL.lightened(0.06), Palette.UI_PANEL_BORDER, 8, 2, 10.0))
	node.add_theme_stylebox_override("hover", panel_style(Palette.UI_PANEL.lightened(0.16), Palette.UI_ACCENT, 8, 2, 10.0))
	node.add_theme_stylebox_override("pressed", panel_style(Palette.UI_ACCENT.darkened(0.45), Palette.UI_ACCENT, 8, 2, 10.0))
	node.add_theme_stylebox_override("disabled", panel_style(Palette.UI_PANEL.darkened(0.25), Palette.UI_PANEL_BORDER.darkened(0.4), 8, 2, 10.0))
	node.add_theme_color_override("font_color", Palette.UI_TEXT)
	node.add_theme_color_override("font_hover_color", Palette.UI_ACCENT)
	node.add_theme_color_override("font_pressed_color", Color.WHITE)
	node.add_theme_color_override("font_disabled_color", Palette.UI_TEXT_DIM)
	return node


static func panel(bg := Palette.UI_PANEL, border := Palette.UI_PANEL_BORDER, radius := 12) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", panel_style(bg, border, radius))
	return node


static func vbox(separation := 10) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func hbox(separation := 10) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func full_rect() -> Control:
	var node := Control.new()
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func dim_layer(alpha := 0.72) -> ColorRect:
	var node := ColorRect.new()
	node.color = Color(0.02, 0.03, 0.05, alpha)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	return node


static func spacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func rarity_dot(color: Color) -> Panel:
	var node := Panel.new()
	node.custom_minimum_size = Vector2(12.0, 12.0)
	node.add_theme_stylebox_override("panel", panel_style(color, color.darkened(0.4), 6, 1, 0.0))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## ---------------- 图标 ----------------
## 图标统一走 ItemDB：道具自带 icon 字段（图集编号或整张贴图），
## 这里只负责把它变成能放进界面的控件。

static func atlas_texture(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas


static func item_icon(item: Dictionary, icon_size := 44.0) -> TextureRect:
	var node := TextureRect.new()
	var texture := ItemDB.icon_texture(item)
	if texture != null:
		node.texture = atlas_texture(texture, ItemDB.icon_region(item))
	node.custom_minimum_size = Vector2(icon_size, icon_size)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func sheet_icon(index: int, icon_size := 26.0) -> TextureRect:
	## 直接按图集编号取图标（血条前面的爱心、金币、钥匙用）
	var icon:=item_icon({"icon": ItemDB.sheet_icon(index)},icon_size)
	if index==ItemDB.ICON_COIN:icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	return icon


static func texture_icon(path: String, icon_size := 26.0) -> TextureRect:
	## 用一整张贴图当图标（钥匙、立绘这些单独的 PNG）
	var node := TextureRect.new()
	if ResourceLoader.exists(path):
		node.texture = load(path)
	node.custom_minimum_size = Vector2(icon_size, icon_size)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	## 用带 mipmap 的线性过滤：立绘是 1536x2704，要缩到 400 多像素显示，
	## 不开 mipmap 的话缩小采样会明显锯齿/闪烁（画面自查里被读成"立绘清晰度不高"）。
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if "pixel_batch" in path else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func slot_panel(border: Color, size := 76.0, fill := Palette.UI_PANEL.lightened(0.05)) -> PanelContainer:
	## 一个方格子（背包格 / 装备栏），边框颜色用来表示稀有度或选中状态
	var node := PanelContainer.new()
	node.custom_minimum_size = Vector2(size, size)
	if _ai_ready(AI_SLOT_FRAMES):
		_mipmap_filter(node)
		node.add_theme_stylebox_override(
			"panel", _plate_style(AI_SLOT_FRAMES[0], _mild_tint(border), 4.0, 4.0))
	else:
		node.add_theme_stylebox_override("panel", panel_style(fill, border, 8, 2, 6.0))
	return node
