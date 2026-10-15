class_name LightUtil
extends RefCounted
## 2D 光照的小工具：统一提供"圆形光贴图"和创建点光的函数。
##
## Godot 的 PointLight2D 必须给一张贴图，通常是一张中心亮、边缘透明的圆形渐变。
## 这里用 GradientTexture2D 现做一张（不用美术素材），全局只做一次、所有灯共用。

static var _radial: Texture2D = null


static func radial_texture() -> Texture2D:
	## 中心纯白不透明 → 边缘全透明，径向渐变。
	if _radial == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 128
		tex.height = 128
		_radial = tex
	return _radial


static func make_point_light(
	color: Color,
	energy: float,
	radius: float,
	casts_shadow := false
) -> PointLight2D:
	## radius 是"光能照到多大范围"（像素），内部换算成贴图缩放。
	var light := PointLight2D.new()
	light.add_to_group("room_point_lights")
	light.texture = radial_texture()
	light.color = color
	light.energy = energy
	light.texture_scale = maxf(0.05, radius / 64.0)
	light.shadow_enabled = casts_shadow
	if casts_shadow:
		# 先都用默认值：之前设了 PCF5 + smooth=2.0，结果整盏灯不亮了
		# （在 GL Compatibility 渲染器下），所以阴影参数保持引擎默认最稳。
		light.shadow_filter = Light2D.SHADOW_FILTER_NONE
		light.shadow_filter_smooth = 0.0
	light.blend_mode = Light2D.BLEND_MODE_ADD
	# Active room games use a single non-additive environment composite.
	# Keep this light as a descriptor while excluding native shaded-item addition.
	var runtime:Node=GameState.runtime_node
	var main:Variant=runtime.get("main") if is_instance_valid(runtime) else null
	if is_instance_valid(main) and main.get("room_weather")!=null:light.range_item_cull_mask=0
	light.z_index = 1
	return light
