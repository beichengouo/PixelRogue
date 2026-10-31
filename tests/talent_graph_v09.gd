extends Node
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+label)
func _ready()->void:process_mode=Node.PROCESS_MODE_ALWAYS;call_deferred("run")
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	for hero:StringName in [&"sylphiette",&"xixifu",&"ilyua"]:
		Characters.set_current(hero);CampSession.active=true;GameState.talents.clear();GameState.talent_points=0
		var graph:=TalentGraph.nodes(hero)
		check(graph.size()==80,"eight ten-node skill trees "+str(hero))
		var roots:=0;var terminals:=0
		for id:StringName in graph:
			var info:Dictionary=graph[id]
			check(int(info.max_rank)==1 and not str(info.desc).is_empty(),"single described purchase "+str(id))
			if info.requires_all.is_empty():roots+=1
			for parent:StringName in info.requires_all:
				check(graph.has(parent) and graph[parent].row<int(info.row) and graph[parent].skill==info.skill,"same-skill downward dependency "+str(id))
			if bool(info.terminal):
				terminals+=1;check(info.requires_all.size()==3 and int(info.row)==4,"terminal requires three route ends "+str(id))
			else:check(info.requires_all.size()==(0 if int(info.rank)==1 else 1),"route rank dependency "+str(id))
		check(roots==24 and terminals==8,"24 routes and eight terminals "+str(hero))
		var tree:=TalentTreeView.new();add_child(tree);tree.build()
		check(tree._centers.size()==80,"camp tree renders all 80 nodes "+str(hero))
		var focus_ok:=true
		for id:StringName in graph:
			var button:=tree.get_node_or_null(NodePath(str(id))) as Button
			if button==null or button.focus_neighbor_bottom.is_empty():focus_ok=false;break
		check(focus_ok,"directional focus for all nodes "+str(hero))
		tree.queue_free();await get_tree().process_frame
		for skill_id:StringName in Skills.order_for(hero):
			var terminal:=TalentGraph.id_for(PermanentTalents.terminal_id(skill_id),1)
			check(not TalentGraph.unlocked(terminal,GameState.talents),"terminal locked before ranks "+str(skill_id))
			for route:StringName in SkillTalentCatalog.ROUTES:GameState.talents[SkillTalentCatalog.route_id(skill_id,route)]=3
			check(TalentGraph.requirement_text(terminal,GameState.talents).contains("击杀"),"terminal states unlock requirements "+str(skill_id))
		CampSession.active=false
	AudioManager.shutdown();await get_tree().process_frame
	print("TALENT_GRAPH_V38 checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
