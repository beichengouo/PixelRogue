class_name BossPatternWarning
extends Node2D
var room:RoomLevel
var spec:Dictionary={}
var age:=0.0
var duration:=.8
var tint:=Color("ff776f")
static func create(parent:Node,level:RoomLevel,data:Dictionary,seconds:float,color:Color)->BossPatternWarning:
	var warning:=BossPatternWarning.new();warning.room=level;warning.spec=data.duplicate(true);warning.duration=seconds;warning.tint=color
	parent.add_child(warning);warning.position=data.get("at",Vector2.ZERO);return warning
func _ready()->void:
	AudioManager.play(&"boss_warning",-13,0)
	z_index=800;z_as_relative=false;add_to_group("boss_pattern_warnings")
	var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;material=ink
func _physics_process(dt:float)->void:
	age+=dt
	if age>=duration:queue_free();return
	queue_redraw()
func _point(at:Vector2)->void:
	if not is_instance_valid(room) or not room.bounds().grow(-4).has_point(global_position+at):return
	draw_rect(Rect2(at-Vector2.ONE*1.5,Vector2.ONE*3),Color(tint,.45+.5*clampf(age/duration,0,1)))
func _draw()->void:
	var shape:=str(spec.get("shape","circle"));var radius:=float(spec.get("radius",60));var direction:Vector2=spec.get("dir",Vector2.RIGHT)
	match shape:
		"line":
			var end:Vector2=spec.get("end",global_position+direction*radius)-global_position
			var length:=end.length();var normal:=end.normalized().orthogonal()*float(spec.get("width",18))
			for index in maxi(2,int(length/8)):
				var at:=end*float(index)/maxf(1,int(length/8)-1);_point(at+normal);_point(at-normal)
		"fan":
			var spread:=float(spec.get("spread",1.0))
			for side in [-.5,.5]:
				for distance in range(18,int(radius),8):_point(direction.rotated(spread*side)*distance)
			for index in 48:_point(direction.rotated(spread*(float(index)/47-.5))*radius)
		"ring":
			var gap:Vector2=spec.get("gap",direction);var opening:=float(spec.get("opening",.8))
			for index in 80:
				var ray:=Vector2.from_angle(index*TAU/80)
				if absf(gap.angle_to(ray))<opening*.5:continue
				_point(ray*radius)
		_:
			for index in 64:_point(Vector2.from_angle(index*TAU/64)*radius)
