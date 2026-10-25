class_name MonsterCodex
extends RefCounted
static var _icons:Dictionary={}
const HABITS := {
	"goblin_scout":"哥布林斥候持短刀近身刺击，抬手蓄势后才造成伤害，不会靠贴身接触持续扣血。离开正面短距离扇区即可躲开。",
	"goblin_spearman":"哥布林投矛手从第三场起出没于林地和湿地边缘，保持距离、抬臂投出一根直线飞矛。飞矛不追踪，利用横移与地形躲避。",
	"goblin_mage":"哥布林法师从第六场起出现，蓄势0.65秒后沿预告方向发射一枚魔法弹。它会寻找通畅射线，不召唤额外怪物。",
	"glimmer_spider":"荧纱蛛出没于第八场起的森林。前肢蓄势后近身咬击，伤及生命会暂时封疗；它没有远程攻击，及时拉开便能避开口器。",
	"walker":"苍白骸骨靠近旅人，留意近身挥击。",
	"flyer":"青色幽骨披着残袍悬浮，越过地形并一次释放三枚轻度追踪幽弹袭击。",
	"charger":"赤色兽人举斧锁定方向，再发起冲锋。",
	"caster":"死灵法师保持距离，吟唱后召唤两名骸骨游荡者；技能或击退可打断。",
	"bomber":"烬骨法师尝试远离旅人，在其周围预告三个互不重叠的火焰爆点。",
	"guard":"重装骸骨盾卫具有正面防御，近身威胁更大。",
	"treant":"森林绿兽人守卫缓慢逼近，蓄势后冲刺并近身挥斧。",
	"bog_crab":"泥沼甲蟹栖息于湿地，接近后挥钳近战。",
	"ruin_sentinel":"星冕残卫守护遗迹，以盾抵御正面攻击，再用星盘锤近身反击。",
	"thorn_mantis":"灰棘螳卫出没于第四场起的林地。自带瞬移与死亡爆炸；两柄镰臂连续近身横扫，第二击延迟片刻，留意蓄势后的挥斩。",
	"lantern_toad":"沼灯囊蛙栖息于湿地。保持距离，鼓起发光毒囊，朝目标喷吐三枚扇形毒弹；实际受伤后中毒。",
	"dusk_acolyte":"暮钟侍祭出没于第六场起的遗迹。举灯锁定通畅射线，释放紫红咒弹；实际受伤后短暂虚弱。"
}
const NEW_NAMES := {"goblin_scout":"哥布林斥候","goblin_spearman":"哥布林投矛手","goblin_mage":"哥布林法师","bog_crab":"泥沼甲蟹", "ruin_sentinel":"星冕残卫","thorn_mantis":"灰棘螳卫","lantern_toad":"沼灯囊蛙","dusk_acolyte":"暮钟侍祭"}
static func entries(category := "all")->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for kind in HABITS:
		var enemy:=WaveDirector.create_enemy(StringName(kind))
		var name:String=str(NEW_NAMES.get(kind,enemy.display_name))
		result.append({"id":kind,"name":name,"desc":HABITS[kind],"kind":kind,"type":"ordinary"})
		enemy.free()
	for id in BossRoster.DATA:
		var info:Dictionary=BossRoster.DATA[id]
		result.append({"id":"boss:"+str(id),"name":info.title,"desc":info.subtitle,"kind":id,"type":"boss"})
	for id in EnemyAffixes.POOL+[EnemyAffixes.CRUEL]:
		if id==&"double_jump":continue
		result.append({"id":"affix:"+str(id),"name":"精英 · "+EnemyAffixes.name_of(id),"desc":str(EnemyAffixes.INFO[id].desc),"kind":id,"type":"affix"})
	for index in HireOffers.MERC_NAMES.size():
		result.append({"id":"merc:%d"%index,"name":HireOffers.MERC_NAMES[index],"desc":HireOffers.merc_description(index)+"。可通过酒馆或雇佣契约加入队伍；不携带怪物词条，阵亡后不会复活。","kind":index,"type":"merc"})
	return result if category=="all" else result.filter(func(entry:Dictionary)->bool:
		return entry.type=="affix" if category=="affixes" else entry.type=="merc" if category=="allies" else entry.type in ["ordinary","boss"])
static func icon(entry:Dictionary)->Texture2D:
	if _icons.has(str(entry.id)):return _icons[str(entry.id)]
	var texture:Texture2D
	if entry.type=="boss":
		var source:=PixelBossArt.make_frames(StringName(entry.kind))
		texture=source.get_frame_texture(source.get_animation_names()[0],0)
	elif entry.type=="affix":
		var icon_path:="res://assets/content_v05/affixes/"+str(entry.kind)+".png"
		if ResourceLoader.exists(icon_path):return load(icon_path)
		return load("res://assets/player_status_v01/cruel.png") if entry.kind==EnemyAffixes.CRUEL and ResourceLoader.exists("res://assets/player_status_v01/cruel.png") else null
	elif entry.type=="merc":
		var source:=PixelHireArt.make_frames(int(entry.kind))
		texture=source.get_frame_texture(&"idle",0)
	elif PixelEnemyArt.supports(StringName(entry.kind)):
		var source:=PixelEnemyArt.make_frames(StringName(entry.kind))
		texture=source.get_frame_texture(&"idle",0)
	if texture==null:return null
	var image:=TexturePixels.image(texture)
	var used:=image.get_used_rect()
	if not used.has_area():return texture
	var crop:=ImageTexture.create_from_image(image.get_region(used))
	_icons[str(entry.id)]=crop
	return crop


