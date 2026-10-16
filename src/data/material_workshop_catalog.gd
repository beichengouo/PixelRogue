class_name MaterialWorkshopCatalog
extends RefCounted
const ART:="res://assets/material_workshop_v01/"
const BOSS_MATERIALS:={
"boss_bone":{"name":"崩坏王骨","rarity":2,"price":0,"boss":"king","icon":"king","desc":"林之骸王留下的裂骨，残存着守护与契约的意志。用于亡灵刻印、营地装备研究与制作；不可出售或兑换购买。"},
"boss_crystal":{"name":"不稳定晶核","rarity":2,"price":0,"boss":"mage","icon":"mage","desc":"晶化巨影体内尚未平息的晶核。可催化晶化刻印，亦是晶体研究的关键材料；不可出售或兑换购买。"},
"boss_root":{"name":"深渊根心","rarity":3,"price":0,"boss":"tide","icon":"tide","desc":"潮汐之根最深处的新生脉动。仅终章首领产出，是林地高级制作的凭证；继续探索仍有死亡损失风险。"},
"boss_gate":{"name":"归城戟印","rarity":2,"price":0,"boss":"sephra","icon":"sephra","desc":"执印巡卫断戟上封存的归城印。用于守御刻印与定向制作；不可出售或兑换购买。"},
"boss_wax":{"name":"记忆封蜡","rarity":2,"price":0,"boss":"verena","icon":"verena","desc":"千页司书解除控制后遗留的封蜡，保存记忆而不束缚未来。用于回响刻印研究；不可出售。"},
"boss_star":{"name":"无名星核","rarity":3,"price":0,"boss":"nameless","icon":"nameless","desc":"无名录仪重获自由的星术核心。仅终章首领产出，用于星城高级研究与制作；不可出售或购买。"}}
const ALCHEMY:=[
{"id":"alch_health","name":"治疗药剂","product":"potion_health","research":"","variants":[{"forest_sample":2,"star_dust":1},{"wetland_sample":2,"star_dust":1},{"ruin_sample":2,"star_dust":1},{"glow_mushroom_0":2,"star_dust":1}]},
{"id":"alch_energy","name":"能量药剂","product":"potion_energy","research":"","variants":[{"star_dust":2,"forest_sample":2},{"star_dust":2,"wetland_sample":2},{"star_dust":2,"ruin_sample":2}]},
{"id":"alch_arcane","name":"秘法药剂","product":"potion_arcane","research":"alch_arcane","variants":[{"storm_crystal":1,"star_dust":2}]},
{"id":"alch_focus","name":"专注药剂","product":"potion_focus","research":"alch_focus","variants":[{"forest_resin":2,"star_dust":2},{"ruin_ore":1,"star_dust":2}]},
{"id":"alch_wind","name":"风行药剂","product":"potion_wind","research":"alch_wind","variants":[{"moss_cloth":2,"forest_sample":1},{"ruin_ore":1,"star_dust":2}]},
{"id":"alch_frost","name":"冰霜药剂","product":"potion_frost","research":"alch_frost","variants":[{"river_pearl":1,"star_dust":2},{"ancient_seal":1,"star_dust":2}]}]
const ENCHANTS:={
"ember":{"name":"余烬刻印","slot":"weapon","research":"","icon":"ember","desc":"普攻首次有效直击施加3秒燃烧，每秒造成角色攻击力8%的伤害。重复施加刷新，不与较强燃烧相加。","variants":[{"forest_resin":3,"star_dust":2},{"ruin_ore":2,"star_dust":2}]},
"moss":{"name":"苔纹护印","slot":"armor","research":"","icon":"moss","desc":"受到实际生命伤害后获得最大生命5%的护盾，持续3秒，冷却8秒。护盾取较强值。","variants":[{"moss_cloth":3,"star_dust":2},{"ruin_sample":3,"star_dust":2}]},
"tide":{"name":"回澜刻印","slot":"accessory","research":"","icon":"tide_etch","desc":"成功施放小技能后，4秒内下一次普攻首次有效命中回复2MP，冷却4秒。不储存次数。","variants":[{"wetland_sample":2,"star_dust":3},{"ruin_sample":2,"star_dust":3},{"forest_sample":2,"star_dust":3}]},
"crystal":{"name":"晶裂刻印","slot":"weapon","research":"etch_crystal","icon":"ember","desc":"普攻首次有效直击追加角色攻击力16%的装备伤害，冷却1秒。不暴击、不吸血、不递归触发。","variants":[{"boss_crystal":1,"star_dust":3}]},
"bone":{"name":"王骨护印","slot":"armor","research":"etch_bone","icon":"moss","desc":"受到实际生命伤害后获得最大生命7%的护盾3秒，并给予144范围最近友军其最大生命4%的护盾3秒，冷却8秒。","variants":[{"boss_bone":1,"moss_cloth":2}]},
"gate":{"name":"归城守印","slot":"armor","research":"etch_gate","icon":"moss","desc":"受到实际生命伤害后获得最大生命6%的护盾4秒，并使72范围内敌人减速20%持续2秒，首领减半，冷却8秒。","variants":[{"boss_gate":1,"ruin_ore":2}]},
"memory":{"name":"封蜡回印","slot":"accessory","research":"etch_memory","icon":"tide_etch","desc":"成功施放小技能后，4秒内下一次普攻首次有效命中回复4MP，冷却6秒。不储存次数。","variants":[{"boss_wax":1,"star_dust":3}]}}
const CRAFT:=[
{"id":"craft_mooncoat","name":"月辉行衣","product":"camp_mooncoat","research":"craft_mooncoat","variants":[{"forest_resin":4,"moss_cloth":4,"star_dust":3}]},
{"id":"craft_thornplate","name":"翠棘守甲","product":"camp_thornplate","research":"craft_thornplate","variants":[{"forest_sample":5,"moss_cloth":4,"star_dust":3}]},
{"id":"craft_windring","name":"苍风契戒","product":"camp_windring","research":"craft_windring","variants":[{"boss_gate":1,"ruin_ore":3,"star_dust":3}]},
{"id":"craft_stararmor","name":"星冕战甲","product":"camp_stararmor","research":"craft_stararmor","variants":[{"boss_root":1,"storm_crystal":2,"forest_resin":6}]},
{"id":"craft_sunpendant","name":"旭星坠饰","product":"camp_sunpendant","research":"craft_sunpendant","variants":[{"boss_star":1,"storm_crystal":2,"ruin_ore":6}]},
{"id":"craft_queenbrooch","name":"女王星章","product":"camp_queenbrooch","research":"craft_queenbrooch","variants":[{"boss_root":1,"boss_star":1,"ancient_seal":2}]}]
const RESEARCH:=[
{"id":"alch_arcane","name":"秘法炼金","desc":"解锁秘法药剂的制作配方。","needs":{"storm_crystal":1,"star_dust":5}},
{"id":"alch_focus","name":"专注炼金","desc":"解锁专注药剂的两种地区配方。","needs":{"forest_sample":3,"star_dust":6}},
{"id":"alch_wind","name":"风行炼金","desc":"解锁风行药剂的两种地区配方。","needs":{"moss_cloth":3,"star_dust":4}},
{"id":"alch_frost","name":"冰霜炼金","desc":"解锁冰霜药剂的两种地区配方。","needs":{"river_pearl":2,"star_dust":5}},
{"id":"etch_bone","name":"王骨守护研究","desc":"解锁护甲王骨护印，保护自己与最近的旅伴。","needs":{"boss_bone":1,"moss_cloth":3}},
{"id":"etch_crystal","name":"晶裂催化研究","desc":"解锁武器晶裂刻印，追加受限装备直击。","needs":{"boss_crystal":1,"storm_crystal":2}},
{"id":"etch_gate","name":"归城守御研究","desc":"解锁护甲归城守印，承伤后护盾与近身减速。","needs":{"boss_gate":1,"ancient_seal":2}},
{"id":"etch_memory","name":"记忆回流研究","desc":"解锁饰品封蜡回印，衔接施法与回蓝。","needs":{"boss_wax":1,"star_dust":8}},
{"id":"craft_mooncoat","name":"月辉缝制","desc":"解锁月辉行衣的定向制作，产物为绑定装备。","needs":{"boss_bone":1,"moss_cloth":4}},
{"id":"craft_thornplate","name":"翠棘织造","desc":"解锁翠棘守甲的定向制作，产物为绑定装备。","needs":{"boss_bone":1,"forest_resin":4}},
{"id":"craft_windring","name":"苍风契铸","desc":"解锁苍风契戒的定向制作，产物为绑定装备。","needs":{"boss_gate":1,"ruin_ore":4}},
{"id":"craft_stararmor","name":"根心星冕","desc":"解锁星冕战甲制作；需要潮汐之根的终章素材。","needs":{"boss_root":1,"ancient_seal":2}},
{"id":"craft_sunpendant","name":"无名旭星","desc":"解锁旭星坠饰制作；需要无名录仪的终章素材。","needs":{"boss_star":1,"ancient_seal":2}},
{"id":"craft_queenbrooch","name":"双章星约","desc":"解锁女王星章制作，结合两章终局战利品。","needs":{"boss_root":1,"boss_star":1,"star_dust":10}}]
static func recipe(id:String)->Dictionary:
	for row in ALCHEMY+CRAFT:
		if str(row.id)==id:return row
	return {}
static func research(id:String)->Dictionary:
	for row in RESEARCH:
		if str(row.id)==id:return row
	return {}
static func unlocked(id:String)->bool:return id.is_empty() or bool(Outpost.data.get("workshop",{}).get("unlocked",{}).get(id,false))
static func enchant(item:Dictionary)->Dictionary:
	var key:=str(item.get("enchant",""));var row:Dictionary=ENCHANTS.get(key,{})
	return row if not row.is_empty() and str(ItemDB.slot_of(item))==str(row.slot) else {}
static func description(item:Dictionary)->String:
	var row:=enchant(item)
	return "" if row.is_empty() else "%s · 本次出征有效\n%s"%[str(row.name),str(row.desc)]
static func boss_material(id:String)->String:
	for key in BOSS_MATERIALS:
		if str(BOSS_MATERIALS[key].boss)==id:return key
	return ""
static func cost_text(needs:Dictionary)->String:
	var parts:PackedStringArray=[]
	for id in needs:parts.append("%s ×%d"%[str(ExpeditionData.resolve(str(id)).get("name",id)),int(needs[id])])
	return "、".join(parts)
static func icon(id:String)->String:
	return ART+id+".png"

static var _uses_index:Dictionary={}
static func uses(id:String)->Array:
	if _uses_index.is_empty():
		for group in [["alchemy",ALCHEMY],["craft",CRAFT],["enchant",ENCHANTS.values()],["research",RESEARCH]]:
			for raw in group[1]:
				var row:Dictionary=raw.duplicate(true)
				if str(group[0])=="enchant":
					for key in ENCHANTS:
						if ENCHANTS[key]==raw:row.id=key;break
				var variants:Array=[row.needs] if str(group[0])=="research" else row.variants
				for index in variants.size():
					for material_id in variants[index]:
						if not _uses_index.has(str(material_id)):_uses_index[str(material_id)]=[]
						_uses_index[str(material_id)].append({"kind":str(group[0]),"id":str(row.id),"name":str(row.name),"variant":index,"needs":variants[index],"research":str(row.id) if str(group[0])=="research" else str(row.research)})
	return _uses_index.get(id,[])
