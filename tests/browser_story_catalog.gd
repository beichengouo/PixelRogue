extends Node
var failures:=0
func _ready()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):
		push_error("Isolated E-drive userdata required");get_tree().quit(2);return
	var catalog=preload("res://tools/browser_tools/story_catalog.gd")
	var ids:Array=catalog.ids();var metadata:Dictionary=catalog.metadata()
	for id in ids:
		check(metadata.has(id),"metadata "+id)
		check(not str(metadata.get(id,{}).get("trigger","")).is_empty(),"trigger "+id)
	check(metadata.cp_10.category=="chapter1" and metadata.city_entry.category=="chapter2","chapters")
	check(metadata.forest_king_before.after==["cp_20"],"boss follows stage clues")
	check(metadata.stage_echo_entry.categories.has("chapter2"),"both chapters share stage four")
	for row:Dictionary in CampCommissionCatalog.DATA:
		var before:=row.duplicate(true)
		for phase in ["offer","accepted","finished"]:
			var id:String="commission:"+str(row.id)+":"+str(phase)
			check(ids.has(id) and metadata[id].category=="commissions","commission catalog "+id)
			var scene:=Story.get_scene(StringName(id),false,&"ilyua")
			check(scene.lines==row[phase],"commission resolves authored lines "+id)
			check(CampCommissionCatalog.story(str(row.id),phase)==scene.lines,"runtime uses story entry "+id)
		check(row==before,"contract fields unchanged")
	print("BROWSER_STORY_CATALOG failures=",failures)
	get_tree().quit(1 if failures else 0)
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;push_error(label)
