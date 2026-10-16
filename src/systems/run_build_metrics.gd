class_name RunBuildMetrics
extends RefCounted
## Bounded counters owned by the expedition, fed only by committed combat events.
const CHANNELS:={"basic":"普攻","skill":"技能","dot":"持续伤害","ally":"友军","equipment":"装备附加","fate":"命运牌"}
static func empty(recorded:=true)->Dictionary:
	return {"recorded":recorded,"partial":not recorded,"damage":{},"triggers":{}}
static func normalize(raw:Variant)->Dictionary:
	var result:=empty(false)
	if not raw is Dictionary:return result
	result.recorded=bool(raw.get("recorded",false));result.partial=bool(raw.get("partial",false))
	for group in ["damage","triggers"]:
		if not raw.get(group,{}) is Dictionary:continue
		for key in raw.get(group,{}):
			var value:Variant=raw[group][key]
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)<0:continue
			if group=="damage" and CHANNELS.has(str(key)):result.damage[str(key)]=float(value)
			elif group=="triggers" and valid_trigger(str(key)):result.triggers[str(key)]=int(value)
	return result
static func valid_trigger(key:String)->bool:
	return key.begins_with("fate:") and FateCatalog.CARDS.has(key.trim_prefix("fate:")) or key.begins_with("etch:") and MaterialWorkshopCatalog.ENCHANTS.has(key.trim_prefix("etch:"))
static func active()->bool:
	return GameState.run_active and not CampSession.active and is_instance_valid(GameState.player) and GameState.player.hp>0 and GameState.player.is_inside_tree() and not GameState.player.get_tree().paused
static func trigger(key:String,effective:=true)->void:
	if not active() or not valid_trigger(key):return
	if effective:
		GameState.build_stats.recorded=true
		GameState.build_stats.triggers[key]=int(GameState.build_stats.triggers.get(key,0))+1
	for strip in GameState.player.get_tree().get_nodes_in_group("player_status_strips"):
		if strip.has_method("pulse"):strip.pulse(key)
static func hit(enemy:EnemyBase,amount:float,source:Node,kind:StringName,fate_factor:=1.0)->void:
	if not active() or not enemy.is_inside_tree() or enemy.is_queued_for_deletion() or enemy.training_target or amount<=0 or not is_finite(amount) or not is_instance_valid(source):return
	var channel:=""
	if source is DamageContext:
		var parent:=source.get_parent()
		if parent is HiredAlly:channel="ally"
		elif parent is Player:
			match str(source.owner_kind):
				"ally":channel="ally"
				"fate":channel="fate"
				"dot","spread_burn":channel="dot"
				"equipment","reflection":channel="equipment"
				"basic_splash":channel="basic"
				"skill","skill_field","character_proc","player":channel="skill"
			if CHANNELS.has(str(source.report_channel)):channel=str(source.report_channel)
	elif source is HiredAlly:channel="ally"
	elif source is RoomProjectile:
		if source.is_friendly:channel="ally" if source.damage_owner==&"ally" else ("basic" if source.is_basic_attack else "skill")
	elif source is Player:channel="basic" if kind==&"basic" else "skill"
	if channel.is_empty():return
	GameState.build_stats.recorded=true
	GameState.build_stats.damage[channel]=float(GameState.build_stats.damage.get(channel,0))+amount
	var ally_source:Node=source.get_parent() if source is DamageContext else source
	if kind==&"ally" and fate_factor>1.0 and FateCatalog.rank("empress")>0 and ally_source is HiredAlly:trigger("fate:empress");FateRuntime.repair_ally_hit()
	var neutral:=1.0+(.08 if kind==&"basic" and FateCatalog.star()=="torch" else 0.0)-(.08 if kind==&"basic" and FateCatalog.rank("moon")==2 else 0.0)
	# Reuse the actual damage multiplier, avoiding another full ally search.
	if kind in [&"basic",&"skill"] and FateCatalog.rank("hermit")>0 and fate_factor>neutral+.001:trigger("fate:hermit")
static func describe(snapshot:Dictionary)->String:
	var stats:=normalize(snapshot.get("build_stats"))
	if not stats.recorded:return "更新前未记录构筑表现。"
	var lines:PackedStringArray=[]
	if stats.partial:lines.append("仅统计更新后的有效伤害与触发次数。")
	var total:=0.0
	for key in CHANNELS:total+=float(stats.damage.get(key,0))
	lines.append("有效伤害合计 %.0f（不含护盾吸收、过量伤害及训练）"%total)
	for key in CHANNELS:lines.append("%s：%.0f · %.1f%%"%[CHANNELS[key],float(stats.damage.get(key,0)),float(stats.damage.get(key,0))/total*100 if total>0 else 0])
	for key in stats.triggers:
		var id:=str(key).get_slice(":",1)
		var title:String=str(FateCatalog.CARDS[id].name) if str(key).begins_with("fate:") else str(MaterialWorkshopCatalog.ENCHANTS[id].name)
		lines.append("%s · 实际触发 %d 次"%[title,int(stats.triggers[key])])
	return "\n".join(lines)
