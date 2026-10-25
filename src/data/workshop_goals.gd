class_name WorkshopGoals
extends RefCounted
## One goal in the existing workshop record; old plain research IDs remain valid.
static func current()->String:return str(Outpost.data.get("workshop",{}).get("goal",""))
static func entry(key:String)->Dictionary:
	if key.begins_with("craft:"):
		var recipe:=MaterialWorkshopCatalog.recipe(key.trim_prefix("craft:"))
		if recipe.is_empty() or not str(recipe.id).begins_with("craft_"):return {}
		var needs:Dictionary=recipe.variants[0].duplicate(true)
		var research:=MaterialWorkshopCatalog.research(str(recipe.research))
		var locked:=not MaterialWorkshopCatalog.unlocked(str(recipe.research))
		if locked:
			for id in research.get("needs",{}):needs[id]=int(needs.get(id,0))+int(research.needs[id])
		return {"id":key,"kind":"craft","recipe":str(recipe.id),"name":"制作 · "+str(recipe.name),"needs":needs,"product":str(recipe.product),"research":str(recipe.research),"locked":locked}
	var research:=MaterialWorkshopCatalog.research(key)
	if research.is_empty() or MaterialWorkshopCatalog.unlocked(key):return {}
	return {"id":key,"kind":"research","name":"研究 · "+str(research.name),"needs":research.needs.duplicate(true),"research":key,"locked":true}
static func requirements(exclude:="")->Dictionary:
	var selected:=entry(current())
	if selected.is_empty() or current()==exclude:return {}
	var needs:Dictionary=selected.needs.duplicate(true)
	# Researching the prerequisite consumes only its own share, preserving the
	# rest for the tracked product and every separately accepted commission.
	if selected.kind=="craft" and selected.locked and str(selected.research)==exclude:
		for id in MaterialWorkshopCatalog.research(exclude).needs:needs[id]=maxi(0,int(needs[id])-int(MaterialWorkshopCatalog.research(exclude).needs[id]))
	return needs
static func snapshot()->Dictionary:
	var selected:=entry(current())
	if selected.is_empty():return {}
	var stock:Dictionary=Outpost.data.get("inventory",{})
	var owned:Dictionary={}
	for id in selected.needs:owned[id]=maxi(0,int(stock.get(id,0)))
	return {"id":current(),"name":str(selected.name),"needs":selected.needs.duplicate(true),"owned":owned}
static func material_source(id:String)->String:
	if MaterialWorkshopCatalog.BOSS_MATERIALS.has(id):
		var boss_id:=str(MaterialWorkshopCatalog.BOSS_MATERIALS[id].boss)
		for chapter in ChapterCatalog.CHAPTERS:
			if ChapterCatalog.bosses(chapter).has(boss_id):return ChapterCatalog.title(chapter)+" · "+str(BossRoster.DATA.get(boss_id,{}).get("title",boss_id))+"；拾取后成功撤离带回"
	if id in ["forest_sample","forest_resin","moss_cloth"]:return "森林生态战斗房；成功撤离带回"
	if id in ["wetland_sample","river_pearl"]:return "湿地生态战斗房；成功撤离带回"
	if id in ["ruin_sample","ruin_ore"]:return "遗迹生态战斗房；成功撤离带回"
	if id=="storm_crystal":return "第10场起的战斗掉落；成功撤离带回"
	if id=="ancient_seal":return "第20场起的战斗掉落，成功撤离带回"
	if id=="star_dust":return "两章探索与战斗材料掉落，成功撤离带回"
	if id=="starbound_sigil":return "完成极限阶段后成功撤离的专属战利品"
	return "探索掉落与现有委托、兑换；具体可用来源以各交互页为准"
static func describe(key:String="")->String:
	var selected:=entry(current() if key.is_empty() else key)
	if selected.is_empty():return "尚未追踪目标；可在制作与研究中选择一项研究或装备制作。"
	var lines:PackedStringArray=["当前目标 · "+str(selected.name)]
	if selected.kind=="craft":lines.append("先完成「%s」研究，再制作绑定装备。"%str(MaterialWorkshopCatalog.research(str(selected.research)).name) if selected.locked else "配方已解锁；材料齐备后可制作一件绑定装备。")
	var stock:Dictionary=Outpost.data.get("inventory",{});var ready:=true
	for id in selected.needs:
		var count:=maxi(0,int(stock.get(id,0)));var need:=int(selected.needs[id]);ready=ready and count>=need
		lines.append("%s %d／%d%s"%[str(ExpeditionData.resolve(str(id)).get("name",id)),count,need," · 还缺%d；%s"%[need-count,material_source(str(id))] if count<need else " · 已备齐"])
	if ready:lines.append("目标总用量已齐；执行前仍会核对委托保留、职业与仓库空间。")
	return "\n".join(lines)
static func result(before:Dictionary,success:bool)->Dictionary:
	if before.is_empty():return {}
	var rows:Array=[];var stock:Dictionary=Outpost.data.get("inventory",{})
	for id in before.get("needs",{}):
		var owned:=maxi(0,int(before.get("owned",{}).get(id,0)));var after:=maxi(0,int(stock.get(id,0)))
		rows.append({"id":str(id),"before":owned,"after":after,"need":int(before.needs[id]),"gain":maxi(0,mini(after,int(before.needs[id]))-mini(owned,int(before.needs[id])))})
	return {"id":str(before.id),"name":str(before.name),"rows":rows,"success":success}
static func result_text(report:Dictionary)->String:
	if report.is_empty():return ""
	var lines:PackedStringArray=["出发目标 · "+str(report.name)]
	for row in report.get("rows",[]):lines.append("%s：%d → %d／%d%s"%[str(ExpeditionData.resolve(str(row.id)).get("name",row.id)),int(row.before),int(row.after),int(row.need)," · 推进%d份"%int(row.gain) if int(row.gain)>0 else ""])
	if not bool(report.get("success",false)):lines.append("本局未带回材料；不会将途中拾取计为永久进度。历史仓库保持结算后的真实数量。")
	return "\n".join(lines)
