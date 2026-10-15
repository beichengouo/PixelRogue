@tool
extends ItemList
## Native file drags let Godot own scene placement, selection and undo.
func _get_drag_data(at_position:Vector2) -> Variant:
	var index=get_item_at_position(at_position,true)
	if index<0:return null
	select(index)
	var data:Dictionary=get_item_metadata(index)
	var preview=Label.new()
	preview.text=data.name
	set_drag_preview(preview)
	return {"type":"files","files":PackedStringArray([data.path])}
