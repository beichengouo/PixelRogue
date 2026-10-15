class_name GlassUIScope
extends Node
## Only mounted player screens are watched; no SceneTree-wide node listener.
var root:Control
var kind:="dialog"
var _pending:Array[Node]=[]
var _queued:=false
var _watched:Array[WeakRef]=[]
func _ready()->void:refresh()
func refresh()->void:
	if not is_instance_valid(root):return
	_watched=_watched.filter(func(reference:WeakRef)->bool:return is_instance_valid(reference.get_ref()))
	InteractionSkin.apply_tree(root,kind);_watch(root)
func _watch(node:Node)->void:
	if node.name in ["GlassUIScope","GlassEdgeGlow","FrostedSurface"] or bool(node.get_meta("glass_exempt",false)):return
	if not node.child_entered_tree.is_connected(_added):node.child_entered_tree.connect(_added);_watched.append(weakref(node))
	for child in node.get_children():_watch(child)
func _added(node:Node)->void:
	if node.name in ["GlassUIScope","GlassEdgeGlow","FrostedSurface"]:return
	_pending.append(node)
	if not _queued:_queued=true;_flush.call_deferred()
func _flush()->void:
	_queued=false
	if not is_inside_tree() or not is_instance_valid(root):return
	_watched=_watched.filter(func(reference:WeakRef)->bool:return is_instance_valid(reference.get_ref()))
	var candidates:=_pending.duplicate();_pending.clear()
	for node:Node in candidates:
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not root.is_ancestor_of(node):continue
		var ancestor:Node=node.get_parent();var covered:=false
		while ancestor!=null and ancestor!=root:
			if candidates.has(ancestor):covered=true;break
			ancestor=ancestor.get_parent()
		if not covered:InteractionSkin.apply_tree(node,kind);_watch(node)
func _exit_tree()->void:
	for reference in _watched:
		var node:Node=reference.get_ref()
		if is_instance_valid(node) and node.child_entered_tree.is_connected(_added):node.child_entered_tree.disconnect(_added)
