class_name RoomSlideOverlay
extends CanvasLayer
## Two temporary in-memory world frames; HUD remains stationary above layer 8.
const DURATION := .32
var old_view: TextureRect
var new_view: TextureRect
var direction := Vector2.RIGHT
var progress := 0.0:
	set(value):
		progress=clampf(value,0,1)
		_layout()
var _root: Control
var _huds: Array[Dictionary]=[]
var _reduced := false
var capture_usec := 0

func _ready()->void:
	layer=8;process_mode=Node.PROCESS_MODE_ALWAYS
	_root=Control.new();_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;_root.clip_contents=true
	add_child(_root);_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for outgoing in [true,false]:
		var rect:=TextureRect.new();rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
		rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;rect.stretch_mode=TextureRect.STRETCH_SCALE
		rect.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		_root.add_child(rect)
		if outgoing:old_view=rect
		else:new_view=rect;new_view.hide()
	_root.resized.connect(_layout)
	_reduced=ComicMotion.reduced();_layout()

func _hide_huds()->void:
	_huds.clear()
	for reference in UIFlow._huds:
		var node:Variant=reference.get_ref()
		if is_instance_valid(node):_huds.append({"node":node,"visible":node.visible});node.hide()
	if is_instance_valid(MobileControls):
		_huds.append({"node":MobileControls,"visible":MobileControls.visible});MobileControls.hide()
func _restore_huds()->void:
	for item in _huds:
		if is_instance_valid(item.node):item.node.visible=item.visible
	_huds.clear()
func _capture()->Texture2D:
	# No files or screenshots are produced. Read the current rendered world once.
	if DisplayServer.get_name()=="headless":
		var fallback:=Image.create(2,2,false,Image.FORMAT_RGBA8);fallback.fill(Color("0b141b"))
		return ImageTexture.create_from_image(fallback)
	var start:=Time.get_ticks_usec()
	RenderingServer.force_draw(false)
	var image:=get_viewport().get_texture().get_image()
	capture_usec+=Time.get_ticks_usec()-start
	return ImageTexture.create_from_image(image) if image!=null and not image.is_empty() else null
func capture_old(step:Vector2i)->void:
	direction=Vector2(step);_hide_huds();hide()
	old_view.texture=_capture()
	show();_restore_huds();_layout()
func capture_new()->void:
	_hide_huds();hide();new_view.texture=_capture();show();_restore_huds()
	new_view.show();_layout()
func _layout()->void:
	if not is_instance_valid(old_view):return
	var extent:=get_viewport().get_visible_rect().size
	old_view.size=extent;new_view.size=extent
	if _reduced:
		old_view.position=Vector2.ZERO;new_view.position=Vector2.ZERO
		new_view.modulate.a=progress
	else:
		old_view.position=-direction*extent*progress
		new_view.position=direction*extent*(1-progress)
func release()->void:
	_restore_huds()
	if is_instance_valid(old_view):old_view.texture=null
	if is_instance_valid(new_view):new_view.texture=null
	hide()
