class_name FateStory
extends RefCounted
static func scene(character_id:StringName=&"",repeated:=false)->Dictionary:
	var hero:Dictionary=Characters.DATA.get(character_id,Characters.current())
	var response:String={"sylphiette":"我对应女祭司。带着它时，小技能成功释放后会多获得祈光，冷却期间不能反复增加。我会先看清正逆位的代价。","xixifu":"我的牌是魔术师。施放小技能后，现有契约伙伴能短暂加快攻击，不会凭空多出一位伙伴。小扣，这下你也有牌面了。","ilyua":"月亮对应我。标记引爆后能准备一支追猎箭，得在时限内用主普攻打出去。效果和限制我会一起看。"}.get(str(hero.id),"先看清效果与代价，再决定要不要选。")
	var entries:Array=[
		{"who":Story.GODDESS,"text":"星象就是本次出征的祝福，也会显示已经形成的相邻道路。开局可以免费选一种；它不会替你决定路线。","expression":"neutral"},
		{"who":Story.GODDESS,"text":"祭坛清理后，先领取誓约，再进行免费塔罗占卜。每次出征最多三次，牌能带多张，换阶段也保留。每次从三张里选一张，也可以先关闭或明确放弃。","expression":"neutral"},
		{"who":Story.GODDESS,"text":"现在共有十张牌。你在回廊认识的契约者对应愚者，我对应世界，三位伙伴也各有一张所属牌。选择到自己的牌，会额外获得能力共鸣，祭坛也会略多提供它。","expression":"neutral"},
		{"who":str(hero.name),"text":response,"expression":"thoughtful"},
		{"who":Story.GODDESS,"text":"每座祭坛的正位或逆位是固定的，关闭、读档都不会重抽。正位画的是顺利的时刻，逆位画的是逆境；机制各有收益和限制，不是保证谁会成功或失败。确认前请看完整说明。","expression":"neutral"},
		{"who":Story.GODDESS,"text":"这些效果只属于本次出征，不会让死亡遗失的物资自动入库。材料仍要成功撤离才能带回。","expression":"neutral"}]
	if repeated:entries=[entries[1],entries[3],entries[4]]
	return {"narrative_revision":ContractorNarrative.REVISION,"title":"星象与塔罗 · 先看效果再选择","portrait":"","lines":entries,"choices":[],"next":&""}
