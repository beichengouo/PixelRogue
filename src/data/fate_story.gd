class_name FateStory
extends RefCounted
static func scene(character_id:StringName=&"",repeated:=false)->Dictionary:
	var hero:Dictionary=Characters.DATA.get(character_id,Characters.current())
	var response:String={"sylphiette":"那么，圣光照见的也该是道路，而非唯一的答案。我会记住每一种选择的代价。","xixifu":"灯可以陪我们看清黑暗，但不该替伙伴决定去向。正位与逆位，我都会亲自读完。","ilyua":"星辰能告诉我风从哪里来，却不能替种子决定向哪里生长。我会自己选择。"}.get(str(hero.id),"我会自己选择，也承担选择的代价。")
	var lines:Array=[{"who":Story.GODDESS,"text":"星辰不替旅人书写命运。选择一种星象，它会在本次出征中为你守灯，也让你看见已经形成的邻接道路。"},{"who":Story.GODDESS,"text":"在清理后的祭坛领过誓约，还可以免费占卜。每次出征最多三次，持牌数量不设上限。正位稳健，逆位更强，也更苛刻。你可以关闭后再考虑，或明确放弃。"},{"who":str(hero.name),"text":response,"expression":"determined"},{"who":Story.GODDESS,"text":"每座祭坛有固定的正位或逆位，选择后请读完收益与代价，再确认缔结。牌与星象只陪伴这一趟旅途，归来后，我们再看新的天空。"}]
	if repeated:lines=[lines[0],lines[2]]
	return {"title":"星象与命运 · 自择的星路","portrait":Story.P_GODDESS,"lines":lines,"choices":[],"next":&""}
