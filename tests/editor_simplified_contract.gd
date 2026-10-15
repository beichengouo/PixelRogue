extends Node

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var editor := RoomTemplateEditor.new();add_child(editor)
	await get_tree().process_frame
	check(not editor.document.is_empty() and editor.document.id==editor.pool.templates[0].id,"initial room is first pool template")
	check(editor.canvas.tool=="collision","initial tool edits collision")
	var labels: Array[String] = []
	_collect_labels(editor,labels)
	for removed in ["新建","画笔","矩形填充","移动物块","物块 / 建筑 / 实体属性 ▾"]:
		check(not labels.has(removed),"removed UI: "+removed)
	var illustrated := RoomTemplateCodec.read_file("res://assets/room_templates/forest_clearing.json")
	editor.document=illustrated;editor._sync();editor._changed()
	check(editor.canvas._handles().is_empty(),"illustrated objects have no drag handles")
	var object_count: int = editor.document.layers.decor.size()
	editor._gesture("brush",Vector2i(8,6),Vector2i(8,6),[Vector2i(8,6)])
	check(editor.document.layers.decor.size()==object_count,"legacy brush gesture cannot edit art")
	editor._move_entry("decor","anything",Vector2i(1,0))
	check(editor.document.layers.decor.size()==object_count,"non-marker drag ignored")
	editor._preview.visible=true;editor._preview.set_document(editor.document)
	editor._preview.set_layer_visible("objects",false)
	check(not editor._preview.level.props_root.visible,"preview objects layer hides scene props")
	editor._preview.set_layer_visible("collision",false)
	check(not editor._preview.guides.layers.collision,"preview collision layer toggles")
	editor._preview.set_layer_visible("spawns",false)
	check(not editor._preview.guides.layers.spawns,"preview spawn layer toggles")
	editor._preview.set_layer_visible("background",false)
	editor._preview.set_layer_visible("water_bridge",false)
	editor._preview.set_layer_visible("doors",false)
	var scene_layers := {"background":false,"water_bridge":false,"doors":false}
	for sprite in editor._preview.level.illustration.get_children():
		if not sprite is Sprite2D:continue
		var file := str(sprite.texture.resource_path).get_file()
		var layer := "background" if file=="background.png" else ("doors" if file.begins_with("door_") else "water_bridge")
		scene_layers[layer]=true
		check(not sprite.visible,"preview hides "+layer+" sprite")
	check(scene_layers.values().all(func(value):return value),"illustrated preview contains background, water/bridge and doors")
	var fixture := RoomTemplateCodec.blank()
	editor.document=fixture;editor._sync()
	var marker_count: int = editor.document.layers.markers.size()
	editor._gesture("spawn",Vector2i(8,5),Vector2i(8,5),[Vector2i(8,5)])
	check(editor.document.layers.markers.size()==marker_count+1,"spawn tool adds enemy marker")
	editor.canvas.visible_layers.spawns=false
	check(editor.canvas._handles().is_empty(),"hidden spawn layer has no handles")
	editor.canvas.visible_layers.spawns=true
	check(editor.canvas._handles().size()==1,"spawn layer exposes only marker handle")
	editor._move_entry("markers",str(editor.document.layers.markers[0].id),Vector2i(1,0))
	check(editor.document.layers.markers[0].at==[9,5],"spawn marker moves by drag")
	editor._gesture("erase",Vector2i(9,5),Vector2i(9,5),[Vector2i(9,5)])
	check(editor.document.layers.markers.size()==marker_count,"right click removes spawn marker")
	var north_before: Array = editor.document.ports[0].at.duplicate()
	editor._gesture("port",Vector2i(north_before[0],north_before[1]),Vector2i(north_before[0]+1,north_before[1]),[])
	check(editor.document.ports[0].at[0]==north_before[0]+1,"north entrance moves along wall")
	print("EDITOR_SIMPLIFIED checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)

func _collect_labels(node: Node, result: Array[String]) -> void:
	if node is Button:result.append(node.text)
	for child in node.get_children():_collect_labels(child,result)
