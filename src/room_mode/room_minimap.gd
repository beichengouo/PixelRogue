class_name RoomMinimap
extends Control
var graph:RoomGraph
var expanded:=false
var map_zoom:=1.0
var pan:=Vector2.ZERO
var _dragging:=false
var _touches:Dictionary={}
func _ready()->void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter=Control.MOUSE_FILTER_STOP if expanded else Control.MOUSE_FILTER_IGNORE

static func _record_has_pickup(entity: Dictionary) -> bool:
	var fields: Dictionary = entity.get("fields", {})
	match str(entity.get("script", "")):
		"res://src/room_mode/room_loot_drop.gd":
			return not bool(fields.get("_collected", false)) and not fields.get("contents", []).is_empty()
		"res://src/room_mode/room_key.gd":
			return not bool(fields.get("_collected", false))
		"res://src/actors/glow_mushroom.gd":
			return not bool(fields.get("_harvested", false)) and float(fields.get("_grow", 0.0)) >= 1.0
	return false

func has_pickups(id: String) -> bool:
	if graph == null or not graph.rooms.has(id): return false
	if id == graph.current and is_instance_valid(GameState.runtime_node):
		var main: Variant = GameState.runtime_node.get("main")
		if is_instance_valid(main) and main.get("graph") == graph:
			for parent in [main.fx_root, main.chests_root, main.actors_root]:
				if not is_instance_valid(parent): continue
				for node in parent.get_children():
					if not is_instance_valid(node) or node.is_queued_for_deletion(): continue
					if node is RoomLootDrop and not node._collected and not node.contents.is_empty(): return true
					if node is RoomKey and not node._collected: return true
					if node is GlowMushroom and not node._harvested and node._grow >= 1.0: return true
			return false
	var runtime: Dictionary = graph.rooms[id].get("delta", {}).get("runtime", {})
	for entity in runtime.get("entities", []):
		if entity is Dictionary and _record_has_pickup(entity): return true
	return false

func _draw_pickup_marker(at: Vector2) -> void:
	# One small pouch; it stays outside the room/type glyph and reads at minimap scale.
	var ink := Color("253343")
	var gold := Color("ffe5a4")
	draw_rect(Rect2(at - Vector2(4, 3), Vector2(8, 7)), ink)
	draw_rect(Rect2(at - Vector2(3, 2), Vector2(6, 5)), gold)
	draw_line(at + Vector2(-2, -4), at + Vector2(2, -4), gold, 2)
	draw_line(at + Vector2(-3, -1), at + Vector2(3, -1), ink, 1)
func _draw()->void:
	if graph==null or graph.rooms.is_empty() or size.x<=28 or size.y<=28:return
	draw_style_box(PixelUi.style(Color(0.03,0.08,0.12,0.65),Color("607f86"),6,1),Rect2(Vector2.ZERO,size))
	var origin:=size/2+pan
	var step:=36.0
	var nearby:Array[String]=[]
	var center:=Vector2(RoomGraph.cell(graph.current))
	if expanded:
		nearby.assign(graph.rooms.keys())
		var lower:=center;var upper:=center
		for id in nearby:
			var at:=Vector2(RoomGraph.cell(id));lower=lower.min(at);upper=upper.max(at)
		center=(lower+upper)*.5
		step=minf(44,minf((size.x-80)/(upper.x-lower.x+1),(size.y-60)/(upper.y-lower.y+1)))*map_zoom
	else:
		for y in range(-3,4):
			for x in range(-4,5):
				var id:=RoomGraph.key(RoomGraph.cell(graph.current)+Vector2i(x,y))
				if graph.rooms.has(id):nearby.append(id)
	for id in nearby:
		var cell:=Vector2(RoomGraph.cell(id))-center
		var at:=origin+cell*step
		if not Rect2(Vector2(14,14),size-Vector2(28,28)).has_point(at):continue
		var record:Dictionary=graph.rooms[id]
		for next in record.doors:
			var direction:=RoomGraph.cell(str(next))-RoomGraph.cell(id)
			draw_line(at,at+Vector2(direction)*step*.5,Color("7b9b92"),2)
		var tint:=Color("eaba87") if record.kind=="boss" else (Color("80c8b5") if record.cleared else Color("728291"))
		if record.kind=="shop":tint=Color("f3ce75")
		elif record.kind=="tavern":tint=Color("da9ccc")
		if id==graph.current:tint=Color("ffe5a4")
		var block:=Vector2(minf(22,step*.62),minf(18,step*.5)) if expanded else Vector2(22,18)
		draw_rect(Rect2(at-block*.5,block),tint)
		if id==graph.current:draw_rect(Rect2(at-block*.5-Vector2.ONE*3,block+Vector2.ONE*6),Color("ffe5a4"),false,2)
		var icon:=SpecialRoomArt.room_icon(str(record.kind))
		if icon!=null:
			var extent:Vector2=Vector2.ONE*(minf(28,step*.70) if expanded else 26.0)
			draw_texture_rect(icon,Rect2(at-extent*.5,extent),false)
		if id != graph.current and has_pickups(id):
			_draw_pickup_marker(at + Vector2(block.x * 0.5 + 3, -block.y * 0.5 - 2))

func _gui_input(event:InputEvent)->void:
	if not expanded:return
	if MobileControls.enabled():
		if event is InputEventScreenTouch:
			if event.pressed:_touches[event.index]=event.position
			else:_touches.erase(event.index)
			accept_event()
		elif event is InputEventScreenDrag and _touches.has(event.index):
			if _touches.size()==1:pan+=event.relative
			elif _touches.size()==2:
				var keys:=_touches.keys();var old:float=(_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]])
				_touches[event.index]=event.position
				var distance:float=(_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]])
				if old>4:map_zoom=clampf(map_zoom*distance/old,.7,4.0)
			_touches[event.index]=event.position;queue_redraw();accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:_dragging=event.pressed;accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			map_zoom=clampf(map_zoom*(1.15 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.15),0.7,4.0);queue_redraw();accept_event()
	elif event is InputEventMouseMotion and _dragging:pan+=event.relative;queue_redraw();accept_event()
