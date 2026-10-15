class_name RunBuildReport
extends RefCounted
## Rebuild from the frozen result snapshot, never the changing live state.
static func populate(label: Label, snapshot: Dictionary) -> void:
	var box := label.get_parent() as VBoxContainer
	for child in box.get_children():
		if child != label:
			box.remove_child(child)
			child.queue_free()
	var gear := UiFactory.hbox(12)
	box.add_child(gear)
	box.move_child(gear, 0)
	for slot in ItemDB.SLOTS:
		var item := ItemDB.by_id(StringName(snapshot.get("equipment", {}).get(str(slot), "")))
		var card := UiFactory.vbox(4)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gear.add_child(card)
		var heading := PixelUi.label(str(ItemDB.SLOT_NAMES[slot]), 16, PixelUi.MUTED)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(heading)
		if not item.is_empty():
			var icon := UiFactory.item_icon(item, 48)
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			card.add_child(icon)
		var name := PixelUi.label(str(item.get("name", "未装备")), 18, PixelUi.GOLD)
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name)
	var spells := UiFactory.hbox(12)
	box.add_child(spells)
	box.move_child(spells, 1)
	var ids: Array = snapshot.get("learned_skills", []).duplicate()
	ids.append(snapshot.get("ultimate_skill", ""))
	for id in ids:
		if str(id) == "": continue
		var skill := Skills.get_skill(StringName(id))
		if skill.is_empty(): continue
		var card := UiFactory.vbox(3)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spells.add_child(card)
		var icon := UiFactory.texture_icon(str(skill.get("icon", Skills.FRAME_EMPTY)), 40)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.add_child(icon)
		var name := PixelUi.label(str(skill.name), 16)
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name)
	var lines := ItemInsight.run_summary(snapshot).split("\n")
	label.text = "\n".join(lines.slice(2))
