class_name FateForecast
extends RefCounted
static func describe()->String:
	if FateCatalog.star().is_empty():return "出发星象将在第一阶段起始房间以三选一方式确定，仅本次出征有效。"
	var runtime:=GameState.runtime_node as RoomRuntime
	if not is_instance_valid(runtime):return "星象仅在正式出征中观测既有房间。"
	var graph:RoomGraph=runtime.main.graph;var lines:Array[String]=[]
	var bosses:Array=graph.boss_ids();var index:=mini(graph.defeated.size(),bosses.size())
	if graph.staged:
		var name_value:="三首领连战" if graph.stage_index==4 else BossRoster.title_of(StringName(bosses[graph.stage_index-1]))
		lines.append("第%d阶段 · %s\n首领位于本阶段固定终点；沿已开放的道路探索。"%[graph.stage_index,name_value])
	elif index<bosses.size():
		var boss:Dictionary=BossRoster.get_data(StringName(bosses[index]))
		lines.append("下一位章节首领 · %s\n固定在第%d场遭遇；到达节点后的下一次入房必定进入首领房。"%[str(boss.get("title",bosses[index])),int(RoomGraph.BOSS_ENTRY_DEADLINES[index])])
	else:lines.append("本章三位首领均已击败。")
	lines.append("\n邻接部署 · 仅观测已经生成、尚未踏入的普通房与精英房：")
	var count:=0;var here:=RoomGraph.cell(graph.current)
	for direction in RoomGraph.DIRECTIONS:
		var id:=RoomGraph.key(here+direction)
		if not graph.rooms.has(id):continue
		var room:Dictionary=graph.rooms[id]
		if bool(room.get("visited",false)) or not str(room.kind) in ["normal","elite"]:continue
		count+=1
		var side:String={Vector2i.UP:"北",Vector2i.RIGHT:"东",Vector2i.DOWN:"南",Vector2i.LEFT:"西"}[direction]
		lines.append("%s侧 · %s · %s"%[side,RoomGraph.title(str(room.kind)),"部分敌人已在房间中" if str(room.get("encounter_mode","spawned")) in ["resident","mixed"] else "敌人将随战斗陆续出现"])
	if count==0:lines.append("目前没有可观测的既有邻接房间。")
	return "\n".join(lines)
