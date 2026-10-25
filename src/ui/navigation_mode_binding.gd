class_name NavigationModeBinding
extends Node
## A live control owns the global subscription. Never leave captured UI objects
## in a callable owned by the UIFlow autoload (including never-mounted controls).
var _owner_ref:WeakRef
var _watched:Array[WeakRef]=[]
var _update:Callable
static func attach(owner:Node,callback:Callable,watched:Array=[])->NavigationModeBinding:
 var binding:=NavigationModeBinding.new();binding.name="NavigationModeBinding"
 binding._owner_ref=weakref(owner);binding._update=callback
 for node:Node in watched:binding._watched.append(weakref(node))
 owner.add_child(binding);return binding
func _enter_tree()->void:
 if is_instance_valid(UIFlow) and not UIFlow.navigation_mode_changed.is_connected(refresh):UIFlow.navigation_mode_changed.connect(refresh)
 refresh.call_deferred()
func _exit_tree()->void:
 if is_instance_valid(UIFlow) and UIFlow.navigation_mode_changed.is_connected(refresh):UIFlow.navigation_mode_changed.disconnect(refresh)
func refresh()->void:
 if not is_inside_tree() or is_queued_for_deletion():return
 var owner:Node=_owner_ref.get_ref() if _owner_ref!=null else null
 if not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree():return
 for reference:WeakRef in _watched:
  var node:Node=reference.get_ref()
  if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree():return
 if _update.is_valid():_update.call()
