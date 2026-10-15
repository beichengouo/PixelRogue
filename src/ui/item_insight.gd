class_name ItemInsight
extends RefCounted
## The same comparison is used by reward and shop descriptions.
static func describe(item: Dictionary, include_activation := true) -> String:
	if item.get("hire_token", false): return "选择后同行者立即加入队伍"
	var count := 0
	for owned in GameState.items:
		if owned.get("id", &"") == item.get("id", &"missing"): count += 1
	var lines: PackedStringArray = ["当前持有 %d 件" % count]
	if not item.get("mechanics", []).is_empty():
		for line in ItemDB.stat_lines(item): lines.append(line)
		lines.append(str(item.get("desc", "")))
		if str(item.get("requires_character", "")) == "xixifu": lines.append("仅希希芙可使用")
		if ItemDB.is_relic(item):
			lines.append("同名遗物效果：1件为100%，2件合计150%，3件合计175%；目标数、触发条件与冷却不增加")
	if ItemDB.is_usable(item):
		lines.append("获得后在背包使用，或放入药水快捷栏")
		return "\n".join(lines)
	if ItemDB.is_material(item):
		lines.append("成功撤回后全部入库；普通材料可手动出售，高品质蘑菇保留兑换")
		return "\n".join(lines)
	if ItemDB.is_equippable(item):
		if not ItemDB.can_equip(item):
			lines.append("当前角色无法装备");return "\n".join(lines)
		if include_activation: lines.append("需在背包装备后生效")
		var current := GameState.equipped(ItemDB.slot_of(item))
		if not current.is_empty(): lines.append("替换：" + str(current.get("name", "")))
	else:
		if include_activation: lines.append("遗物：获得后立即生效")
	var preview := GameState.preview_with(item)
	for entry in [[&"attack", "攻击", 1.0, ""], [&"attack_speed", "攻击速度", 1.0, ""], [&"max_hp", "生命上限", 1.0, ""], [&"move_speed", "移速", 1.0, ""], [&"crit_chance", "暴击", 100.0, "%"], [&"lifesteal", "普攻命中回复", 1.0, "点生命"], [&"crit_mult", "暴击伤害", 100.0, "%"], [&"dash_cooldown", "冲刺冷却", 1.0, ""], [&"thorns", "反伤", 1.0, ""], [&"mp_regen", "魔法回复速度", 1.0, "/秒"], [&"coin_gain", "金币收益倍率", 1.0, ""]]:
		var before := GameState.stats.get_value(entry[0]) * float(entry[2])
		var after := preview.get_value(entry[0]) * float(entry[2])
		if is_equal_approx(before, after): continue
		lines.append("%s  %s → %s" % [entry[1], stat_text(entry[0], GameState.stats.get_value(entry[0])), stat_text(entry[0], preview.get_value(entry[0]))])
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
