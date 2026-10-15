extends Node
class QuietRooms extends "res://src/room_mode/room_main.gd":
	func _autoplay_requested()->bool:return true
var main
var checks:=0
var failures:Array[String]=[]
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("ROOM_MUSIC_FAIL "+label)
func wait(seconds:float)->void:
	await get_tree().create_timer(seconds,true,false,true).timeout
func run()->void:
	AudioServer.set_bus_mute(0,true)
	check(OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/test-userdata/"),"Isolated E save profile")
	Outpost.data={"version":4,"gold":10000,"danger":3,"inventory":{},"capacity":30,"expansions":0,"contracts":[],"bonds":{},"events":{"camp:intro":true},"best":{},"active":{},"last_result":{},"shop":{},"contract_jobs":{},"bond_daily":{},"contract_clock":0}
	main=QuietRooms.new();main.show_menu_on_ready=false;add_child(main)
	main._begin_run({"departure":{"loadout":[],"carried":20,"danger":0,"combat_mode":"rooms"}})
	main.set_process(false);main.player.set_physics_process(false);main.director.set_process(false)
	check(AudioManager._room_music_group==RoomMusicCatalog.group(main.world_clock.minutes,main.room_weather.kind),"New run synchronizes actual world state")
	for entry in [[400.0,"clear","environment_morning_clear_1"],[750.0,"clear","environment_noon_clear_1"],[1250.0,"clear","environment_night_clear_1"],[400.0,"rain","environment_morning_rain_1"],[750.0,"snow","environment_noon_snow_1"],[1250.0,"fog","environment_night_fog_1"],[750.0,"storm","environment_noon_rain_1"]]:
		main.world_clock.minutes=entry[0];main.room_weather.kind=entry[1];main.room_weather.previous=entry[1];main._process(0)
		await wait(0.9)
		check(str(AudioManager._current_music)==entry[2],"Actual RoomMain time/weather selection "+str(entry))
		var epoch:=AudioManager._music_epoch;var at:=AudioManager._music_player.get_playback_position()
		main._process(0);EventBus.wave_started.emit(9,2);await wait(.12)
		check(AudioManager._music_epoch==epoch and AudioManager._music_player.get_playback_position()>at,"Same room state/wave does not restart "+str(entry))
	main.world_clock.minutes=400;main.room_weather.kind="clear";main.room_weather.previous="clear";main._process(0)
	EventBus.boss_started.emit(&"king");await wait(.5)
	main.world_clock.minutes=1250;main._process(0)
	check(AudioManager._current_music==&"music_boss_king","Boss retains priority while world time changes")
	EventBus.boss_defeated.emit(&"king");await wait(.9)
	check(AudioManager._current_music==&"environment_night_clear_1","Boss returns to latest clear night pair")
	var saved:Dictionary=GameState.snapshot();var minutes:float=main.world_clock.minutes
	main._begin_run(saved);main.set_process(false);main.player.set_physics_process(false);main.director.set_process(false);await wait(.9)
	check(is_equal_approx(main.world_clock.minutes,minutes) and main.room_weather.kind=="clear","Continue restores clock/weather")
	check(AudioManager._current_music==&"environment_night_clear_1","Continue picks restored music without forest fallback")
	GameState.run_active=false;AudioManager.play_context(&"settlement");main._process(1);await wait(.9)
	check(AudioManager._current_music==&"menu_humming_alt","Ended room cannot replace settlement music")
	main.queue_free();await get_tree().process_frame;AudioManager.shutdown()
	print("ROOM_MUSIC_INTEGRATION ",JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
