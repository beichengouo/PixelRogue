class_name ItemInsight
extends RefCounted
## The same comparison is used by reward and shop descriptions.
static func describe(item: Dictionary, include_activation := true, include_rules:=true, include_story:=true) -> String:
	if item.get("hire_token",false):return "选择后同行者立即加入队伍"
	var count:=0
	for owned in GameState.items:
		if str(owned.get("id",""))==str(item.get("id","missing")):count+=1
	var lines:PackedStringArray=["当前持有 %d 件"%count]
	if not item.get("mechanics",[]).is_empty():
		for line in ItemDB.stat_lines(item):lines.append(line)
		if include_rules:lines.append(str(item.get("desc","")))
	if ItemDB.is_usable(item):lines.append("获得后在背包使用，或放入药剂快捷栏")
	elif ItemDB.is_material(item):lines.append("成功撤回后入库；材料可用于委托或兑换")
	else:
		if ItemDB.is_equippable(item):
			if not ItemDB.can_equip(item):return "当前角色无法装备"
			if include_activation:lines.append("需在背包装备后生效")
			var current:=GameState.equipped(ItemDB.slot_of(item))
			if not current.is_empty():lines.append("替换："+str(current.name))
		else:
			if include_activation:lines.append("遗物：获得后立即生效")
			if ItemDB.is_relic(item):lines.append(relic_increment(item,count))
		var preview:=GameState.preview_with(item)
		for entry in [[&"attack","攻击"],[&"attack_speed","攻击速度"],[&"max_hp","生命上限"],[&"move_speed","移速"],[&"crit_chance","暴击"],[&"lifesteal","普攻命中回复"],[&"crit_mult","暴击伤害"],[&"dash_cooldown","闪避冷却"],[&"thorns","反伤"],[&"mp_regen","魔法回复速度"],[&"coin_gain","金币收益倍率"]]:
			var before:=GameState.stats.get_value(entry[0]);var after:=preview.get_value(entry[0])
			if not is_equal_approx(before,after):lines.append("%s  %s → %s"%[entry[1],stat_text(entry[0],before),stat_text(entry[0],after)])
		if ItemDB.is_equippable(item):
			var lost:=replacement_losses(item)
			if not lost.is_empty():lines.append(lost)
	if include_story:
		var flavor:=ItemDB.flavor_text(item)
		if not flavor.is_empty():lines.append("\n"+flavor)
	return "\n".join(lines)

static func run_summary(snapshot: Dictionary = {}) -> String:
	var data := GameState.snapshot() if snapshot.is_empty() else snapshot.duplicate(true)
	var names: PackedStringArray = []
	var equipment: Dictionary = data.get("equipment", {})
	for slot in ItemDB.SLOTS:
		var id := StringName(equipment.get(str(slot), ""))
		var item := ItemDB.by_id(id)
		if not item.is_empty(): names.append(str(item.get("name", "")))
	var total := 0
	var loot_data: Dictionary = data.get("run_loot", {})
	for count in loot_data.values(): total += int(count)
	var loot := "暂无记录" if not bool(data.get("loot_history_complete", true)) else "%d 件 / %d 种" % [total, loot_data.size()]
	var points := 0
	var talent_names: PackedStringArray = []
	for id in data.get("talents", {}):
		var rank := int(data.talents[id])
		points += rank
		if rank > 0 and GameState.TALENT_BRANCHES.has(StringName(id)): talent_names.append("%s %d级" % [GameState.TALENT_BRANCHES[StringName(id)].name, rank])
	var skills: PackedStringArray = []
	for id in data.get("learned_skills", []):
		if str(id) != "": skills.append(str(Skills.get_skill(StringName(id)).get("name", id)))
	var ultimate := StringName(data.get("ultimate_skill", ""))
	if ultimate != &"": skills.append(str(Skills.get_skill(ultimate).get("name", ultimate)))
	return "最终配装：%s\n法术：%s\n天赋：%s\n本局收获：%s\n成长：Lv.%d · 已投入 %d 点天赋 · 同行者 %d 位" % [" / ".join(names) if not names.is_empty() else "未装备", " / ".join(skills) if not skills.is_empty() else "未装配", " / ".join(talent_names) if not talent_names.is_empty() else "未投入", loot, int(data.get("level", 1)), points, data.get("hired", []).size()]


static func stat_text(stat: StringName, value: float) -> String:
	if stat == &"lifesteal": return "%.0f 点生命" % value
	if stat in [&"crit_chance", &"crit_mult"]: return "%.0f%%" % (value * 100.0)
	if stat == &"dash_cooldown": return "%.2f 秒" % value
	if stat == &"mp_regen": return "%.1f/秒" % value
	if stat in [&"coin_gain",&"attack_speed"]: return "%.2f×" % value
	return "%.1f" % value if absf(value - roundf(value)) > 0.01 else "%.0f" % value

static func replacement_losses(item:Dictionary)->String:
	var current:=GameState.equipped(ItemDB.slot_of(item))
	if current.is_empty() or GameState.is_equipped(item) or str(current.get("id",""))==str(item.get("id","")):return ""
	var lines:PackedStringArray=[]
	if not current.get("mechanics",[]).is_empty():lines.append("替换将失去「%s」的单件机制：%s"%[str(current.name),str(current.desc)])
	if LegendarySets.complete():
		var set:Dictionary=LegendarySets.DATA.get(Characters.current_id(),{})
		if str(current.id)==str(set.get(str(ItemDB.slot_of(item)),"")):lines.append("替换后不再成套，套装效果将失效；已解锁立绘保留。")
	return "\n".join(lines)
static func relic_increment(item:Dictionary,count:int=-1)->String:
	if not ItemDB.is_relic(item):return ""
	if count<0:
		count=0
		for owned in GameState.items:
			if str(owned.get("id",""))==str(item.get("id","")):count+=1
	if item.get("mechanics",[]).is_empty():return "同名已持有%d件 · 再获得1件将继续叠加该物品属性；变化见属性对比。"%count
	var before:float=[0.0,1.0,1.5,1.75][clampi(count,0,3)]
	var after:float=[0.0,1.0,1.5,1.75][clampi(count+1,0,3)]
	return "同名已持有%d件 · 再获得1件增加基础机制数值的%.0f%%（合计%.0f%% → %.0f%%）；次数、目标数和冷却不增加。"%[count,(after-before)*100,before*100,after*100]
static func append_story(parent:Control,item:Dictionary,font_size:=17)->void:
	var text:=ItemDB.flavor_text(item)
	if text.is_empty():return
	var toggle:=PixelUi.compact_button("背景故事 ▸",font_size);toggle.name="ItemLoreToggle";toggle.set_meta("item_lore_toggle",true);parent.add_child(toggle)
	var story:=PixelUi.label(text,font_size,PixelUi.MUTED);story.name="ItemLoreText";story.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;story.size_flags_horizontal=Control.SIZE_EXPAND_FILL;story.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(story);story.hide()
	toggle.pressed.connect(func()->void:story.visible=not story.visible;toggle.text="背景故事 ▾" if story.visible else "背景故事 ▸")

static func talent_requirement(branch:StringName)->String:
	var info:Dictionary=GameState.TALENT_BRANCHES.get(branch,{})
	if info.is_empty():return "天赋不可用"
	if GameState.talent_rank(branch)>=int(info.get("max_rank",3)):return "已达到最高等级"
	var needs:PackedStringArray=[]
	for id in info.get("requires",{}):
		var level:=int(info.requires[id]);var current:=GameState.talent_rank(StringName(id))
		if current<level:needs.append("%s需要%d级（当前%d级）"%[str(GameState.TALENT_BRANCHES[id].name),level,current])
	if not needs.is_empty():return "前置未满足："+"；".join(needs)
	return "天赋点不足：需要1点，当前0点" if GameState.talent_points<=0 else "投入1点提升至%d级"%(GameState.talent_rank(branch)+1)
