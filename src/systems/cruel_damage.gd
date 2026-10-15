class_name CruelDamage
extends RefCounted
class TickSource extends Node:
	var cruel_damage:=true
	var cruel_amount:=0.0
## Latch projectile/hazard damage before an owner dies or a save is restored.
static func applies(source:Node)->bool:
	if not is_instance_valid(source):return false
	if source is RoomProjectile:return source.cruel_damage
	if source is AffixHazard:return source.cruel_damage
	if source is TickSource:return source.cruel_amount>0.0
	if source.has_method("has_affix") and bool(source.call("has_affix",EnemyAffixes.CRUEL)):return true
	for property in source.get_property_list():
		if str(property.name)=="cruel_damage":return bool(source.get("cruel_damage"))
	return false
static func portion(source:Node,amount:float)->float:
	if source is TickSource:return clampf(source.cruel_amount,0,amount)
	return amount if applies(source) else 0.0
