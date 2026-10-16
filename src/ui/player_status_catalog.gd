class_name PlayerStatusCatalog
extends RefCounted
## Read-only view of the combat timers. Never starts a second HUD countdown.
const DATA_PATH := "res://data/player_statuses.json"
static var _definitions: Dictionary = {}

static func definitions() -> Dictionary:
	if _definitions.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary: _definitions = parsed.get("statuses", {})
	return _definitions

static func _append(rows: Array[Dictionary], id: String, remaining: float, detail: String = "", stacks: int = 0, harmful: bool = false, key: String = "", permanent:=false) -> void:
	if not permanent and (not is_finite(remaining) or remaining <= 0.0): return
	var info: Dictionary = definitions().get(id, {})
	if info.is_empty(): return
	var identity:=key if not key.is_empty() else id
	for row in rows:
		if str(row.id)==identity:
			row.remaining=maxf(float(row.remaining),remaining);row.stacks=maxi(int(row.stacks),stacks);row.permanent=bool(row.permanent) or permanent
			return
	rows.append({"id": identity, "icon_id": id,
		"name": str(info.name), "description": detail if not detail.is_empty() else str(info.description),
		"remaining": remaining, "permanent":permanent,"stacks": stacks, "debuff": harmful or bool(info.get("debuff", false)),
		"icon": str(info.get("icon","res://assets/player_status_v01/" + id + ".png"))})

static func snapshot(actor: Player) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.hp <= 0.0: return rows
	if FateCatalog.active():
		for card in GameState.fate.cards:
			var id:=str(card.id);var reversed:=bool(card.reverse)
			rows.append({"id":"fate_"+id,"badge":"逆" if reversed else "正","icon_id":"fate_"+id,"name":str(FateCatalog.CARDS[id].name)+(" · 逆位" if reversed else " · 正位"),"description":FateCatalog.description(id,reversed),"remaining":0.0,"permanent":true,"stacks":0,"debuff":false,"icon":FateCatalog.icon(id)})
		var star:=FateCatalog.star()
		if not star.is_empty():rows.append({"id":"star_"+star,"icon_id":"star_"+star,"name":str(FateCatalog.STARS[star].name),"description":str(FateCatalog.STARS[star].description)+"本次出征生效。","remaining":0.0,"permanent":true,"stacks":0,"debuff":false,"icon":FateCatalog.icon(star)})
		for id in ["magician","priestess","chariot"]:
			var remaining:=float(GameState.fate.pending.get(id,0))
			if FateCatalog.rank(id)>0 and remaining>0:rows.append({"id":"fate_pending_"+id,"icon_id":"fate_"+id,"name":str(FateCatalog.CARDS[id].name)+" · 待发","description":"强化尚未消耗；"+FateCatalog.description(id,FateCatalog.rank(id)==2),"remaining":remaining,"permanent":false,"stacks":0,"debuff":false,"icon":FateCatalog.icon(id)})
	if RoomInput.using_auto():_append(rows,"clumsy",0,"",0,true,"",true)
	if RunDifficulty.is_bloodbath(GameState.difficulty) and not CampSession.active:_append(rows,"bloodbath",0,"证明你的荣耀\n受到真实伤害；灰色伤痕 %.1f 生命上限。普通回血无效，星星／女皇命运牌可部分修复并返还等量生命。"%actor.bloodbath_hp_loss,0,true,"",true)
	_append(rows,"dash_cooldown",actor._dash_cd)
	if actor is RoomPlayer and is_instance_valid((actor as RoomPlayer).holy_runtime):
		var holy:HolyRuntime=(actor as RoomPlayer).holy_runtime
		if holy.prayer>0:_append(rows,"holy_prayer",0,"祈光 %.0f／100；有效直击或护盾实际承伤积累。"%holy.prayer,ceili(holy.prayer/20),false,"",true)
		if holy.prayer>=100:_append(rows,"holy_full",0,"",0,false,"",true)
		for entry in [["holy_feathers",holy.feathers_until],["holy_cloud",holy.cloud_until],["holy_attack",holy.step_attack_until],["holy_judgment",holy.judgment_until],["holy_sanctuary",holy.sanctuary_until],["holy_grace",holy.grace_until],["holy_afterlight",holy.afterlight_until],["holy_hymn",holy.hymn_until],["holy_devout",holy.devout_until]]:_append(rows,str(entry[0]),float(entry[1])-holy.clock)
		for field in holy.fields:
			if field.kind=="court" and actor.global_position.distance_to(holy.at(field))<=90:_append(rows,"holy_dew",float(field.remaining));break
	if not CampSession.active:
		for id:String in AltarBlessings.DEFINITIONS:
			var rank:=int(GameState.altar_blessings.get(id,0))
			if rank>0:_append(rows,"altar_"+id,0,"%s／级 · 当前%d／3级 · 本次出征永久。"%[AltarBlessings.DEFINITIONS[id].description,rank],rank,false,"",true)
	if actor.permanent_hp_loss()>0.0:
		_append(rows,"cruel",0,"本次出征伤痕 %.1f 生命上限（残忍 %.1f／浴血 %.1f）；血条灰色显示，可由星星／女皇命运牌部分修复。"%[actor.permanent_hp_loss(),actor.cruel_hp_loss,actor.bloodbath_hp_loss],0,true,"",true)
		rows[-1].name="生命伤痕"
	for buff in GameState.temp_buffs:
		var label := str(buff.get("label", ""))
		# Wind rhythm uses an artificial one-hour stat entry. Its real decay is below.
		if label in ["风之律动·攻速", "风之律动·移动"]: continue
		var stat := str(buff.get("stat", ""))
		var id: String = {"attack": "arcane", "thorns": "frost", "attack_speed": "focus", "move_speed": "wind"}.get(stat, "arcane")
		if label == "灵动编织": id = "weave"
		elif label == "林影": id = "forest_shadow"
		elif label == "风铃回响":id="wind_chime"
		var harmful := float(buff.get("value", 0.0)) < 0.0
		var key:="stat_"+stat+("_"+str(buff.source) if not str(buff.get("source","")).is_empty() else "")
		_append(rows, id, float(buff.get("remaining", 0.0)), label + "\n" + str(definitions()[id].description), 0, harmful, key)
		if not rows.is_empty() and rows[-1].id == key and not label.is_empty(): rows[-1].name = label
	if actor.shield_hp > 0.0:
		_append(rows, "shield", actor._shield_time, "吸收伤害的护盾，剩余护盾 %.0f。耗尽或到期即消失。" % actor.shield_hp)
	for id in actor._debuffs:
		var effect: Dictionary = actor._debuffs[id]
		_append(rows,str(id),float(effect.get("left",0.0)),"",0,true)
	var strength := 0.0
	var slow_left := 0.0
	for slow in actor._slows:
		if float(slow.get("left", 0.0)) <= 0.0 or float(slow.get("strength", 0.0)) <= 0.0: continue
		if float(slow.strength) > strength:
			strength = float(slow.strength); slow_left = float(slow.left)
		elif is_equal_approx(float(slow.strength), strength): slow_left = maxf(slow_left, float(slow.left))
	_append(rows, "slow", slow_left, "当前移动速度降低 %.0f%%；较强减速结束后，按仍生效的减速更新。" % (strength * 100.0))
	_append(rows, "invulnerable", actor._invuln, "女神接引期间的短暂无敌。" if actor.extraction_controls_locked() else "")
	if actor is RoomPlayer:
		var player := actor as RoomPlayer
		var gear := player.equipment_mechanics
		if is_instance_valid(gear):
			if gear.has(&"amber_pendulum"):_append(rows,"amber_pendulum",gear.wayfarer.pendulum_until-gear.clock,"下一次小技能伤害增加%.0f%%，施放后消耗。"%(16*gear.scale(&"amber_pendulum")))
			var single:=gear.legendary
			for entry in [["circlet_memory","eternal_circlet",single.circlet_until,single.circlet_hits],["covenant_beats","covenant_bells",single.covenant_until,single.covenant_hits],["lakeleaf_stacks","lakeleaf_guard",single.lakeleaf_until,single.lakeleaf_hits],["moonwind_echo","moonwind_chime",single.chime_until,single.chime_echoes]]:
				if gear.has(StringName(entry[1])) and int(entry[3])>0:_append(rows,str(entry[0]),float(entry[2])-gear.clock,"",int(entry[3]))
			var cadence:=gear.cadence
			for entry in [["storm_conductor",cadence.storm_until,cadence.storm_hits],["mana_reservoir",cadence.reservoir_until,cadence.reservoir_charges],["orbit_guard",cadence.ally_until,cadence.ally_hits],["cadence_prism",cadence.cadence_until,cadence.cadence_stacks],["copper_metre",cadence.metre_until,cadence.metre_hits],["wayfarer_score",cadence.score_until,cadence.score_hits]]:
				if gear.has(StringName(entry[0])) and (int(entry[2])>0 or (str(entry[0])=="cadence_prism" and cadence.cadence_kind>0)):_append(rows,str(entry[0]),float(entry[1])-gear.clock,"",int(entry[2]))
			for entry in [["counterbeat",cadence.counter_until],["dew_battery",cadence.battery_until],["sentinel_thread",cadence.sentinel_until]]:
				if gear.has(StringName(entry[0])):_append(rows,str(entry[0]),float(entry[1])-gear.clock)
			if gear.has(&"spring_wind_bow"):
				if gear.legendary.spring_charges>0:_append(rows,"spring_charges",gear.legendary.spring_until-gear.clock,"",gear.legendary.spring_charges)
				if gear.legendary.spring_echoes>0:_append(rows,"spring_echo",gear.legendary.spring_echo_until-gear.clock,"",gear.legendary.spring_echoes)
			if gear.has(&"half_star"):_append(rows,"half_star",gear.expansion.dash_until-gear.clock)
			if gear.has(&"leaf_page"):_append(rows,"leaf_page",gear.expansion.verse_until-gear.clock)
			if gear.etching.current(&"accessory") in ["tide","memory"] and not gear.ready(&"material_accessory_pending"):_append(rows,"material_tide",float(gear.cooldowns.get(&"material_accessory_pending",0))-gear.clock,"下一次普通攻击首次有效命中回复%d MP；卸下或替换刻印后失效。"%(4 if gear.etching.current(&"accessory")=="memory" else 2))
			if gear.has(&"cloud_staff") and gear.legendary.cloud_charges>0:_append(rows,"cloud_runes",gear.legendary.cloud_until-gear.clock,"",gear.legendary.cloud_charges)
			if gear.legendary.halo_orbs>0:_append(rows,"cloud_orbs",gear.legendary.halo_until-gear.clock,"",gear.legendary.halo_orbs)
			if Characters.current_id()==&"ilyua" and LegendarySets.complete() and gear.legendary.moon_hits>0:_append(rows,"moon_oath",gear.legendary.moon_until-gear.clock,"",gear.legendary.moon_hits)
			if gear.has(&"wind_branch"): _append(rows, "wind_fan", gear.wind_until - gear.clock)
			if gear.has(&"tide_pearl"): _append(rows, "tide", gear.tide_until - gear.clock)
			if gear.has(&"patrol_bell"): _append(rows, "patrol", gear.patrol_until - gear.clock)
		var elf := player.ilyua_runtime
		if is_instance_valid(elf):
			_append(rows,"wind_pierce",elf.wind_pierce_until-elf.clock)
			_append(rows, "thousand_winds", elf.ultimate_left)
			var reaction_left := 0.0
			var reactions := 0
			for moon in elf.moon_slots:
				if str(moon.get("kind", "")) == "reaction" and float(moon.get("expires", 0.0)) > elf.clock and float(moon.get("ready", 0.0)) <= elf.clock:
					reaction_left = maxf(reaction_left, float(moon.expires) - elf.clock); reactions += 1
			_append(rows, "moon", maxf(elf.moon_left, reaction_left), "月影箭阵：月箭可挡弹或自动攻击，消耗后重新凝聚。" if elf.moon_left > 0.0 else "成功闪避获得的临时反击月箭，可挡弹或反击；消耗即消失。", elf.moon_charges if elf.moon_left > 0.0 else reactions)
			_append(rows, "pact", elf.next_basic_until - elf.clock)
			if elf.light_empower: _append(rows, "light_arrow", elf.light_empower_until - elf.clock)
			_append(rows, "phase", float(elf._skill_history.get("phase_until", 0.0)) - elf.clock)
			_append(rows, "forest_will", float(elf._skill_history.get("will_until", 0.0)) - elf.clock)
			_append(rows, "nature_favor", float(elf._skill_history.get("favor_until", 0.0)) - elf.clock)
			if GameState.passive_id == &"ilyua_wind_rhythm" and elf.wind_stacks > 0:
				var grace := 3.0 if player.velocity.length_squared() > 64.0 else 2.0
				var decay_left := maxf(0.0, grace - elf.no_fire) + maxf(0.0, elf.wind_stacks - elf.wind_grace)
				_append(rows, "wind_rhythm", decay_left, "每层攻速 +2%、箭速 +4%。按当前移动状态显示不再攻击时的完全衰减时间；攻击会刷新宽限，受伤会失去两层。", elf.wind_stacks)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority_a := 0 if a.debuff else (1 if a.icon_id == "shield" else 2)
		var priority_b := 0 if b.debuff else (1 if b.icon_id == "shield" else 2)
		return str(a.id) < str(b.id) if priority_a == priority_b else priority_a < priority_b)
	return rows
