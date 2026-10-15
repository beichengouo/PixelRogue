extends Node

func _ready() -> void:
	call_deferred("_capture")

func _capture() -> void:
	get_tree().root.size=Vector2i(1280,720)
	var editor := load("res://tools/room_editor/room_editor.tscn").instantiate() as RoomTemplateEditor
	get_tree().root.add_child(editor)
	await get_tree().process_frame
	var template_id := "wetland_curve"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--template="):template_id=argument.trim_prefix("--template=")
	for item in editor.pool.templates:
		if item.id==template_id:editor.document=item.duplicate(true);editor._sync();editor._changed();break
	if "--move-building" in OS.get_cmdline_user_args():
		for entry in editor.document.layers.decor:
			if str(entry.asset_id)=="service:building_shop":entry.at=[int(entry.at[0])+10,int(entry.at[1])+2]
	if "--preview" in OS.get_cmdline_user_args():
		editor._preview_toggle.button_pressed=true
	var suffix := "canvas"
	if "--preview" in OS.get_cmdline_user_args():suffix="day"
	if "--night" in OS.get_cmdline_user_args():editor._environment.select(2);editor._environment.item_selected.emit(2);suffix="night"
	if "--fog" in OS.get_cmdline_user_args():editor._environment.select(3);editor._environment.item_selected.emit(3);suffix="fog"
	for i in 5:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	if template_id!="wetland_curve":suffix=template_id+"-"+suffix+("-moved" if "--move-building" in OS.get_cmdline_user_args() else "")
	image.save_png("E:/CodexWorkspace/PixelRogue/temp/room-editor-visual-qa-"+suffix+".png")
	print("ROOM_EDITOR_VISUAL_CAPTURE_OK "+suffix)
	get_tree().quit()
