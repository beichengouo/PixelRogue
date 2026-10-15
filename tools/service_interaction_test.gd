extends Node
class QuietRooms extends "res://src/room_mode/room_main.gd":
	func _autoplay_requested()->bool:return true
var main
var checks:=0
var failures:Array[String]=[]
func _ready()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("SERVICE_INTERACTION_FAIL "+label)
func run()->void:
	AudioServer.set_bus_mute(0,true)
	Outpost.data={"version":4,"gold":10000,"danger":3,"inventory":{},"capacity":30,"expansions":0,"contracts":[],"bonds":{},"events":{"camp:intro":true},"best":{},"active":{},"last_result":{},"shop":{},"contract_jobs":{},"bond_daily":{},"contract_clock":0}
	main=QuietRooms.new();main.show_menu_on_ready=false;add_child(main)
	main._begin_run({"departure":{"loadout":[],"carried":20,"danger":0,"combat_mode":"rooms"}})
	main.set_process(false);main.player.set_physics_process(false);main.director.set_process(false)
	var pool:=RoomTemplatePool.new();pool.reload()
	for template in pool.templates:
		var kind:String=template.room_kinds[0]
		if kind not in ["shop","tavern"]:continue
		var layout:=RoomTemplateCodec.to_layout(template)
		var building_index:=-1
		for index in layout.service_props.size():
			if str(layout.service_props[index].role)=="building":building_index=index
		check(building_index>=0,"Service building exists "+str(template.id))
		layout.service_props[building_index].position_px[0]+=36
		var record:Dictionary={"id":"0,0","kind":kind,"biome":template.theme,"seed":1,"cleared":true,"rewarded":true,"delta":{},"doors":[],"terrain_layout":layout}
		main.graph.rooms["0,0"]=record;main.graph.current="0,0";main.level.load_room(record);main._sync_services()
		var npc:Node2D=main.npc if kind=="shop" else main.tavern
		var point:Array=layout.service_props[building_index].position_px
		check(is_instance_valid(npc) and npc.position==Vector2(point[0],point[1])+Vector2(0,34),"Actual NPC interaction follows moved building "+str(template.id))
		main.player.global_position=npc.global_position;npc.in_range=true;npc.try_interact()
		check(UIFlow.has_screen(),"Moved entrance opens real service UI "+str(template.id))
		main.shop_ui.close();main.tavern_ui.close()
		layout.service_props.remove_at(building_index);main.level.load_room(record);main._sync_services()
		check(not is_instance_valid(main.npc) and not is_instance_valid(main.tavern),"Deleting building removes ghost service NPC "+str(template.id))
		await get_tree().process_frame
	GameState.run_active=false;main.queue_free();await get_tree().process_frame;AudioManager.shutdown()
	print("SERVICE_INTERACTION ",JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
