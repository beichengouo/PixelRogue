class_name ExpeditionData
extends RefCounted

const DANGER_HP = [1.0, 1.15, 1.30, 1.50]
const DANGER_VALUE = [1.0, 1.20, 1.40, 1.65]
const CAPACITY = 24
const MATERIALS = {
	"forest_resin": {"name":"林脂凝晶", "price":10, "rarity":0, "icon":0},
	"river_pearl": {"name":"溪湾明珠", "price":18, "rarity":1, "icon":0},
	"moss_cloth": {"name":"苔纹织片", "price":9, "rarity":0, "icon":0},
	"ruin_ore": {"name":"遗迹铁矿", "price":16, "rarity":1, "icon":0},
	"storm_crystal": {"name":"风暴晶核", "price":30, "rarity":2, "icon":0},
	"ancient_seal": {"name":"远古封印片", "price":34, "rarity":2, "icon":0},

	"forest_sample": {"name":"林地晶芽", "price":8, "rarity":0, "icon":0},
	"wetland_sample": {"name":"湿地琥珀", "price":10, "rarity":0, "icon":2},
	"ruin_sample": {"name":"遗迹碎晶", "price":12, "rarity":1, "icon":4},
	"deep_evidence": {"name":"深层黑晶物证", "price":24, "rarity":2, "icon":6},
	"echo_evidence": {"name":"回廊回响物证", "price":36, "rarity":2, "icon":7},
	"star_dust": {"name":"星辉尘", "price":6, "rarity":0, "icon":1},
	"memory_gift": {"name":"未褪色的记忆花", "price":16, "rarity":1, "icon":3},
}
const CONTRACTS = [
	{"id":"survey","title":"地区踏勘","desc":"带回三份地区样本：林地晶芽2份与湿地琥珀1份，或星城遗迹碎晶3份。旧三地样本各1份亦可等价提交。","needs":{"forest_sample":2,"wetland_sample":1},"danger":0,"wave":1,"unlock":1,"reward":30,"owner":"merchant","issuer":"surveyor","bond":3,"penalty":2,"hours":2,"require":""},
	{"id":"deep","title":"黑晶的来处","desc":"提交2份深层黑晶物证（危险或绝境，第10场起掉落）。","needs":{"deep_evidence":2},"danger":1,"wave":10,"unlock":2,"reward":60,"owner":"iris","bond":4,"penalty":3,"hours":6,"require":"survey"},
	{"id":"echo","title":"回廊的代价","desc":"提交3份回廊回响物证（绝境，第20场起掉落）。","needs":{"echo_evidence":3},"danger":2,"wave":20,"unlock":3,"reward":100,"owner":"sylphiette","bond":5,"penalty":4,"hours":12,"require":"deep"},
	{"id":"daily_repairs","title":"货架的修补","desc":"提交苔纹织片3份、林脂凝晶2份。每日可完成一次。","needs":{"moss_cloth":3,"forest_resin":2},"danger":0,"wave":1,"unlock":0,"reward":35,"owner":"merchant","issuer":"carpenter","bond":2,"penalty":1,"hours":2,"require":"","repeatable":true},
	{"id":"daily_soup","title":"雨夜的药汤","desc":"提交焰光菇2份。每日可完成一次。","needs":{"glow_mushroom_0":2},"danger":0,"wave":1,"unlock":0,"reward":30,"owner":"tavern","issuer":"herbalist","bond":3,"penalty":2,"hours":6,"require":"","repeatable":true},
	{"id":"daily_flower","title":"留给归人的花","desc":"提交未褪色的记忆花1份、林地晶芽2份。每日可完成一次。","needs":{"memory_gift":1,"forest_sample":2},"danger":0,"wave":1,"unlock":0,"reward":25,"owner":"sylphiette","bond":4,"penalty":2,"hours":12,"require":"","repeatable":true},
	{"id":"daily_seal","title":"修补旧约","desc":"提交远古封印片1份、风暴晶核1份。每日可完成一次。","needs":{"ancient_seal":1,"storm_crystal":1},"danger":2,"wave":1,"unlock":0,"reward":50,"owner":"iris","bond":5,"penalty":3,"hours":12,"require":"deep","repeatable":true},
]

static func material(id: String) -> Dictionary:
	if not MATERIALS.has(id) and not MaterialWorkshopCatalog.BOSS_MATERIALS.has(id): return {}
	var d: Dictionary = MATERIALS.get(id,MaterialWorkshopCatalog.BOSS_MATERIALS.get(id,{}))
	return {"id":StringName(id),"name":d.name,"kind":&"material","rarity":d.rarity,"cost":d.price,
		"desc":d.get("desc","用于战地炼金、装备刻印、委托与营地研究；成功撤离后入库，死亡会丢失本局携带材料。"),"flat":{},"mult":{},
		"icon":{"tex":material_icon(id)}}

static func resolve(id: String) -> Dictionary:
	if MATERIALS.has(id) or MaterialWorkshopCatalog.BOSS_MATERIALS.has(id): return material(id)
	if id.begins_with("glow_mushroom_"): return ItemDB.mushroom_item(int(id.trim_prefix("glow_mushroom_")))
	for raw in ItemDB.all():
		if str(raw.get("id","")) == id: return raw.duplicate(true)
	return {}

static func retained(id: String) -> bool:
	return ItemDB.is_material(resolve(id))

static func stack_limit(item: Dictionary) -> int:
	if ItemDB.is_material(item): return 20
	if ItemDB.is_usable(item): return 5
	return 1

static func sale_value(item: Dictionary) -> int:
	if MaterialWorkshopCatalog.BOSS_MATERIALS.has(str(item.get("id",""))):return 0
	if str(item.get("id","")).begins_with("glow_mushroom_") and int(item.get("rarity",0))>0:return 0
	if not ItemDB.is_equippable(item) and not ItemDB.is_material(item) and not ItemDB.is_usable(item) and not ItemDB.is_relic(item): return 0
	var base = int(item.get("_base_cost", item.get("cost",0)))
	if ItemDB.is_equippable(item) or ItemDB.is_relic(item): return maxi(1,int(floor(base*0.5)))
	if ItemDB.is_usable(item): return mini(maxi(0,int(item.get("sale_value",floor(base*.5)))),maxi(1,int(floor(base*.5)))) if bool(item.get("workshop_made",false)) else maxi(1,int(floor(base*.5)))
	return maxi(1,int(item.get("sale_value",base)))

static func catalog(max_rarity: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw in ItemDB.all():
		if (ItemDB.is_equippable(raw) or ItemDB.is_usable(raw)) and ItemDB.in_source(raw,&"shop") and int(raw.get("rarity",0)) <= max_rarity:
			out.append(raw.duplicate(true))
	return out

static func pack(item: Dictionary) -> Dictionary:
	return {"id":str(item.get("id","")),"uid":str(item.get("uid","")),"sale_value":int(item.get("sale_value",-1)),"base":int(item.get("_base_cost",item.get("cost",0))),"bound":BoundEquipment.is_bound(item),"enchant":str(item.get("enchant","")),"workshop_made":bool(item.get("workshop_made",false))}

static func unpack(record: Dictionary) -> Dictionary:
	var item = resolve(str(record.get("id","")))
	if item.is_empty(): return {}
	item["uid"] = str(record.get("uid",""))
	item.workshop_made=bool(record.get("workshop_made",false))
	var etch:=str(record.get("enchant",""))
	if MaterialWorkshopCatalog.ENCHANTS.has(etch) and str(ItemDB.slot_of(item))==str(MaterialWorkshopCatalog.ENCHANTS[etch].slot):item.enchant=etch
	if ItemDB.is_equippable(item):
		item.bound=bool(record.get("bound",false))
		# Older sorties did not save binding flags. Only their original launch
		# instances qualify, never a later drop with the same equipment ID.
		if not record.has("bound"):
			var active:Dictionary=Outpost.data.get("active",{})
			var loadout:Array=active.get("loadout",[])
			for index in loadout.size():
				if str(loadout[index])==str(item.id) and not str(active.get("id","")).is_empty() and str(item.uid)==str(active.id)+":"+str(index+1):item.bound=true
	item["_base_cost"] = int(record.get("base",item.get("cost",0)))
	if int(record.get("sale_value",-1)) >= 0: item["sale_value"] = int(record.sale_value)
	return item

static func reserve_limit(id: String) -> int:
	return 999 if id.begins_with("glow_mushroom_") else 2147483647

static func material_icon(id: String) -> String:
	if MaterialWorkshopCatalog.BOSS_MATERIALS.has(id):return MaterialWorkshopCatalog.icon(str(MaterialWorkshopCatalog.BOSS_MATERIALS[id].icon))
	var revised="res://assets/next_revision/materials/"+id+".png"
	if ResourceLoader.exists(revised):return revised
	var own="res://assets/camp_inventory/"+id+".tres"
	if ResourceLoader.exists(own):return own
	var icons = {"forest_sample":"07_Plants_Nature/0055_herb.png", "wetland_sample":"04_Gems_Jewelry/0030_square_gem_topaz.png", "ruin_sample":"04_Gems_Jewelry/0032_crystal_cluster_aquamarine.png", "deep_evidence":"06_Materials/0053_coal.png", "echo_evidence":"08_Magic/0061_spellbook_arcane.png", "star_dust":"12_Status_UI/0090_star.png", "memory_gift":"07_Plants_Nature/0054_tulip_red.png"}
	var path = "res://assets/icons/"+str(icons.get(id,"12_Status_UI/0090_star.png"))
	if ResourceLoader.exists(path): return path
	return "res://assets/round5/items/crystal_pendant.png"
