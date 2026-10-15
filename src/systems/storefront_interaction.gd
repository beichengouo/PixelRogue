class_name StorefrontInteraction
extends RefCounted
static var _caption := ""
static var _epoch := -1

static func closest(tree: SceneTree, player: Node2D) -> Node2D:
	if not is_instance_valid(player): return null
	var best: Node2D
	var distance := INF
	for node in tree.get_nodes_in_group("storefronts"):
		if not node.in_range: continue
		var d := player.global_position.distance_squared_to(node.global_position)
		if d < distance:
			distance = d
			best = node
	return best

static func refresh(source: Node) -> void:
	if _epoch != GameState.run_epoch:
		_epoch = GameState.run_epoch
		_caption = ""
	var selected := closest(source.get_tree(), GameState.player)
	var caption := ""
	if selected != null:
		var shop := selected is ShopNPC
		caption = ("按 [%s] 进入%s"%[UIFlow.hint(&"interact"),"商店" if shop else "酒馆"]) if selected.is_open else ("商店 · 休整时营业" if shop else "酒馆 · 休整时营业")
	if caption == _caption: return
	_caption = caption
	if caption == "": EventBus.interact_prompt_hide.emit()
	else: EventBus.interact_prompt_show.emit(caption)
