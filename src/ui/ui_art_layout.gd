class_name UiArtLayout
extends RefCounted
const PATH:="res://assets/ui_layout_overrides.json"
static var defaults:Dictionary={}
static var _saved:Dictionary={}
static var _signature:=""
static func reload()->void:
	var signature:=FileAccess.get_md5(PATH) if FileAccess.file_exists(PATH) else "missing"
	if signature==_signature:return
	_signature=signature;var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else {}
	_saved=value if value is Dictionary else {}
static func register(kind:String,node:Control,rect:Rect2,id:String="")->void:
	if id.is_empty():id="%s_%d_%d_%d_%d"%[node.get_class(),rect.position.x,rect.position.y,rect.size.x,rect.size.y]
	var key:=kind+":"+id
	node.set_meta("art_layout_key",key);node.set_meta("art_layout_default",rect)
	var caption:=str(node.get("text")) if node is Label or node is Button else id
	if node is ShopArtButton:caption={"purchase":"购买","refresh":"刷新","key":"钥匙","rest":"休憩","close":"关闭"}.get(node.art_key,node.art_key)
	defaults[key]={"id":key,"kind":kind,"caption":caption,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"type":"button" if node is Button else ("text" if node is Label else ("glass" if node is Panel or node is PanelContainer else "region")),"font_size":node.get_theme_font_size("font_size")}
	var origin:=rect.position;var parent:=node.get_parent();var owner:=""
	while parent is Control and not parent.has_meta("ui_layout_canvas"):
		origin+=parent.position
		if owner.is_empty() and parent.has_meta("art_layout_key"):owner=str(parent.get_meta("art_layout_key"))
		parent=parent.get_parent()
	defaults[key].preview_rect=[origin.x,origin.y,rect.size.x,rect.size.y];defaults[key].parent=owner
	apply(node)
static func apply(node:Control)->void:
	if not node.has_meta("art_layout_key"):return
	reload();var key:=str(node.get_meta("art_layout_key"));var entry:Dictionary=_saved.get(key,{})
	var rect:Rect2=node.get_meta("art_layout_default")
	var position:Variant=entry.get("position",[])
	if position is Array and position.size()==2:rect.position=Vector2(float(position[0]),float(position[1]))
	node.position=rect.position;node.size=rect.size
	if entry.has("font_size") and (node is Label or node is Button):
		node.set_meta("art_layout_font_size",clampi(int(entry.font_size),10,48));node.add_theme_font_size_override("font_size",clampi(int(entry.font_size),10,48))
	elif node.has_meta("art_layout_font_size"):node.remove_meta("art_layout_font_size")
static func refresh(root:Node)->void:
	if root is Control:apply(root)
	for child in root.get_children():refresh(child)
static func save(entries:Dictionary)->Error:
	var temporary:=PATH+".writing"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(entries,"\t"));file.flush()
	var result:=file.get_error();file.close()
	if result!=OK:return result
	result=DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(PATH))
	if result!=OK:return result
	_signature="";reload();return OK
static func snapshot()->Dictionary:
	reload();return _saved.duplicate(true)
