extends Node
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v37-narrative-and-heroes/"
const HEROES:Array[StringName]=[&"xixifu",&"sylphiette",&"ilyua"]
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func frames(count:=3)->void:
	for index in count:await get_tree().process_frame
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;call_deferred("run")
func effects(scene:Dictionary)->Dictionary:
	var result:Dictionary={"next":str(scene.get("next","")),"source_scenes":scene.get("source_scenes",[]),"choices":[]}
	for choice:Dictionary in scene.get("choices",[]):
		var value:=choice.duplicate(true);value.erase("text");value.erase("reply");result.choices.append(value)
	return result
func signatures()->Dictionary:
	var result:Dictionary={}
	var forest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/narrative_v11.json"))
	for hero:StringName in HEROES:
		Characters.set_current(hero)
		for id in forest:
			for repeated in [false,true]:result[str(hero)+":"+id+":"+str(repeated)]=effects(Story.get_scene(StringName(id),repeated,hero))
		for id:StringName in CityStories.IDS:
			for repeated in [false,true]:result[str(hero)+":"+str(id)+":"+str(repeated)]=effects(Story.get_scene(id,repeated,hero))
	for npc in CampStory.EVENTS:
		for event:Dictionary in CampStory.EVENTS[npc]:
			var value:=event.duplicate(true);value.erase("title");value.erase("lines");value.erase("choices");value["options"]=effects(event)
			result["camp:"+npc+":"+str(event.id)]=value
	return result
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);GameState.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=true
	Characters.set_current(&"sylphiette")
	check(Characters.portrait_path("determined")==Characters.portrait_path("thoughtful"),"retired determined portrait resolves to thoughtful")
	for index in 40:check(Characters.random_portrait_path()!="res://assets/characters/sylphiette_holy_v01/determined.png","random portrait excludes retired expression")
	var path:=OS.get_user_data_dir()+"/v37-gameplay-baseline.json"
	if "baseline" in OS.get_cmdline_user_args():
		var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(signatures()));file.close()
		print("NOVEL_V37_BASELINE checks=1 failures=0");AudioManager.shutdown();await frames();get_tree().quit();return
	check(FileAccess.file_exists(path),"pre-change gameplay signature exists")
	if FileAccess.file_exists(path):
		var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		var current:Dictionary=JSON.parse_string(JSON.stringify(signatures()))
		check(current.keys().size()==original.keys().size(),"scene and event IDs preserved")
		for key in original:check(current.get(key)==original[key],"effects/next/conditions preserved "+key)
	var raw:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/narrative_v11.json"))
	for hero:StringName in HEROES:
		Characters.set_current(hero)
		for id in raw:
			var scene:=Story.get_scene(StringName(id),false,hero)
			check(not JSON.stringify(scene).contains("小扣"),"retired spirit name absent "+id)
			if raw[id].has("hero_lines"):check(scene.lines.size()>raw[id].lines.size(),"hero-specific perspective included "+id)
		var opening:=JSON.stringify(Story.get_scene(&"intro_wake",false,hero))
		if hero==&"xixifu":check(opening.contains("小灵") and opening.contains("骸灵") and opening.contains("自愿") and opening.contains("不是"),"opening explains spirit identity and consent")
		for id:StringName in CityStories.IDS:
			var scene:=Story.get_scene(id,false,hero)
			check(not JSON.stringify(scene).contains("小扣"),"city spirit rename "+str(id))
			if not scene.choices.is_empty():check(not str(scene.lines.back().get("who","")).is_empty() and str(scene.lines.back().text).ends_with("？"),"city asks before options "+str(id))
		for event:Dictionary in CampStory.EVENTS[str(hero)]:
			if event.get("choices",[]).is_empty():continue
			check(str(event.lines.back().get("who",""))==str(hero) and str(event.lines.back().text).ends_with("？"),"bond asks player before choice "+str(hero)+str(event.id))
	var dialogue:=DialogueUI.new();add_child(dialogue);await frames()
	for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await frames(3)
		for hero:StringName in HEROES:
			Characters.set_current(hero)
			var scene:=Story.get_scene(&"intro_wake",false,hero)
			var state_before:=StoryState.flags.duplicate(true);var outpost_before:=Outpost.data.duplicate(true)
			dialogue.play_local_scene(scene,func(_option:Dictionary)->bool:return true);await frames()
			check(dialogue._narration_line and dialogue._full.length()>90,"expanded authored opening paragraph")
			var narrator_height:=dialogue._bubble.size.y
			var full:=dialogue._full;dialogue._advance();check(dialogue._text_label.text==full and dialogue._text_label.visible_characters==-1,"reveal never truncates long narration")
			check(dialogue._text_scroll.get_global_rect().end.x<=dialogue._root.size.x+1 and dialogue._bubble.get_global_rect().end.y<=dialogue._root.size.y+1,"narrator fits safe viewport "+str(extent))
			dialogue._skip_story();await frames()
			check(dialogue._choosing and not dialogue._narration_line,"skip still shows character question")
			check(dialogue._text_label.text==scene.choice_prompt.text and dialogue._actor_id==str(hero),"actual heroine asks, not generic instruction")
			check(narrator_height>dialogue._bubble.size.y,"narration has more reading room than speech")
			check(dialogue._offered.size()==3 and dialogue._text_label.visible_characters==-1,"all consultation options and full question remain")
			check(StoryState.flags==state_before and Outpost.data==outpost_before,"local presentation does not mutate story/relationships")
			dialogue.cancel();await frames()
		# A long unforeseen paragraph remains complete and scrollable, not silently sliced.
		var long_text:=str(raw.intro_wake.lines[0].text).repeat(5)
		dialogue.play_local_lines([{"who":"","text":long_text}]);await frames()
		dialogue._advance();await frames()
		check(dialogue._text_label.text==long_text and dialogue._text_label.visible_characters==-1,"large narration retains every character")
		dialogue._text_scroll.scroll_vertical=100000;await frames()
		check(dialogue._text_scroll.scroll_vertical>0,"overflow can be read by scrolling")
		dialogue.cancel();await frames()
	# A v12 suspended dialogue refreshes presentation only; no awards or commitments replay.
	var flags:=StoryState.flags.duplicate(true);var before:=Outpost.data.duplicate(true)
	dialogue.expedition_restore({"scene_id":"city_entry","scene":{"title":"old","narrative_revision":12},"lines":[{"text":"OBSOLETE小扣"}],"offered":[{"text":"OLD_REWARD","give":"iron_sword"}],"repeat_read_only":true,"mode":"reply"});await frames()
	check(dialogue._scene.narrative_revision==13 and not JSON.stringify(dialogue._lines).contains("OBSOLETE"),"v12 save gets updated canonical prose")
	check(dialogue._offered.is_empty() and StoryState.flags==flags and Outpost.data==before,"presentation migration cannot replay choice or reward")
	dialogue.cancel();await frames();dialogue.queue_free();AudioManager.shutdown();await frames()
	print("NOVEL_DIALOGUE_V37 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
