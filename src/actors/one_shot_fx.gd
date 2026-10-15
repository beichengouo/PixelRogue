class_name OneShotFX
extends Sprite2D
## 通用一次性特效：按横向图集逐帧播一遍，然后自己消失。
##
## 爆炸、命中火花、挥砍弧光都用它 —— 素材（KILN FX）本身就是「横向一条」的图集，
## 帧宽 = 图宽 / 帧数，按 15 fps 设计。

const FPS := 15.0
## 特效自带的照明强度。夜战里技能炸开时应该照亮周围一圈 ——
## 不然放了大招画面还是黑的，打击感会差一截。
## 半径按特效自己的显示尺寸推（见 _update_light），跟缩放/成长一起变。
var light_energy := 1.7
## 光源半径相对特效宽度的倍数：1.4 表示"比特效本身再大一圈"
const LIGHT_RADIUS_RATIO := 1.4
## 有些特效（比如纯拖尾）不需要照明，可以单独把这个设成 0
var light_color := Color.WHITE

var _frames := 1
var _life := 0.5
var _max_life := 0.5
var _frame_timer := 0.0
var _frame := 0
var _grow := 0.0
var _base_scale := Vector2.ONE
var _light: PointLight2D
var _light_radius := 0.0


static func spawn(
	parent: Node,
	where: Vector2,
	path: String,
	frame_size: Vector2i,
	frames: int,
	rotation_rad := 0.0,
	scale_factor := 1.0,
	grow := 0.0,
	color := Color.WHITE
) -> OneShotFX:
	if parent == null or not is_instance_valid(parent):
		return null
	var fx := OneShotFX.new()
	parent.add_child(fx)
	fx.setup(where, path, frame_size, frames, rotation_rad, scale_factor, grow, color)
	return fx


func setup(
	where: Vector2,
	path: String,
	frame_size: Vector2i,
	frames: int,
	rotation_rad: float,
	scale_factor: float,
	grow: float,
	color: Color
) -> void:
	global_position = where
	rotation = rotation_rad
	modulate = color
	z_index = 7
	texture = load(path)
	region_enabled = true
	region_rect = Rect2(0.0, 0.0, float(frame_size.x), float(frame_size.y))
	centered = true
	_frames = maxi(1, frames)
	_life = float(_frames) / FPS
	_max_life = _life
	_frame_timer = 1.0 / FPS
	_frame = 0
	_grow = grow
	# 注意别把参数命名成 scale —— 那是 Sprite2D 自带的属性，会互相覆盖
	_base_scale = Vector2.ONE * scale_factor
	scale = _base_scale
	_build_light(frame_size, scale_factor, color)


func _build_light(frame_size: Vector2i, scale_factor: float, tint: Color) -> void:
	if light_energy <= 0.0:
		return
	_light_radius = float(frame_size.x) * scale_factor * LIGHT_RADIUS_RATIO
	light_color = tint
	_light = LightUtil.make_point_light(tint, light_energy, _light_radius, false)
	add_child(_light)


func _process(delta: float) -> void:
	_life -= delta
	_frame_timer -= delta
	if _frame_timer <= 0.0 and _frame < _frames - 1:
		_frame_timer = 1.0 / FPS
		_frame += 1
		region_rect = Rect2(
			float(_frame * int(region_rect.size.x)), 0.0,
			region_rect.size.x, region_rect.size.y
		)
	if _grow != 0.0:
		var t := 1.0 - clampf(_life / _max_life, 0.0, 1.0)
		scale = _base_scale * (1.0 + _grow * t)
	if _light != null:
		# 亮度随特效一起淡出（最后 40% 寿命开始收），
		# 半径跟着 scale 一起长大，陨石那种"炸开"才有扩张感
		var k := clampf(_life / maxf(0.0001, _max_life * 0.4), 0.0, 1.0)
		_light.energy = light_energy * k
		_light.texture_scale = maxf(0.05, _light_radius * scale.x / 64.0)
	if _life <= 0.0:
		queue_free()
