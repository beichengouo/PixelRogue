class_name BossActor
extends BossBase
## 通用 Boss 实现：招式表全部数据驱动（BossRoster），三个 Boss 只用不同参数 + 招式组合。
## 这样加 Boss 不用写新脚本，改 BossRoster 就行。

var roster: Dictionary = {}
var _minion_kinds: Array = []


static func create(id: StringName) -> BossBase:
	var boss := BossActor.new()
	boss.configure(id)
	return boss


func configure(id: StringName) -> void:
	roster = BossRoster.get_data(id)
	boss_id = id
	boss_title = str(roster["title"])
	boss_icon = BossRoster.icon_path(id)
	display_name = boss_title
	kind = StringName("boss_%s" % str(id))
	base_hp = float(roster["hp"])
	base_damage = float(roster["damage"])
	base_speed = float(roster["speed"])
	base_coins = int(roster["coins"])
	body_color = Color(str(roster["color"]))
	body_size = roster["size"]
	art_scale = float(roster["scale"])
	sprite_name = str(roster["strip"])
	uses_gravity = bool(roster["gravity"])
	collides_with_world = uses_gravity
	_minion_kinds = roster.get("minions", [&"walker"])
	max_phase = 3 if id != BossRoster.KING else 2
	## Boss 永远带"最高危险度"光环（金红），一眼能从小怪里认出来
	danger = 9


func minion_kinds() -> Array:
	return _minion_kinds


func _build_visual() -> void:
	## 独立原创图集，使用统一画布和脚底锚点。
	if PixelBossArt.HEIGHTS.has(boss_id):
		var anim := AnimatedSprite2D.new()
		anim.name = "Visual"
		anim.sprite_frames = PixelBossArt.make_frames(boss_id)
		anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		anim.material = PixelSpellArt.material()
		anim.centered = true
		add_child(anim)
		anim.play(&"idle")
		visual = anim
		return
	_build_polygon_placeholder()


