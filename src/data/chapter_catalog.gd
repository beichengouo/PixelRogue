class_name ChapterCatalog
extends RefCounted
## Chapter ownership is metadata; authored collision geometry never changes here.
const FIRST := &"awakening_woods"
const NEXT := &"chapter_2"
const CHAPTERS := {
	FIRST:{"title":"苏醒林地","last_wave":30,"next":NEXT,"scene":"res://src/room_mode/room_main.tscn","start":"forest_clearing","bosses":["king","mage","tide"],"maps":["forest_clearing","forest_grove","forest_timber","forest_bone_glade","wetland_curve","wetland_twin_pools"],"enemies":["charger","treant","moss_badger","thorn_mantis","glimmer_spider","bog_crab","lantern_toad","bell_snail"]},
	NEXT:{"title":"失名星城","last_wave":30,"next":&"","scene":"res://src/room_mode/room_main.tscn","start":"city_silent_gate","bosses":["sephra","verena","nameless"],"maps":["ruin_courtyard","ruin_archive","city_silent_gate","city_star_canal","city_wax_street","city_eclipse_court","city_name_archive","city_observatory"],"enemies":["walker","flyer","caster","bomber","guard","ruin_sentinel","dusk_acolyte"]},
}

static func normalize(id:Variant)->StringName:
	return StringName(id) if CHAPTERS.has(StringName(id)) else FIRST
static func config(id:Variant)->Dictionary:return CHAPTERS[normalize(id)]
static func title(id:Variant)->String:return str(config(id).title)
static func bosses(id:Variant)->Array:return config(id).bosses.duplicate()
static func unlocked(id:Variant)->bool:
	return normalize(id)==FIRST or bool(StoryState.get_flag(&"chapter_2_unlocked",false)) or bool(StoryState.get_flag(&"forest_cleared",false))
static func is_ready(id:StringName)->bool:
	return CHAPTERS.has(id) and ResourceLoader.exists(str(config(id).scene))
static func map_chapter(id:String)->StringName:
	for chapter in CHAPTERS:
		if CHAPTERS[chapter].maps.has(id):return chapter
	return &""
static func allows(template:Dictionary,chapter:Variant,kind:String)->bool:
	if kind not in ["normal","spawn"]:return true
	if str(template.get("id",""))=="normal_windbridge" or str(template.get("scene_art",""))=="normal_windbridge_v01":return false
	var owner:=map_chapter(str(template.get("id","")))
	if owner!=&"":return owner==normalize(chapter)
	var chapters:Array=template.get("chapters",[])
	return chapters.is_empty() or chapters.has(str(normalize(chapter)))
static func stage(boss_id:String)->int:
	for chapter in CHAPTERS:
		var index:int=CHAPTERS[chapter].bosses.find(boss_id)
		if index>=0:return index
	return 0
static func enemy_variant(original:StringName,chapter:Variant,biome:String,rng:RandomNumberGenerator,wave:int)->StringName:
	var habitat:="ruin" if normalize(chapter)==NEXT else ("wetland" if biome=="wetland" else "forest")
	if config(chapter).enemies.has(str(original)) and EnemyCombatPolicy.biome_of(original)==habitat:return original
	var mapped:=EnemyCombatPolicy.room_variant(original,habitat,rng,wave)
	var allowed:Array=config(chapter).enemies
	if allowed.has(str(mapped)):return mapped
	return &"walker" if normalize(chapter)==NEXT else (&"bog_crab" if biome=="wetland" else &"charger")
