extends Node
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _ready()->void:call_deferred("run")
func mouse(canvas:RoomEditorCanvas,world:Vector2,pressed:bool)->void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
	event.position=(world+canvas._origin)*canvas.zoom
	canvas._gui_input(event)
func run()->void:
	var editor:=RoomTemplateEditor.new();add_child(editor)
	await get_tree().process_frame
	var source:=RoomTemplateCodec.read_file("res://assets/room_templates/boss_king_court.json")
	var pool:=RoomTemplatePool.new();pool.reload()
	for template in pool.templates:
		var same_bounds:=template.duplicate(true)
		var bounds:=RoomEditorCollision.bounds(template)
		same_bounds.room_bounds_override=[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
		check(RoomTemplateValidator.validate(same_bounds).is_empty(),"unchanged explicit bounds keep template valid: "+str(template.id))
	for index in 8:
		editor.document=source.duplicate(true);editor._sync();editor.canvas.tool="collision";editor.canvas.collision_target="room_bounds"
		var start:=RoomEditorCollision.bounds_handles(source)[index]
		var desired:=start+Vector2(20 if index in [0,6,7] else (-20 if index in [2,3,4] else 0),20 if index in [0,1,2] else (-20 if index in [4,5,6] else 0))
		var expected:=RoomEditorCollision.moved_bounds(source,index,desired)
		mouse(editor.canvas,start,true)
		var motion:=InputEventMouseMotion.new();motion.button_mask=MOUSE_BUTTON_MASK_LEFT;motion.position=(desired+editor.canvas._origin)*editor.canvas.zoom
		editor.canvas._gui_input(motion)
		mouse(editor.canvas,desired,false)
		check(editor.document.get("room_bounds_override",[])==expected,"handle %d drag commits without rebound: %s"%[index,editor._status.text])
		check(editor.canvas._collision_drag_index==-1,"handle %d releases mouse gesture"%index)
		editor._undo_edit()
		check(RoomEditorCollision.bounds(editor.document)==RoomEditorCollision.bounds(source),"handle %d undo restores bounds"%index)
		editor._redo_edit()
		check(editor.document.get("room_bounds_override",[])==expected,"handle %d redo keeps dragged bounds"%index)
	var tightened:=source.duplicate(true)
	tightened.room_bounds_override=RoomEditorCollision.moved_bounds(source,5,Vector2(414,448))
	var errors:=RoomTemplateValidator.validate(tightened)
	check(errors.is_empty(),"real illustrated room bottom adjustment validates: "+"; ".join(errors))
	if errors.is_empty():
		var path:="E:/CodexWorkspace/PixelRogue/temp/editor-bounds-drag-saved.json"
		check(RoomTemplateCodec.write_file(path,tightened)==OK,"adjusted illustrated bounds save")
		var reloaded:=RoomTemplateCodec.read_file(path)
		check(RoomEditorCollision.bounds(reloaded)==Rect2(0,0,828,448),"adjusted bounds survive reopening")
		check(RoomTemplateCodec.to_layout(reloaded).get("room_rect",[])==tightened.room_bounds_override,"saved bounds reach runtime layout")
	editor.document=RoomTemplateCodec.blank();editor._sync()
	editor._collision_edit("room_bounds","move",1,Vector2(414,200))
	check(RoomEditorCollision.bounds(editor.document).position.y==200,"temporarily invalid route remains editable")
	check(not editor._validate(),"explicit validation still rejects blocked/outside entrances")
	check(RoomEditorCollision.bounds(editor.document).position.y==200,"validation failure never rolls back draft")
	editor._collision_restore()
	check(not editor.document.has("room_bounds_override"),"restore default removes edited bounds")
	var blocked:=RoomTemplateCodec.blank()
	blocked.room_bounds_override=[0,0,828,468]
	var water_key:=RoomEditorCollision.add_water(blocked)
	RoomEditorCollision.assign(blocked,water_key,[[390,36],[440,36],[440,80],[390,80]])
	check(not RoomTemplateValidator.validate(blocked).is_empty(),"explicit bounds still reject real entrance collision")
	print("EDITOR_BOUNDS_DRAG checks=",checks," failures=",failures)
	editor.queue_free();await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
