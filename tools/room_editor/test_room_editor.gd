extends Node
var failures: Array[String] = []
var check_count := 0

func _ready() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	check_count+=1
	if not condition:failures.append(message);printerr("FAIL: "+message)

func _run() -> void:
	var pool := RoomTemplatePool.new();pool.reload()
	check(pool.rejected.is_empty(),"All authored templates valid: "+str(pool.rejected))
	check(pool.templates.size()>=15,"At least 15 authored templates")
	var counts := {"normal":0,"shop":0,"tavern":0,"boss":0}
	for template in pool.templates:
		counts[str(template.room_kinds[0])]+=1
		var layout := RoomTemplateCodec.to_layout(template)
		check(not layout.is_empty(),"Template imports: "+str(template.id))
		check(layout.get("room_rect",[]).size()==4 and layout.get("ports",[]).size()==4,"Size and port contract: "+str(template.id))
		check(layout.get("ground",[]).size()==int(template.grid.size[0])*int(template.grid.size[1]),"Complete explicit ground: "+str(template.id))
		if str(template.room_kinds[0]) in ["shop","tavern"]:
			check(layout.get("service_layout",false) and layout.get("service_props",[]).size()==9 and layout.decor.is_empty(),"Exactly nine authored service props and no duplicate decor: "+str(template.id))
			var expected := _original_service_props(str(template.room_kinds[0]))
			for i in expected.size():
				var prop: Dictionary = layout.service_props[i]
				check(prop.asset==expected[i][0] and Vector2(prop.position_px[0],prop.position_px[1])==Vector2(expected[i][1][0],expected[i][1][1]) and float(prop.width_px)==float(expected[i][2]) and float(prop.depth_px)==float(expected[i][3]),"Fixed-layout coordinates and dimensions preserved: "+str(template.id)+" "+str(i))
	check(counts.normal==8 and counts.shop==2 and counts.tavern==2 and counts.boss==3,"Expected pool classifications: "+str(counts))
	for boss in ["king","mage","tide"]:
		var chosen := pool.select(12345,"boss:"+boss,"forest")
		check(not chosen.is_empty() and chosen.tags.has("boss:"+boss),"Boss-specific pool selection: "+boss)
	check(pool.select(8,"spawn","forest").is_empty(),"Unknown kind safely falls back")
	var first := pool.select(77,"normal","forest")
	check(first==pool.select(77,"normal","forest"),"Seeded selection repeatable")
	var original := pool.templates.duplicate(true)
	first.layers.obstacles.clear()
	check(pool.templates==original,"Selected data isolated from pool mutation")
	for size in [Vector2i(19,11),Vector2i(23,13),Vector2i(27,15),Vector2i(31,19)]:
		check(RoomTemplateValidator.validate(RoomTemplateCodec.blank(size)).is_empty(),"Supported blank size: "+str(size))
	var data := RoomTemplateCodec.blank()
	data.layers.obstacles.append({"id":"bad","asset_id":"unknown","at":[2,2]})
	check(not RoomTemplateValidator.validate(data).is_empty() and RoomTemplateCodec.to_layout(data).is_empty(),"Unknown assets prohibited")
	data=RoomTemplateCodec.blank();data.layers.obstacles.append({"id":"bad","asset_id":"terrain:boulder:2x2","at":[22,12]})
	check(not RoomTemplateValidator.validate(data).is_empty(),"Multi-cell out of bounds detected")
	data=RoomTemplateCodec.blank();data.layers.obstacles.append({"id":"gate","asset_id":"terrain:boulder:1x1","at":[11,2]})
	check(not RoomTemplateValidator.validate(data).is_empty(),"Blocked door approach detected")
	data=RoomTemplateCodec.blank()
	for y in range(1,12):
		if y==6:continue
		data.layers.obstacles.append({"id":"wall_%d" % y,"asset_id":"terrain:boulder:1x1","at":[8,y]})
	var corridor_errors := RoomTemplateValidator.validate(data)
	check(not corridor_errors.is_empty(),"One-cell gap rejected for large bodies")
	data=RoomTemplateCodec.blank();data.ports.pop_back()
	check(not RoomTemplateValidator.validate(data).is_empty(),"All four future sockets required")
	data=RoomTemplateCodec.blank();data.ports[0].at=[7,0]
	check(RoomTemplateValidator.validate(data).is_empty(),"Moved valid north socket accepted")
	data=RoomTemplateCodec.blank(Vector2i(23,13),"shop")
	check(RoomTemplateCodec.to_layout(data).get("service_layout",false) and RoomTemplateCodec.to_layout(data).service_props.is_empty(),"Empty authored shop suppresses fixed building fallback")
	data.layers.decor.append({"id":"bad_service","asset_id":"service:building_shop","at":[11,2]})
	check(not RoomTemplateValidator.validate(data).is_empty(),"Service building blocking north door rejected")
	data.layers.decor[0].at=[6,5];data.layers.decor[0].config={"offset_px":"wrong"}
	check(not RoomTemplateValidator.validate(data).is_empty(),"Malformed pixel offset reports error without throwing")
	data.layers.decor[0].config={"width_px":-1}
	check(not RoomTemplateValidator.validate(data).is_empty(),"Invalid service dimensions rejected")
	data.layers.decor[0].config={};data.layers.decor[0].at=[0,4]
	check(not RoomTemplateValidator.validate(data).is_empty(),"Pixel footprint out of room rejected")
	data=RoomTemplateCodec.blank();data.schema_version=999
	check(not RoomTemplateValidator.validate(data).is_empty(),"Unknown schema version rejected")
	var path := "E:/CodexWorkspace/PixelRogue/temp/room-editor-roundtrip.json"
	data=pool.templates[0].duplicate(true)
	check(RoomTemplateCodec.write_file(path,data)==OK,"Atomic JSON save")
	check(RoomTemplateCodec.read_file(path)==data,"JSON round-trip preserves document")
	check(RoomTemplateCodec.is_player_save("user://pixel_rogue_save.json.bak"),"Player-save backups recognized")
	check(RoomTemplateCodec.write_file("user://pixel_rogue_save.json",data)==ERR_UNAUTHORIZED,"Editor cannot overwrite player save")
	check(RoomTemplateCodec.read_file("user://pixel_rogue_story.json").is_empty(),"Editor cannot read player story")
	var scene := load("res://tools/room_editor/room_editor.tscn") as PackedScene
	var editor := scene.instantiate() as RoomTemplateEditor
	get_tree().root.add_child(editor)
	await get_tree().process_frame
	check(editor.canvas!=null and editor.canvas.document.grid.size==[23,13],"Independent editor creates UI")
	editor._layer.select(2);editor._selected="terrain:boulder:2x2"
	editor._gesture("brush",Vector2i(4,3),Vector2i(4,3),[Vector2i(4,3)])
	check(editor.document.layers.obstacles.size()==1,"Brush places multi-cell prop once")
	editor._gesture("move",Vector2i(5,4),Vector2i(7,4),[])
	check(editor.document.layers.obstacles[0].at==[6,3],"Move from any occupied cell keeps anchor offset")
	editor._gesture("erase",Vector2i(7,4),Vector2i(7,4),[Vector2i(7,4)])
	check(editor.document.layers.obstacles.is_empty(),"Erase entire multi-cell object")
	editor._undo_edit();check(editor.document.layers.obstacles.size()==1,"Undo restores multi-cell object")
	editor._redo_edit();check(editor.document.layers.obstacles.is_empty(),"Redo restores erase")
	editor._layer.select(0);editor._selected="floor:mud"
	editor._gesture("rect",Vector2i(4,4),Vector2i(6,5),[])
	check(editor.document.base_ground=="floor:grass" and editor.document.layers.ground.size()==6,"Normal floor rectangle preserves base and paints six cells")
	editor._undo_edit();check(editor.document.base_ground=="floor:grass","Per-cell floor undo")
	editor.document.room_kinds=["shop"];editor._sync()
	editor._gesture("rect",Vector2i(4,4),Vector2i(6,5),[])
	check(editor.document.layers.ground.size()==6,"Service-room rectangle fills individual grid cells")
	editor.document.room_kinds=["normal"];editor._sync()
	editor._gesture("port",Vector2i(11,0),Vector2i(8,0),[])
	check(editor.document.ports[0].at==[8,0],"Port dragging changes boundary position")
	check(RoomTemplateValidator.validate(editor.document).is_empty(),"Edited room remains importable")
	editor._width.value=27;editor._height.value=15;editor._resize()
	check(editor.document.grid.size==[27,15] and editor.document.ports[1].at[0]==26 and editor.document.ports[2].at[1]==14,"Editor resize updates boundary sockets")
	editor._undo_edit();check(editor.document.grid.size==[23,13],"Resize undo restores full document")
	var custom_id := "__editor_qa_"+str(Time.get_ticks_usec())
	editor.document=RoomTemplateCodec.blank();editor.document.id=custom_id;editor._sync();editor._save_to_pool()
	var custom_path := RoomTemplatePool.USER+"/"+custom_id+".json"
	check(FileAccess.file_exists(custom_path),"Save-to-pool persists under launched project user directory")
	var saved := RoomTemplateCodec.read_file(custom_path)
	check(saved.get("id","")==custom_id and saved.get("revision",0)==1,"New template JSON persists identity and revision")
	editor._save_to_pool();saved=RoomTemplateCodec.read_file(custom_path)
	check(saved.get("revision",0)==2,"Repeat save monotonically increments revision")
	var reloaded := RoomTemplatePool.new();reloaded.reload()
	check(reloaded.templates.any(func(item):return item.id==custom_id),"Fresh game pool loads user-authored template")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(custom_path))==OK,"Remove only this test's generated template")
	editor.canvas.hide();editor._preview.show()
	for template in pool.templates:
		editor._preview.set_document(template)
		check(editor._preview.level.record.terrain_layout.template_id==template.id,"Actual RoomLevel preview imports: "+str(template.id))
		check(editor._preview.level.room_rect.size==Vector2(int(template.grid.size[0])*36,int(template.grid.size[1])*36),"Preview physical room size exact: "+str(template.id))
		if str(template.room_kinds[0]) in ["shop","tavern"]:
			var level := editor._preview.level
			check(level.decor_root.get_children().filter(func(node):return node is RoomServiceProp).size()==9 and level.service_footprints.size()==9,"Runtime service preview has no fixed duplicates: "+str(template.id))
			check(level.service_building!=null,"Authored building becomes interaction building: "+str(template.id))
			for entry in template.layers.decor:
				var footprint := RoomEditorCatalog.service_footprint(entry)
				check(level.service_footprints.has(footprint),"Runtime footprint equals validator/canvas: "+str(entry.id))
				var actual: RoomServiceProp = level.decor_root.get_node(str(entry.id)) as RoomServiceProp
				var runtime_art: Rect2 = actual.art.global_transform*actual.art.get_rect()
				check(runtime_art.is_equal_approx(RoomEditorCatalog.service_art_rect(entry,actual.art.texture.get_size())),"Canvas sprite projection equals runtime bottom anchor: "+str(entry.id))
			check(editor.canvas._cell(editor.canvas._origin*editor.canvas.zoom+Vector2(18,18)*editor.canvas.zoom)==Vector2i.ZERO,"Padded canvas input maps back to first 36px cell")
	var shop: Dictionary = pool.templates.filter(func(template):return template.id=="shop_garden")[0].duplicate(true)
	editor.document=shop;editor._sync();editor._layer.select(1)
	var building: Dictionary = editor.document.layers.decor.filter(func(entry):return entry.asset_id=="service:building_shop")[0]
	var old_anchor := RoomEditorCatalog.service_position(building)
	var old_offset: Array = building.config.offset_px.duplicate()
	var start := Vector2i(int(building.at[0]),int(building.at[1]))
	editor._gesture("move",start,start+Vector2i(10,2),[])
	check(RoomEditorCatalog.service_position(building)==old_anchor+Vector2(360,72) and building.config.offset_px==old_offset,"Building grid move preserves exact pixel offset")
	check(RoomTemplateValidator.validate(editor.document).is_empty(),"Moved building has valid large-character paths: "+str(RoomTemplateValidator.validate(editor.document)))
	editor._preview.set_document(editor.document)
	check(editor._preview.level.service_anchor()==old_anchor+Vector2(360,72),"Shared runtime door/interaction anchor follows moved building")
	check(editor._preview.level.service_building.footprint==RoomEditorCatalog.service_footprint(building),"Moved runtime collision follows authored footprint")
	var collider := editor._preview.level.service_building.get_children().filter(func(node):return node is CollisionShape2D)[0] as CollisionShape2D
	check(collider.global_position==editor._preview.level.service_building.global_position-Vector2(0,float(building.config.depth_px)*0.5),"Physical collision translates with building")
	var service_path := "E:/CodexWorkspace/PixelRogue/temp/service-editor-moved-shop.json"
	check(RoomTemplateCodec.write_file(service_path,editor.document)==OK,"Moved service layout persists to JSON")
	var restored_service := RoomTemplateCodec.read_file(service_path)
	var restored_building: Dictionary = restored_service.layers.decor.filter(func(entry):return entry.asset_id=="service:building_shop")[0]
	check(RoomEditorCatalog.service_position(restored_building)==old_anchor+Vector2(360,72) and restored_building.config==building.config,"JSON reload preserves moved position, dimensions and offset")
	editor._undo_edit();building=editor.document.layers.decor.filter(func(entry):return entry.asset_id=="service:building_shop")[0]
	check(RoomEditorCatalog.service_position(building)==old_anchor,"Building undo restores original position")
	editor._redo_edit();building=editor.document.layers.decor.filter(func(entry):return entry.asset_id=="service:building_shop")[0]
	check(RoomEditorCatalog.service_position(building)==old_anchor+Vector2(360,72),"Building redo restores move")
	editor._gesture("select",Vector2i(int(building.at[0]),int(building.at[1])),Vector2i.ZERO,[])
	editor._properties.text='{"offset_px":[-12,12],"width_px":180,"depth_px":66}'
	editor._apply_properties();building=editor.document.layers.decor.filter(func(entry):return entry.asset_id=="service:building_shop")[0]
	check(Vector2(building.config.offset_px[0],building.config.offset_px[1])==Vector2(-12,12),"Selected building supports pixel properties")
	var property_before: Dictionary = building.config.duplicate(true)
	editor._properties.text='{"offset_px":"invalid"}';editor._apply_properties()
	check(building.config==property_before,"Invalid service properties leave object unchanged")
	editor._gesture("erase",Vector2i(int(building.at[0]),int(building.at[1])),Vector2i.ZERO,[Vector2i(int(building.at[0]),int(building.at[1]))])
	editor._preview.set_document(editor.document)
	check(editor._preview.level.service_building==null and editor._preview.level.service_footprints.size()==8,"Delete building removes collision and does not reinject fixed building")
	editor.document.layers.decor.clear();editor._preview.set_document(editor.document)
	check(editor._preview.level.service_footprints.is_empty() and editor._preview.level.service_building==null,"Clear service layout remains empty at runtime")
	editor.document=RoomTemplateCodec.blank(Vector2i(23,13),"tavern");editor._sync();editor._layer.select(1);editor._selected="service:building_tavern"
	editor._gesture("brush",Vector2i(13,4),Vector2i(13,4),[Vector2i(13,4)])
	check(editor.document.layers.decor.size()==1 and editor.document.layers.decor[0].config.width_px==204,"Service brush uses real building dimensions")
	var lit := RoomTemplateCodec.blank()
	lit.layers.entities.append({"id":"qa_light","asset_id":"light:torch:2x1","at":[5,5],"config":{"radius":160,"strength":0.8,"flicker":false}})
	lit.layers.water.append({"id":"qa_water","asset_id":"water","at":[6,8]})
	lit.layers.entities.append({"id":"qa_chest","asset_id":"chest","at":[7,5]})
	editor._preview.set_document(lit);editor._preview.set_environment(2)
	await get_tree().process_frame
	editor._preview._update_environment(1.0)
	check(editor._preview.environment_material.shader.resource_path=="res://src/room_mode/room_environment_visual.gdshader","Preview uses final game lighting shader")
	check(int(editor._preview.environment_material.get_shader_parameter("light_count"))==1,"Night preview resolves authored light without player")
	check(float(editor._preview.environment_material.get_shader_parameter("darkness"))==1.0,"Night preview drives shared darkness")
	check(editor._preview.level.decor_root.get_children().any(func(node):return node is RoomChest and node.process_mode==Node.PROCESS_MODE_DISABLED),"Shared chest visual is present without gameplay processing")
	var water: RoomWater
	for node in editor._preview.level.water_root.get_children():
		if node is RoomWater:water=node
	check(water!=null and water.flow.shader.resource_path=="res://src/room_mode/room_water_flow.gdshader","Preview uses final game water shader")
	editor._preview.set_environment(3)
	check(float(editor._preview.environment_material.get_shader_parameter("fog_density"))>0.5,"Fog preview uses final composite")
	editor._preview.set_environment(0)
	check(not editor._preview.environment_shade.visible,"Daylight preview has no overlay")
	check(not GameState.run_active,"Editor does not start a game run")
	await _extra_tests(editor)
	editor.queue_free();await get_tree().process_frame
	if failures.is_empty():print("ROOM_EDITOR_CHECK_COUNT "+str(check_count))
	if failures.is_empty():print("ROOM_EDITOR_TESTS_OK templates=15 classification=8/2/2/3 sizes=4 codec/pool/navigation/undo/redo/ports/storage/light/water/fog/service_exact_anchors/service_move/service_collision/service_delete/per_cell_floor/direct_handles=pass user="+ProjectSettings.globalize_path(RoomTemplatePool.USER))
	get_tree().quit(0 if failures.is_empty() else 1)

func _original_service_props(kind: String) -> Array:
	if kind=="shop":return [["goods",[110,146],58,24],["goods",[538,146],58,24],["planter",[162,308],54,20],["planter",[510,308],54,20],["notice",[496,88],46,14],["lantern",[288,82],44,10],["shrub",[92,310],38,18],["shrub",[592,84],38,18],["building_shop",[216,170],180,66]]
	return [["barrels",[552,276],52,22],["brazier",[568,90],44,16],["table",[156,138],64,32],["table",[162,290],64,32],["lantern",[96,82],44,10],["lantern",[402,310],44,10],["shrub",[94,310],38,18],["barrels",[576,150],48,22],["building_tavern",[468,174],204,76]]


func _extra_tests(editor: RoomTemplateEditor) -> void:
	editor.canvas.show();editor._preview.hide()
	editor.document=RoomTemplateCodec.blank();editor._sync();editor._layer.select(0);editor._selected="floor:mud"
	editor._gesture("brush",Vector2i(5,5),Vector2i(5,5),[Vector2i(5,5)])
	check(editor.document.layers.ground.size()==1 and editor.document.base_ground=="floor:grass","One-cell normal floor brush")
	editor._selected="floor:stone";editor._gesture("brush",Vector2i(6,5),Vector2i(6,5),[Vector2i(6,5)])
	check(editor.document.layers.ground.size()==2 and editor.document.layers.ground[0].asset_id=="floor:mud","Painting another floor leaves first cell intact")
	var changed := RoomTemplateCodec.to_layout(editor.document)
	check(changed.ground.filter(func(e):return e.at==[5,5])[0].kind=="mud" and changed.ground.filter(func(e):return e.at==[6,5])[0].kind=="stone","Codec retains mixed normal-room materials")
	editor._base.select(3);editor._base.item_selected.emit(3)
	check(editor.document.layers.ground.size()==2 and editor.document.base_ground=="floor:wood","Default-base change preserves explicit cells")
	editor._gesture("erase",Vector2i(6,5),Vector2i(6,5),[Vector2i(6,5)])
	check(editor.document.layers.ground.size()==1 and editor.document.layers.ground[0].at==[5,5],"Floor erase affects only addressed cell")
	editor._undo_edit();check(editor.document.layers.ground.size()==2,"Floor erase undo")
	editor.canvas.hide();editor._preview.show();editor._preview.set_document(editor.document)
	check(editor._preview.level.service_material(Vector2i(5,5))=="mud" and editor._preview.level.service_material(Vector2i(6,5))=="stone" and editor._preview.level.service_material(Vector2i(7,5))=="wood","Actual RoomLevel displays normal per-cell edits")

	for i in 4:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("E:/CodexWorkspace/PixelRogue/temp/editor-handles-mixed-normal-preview.png")
	editor._preview.hide();editor.canvas.show()
	for i in 4:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("E:/CodexWorkspace/PixelRogue/temp/editor-handles-mixed-normal-canvas.png")
	editor.document=RoomTemplateCodec.blank();editor.document.layers.obstacles=[{"id":"dragbox","asset_id":"terrain:boulder:2x2","at":[4,3]},{"id":"other","asset_id":"terrain:boulder:1x1","at":[8,4]}]
	editor.document.layers.decor=[{"id":"fern","asset_id":"terrain:fern:1x1","at":[5,9]}]
	editor.document.layers.markers=[{"id":"spawner","asset_id":"spawn","at":[11,6]}]
	editor.document.layers.entities=[{"id":"chest","asset_id":"chest","at":[15,7]}]
	editor.document.layers.water=[{"id":"water","asset_id":"water","at":[17,6]}]
	editor._sync();editor._layer.select(0);editor.canvas.tool="brush"
	var handles := editor.canvas._handles()
	check(handles.size()==6 and handles.all(func(h):return h.layer!="ground"),"Every non-ground entry gets one center handle")
	var handle: Dictionary = handles.filter(func(h):return h.id=="dragbox")[0]
	var point: Vector2 = (handle.center+editor.canvas._origin)*editor.canvas.zoom
	check(editor.canvas._handle_at(point).id=="dragbox","Handle hit test uses visible center")
	var before: Array = editor.document.layers.obstacles[0].at.duplicate()
	_input_drag(editor.canvas,point,Vector2(72,0)*editor.canvas.zoom,false)
	check(editor.document.layers.obstacles[0].at==before,"Drag preview never mutates document before release")
	var release := InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=point+Vector2(72,0)*editor.canvas.zoom;release.pressed=false;editor.canvas._gui_input(release)
	check(editor.document.layers.obstacles[0].at==[6,3],"Real mouse handle drag moves multi-grid object while ground layer selected")
	editor._undo_edit();check(editor.document.layers.obstacles[0].at==[4,3],"Handle move undo restores all occupied cells")
	editor._redo_edit();check(editor.document.layers.obstacles[0].at==[6,3],"Handle move redo")
	var count := editor._undo.size()
	editor._move_entry("obstacles","dragbox",Vector2i(2,0))
	check(editor.document.layers.obstacles[0].at==[6,3] and editor._undo.size()==count,"Overlapping drop rejected without undo entry")
	editor._move_entry("obstacles","dragbox",Vector2i(30,0))
	check(editor.document.layers.obstacles[0].at==[6,3],"Out-of-bounds drop rejected")
	editor._move_entry("markers","spawner",Vector2i(-2,0))
	check(editor.document.layers.markers[0].at==[9,6],"Yellow enemy-spawn handle moves independently of selected layer")
	check(editor.canvas._get_tooltip((Vector2(9,6)*36+Vector2(18,18)+editor.canvas._origin)*editor.canvas.zoom).contains("敌人出生点"),"Yellow cross tooltip explains semantics")
	editor.canvas.visible_layers.markers=false
	check(not editor.canvas._handles().any(func(h):return h.layer=="markers"),"Hidden layers have no draggable handles")
	editor.canvas.visible_layers.markers=true
	editor._move_entry("water","water",Vector2i(0,1));check(editor.document.layers.water[0].at==[17,7],"Water-cell handle moves logical water cell")
	check(RoomTemplateValidator.validate(editor.document).is_empty(),"Moved document remains valid")
	var path := "E:/CodexWorkspace/PixelRogue/temp/editor-handles-roundtrip.json"
	check(RoomTemplateCodec.write_file(path,editor.document)==OK and RoomTemplateCodec.read_file(path)==JSON.parse_string(JSON.stringify(editor.document)),"Handles persist logical anchors across JSON roundtrip")
	get_tree().root.size=Vector2i(1280,720)
	for i in 4:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("E:/CodexWorkspace/PixelRogue/temp/editor-handles-normal.png")
	var shop: Dictionary = editor.pool.templates.filter(func(t):return t.id=="shop_garden")[0].duplicate(true)
	editor.document=shop;editor._sync();editor._layer.select(0);editor.canvas.zoom=0.75;editor.canvas.set_document(editor.document)
	var service: Dictionary = editor.document.layers.decor.filter(func(e):return e.asset_id=="service:building_shop")[0]
	var anchor := RoomEditorCatalog.service_position(service);var offset: Array = service.config.offset_px.duplicate()
	handle=editor.canvas._handles().filter(func(h):return h.id==service.id)[0];point=(handle.center+editor.canvas._origin)*editor.canvas.zoom
	_input_drag(editor.canvas,point,Vector2(360,72)*editor.canvas.zoom,true)
	check(RoomEditorCatalog.service_position(service)==anchor+Vector2(360,72) and service.config.offset_px==offset,"Actual service center drag keeps configured pixel offsets")
	for i in 4:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("E:/CodexWorkspace/PixelRogue/temp/editor-handles-shop.png")
	editor._undo_edit();check(RoomEditorCatalog.service_position(editor.document.layers.decor.filter(func(e):return e.id==service.id)[0])==anchor,"Center-drag service undo")
	check(not GameState.run_active,"Handle editor does not initialize gameplay")

func _input_drag(canvas: RoomEditorCanvas, point: Vector2, offset: Vector2, release: bool) -> void:
	var press := InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=point;press.pressed=true;canvas._gui_input(press)
	var move := InputEventMouseMotion.new();move.position=point+offset;canvas._gui_input(move)
	if release:
		press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=point+offset;press.pressed=false;canvas._gui_input(press)


