class_name EnemyCombatPolicy
extends RefCounted
## Visible equipment determines combat role, including elite affix compatibility.
const EXPANSION_KINDS:Array[StringName]=[&"thorn_mantis",&"lantern_toad",&"dusk_acolyte",&"bell_snail",&"glimmer_spider"]
const NEW_KINDS:Array[StringName]=[&"moss_badger",&"bog_crab",&"ruin_sentinel",&"thorn_mantis",&"lantern_toad",&"dusk_acolyte",&"bell_snail",&"glimmer_spider"]
const NEW_DATA:Dictionary={
	&"bell_snail":{"name":"铃壳蜗使","hp":48.0,"damage":18.0,"speed":48.0,"coins":4,"theme":"wetland","role":"bell_waves"},
	&"glimmer_spider":{"name":"荧纱蛛","hp":36.0,"damage":18.0,"speed":84.0,"coins":3,"theme":"forest","role":"silk_bite"},
	&"moss_badger":{"name":"棘冠苔獾","hp":38.0,"damage":18.0,"speed":88.0,"coins":3,"theme":"forest","role":"short_charge"},
	&"bog_crab":{"name":"泥沼甲蟹","hp":50.0,"damage":20.0,"speed":57.0,"coins":3,"theme":"wetland","role":"melee"},
	&"ruin_sentinel":{"name":"星冕残卫","hp":65.0,"damage":24.0,"speed":53.0,"coins":4,"theme":"ruin","role":"shield_melee"},
	&"thorn_mantis":{"name":"灰棘螳卫","hp":42.0,"damage":20.0,"speed":96.0,"coins":3,"theme":"forest","role":"double_sickle"},
	&"lantern_toad":{"name":"沼灯囊蛙","hp":40.0,"damage":18.0,"speed":64.0,"coins":3,"theme":"wetland","role":"poison_spit"},
	&"dusk_acolyte":{"name":"暮钟侍祭","hp":46.0,"damage":20.0,"speed":60.0,"coins":4,"theme":"ruin","role":"curse_bolt"},
}
static func ranged_affix_allowed(kind:StringName)->bool:return kind in [&"flyer",&"lantern_toad",&"dusk_acolyte",&"bell_snail"]
static func filtered_affixes(kind:StringName,ids:Array[StringName])->Array[StringName]:
	var result:Array[StringName]=[]
	for id in ids:
		if not ranged_affix_allowed(kind) and id in [EnemyAffixes.RANGED,EnemyAffixes.HUNTER_LOCK]:continue
		result.append(id)
	return result
static func excluded_affixes(kind:StringName)->Array[StringName]:
	var excluded:Array[StringName]=[]
	if not ranged_affix_allowed(kind):excluded.assign([EnemyAffixes.RANGED,EnemyAffixes.HUNTER_LOCK])
	if kind==&"thorn_mantis":excluded.append(EnemyAffixes.EMBER_GRAVE)
	return excluded
static func create(kind:StringName)->EnemyBase:
	var data:Dictionary=NEW_DATA[kind]
	var enemy:=EnemyBase.new();enemy.kind=kind;enemy.display_name=str(data.name)
	enemy.base_hp=float(data.hp);enemy.base_damage=float(data.damage);enemy.base_speed=float(data.speed);enemy.base_coins=int(data.coins)
	enemy.body_size=Vector2(29,32);enemy.body_color=Color.WHITE;enemy.uses_gravity=false;enemy.collides_with_world=true
	return enemy
static func room_variant(kind:StringName,biome:String,rng:RandomNumberGenerator,wave:=1)->StringName:
	if str(kind).begins_with("boss_"):return kind
	# Replace roster slots, never add population. The selected artwork's theme
	# owns the habitat, rather than the graph's initial random biome hint.
	match biome:
		"forest":
			if kind in [&"charger",&"treant"] and rng.randf()>=.35:return kind
			if kind in [&"thorn_mantis",&"glimmer_spider",&"moss_badger"]:return kind
			if wave>=8 and rng.randf()<.25:return &"glimmer_spider"
			if wave>=4 and rng.randf()<.45:return &"thorn_mantis"
			return &"moss_badger"
		"wetland":
			if biome_of(kind)=="wetland":return kind
			if wave>=11 and rng.randf()<.22:return &"bell_snail"
			if wave>=6 and kind in [&"flyer",&"caster",&"bomber"]:return &"lantern_toad"
			return &"bog_crab"
		_:
			if kind==&"caster" and wave>=6 and rng.randf()<.40:return &"dusk_acolyte"
			if kind in [&"walker",&"guard"] and rng.randf()<.35:return &"ruin_sentinel"
			if biome_of(kind)=="ruin":return kind
			return &"ruin_sentinel" if kind in [&"treant",&"charger"] else &"walker"

static func biome_of(kind:StringName)->String:
	if NEW_DATA.has(kind):return str(NEW_DATA[kind].theme)
	return "forest" if kind in [&"charger",&"treant"] else "ruin"

static func record_biome(record:Dictionary)->String:
	var authored:=str(record.get("terrain_layout",{}).get("theme",record.get("biome","forest")))
	return authored if authored in ["forest","wetland","ruin"] else "forest"
