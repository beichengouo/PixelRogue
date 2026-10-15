class_name BoundEquipment
extends RefCounted
static func is_bound(item:Dictionary)->bool:
	return ItemDB.is_equippable(item) and bool(item.get("bound",false))
static func from_camp(item:Dictionary)->Dictionary:
	var result:=item.duplicate(true)
	if ItemDB.is_equippable(result):result.bound=true
	return result
static func binding_price(item:Dictionary)->int:
	if not ItemDB.is_equippable(item) or is_bound(item):return 0
	return {2:500,3:1000}.get(int(item.get("rarity",0)),0)
static func retained(item:Dictionary)->bool:
	return ItemDB.is_material(item) or is_bound(item)
static func description()->String:
	return "绑定装备 · 成功撤离后原件入库，绑定保留；战斗死亡仍会丢失。"
static func badge(button:Control,item:Dictionary)->void:
	if not is_bound(item):return
	var badge:=PixelUi.label("绑",12,Color("a9f5d4"));badge.position=Vector2(3,2);badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
	badge.add_theme_color_override("font_outline_color",Color("133f35"));badge.add_theme_constant_override("outline_size",4);button.add_child(badge)
	button.tooltip_text+="\n"+description()
