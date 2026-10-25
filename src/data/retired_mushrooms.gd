class_name RetiredMushrooms
extends RefCounted
## Compatibility redemption only. No generation, harvesting or exchange currency.
static func is_legacy(id:String)->bool:
	var suffix:=id.trim_prefix("glow_mushroom_")
	return id.begins_with("glow_mushroom_") and suffix.is_valid_int() and int(suffix)>=0 and int(suffix)<8
static func value(id:String)->int:
	var kind:=clampi(int(id.trim_prefix("glow_mushroom_")),0,7)
	return [12,15,160,12,162,26,22,512][kind]
static func redeem_bank()->bool:
	var before:Dictionary=Outpost.data.duplicate(true);var saved:Dictionary=SaveService.data.duplicate(true);var amount:=0
	for id in Outpost.data.get("inventory",{}).keys():
		if not is_legacy(str(id)):continue
		amount+=maxi(0,int(Outpost.data.inventory[id]))*value(str(id));Outpost.data.inventory.erase(id)
	if before==Outpost.data:return true
	Outpost.data.gold=Outpost.gold()+amount
	var ok:=Outpost._finish_mutation(before,saved)
	SaveService.migration_notice+=("\n" if not SaveService.migration_notice.is_empty() else "")+("旧蘑菇库存已折算为%d金币。"%amount if ok else "旧蘑菇折算未保存，原库存保留；下次启动会重试。")
	return ok
