class_name ArtEditCanvas
extends Control
signal edited
signal control_selected(index:int)
var document:Dictionary={}
var buffer:=AlphaEditBuffer.new()
var selected:=-1
var selected_control:=-1
var mode:=0
var brush:=12.0
var restore:=false
var solo:=false
var zoom:=1.0
var origin:=Vector2.ZERO
var overrides:Dictionary={}
var _textures:Dictionary={}
var _stroke:=false
var _panning:=false
var _drag:=false
var _mouse:=Vector2.ZERO
var _drag_start:=Vector2.ZERO
var _control_start:=Vector2.ZERO
func _ready()->void:
	clip_contents=true;mouse_filter=Control.MOUSE_FILTER_STOP;custom_minimum_size=Vector2(400,400)
func set_document(value:Dictionary)->void:
	document=value;selected=-1;selected_control=-1;_textures.clear();fit();queue_redraw()
func fit()->void:
	var extent:Vector2=Vector2(document.get("canvas",[1536,1024])[0],document.get("canvas",[1536,1024])[1])
	zoom=minf(maxf(1,size.x-40)/extent.x,maxf(1,size.y-40)/extent.y);origin=(size-extent*zoom)*.5;queue_redraw()
func select_layer(index:int)->Error:
	selected=index;var layer:Dictionary=document.layers[index];var error:=buffer.open(layer.path,bool(layer.locked))
	if error==OK:_textures[layer.path]=ImageTexture.create_from_image(buffer.image)
	queue_redraw();return error
func _texture(path:String)->Texture2D:
	if not _textures.has(path):
		var image:=Image.load_from_file(ProjectSettings.globalize_path(path));_textures[path]=ImageTexture.create_from_image(image) if image!=null and not image.is_empty() else null
	return _textures[path]
func _rect(values:Array)->Rect2:return Rect2(values[0],values[1],values[2],values[3])
func control_rect(index:int)->Rect2:
	var entry:Dictionary=document.controls[index];var result:=_rect(entry.preview_rect);var current:=entry;var seen:Dictionary={}
	for step in 10:
		if seen.has(current.id):break
		seen[current.id]=true;var changed:Dictionary=overrides.get(current.id,{})
		if changed.has("position"):result.position+=Vector2(changed.position[0],changed.position[1])-Vector2(current.rect[0],current.rect[1])
		var parent:=str(current.get("parent",""));var matches:Array=document.controls.filter(func(c:Dictionary)->bool:return c.id==parent)
		if matches.is_empty():break
		current=matches[0]
	return result
func _screen(rect:Rect2)->Rect2:return Rect2(origin+rect.position*zoom,rect.size*zoom)
func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("222831"))
	for y in range(0,int(size.y),24):
		for x in range(0,int(size.x),24):
			if (int(x/24)+int(y/24))%2==0:draw_rect(Rect2(x,y,24,24),Color("2c343e"))
	if document.is_empty():return
	for i in document.layers.size():
		var layer:Dictionary=document.layers[i]
		if solo and i!=selected or not solo and not bool(layer.visible) and i!=selected:continue
		var texture:=_texture(layer.path)
		if texture!=null:draw_texture_rect(texture,_screen(_rect(layer.rect)),false)
	if mode==1:
		for i in document.controls.size():
			var entry:Dictionary=document.controls[i];var rect:=_screen(control_rect(i))
			if entry.type=="glass":draw_style_box(InteractionSkin.style("preview"),rect)
			if entry.type in ["button","text"]:
				if entry.type=="button":draw_style_box(InteractionSkin.style("preview"),rect)
				var font:=GameFonts.get_font();var point_size:=clampi(int(overrides.get(entry.id,{}).get("font_size",entry.font_size)*zoom),10,40);draw_string(font,rect.position+Vector2(0,rect.size.y*.65),entry.caption,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,point_size,Color("edf4fa"))
			draw_rect(rect,Color("ffe692") if i==selected_control else Color(1,1,1,.2),false,2)
	elif selected>=0:
		draw_rect(_screen(_rect(document.layers[selected].rect)),Color("ffe692"),false,1)
		if not buffer.locked:draw_arc(_mouse,brush*zoom,0,TAU,32,Color("8cecc7") if restore else Color("ff9989"),1.5)
func _paint(at:Vector2)->void:
	if selected<0 or buffer.locked:return
	var rect:=_rect(document.layers[selected].rect);var point:Vector2=(at-origin)/zoom-rect.position
	point*=Vector2(buffer.image.get_width(),buffer.image.get_height())/rect.size
	buffer.paint(point,brush,restore);(_textures[buffer.path] as ImageTexture).update(buffer.image);queue_redraw()
func _gui_input(event:InputEvent)->void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var point:Vector2=(event.position-origin)/zoom;zoom=clampf(zoom*(1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.2),.05,12);origin=event.position-point*zoom;queue_redraw();accept_event();return
		if event.button_index==MOUSE_BUTTON_MIDDLE:_panning=event.pressed;accept_event();return
		if event.button_index!=MOUSE_BUTTON_LEFT:return
		if mode==1:
			if event.pressed:
				for i in range(document.controls.size()-1,-1,-1):
					if _screen(control_rect(i)).has_point(event.position):selected_control=i;control_selected.emit(i);_drag=true;_drag_start=event.position;_control_start=control_rect(i).position;break
			else:_drag=false;edited.emit()
		elif selected>=0 and not buffer.locked:
			if event.pressed:_stroke=true;buffer.begin_stroke();_paint(event.position)
			else:_stroke=false;buffer.end_stroke();edited.emit()
		queue_redraw();accept_event()
	elif event is InputEventMouseMotion:
		_mouse=event.position
		if _panning:origin+=event.relative
		elif _drag and selected_control>=0:
			var entry:Dictionary=document.controls[selected_control];var prior:=control_rect(selected_control).position;var target:Vector2=_control_start+(event.position-_drag_start)/zoom;var data:Dictionary=overrides.get(entry.id,{}).duplicate(true);var local:Vector2=Vector2(data.get("position",[entry.rect[0],entry.rect[1]])[0],data.get("position",[entry.rect[0],entry.rect[1]])[1]);local+=target-prior;data.position=[snappedf(local.x,.1),snappedf(local.y,.1)];overrides[entry.id]=data
		elif _stroke:_paint(event.position)
		queue_redraw();accept_event()
func refresh_image()->void:
	if selected>=0 and buffer.image!=null:(_textures[buffer.path] as ImageTexture).update(buffer.image)
	queue_redraw()
