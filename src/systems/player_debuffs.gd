class_name PlayerDebuffs
extends RefCounted
## Effects are attached only by an accepted hit that reaches player HP.
## Reapplication refreshes the strongest instance, never adds unbounded stacks.
const EFFECTS := {
	"heal_seal":{"duration":4.0,"strength":.4,"dot_ratio":0.0,"stat":"heal_received"},
	"mana_leech":{"duration":3.0,"strength":0.0,"dot_ratio":0.0,"stat":""},
	"spell_delay":{"duration":4.0,"strength":.15,"dot_ratio":0.0,"stat":"skill_cooldown"},
	"thorn_step":{"duration":2.0,"strength":.2,"dot_ratio":0.0,"stat":"move_speed"},
	"bleeding": {"duration":4.0,"strength":0.0,"dot_ratio":0.06,"stat":""},
	"poison": {"duration":4.0,"strength":0.0,"dot_ratio":0.08,"stat":""},
	"scorch": {"duration":3.0,"strength":0.0,"dot_ratio":0.10,"stat":""},
	"chill": {"duration":3.0,"strength":0.20,"dot_ratio":0.0,"stat":"move_speed"},
	"weakness": {"duration":3.0,"strength":0.15,"dot_ratio":0.0,"stat":"attack"},
	"sluggish": {"duration":3.0,"strength":0.20,"dot_ratio":0.0,"stat":"attack_speed"},
	"mana_drought": {"duration":4.0,"strength":0.35,"dot_ratio":0.0,"stat":"mp_regen"},
}
const AFFIX_EFFECTS := {&"venom_edge":"poison",&"ember_touch":"scorch",&"frostbite":"chill",&"hollow_curse":"weakness",&"leaden_strike":"sluggish",&"mana_drought":"mana_drought",&"heal_seal":"heal_seal",&"mana_leech":"mana_leech",&"spell_delay":"spell_delay"}

static func effects_for(enemy: EnemyBase) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	if not is_instance_valid(enemy) or enemy is BossBase: return effects
	var ids: Array[String] = []
	if enemy.kind == &"moss_badger": ids.append("bleeding")
	elif enemy.kind == &"lantern_toad": ids.append("poison")
	elif enemy.kind == &"dusk_acolyte": ids.append("weakness")
	elif enemy.kind==&"bell_snail":ids.append("spell_delay")
	elif enemy.kind==&"glimmer_spider":ids.append("heal_seal")
	for affix in AFFIX_EFFECTS:
		if enemy.has_affix(affix) and not ids.has(AFFIX_EFFECTS[affix]): ids.append(AFFIX_EFFECTS[affix])
	for id in ids:
		var info: Dictionary = EFFECTS[id]
		effects.append({"id":id,"duration":info.duration,"strength":info.strength,"damage":enemy.attack_damage()*float(info.dot_ratio),"cruel_damage":enemy.has_affix(EnemyAffixes.CRUEL)})
	return effects

static func apply(actor: Player, effect: Dictionary) -> void:
	var id := str(effect.get("id", ""))
	if not EFFECTS.has(id) or actor.hp <= 0.0 or actor.extraction_controls_locked() or CampSession.active or bool(actor.get_meta("editor_invincible",false)): return
	var duration := clampf(float(effect.get("duration",EFFECTS[id].duration)),0.0,8.0)
	if duration <= 0.0: return
	var current: Dictionary = actor._debuffs.get(id,{"left":0.0,"strength":0.0,"damage":0.0,"tick":0.0})
	current.left = maxf(float(current.left),duration)
	current.strength = maxf(float(current.strength),clampf(float(effect.get("strength",EFFECTS[id].strength)),0.0,0.5))
	current.damage = maxf(float(current.damage),clampf(float(effect.get("damage",0.0)),0.0,actor.max_hp*0.02))
	current.cruel_damage=bool(current.get("cruel_damage",false)) or bool(effect.get("cruel_damage",false))
	actor._debuffs[id] = current
	EventBus.player_stats_changed.emit()

static func from_source(actor: Player, source: Node) -> void:
	if not is_instance_valid(source) or not source.has_method("player_debuffs"): return
	var effects: Variant = source.call("player_debuffs")
	if not effects is Array: return
	for effect in effects:
		if effect is Dictionary: apply(actor,effect)

static func multiplier(actor: Player, stat: StringName) -> float:
	if not is_instance_valid(actor): return 1.0
	var strength := 0.0
	for id in actor._debuffs:
		var effect: Dictionary = actor._debuffs[id]
		if float(effect.get("left",0.0)) > 0.0 and str(EFFECTS.get(id,{}).get("stat","")) == str(stat): strength=maxf(strength,float(effect.get("strength",0.0)))
	return 1.0-clampf(strength,0.0,0.5)

static func advance(actor: Player, delta: float) -> void:
	var expired := false
	var tick_damage := 0.0
	var cruel_tick:=0.0
	for id in actor._debuffs.keys():
		if not actor._debuffs.has(id): continue
		var effect: Dictionary = actor._debuffs[id]
		var elapsed := minf(maxf(0.0,float(effect.left)),delta)
		effect.left = maxf(0.0,float(effect.left)-delta)
		if id=="mana_leech":
			effect.tick=float(effect.get("tick",0))+elapsed
			while float(effect.tick)>=1:
				effect.tick=float(effect.tick)-1;GameState.mp=maxf(0,GameState.mp-2);EventBus.mp_changed.emit(GameState.mp,GameState.MAX_MP)
		if id in ["poison","scorch","bleeding"]:
			effect.tick=float(effect.get("tick",0.0))+elapsed
			while float(effect.tick)>=1.0:
				effect.tick=float(effect.tick)-1.0
				# Uses the real HP/shield/passive/i-frame pipeline. No on-hit source:
				# a DoT cannot recursively apply effects or reflect into its old owner.
				var amount:=minf(float(effect.damage),actor.max_hp*0.02)
				tick_damage+=amount
				if bool(effect.get("cruel_damage",false)):cruel_tick+=amount
		if float(effect.left)<=0.0: actor._debuffs.erase(id); expired=true
	if expired: EventBus.player_stats_changed.emit()
	# Concurrent poison/burn ticks share one damage event, so one DoT's normal
	# hit protection cannot accidentally suppress the other status indefinitely.
	if tick_damage>0.0:
		if cruel_tick>0:
			var source:=CruelDamage.TickSource.new();source.cruel_amount=cruel_tick
			actor.take_damage(tick_damage,actor.global_position,source);source.free()
		else:actor.take_damage(tick_damage,actor.global_position,null)
		if actor.hp<=0.0:actor._debuffs.clear()
