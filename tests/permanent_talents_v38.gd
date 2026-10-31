extends Node
var checks:=0
var failures:=0
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+label)
func _ready()->void:call_deferred("run")
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	AchievementTracker.set_process(false);GameState.set_process(false)
	var old_outpost:=Outpost.data.duplicate(true);var old_save:=SaveService.data.duplicate(true)
	verify(PermanentTalents.catalog().get("skills",{}).size()==24,"24 external skill trees")
	for hero:StringName in [&"sylphiette",&"xixifu",&"ilyua"]:
		Characters.set_current(hero)
		verify(Skills.order_for(hero).size()==8,"eight skills per hero")
		for skill:StringName in Skills.order_for(hero):
			verify(SkillTalentCatalog.definition(skill).size()==5,"external route "+str(skill))
		Outpost.data.permanent_stats={};Outpost.data.gold=5000;Outpost.data.inventory={}
		CampSession.begin(self)
		var id:=&"vitality";var price:=PermanentStats.cost(id,1)
		for material in price.materials:Outpost.data.inventory[material]=3
		verify(PermanentStats.purchase(id),"camp stat purchase "+str(hero))
		verify(PermanentStats.rank(id)==1 and Outpost.gold()==5000-int(price.gold),"durable rank and charge "+str(hero))
		var blocker:=ProjectSettings.globalize_path(SaveService.SAVE_PATH)+".tmp"
		verify(DirAccess.make_dir_absolute(blocker)==OK,"save blocker "+str(hero))
		var before:=Outpost.data.duplicate(true)
		verify(not PermanentStats.purchase(id) and Outpost.data==before,"purchase rollback "+str(hero))
		verify(DirAccess.remove_absolute(blocker)==OK,"remove blocker "+str(hero))
		verify(not PermanentStats.gate(id,4).met,"fourth rank gate "+str(hero))
		var spent_gold:=Outpost.gold()
		verify(PermanentStats.reset(hero) and PermanentStats.ranks(hero).is_empty() and Outpost.gold()==spent_gold,"reset no refund "+str(hero))
		CampSession.end(self)
		CampSession.begin(self,true)
		CampSession.fill_talents()
		verify(PermanentStats.rank(id)==PermanentStats.MAX_RANK,"training full preview "+str(hero))
		CampSession.clear_talents()
		verify(PermanentStats.rank(id)==0,"training clear preview "+str(hero))
		CampSession.end(self)
	Outpost.data=old_outpost;SaveService.data=old_save
	AudioManager.shutdown();await get_tree().process_frame
	print("PERMANENT_TALENTS_V39 checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
