class_name CampMapUI
extends CanvasLayer
var world:CampWorld
var _root:Control
var _map:MapCanvas
var _tick:=0.0
class MapCanvas extends Control:
	var world:CampWorld
	func point(value:Vector2,bounds:Rect2,area:Rect2)->Vector2:
		return area.position+(value-bounds.position)*area.size/bounds.size
	func building_sprites()->Array[Sprite2D]:
		var result:Array[Sprite2D]=[]
		for root in [world.level.decor_root,world.level.props_root]:
			_collect_sprites(root,result)
		result.sort_custom(func(a:Sprite2D,b:Sprite2D)->bool:
			if a.z_index!=b.z_index:return a.z_index<b.z_index
			return a.get_parent().global_position.y<b.get_parent().global_position.y)
		return result
	func _collect_sprites(node:Node,result:Array[Sprite2D])->void:
		if not is_instance_valid(node):return
		if node is Sprite2D and node.texture!=null and node.is_visible_in_tree():result.append(node)
		for child in node.get_children():_collect_sprites(child,result)
	func _paint_sprite(sprite:Sprite2D,map_transform:Transform2D)->void:
		var rect:=sprite.get_rect()
		var source:=sprite.region_rect if sprite.region_enabled else Rect2(Vector2(sprite.frame_coords)*sprite.texture.get_size()/Vector2(sprite.hframes,sprite.vframes),sprite.texture.get_size()/Vector2(sprite.hframes,sprite.vframes))
		if sprite.flip_h:rect.position.x+=rect.size.x;rect.size.x=-rect.size.x
		if sprite.flip_v:rect.position.y+=rect.size.y;rect.size.y=-rect.size.y
		draw_set_transform_matrix(map_transform*world.level.global_transform.affine_inverse()*sprite.global_transform)
		# Map buildings remain readable while their world sprites fade for actors.
		draw_texture_rect_region(sprite.texture,rect,source,Color.WHITE)
	func _draw()->void:
		if not is_instance_valid(world) or world.level.illustration==null:return
		var illustration:RoomSceneArtwork=world.level.illustration
		var bounds:=illustration.frame_rect()
		var factor:=minf((size.x-36)/bounds.size.x,(size.y-36)/bounds.size.y)
		var area:=Rect2((size-bounds.size*factor)*.5,bounds.size*factor)
		var map_transform:=Transform2D(Vector2(factor,0),Vector2(0,factor),area.position-bounds.position*factor)
		var planes:Array[Sprite2D]=[]
		_collect_sprites(illustration,planes)
		for sprite in planes:
			if sprite.modulate.a>0:_paint_sprite(sprite,map_transform)
		for sprite in building_sprites():_paint_sprite(sprite,map_transform)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		for role in world.facilities:
			var at:=point(world.facility_guide_center(role),bounds,area)
			var name:=str(world.FACILITY_NAMES[role])+str({"shop":" · 姜糖","relations":" · 温阮","iris":" · 伊莉丝"}.get(role,""))
			_marker(at,name,Color("f2d28b"))
		for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var at:=point(world.level.door_point(direction,0),bounds,area)
			_marker(at,str({Vector2i.UP:"北门",Vector2i.RIGHT:"东门",Vector2i.DOWN:"南门",Vector2i.LEFT:"西门"}[direction])+(" · 已开启" if world.level.doors_open else " · 未开启"),Color("9fe6c4") if world.level.doors_open else Color("b0bcc7"))
		if is_instance_valid(world.residents_root):
			for npc in world.residents_root.get_children():
				var at:=point(world.level.to_local(npc.global_position),bounds,area)
				_marker(at,str(CampResidents.DATA.get(npc.resident_id,{}).get("name",npc.resident_id)),Color("9fe6c4"))
		if is_instance_valid(world.dummy):_marker(point(world.dummy.position,bounds,area),"训练稻草人",Color("e9ba81"))
		if is_instance_valid(world.player):_marker(point(world.player.position,bounds,area),"你 · "+Characters.current_name(),Color("98d9ff"),7)
	func _marker(at:Vector2,text:String,color:Color,radius:=4.0)->void:
		draw_circle(at,radius+2,Color("13232c"));draw_circle(at,radius,color)
		var font:=GameFonts.get_font("body");var label_size:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,16)
		var origin:=Vector2(clampf(at.x+10,4,maxf(4,size.x-label_size.x-4)),clampf(at.y+5,18,size.y-6))
		draw_string_outline(font,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,4,Color("14212a"));draw_string(font,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)
func _ready()->void:
	layer=34;process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true)
	_root=UiFactory.full_rect();add_child(_root);_root.add_child(UiFactory.dim_layer(.42))
	var frame:=StarUi.frame(_root,Vector2(1140,700));var panel:=PixelUi.inset_panel(20);frame.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var body:=UiFactory.vbox(12);panel.add_child(body)
	var row:=UiFactory.hbox(16);body.add_child(row)
	var heading:=PixelUi.title("星辉回廊 · 营地地图",28);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(heading)
	var close_button:=PixelUi.compact_button("关闭 [%s]"%KeyBindings.label("room_map"),18);row.add_child(close_button);close_button.pressed.connect(close)
	_map=MapCanvas.new();_map.world=world;_map.custom_minimum_size.y=450;_map.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(_map)
	body.add_child(PixelUi.label("蓝色 · 自己    金色 · 设施    绿色 · 营地旅人",16,PixelUi.MUTED))
	InteractionSkin.mount(_root,"camp_map",panel);_root.hide();visible=false
func open()->void:
	if not UIFlow.can_open(self):return
	visible=true;_root.show();_map.queue_redraw();UIFlow.push_screen(self)
func close()->void:
	_root.hide();visible=false;UIFlow.pop_screen(self)
func _process(dt:float)->void:
	if not _root.visible:return
	_tick+=dt
	if _tick>=.1:_tick=0;_map.queue_redraw()
func _input(event:InputEvent)->void:
	if _root.visible and UIFlow.is_top(self) and not event.is_echo() and (event.is_action_pressed("room_map") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		get_viewport().set_input_as_handled();close()
