extends Node
var failures:=0
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;printerr("FAIL ",label)
func _ready()->void:
	var path:="E:/CodexWorkspace/PixelRogue/work/browser-tools-regression/set-grant-fixture.json"
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify({"outpost":{"inventory":{},"gold":123},"run":{"coins":17},"unrelated":{"preserve":true}}));file.close()
	var tool:=DeveloperSaveTool.new();check(tool.open_file(path).is_empty(),"fixture loaded")
	var before:=tool.fingerprint
	check(tool.grant("legendary_sets","all",1).is_empty(),"all sets single transaction")
	check(tool.data.outpost.inventory.size()==9,"nine unique pieces")
	for hero in LegendarySets.DATA:
		for slot in ["weapon","armor","accessory"]:check(int(tool.data.outpost.inventory.get(LegendarySets.DATA[hero][slot],0))==1,"piece issued once")
	check(tool.data.run.coins==17 and tool.data.outpost.gold==123 and tool.data.unrelated.preserve,"unrelated state preserved")
	check(FileAccess.file_exists(tool.last_backup) and FileAccess.get_sha256(tool.last_backup)==before,"backup matches original")
	check(tool.grant("legendary_sets","ilyua",1).is_empty(),"selected set")
	check(tool.data.outpost.inventory.bow_spring_wind==2 and tool.data.outpost.inventory.staff_cloud_radiance==1,"selected set affects three only")
	before=FileAccess.get_sha256(path)
	check(not tool.grant("legendary_sets","missing",1).is_empty() and before==FileAccess.get_sha256(path),"invalid set changes nothing")
	var stale:=DeveloperSaveTool.new();stale.open_file(path)
	check(tool.grant("legendary_sets","xixifu",1).is_empty(),"second valid write")
	before=FileAccess.get_sha256(path)
	check(not stale.grant("legendary_sets","all",1).is_empty() and before==FileAccess.get_sha256(path),"stale fingerprint refuses entire grant")
	print("BROWSER_AUTHORING failures=",failures);get_tree().quit(1 if failures else 0)
