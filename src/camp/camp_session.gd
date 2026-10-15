class_name CampSession
extends RefCounted
static var active:=false
static var owner:WeakRef
static func begin(world:Node)->void:
	active=true;owner=weakref(world)
	if GameState.stats==null:GameState.stats=StatBlock.new()
	GameState.restore({"character":str(Characters.current_id()),"passive_id":str(PassiveDefinitions.selected(Characters.current_id())),"level":1,"wave":1,"talents":{},"unlocked_skills":Skills.order_for().duplicate(),"items":[],"equipment":{}})
	GameState.run_active=false;GameState.runtime_node=null;GameState.wave=0;GameState.sortie_id="";GameState.active_play_seconds=0
	fill_talents()
static func end(world:Node)->void:
	if not active:return
	if owner!=null and owner.get_ref()!=world:return
	active=false;owner=null;GameState.run_active=false
static func refresh_stats()->void:
	GameState._reset_stats();EventBus.player_stats_changed.emit();EventBus.talents_changed.emit();EventBus.skills_changed.emit()
static func fill_talents()->void:
	GameState.talents.clear();GameState.talent_points=0
	for id in GameState.TALENT_BRANCHES:GameState.talents[id]=int(GameState.TALENT_BRANCHES[id].max_rank)
	refresh_stats()
static func clear_talents()->void:
	GameState.talents.clear();GameState.talent_points=0
	for data in GameState.TALENT_BRANCHES.values():GameState.talent_points+=int(data.max_rank)
	refresh_stats()
static func set_rank(id:StringName,value:int)->bool:
	if not GameState.TALENT_BRANCHES.has(id):return false
	var previous:=GameState.talents.duplicate(true)
	GameState.talents[id]=clampi(value,0,int(GameState.TALENT_BRANCHES[id].max_rank))
	for key in GameState.TALENT_BRANCHES:
		if GameState.talent_rank(key)>0 and not GameState.talent_unlocked(key):GameState.talents=previous;return false
	GameState.talent_points=0
	for key in GameState.TALENT_BRANCHES:GameState.talent_points+=int(GameState.TALENT_BRANCHES[key].max_rank)-GameState.talent_rank(key)
	refresh_stats();return true
static func try_equipment(id:String)->bool:
	var item:=BoundEquipment.from_camp(ExpeditionData.resolve(id))
	if int(Outpost.data.inventory.get(id,0))<=0 or not ItemDB.is_equippable(item) or not ItemDB.can_equip(item):return false
	GameState.equipment[ItemDB.slot_of(item)]=item.duplicate(true);GameState._after_equipment_change();return true

