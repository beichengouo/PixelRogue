class_name BossPatternWarning
extends Node2D
var room:RoomLevel
var spec:Dictionary={}
var age:=0.0
var duration:=.8
const ATTACK_RED:=Color("ff454f")
var tint:=ATTACK_RED
static func create(parent:Node,level:RoomLevel,data:Dictionary,seconds:float,color:Color)->BossPatternWarning:
	var warning:=BossPatternWarning.new();warning.room=level;warning.spec=data.duplicate(true);warning.duration=seconds;warning.tint=Color("85ebbd") if bool(data.get("safe_corridor",false)) else ATTACK_RED
	parent.add_child(warning);warning.position=data.get("at",Vector2.ZERO);return warning
func _ready()->void:
	AudioManager.play(&"boss_warning",-13,0)
	z_index=800;z_as_relative=false;add_to_group("boss_pattern_warnings")
	var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;material=ink
func _physics_process(dt:float)->void:
	age+=dt
	if age>=duration:queue_free();return
	queue_redraw()
var _boundary:=PackedVector2Array()
func _draw()->void:
	if _boundary.is_empty():
		for point in AttackGeometry.outline(spec):
			if is_instance_valid(room) and room.bounds().grow(-4).has_point(global_position+point):_boundary.append(point)
	var progress:=clampf(age/maxf(.001,duration),0,1)
	for index in _boundary.size():
		var point:=_boundary[index]
		draw_rect(Rect2(point-Vector2.ONE*2,Vector2.ONE*4),Color(.09,.025,.04,.9))
		draw_rect(Rect2(point-Vector2.ONE,Vector2.ONE*2),Color(tint,.65+.35*progress))
		if float(index)/maxi(1,_boundary.size())<=progress:draw_rect(Rect2(point-Vector2.ONE*1.5,Vector2.ONE*3),Color(tint,.95))
