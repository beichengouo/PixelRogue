class_name PixelHeroArt
extends RefCounted
## 精修角色图集与动作配置。图像原文件保留；裁剪、缩放与脚底对齐由引擎完成。
const ROOT := "res://assets/hero_sylphiette_v2/"
const CORE := ROOT + "core.png"
const MOBILITY := ROOT + "mobility.png"
const COMBAT := ROOT + "combat.png"
const MOVING_COMBAT := ROOT + "moving.png"
const AIR := ROOT + "air.png"
const REACTION := ROOT + "reaction.png"
const SUPPORT := ROOT + "support.png"
const EXTRA := ROOT + "extra.png"
const WORLD_HEIGHT := 49.0
const LOGICAL_FRAME := Vector2(768, 768)
const FOOT_Y := 640.0
const ANIMATIONS := {
	&"idle": [CORE, 0, 8, 5.0, true],
	&"run": [CORE, 8, 8, 12.0, true],
	&"cast": [COMBAT, 8, 8, 8.0 / 0.28, false],
	&"jump": [MOBILITY, 0, 4, 12.0, false],
	&"fall": [MOBILITY, 4, 4, 10.0, false],
	&"land": [MOBILITY, 8, 4, 4.0 / 0.16, false],
	&"dash": [MOBILITY, 12, 4, 4.0 / 0.16, false],
	&"attack": [COMBAT, 0, 8, 8.0 / 0.26, false],
	&"hurt": [REACTION, 0, 4, 4.0 / 0.35, false],
	&"block": [REACTION, 4, 4, 4.0 / 0.22, false],
	&"death": [REACTION, 8, 8, 8.0 / 0.95, false],
	&"move_attack": [MOVING_COMBAT, 0, 8, 12.0, true],
	&"move_cast": [MOVING_COMBAT, 8, 8, 12.0, true],
	&"air_attack": [AIR, 0, 8, 8.0 / 0.26, false],
	&"air_cast": [AIR, 8, 8, 8.0 / 0.28, false],
	&"heal": [SUPPORT, 0, 4, 10.0, false],
	&"shield": [SUPPORT, 4, 4, 4.0 / 0.36, false],
	&"blink_out": [SUPPORT, 8, 4, 25.0, false],
	&"blink_in": [SUPPORT, 12, 4, 4.0 / 0.28, false],
	&"double_jump": [EXTRA, 0, 4, 4.0 / 0.24, false],
	&"brake": [EXTRA, 4, 4, 20.0, false],
	&"interact": [EXTRA, 8, 4, 12.5, false],
	&"victory": [EXTRA, 12, 4, 7.0, false],
}
static var _frames: SpriteFrames
static var _metadata: Dictionary
static var _units_per_pixel: Dictionary

static func metadata() -> Dictionary:
	if not _metadata.is_empty():
		return _metadata
	for path in [ROOT + "atlas_metadata.json"]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			_metadata.merge(parsed, true)
	return _metadata

static func make_frames() -> SpriteFrames:
	if Characters.current_id()==&"xixifu":return XixifuArt.make_frames()
	if _frames != null:
		return _frames
	_frames = SpriteFrames.new()
	_frames.remove_animation(&"default")
	for animation: StringName in ANIMATIONS:
		var spec: Array = ANIMATIONS[animation]
		var path := str(spec[0])
		var source := load(path) as Texture2D
		var info: Dictionary = metadata()[path.get_file()]
		var regions: Array = info["regions"]
		var ratio := float(source.get_width()) / float(info["source_size"][0])
		var action_heights: Dictionary = info.get("action_heights", {})
		_units_per_pixel[animation] = 1.0 / (float(action_heights.get(str(animation), info["upright_height"])) * ratio)
		_frames.add_animation(animation)
		_frames.set_animation_speed(animation, float(spec[3]))
		_frames.set_animation_loop(animation, bool(spec[4]))
		for frame in int(spec[2]):
			var index := int(spec[1]) + frame
			var rect: Array = regions[index]
			var bounds: Array = info["rects"][index]
			var start := Vector2(floorf((float(rect[0]) + float(bounds[0])) * ratio), floorf((float(rect[1]) + float(bounds[1])) * ratio))
			var end := Vector2(ceilf((float(rect[0]) + float(bounds[0]) + float(bounds[2])) * ratio), ceilf((float(rect[1]) + float(bounds[1]) + float(bounds[3])) * ratio))
			var atlas := AtlasTexture.new()
			atlas.atlas = source
			atlas.region = Rect2(start, end - start)
			var anchor: Array = info["anchors"][index]
			var padding_x := LOGICAL_FRAME.x * 0.5 - ((float(rect[0]) + float(anchor[0])) * ratio - start.x)
			var padding_y := FOOT_Y - ((float(rect[1]) + float(anchor[1])) * ratio - start.y)
			atlas.margin = Rect2(Vector2(padding_x, padding_y), LOGICAL_FRAME - atlas.region.size)
			atlas.filter_clip = true
			_frames.add_frame(animation, atlas)
	return _frames

static func align(sprite: AnimatedSprite2D, height := WORLD_HEIGHT) -> void:
	if Characters.current_id()==&"xixifu":XixifuArt.align(sprite);return
	if not ANIMATIONS.has(sprite.animation):
		return
	var scale_factor := height * float(_units_per_pixel[sprite.animation])
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = Vector2(0, 21.0 - (FOOT_Y - LOGICAL_FRAME.y * 0.5) * scale_factor)
