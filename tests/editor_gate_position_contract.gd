extends Node

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var original := RoomTemplateCodec.read_file("res://assets/room_templates/forest_clearing.json")
	var moved := original.duplicate(true)
	var directions := {"north":Vector2i.UP,"east":Vector2i.RIGHT,"south":Vector2i.DOWN,"west":Vector2i.LEFT}
	for port in moved.ports:
		if str(port.side) in ["north","south"]:port.at[0]+=1
		else:port.at[1]+=1
	check(RoomTemplateValidator.validate(moved).is_empty(),"four moved entrances remain valid")
	var room: RoomLevel = load("res://src/room_mode/room_level.tscn").instantiate();add_child(room)
	room.load_room(_record(original))
	var original_frame := room.illustration.frame_rect()
	var original_positions := {}
	var original_scales := {}
	for side in directions:
		original_positions[side]=room.illustration.gates[side].position
		original_scales[side]=room.illustration.gates[side].scale
	room.load_room(_record(moved))
	check(room.illustration.frame_rect()==original_frame,"room artwork frame remains fixed")
	for side in directions:
		var offset := RoomSceneArtwork.gate_offset(side,moved.ports)
		var gate: Sprite2D = room.illustration.gates[side]
		check(gate.position==original_positions[side]+offset,"moved "+side+" gate art aligns with port")
		check(gate.scale==original_scales[side],"moved "+side+" gate keeps original size")
		var direction: Vector2i = directions[side]
		var port: Dictionary = moved.ports.filter(func(item):return str(item.side)==side)[0]
		var point := room.door_point(direction)
		check(is_equal_approx(point.x,(float(port.at[0])+0.5)*36.0) if direction.y!=0 else is_equal_approx(point.y,(float(port.at[1])+0.5)*36.0),"moved "+side+" trigger follows port")
		check(room.door_at(point)==direction,"moved "+side+" door trigger activates")
	var path := "E:/CodexWorkspace/PixelRogue/temp/editor_gate_position_contract.json"
	check(RoomTemplateCodec.write_file(path,moved)==OK,"moved entrances save to isolated JSON")
	var reloaded := RoomTemplateCodec.read_file(path)
	check(reloaded.ports==moved.ports,"all four moved entrances survive JSON round trip")
	check(int(original.ports[0].at[0])==11 and int(original.ports[0].at[1])==0 and int(original.ports[1].at[0])==22 and int(original.ports[1].at[1])==5,"source template retains original ports")
	var editor := RoomTemplateEditor.new();add_child(editor)
	await get_tree().process_frame
	editor.document=original.duplicate(true);editor._sync()
	for port in original.ports:
		var start := Vector2i(int(port.at[0]),int(port.at[1]))
		var end := start+(Vector2i.RIGHT if str(port.side) in ["north","south"] else Vector2i.DOWN)
		editor._gesture("port",start,end,[])
	var editor_ports_match := true
	for i in moved.ports.size():
		for axis in 2:
			if int(editor.document.ports[i].at[axis])!=int(moved.ports[i].at[axis]):editor_ports_match=false
	check(editor_ports_match,"editor tool moves all four entrances")
	var preview := RoomTemplatePreview.new();preview.visible=true;add_child(preview)
	preview.set_document(moved)
	for side in directions:
		check(preview.level.illustration.gates[side].position==room.illustration.gates[side].position,"preview "+side+" gate matches runtime")
	print("EDITOR_GATE_POSITION checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)

func _record(data: Dictionary) -> Dictionary:
	return {"id":"0,0","seed":7,"kind":"normal","biome":"forest","doors":["0,-1","1,0","0,1","-1,0"],"cleared":true,"delta":{},"terrain_layout":RoomTemplateCodec.to_layout(data)}
