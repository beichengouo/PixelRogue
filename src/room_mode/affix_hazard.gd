class_name AffixHazard
extends Node2D
static var trail_hit_at:Dictionary={}

## Detached room effects: their lifetime does not depend on the casting enemy.
var room: RoomLevel
var mode: StringName = &"ring"
var direction := Vector2.RIGHT
var damage := 0.0
var lifetime := 0.18
var age := 0.0
var tick_left := 0.0
var source_ref: WeakRef
var source_key:=0
var cruel_damage:=false
var _struck := false
var pending_hits:Array=[]

static func create(parent:Node, level:RoomLevel, kind:StringName, at:Vector2, aim:Vector2, amount:float, source:Node)->AffixHazard:
	var hazard:=AffixHazard.new()
	hazard.room=level;hazard.mode=kind;hazard.direction=aim.normalized() if aim.length_squared()>0.01 else Vector2.RIGHT
	hazard.damage=amount;hazard.source_ref=weakref(source) if is_instance_valid(source) else null
	hazard.source_key=source.get_instance_id() if is_instance_valid(source) else 0
	hazard.cruel_damage=CruelDamage.applies(source)
	hazard.lifetime=3.0 if kind==&"grave" else (2.0 if kind==&"trail" else 0.18)
	if kind==&"grave":hazard.age=-0.9
	parent.add_child(hazard);hazard.global_position=at
	if kind in [&"ring",&"line"]:hazard._strike()
	return hazard

func _ready()->void:
	add_to_group("affix_hazards")
	z_index=800;z_as_relative=false
	var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;material=ink

func _physics_process(dt:float)->void:
	if not is_instance_valid(room):queue_free();return
	if mode==&"grave" and age<0 and not is_in_group("new_affix_warning"):
		if get_tree().get_nodes_in_group("new_affix_warning").size()>=2:return
		add_to_group("new_affix_warning")
	age+=dt
	if age>=0 and is_in_group("new_affix_warning"):remove_from_group("new_affix_warning")
	if mode in [&"grave",&"trail"] and age>=0:
		tick_left-=dt
		if tick_left<=0:
			tick_left+=0.5
			_strike()
	if age>=lifetime:queue_free();return
	queue_redraw()

func _strike()->void:
	if mode in [&"ring",&"line"] and _struck:return
	_struck=true
	for body in _targets():
		if not _inside(body.global_position):continue
		if not room.bounds().grow(-6).has_point(body.global_position):continue
		if not room.projectile_clear(global_position,body.global_position):continue
		if mode==&"trail":
			var key:String="%d:%d" % [source_key,body.get_instance_id()]
			var now:=Time.get_ticks_msec()
			if now-int(trail_hit_at.get(key,-1000))<500:continue
			trail_hit_at[key]=now
			if trail_hit_at.size()>2048:
				for old_key in trail_hit_at.keys():
					if now-int(trail_hit_at[old_key])>2000:trail_hit_at.erase(old_key)
		var source:Node=source_ref.get_ref() if source_ref!=null else null
		if not is_instance_valid(source):source=self
		body.take_damage(damage,global_position,source)
		if mode==&"line" and body.has_method("apply_slow"):body.apply_slow(0.35,2.0)

func _targets()->Array[Node2D]:
	var out:Array[Node2D]=[]
	if is_instance_valid(room) and is_instance_valid(GameState.player):
		var hero:=GameState.player as Node2D
		if hero!=null and float(hero.get("hp"))>0:out.append(hero)
	for node in get_tree().get_nodes_in_group("allies"):
		if node is Node2D and is_instance_valid(node) and not node.is_queued_for_deletion() and float(node.get("hp"))>0:
			if node.get("room")==room:out.append(node)
	return out

func _inside(at:Vector2)->bool:
	var offset:Vector2=at-global_position
	match mode:
		&"ring":return offset.length()>=72 and offset.length()<=144
		&"line":return offset.dot(direction)>=0 and offset.dot(direction)<=180 and absf(offset.cross(direction))<=18
		&"trail":return offset.length()<=13
		&"grave":return offset.length()<=72
	return false

func _draw()->void:
	if not is_instance_valid(room):return
	if mode==&"grave" and age<0 and not is_in_group("new_affix_warning"):return
	var color:=Color("ff6d50") if mode in [&"trail",&"grave"] else (Color("a9db73") if mode==&"line" else Color("ffba62"))
	if mode in [&"ring",&"grave"]:
		var outer:=144.0 if mode==&"ring" else 72.0
		for i in 64:
			var at:Vector2=Vector2.from_angle(TAU*i/64.0)*outer
			if _visual_point(at):draw_rect(Rect2(at.round(),Vector2(3,3)),Color(color,0.65))
		if mode==&"ring":
			for i in 48:
				var at:Vector2=Vector2.from_angle(TAU*i/48.0)*72
				if _visual_point(at):draw_rect(Rect2(at.round(),Vector2(2,2)),Color(color,0.6))
	elif mode==&"line":
		for i in 19:
			var at:Vector2=direction*float(i)*10
			for side in [-18.0,18.0]:
				var point:Vector2=at+direction.orthogonal()*side
				if _visual_point(point):draw_rect(Rect2(point.round(),Vector2(3,3)),Color(color,0.7))
	else:
		for i in 24:
			var p:Vector2=Vector2.from_angle(TAU*i/24.0)*13
			if _visual_point(p):draw_rect(Rect2(p.round(),Vector2(3,3)),Color(color,0.65))

func _visual_point(offset:Vector2)->bool:
	var at:=global_position+offset
	return room.bounds().grow(-4).has_point(at) and room.projectile_clear(global_position,at)

func snapshot()->Dictionary:
	var hits:Array=[]
	var prefix:=str(source_key)+":"
	var now:=Time.get_ticks_msec()
	if mode==&"trail":
		for key in trail_hit_at:
			if str(key).begins_with(prefix) and now-int(trail_hit_at[key])<500:
				hits.append({"victim":str(key).trim_prefix(prefix),"left":500-now+int(trail_hit_at[key])})
	return {"kind":str(mode),"at":[global_position.x,global_position.y],"dir":[direction.x,direction.y],"damage":damage,"life":lifetime,"age":age,"tick":tick_left,"struck":_struck,"source_key":source_key,"hit_cooldowns":hits,"cruel_damage":cruel_damage}

func restore_hit_cooldowns(ids:Dictionary)->void:
	for hit in pending_hits:
		var body:Node=ids.get(str(hit.get("victim","")))
		if is_instance_valid(body):trail_hit_at["%d:%d"%[source_key,body.get_instance_id()]]=Time.get_ticks_msec()-500+clampi(int(hit.get("left",0)),0,500)
	pending_hits.clear()

static func restore_hazard(parent:Node,level:RoomLevel,data:Dictionary)->AffixHazard:
	var hazard:=AffixHazard.new()
	hazard.room=level;hazard.mode=StringName(data.get("kind","grave"))
	var at:Array=data.get("at",[0,0]);var aim:Array=data.get("dir",[1,0])
	hazard.direction=Vector2(float(aim[0]),float(aim[1])).normalized()
	hazard.damage=float(data.get("damage",0));hazard.lifetime=float(data.get("life",3))
	hazard.source_key=int(data.get("source_key",0))
	hazard.cruel_damage=bool(data.get("cruel_damage",false))
	hazard.age=float(data.get("age",0));hazard.tick_left=float(data.get("tick",0))
	hazard._struck=bool(data.get("struck",true))
	hazard.pending_hits=data.get("hit_cooldowns",[]).duplicate(true)
	parent.add_child(hazard);hazard.global_position=Vector2(float(at[0]),float(at[1]))
	return hazard
