class_name InteractionSkin
extends RefCounted
# Live controls use procedural glass; retired art plates are archived outside the project.
const ROOT:="res://assets/ui_interaction_v02/"
static var _textures:Dictionary={}
static var _theme:Theme
static func theme()->Theme:
	if _theme!=null:return _theme
	_theme=PixelUi.theme().duplicate()
	for type in ["LineEdit","TextEdit","SpinBox"]:
		for state in ["normal","read_only","focus"]:
			var box:=style("input");box.bg_color=Color(.06,.11,.16,.45);box.border_color=Color(.78,.88,.95,.65 if state=="focus" else .25)
			_theme.set_stylebox(state,type,box)
		_theme.set_color("font_color",type,Color("edf4fa"));_theme.set_color("caret_color",type,PixelUi.GOLD)
	_theme.set_stylebox("panel","PopupMenu",style("popup"))
	_theme.set_stylebox("panel","TooltipPanel",style("tooltip"))
	_theme.set_color("font_color","TooltipLabel",Color("edf4fa"))
	return _theme
static func mount(root:Control,kind:String,frame:Control=null)->void:
	root.theme=theme()
	if frame!=null:
		if frame is Panel or frame is PanelContainer:surface(frame,kind)
		else:
			for child in frame.get_children():
				if child is Control and child.name!="GlassFrame" and child.anchor_right==1 and child.anchor_bottom==1 and child.offset_left==0 and child.offset_top==0 and child.offset_right==0 and child.offset_bottom==0:
					child.offset_left=24;child.offset_top=24;child.offset_right=-24;child.offset_bottom=-24
			var plate:=frame.get_node_or_null("GlassFrame") as Panel
			if plate==null:
				plate=Panel.new();plate.name="GlassFrame";plate.mouse_filter=Control.MOUSE_FILTER_IGNORE;plate.show_behind_parent=true;frame.add_child(plate);frame.move_child(plate,0);plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			surface(plate,kind)
	var scope:=root.get_node_or_null("GlassUIScope")
	if scope==null:
		scope=load("res://src/ui/glass_ui_scope.gd").new();scope.name="GlassUIScope";scope.set("root",root);scope.set("kind",kind);root.add_child(scope)
	else:scope.call("refresh")
static func unmount(root:Control)->void:
	var scope:=root.get_node_or_null("GlassUIScope")
	if scope!=null:root.remove_child(scope);scope.queue_free()
	root.theme=null
static func surface(panel:Control,kind:String,flow:=true)->void:
	panel.set_meta("glass_surface",true);panel.add_theme_stylebox_override("panel",style(kind,"frame",panel.get_theme_stylebox("panel")));attach_glass(panel)
	if flow and panel.get_node_or_null("GlassEdgeGlow")==null:
		var glow:Node2D=load("res://src/ui/glass_border_fx.gd").new();glow.name="GlassEdgeGlow";panel.add_child(glow)
static func clear_surface(panel:Control)->void:
	for name in ["FrostedSurface","GlassEdgeGlow"]:
		var child:=panel.get_node_or_null(name)
		if child!=null:panel.remove_child(child);child.queue_free()
	panel.remove_meta("glass_surface")
static func texture(kind:String,name:String)->Texture2D:
	var path:=ROOT+kind+"/"+name+".png"
	if not _textures.has(path):_textures[path]=load(path) if ResourceLoader.exists(path) else null
	return _textures[path]
static func style(_kind:String,_name:String="frame",old:StyleBox=null,_tint:=Color.WHITE)->StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=Color(0.06,0.11,0.16,0.28);box.border_color=Color(0.78,0.88,0.95,0.22);box.set_border_width_all(1);box.set_corner_radius_all(12)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:box.set_content_margin(side,old.get_content_margin(side) if old!=null else 16)
	return box
static func attach_glass(panel:Control)->void:
	if panel.get_node_or_null("FrostedSurface")!=null:return
	var glass:=FrostedGlass.new();glass.name="FrostedSurface";panel.add_child(glass);glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
static func apply_button(button:Button,_kind:String,_allow_option:=false)->void:
	if bool(button.get_meta("glass_skip_style",false)):return
	for state in ["normal","hover","pressed","disabled","focus"]:
		var box:=StyleBoxFlat.new();box.set_corner_radius_all(8);box.set_border_width_all(1)
		var selected:=bool(button.get_meta("interaction_selected",false))
		box.bg_color=Color(.74,.86,.96,.08 if state=="disabled" else (.20 if state=="hover" else (.25 if state=="pressed" or selected else .10)))
		box.border_color=Color(.75,.88,.98,.12 if state=="disabled" else (.80 if state=="focus" else (.58 if selected or state=="hover" else .26)))
		if state=="focus":box.bg_color=Color.TRANSPARENT;box.set_border_width_all(2)
		if button.has_meta("quality_slot"):
			box.border_color=button.get_meta("quality_slot");box.set_border_width_all(4 if selected or state=="focus" else 3);box.bg_color=Color(.12,.20,.28,.64) if selected or state=="hover" else Color(.04,.08,.12,.48)
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:box.set_content_margin(side,10 if side in [SIDE_LEFT,SIDE_RIGHT] else 6)
		button.add_theme_stylebox_override(state,box)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,Color("edf4fa"))
	button.add_theme_color_override("font_disabled_color",Color(.68,.74,.80,.68));button.add_theme_constant_override("outline_size",0)
	button.add_theme_font_size_override("font_size",int(button.get_meta("art_layout_font_size",clampi(button.get_theme_font_size("font_size"),14,24))))
	# Intrinsic-width tabs must measure their caption. Clipping a zero-width
	# compact button reduces its minimum width to the style margins alone.
	button.clip_text=button.custom_minimum_size.x>0 or bool(button.size_flags_horizontal & Control.SIZE_EXPAND)
	button.alignment=HORIZONTAL_ALIGNMENT_CENTER
	if bool(button.get_meta("glass_danger",false)):
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,Color("ffb8b5"))
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	if button is OptionButton:
		var popup:PopupMenu=button.get_popup();popup.add_theme_stylebox_override("panel",style("popup"));popup.add_theme_color_override("font_color",Color("edf4fa"))
static func apply_tree(node:Node,kind:String,_paper:=false)->void:
	if node.name in ["GlassUIScope","GlassEdgeGlow","FrostedSurface"] or bool(node.get_meta("glass_exempt",false)):return
	if node is PanelContainer or node is Panel:
		var panel_style:=style(kind,"frame",node.get_theme_stylebox("panel"))
		if not bool(node.get_meta("glass_surface",false)):panel_style.bg_color.a=.10;panel_style.border_color.a=.16
		node.add_theme_stylebox_override("panel",panel_style)
		if node is UiOrnate:node.show_corners=false;node.show_bands=false;node.show_inner=false;node.queue_redraw()
		if node.has_meta("ui_layout_canvas") or node.get_parent() is Control and node.get_parent().has_meta("ui_layout_canvas") or node.has_meta("interaction_paper"):attach_glass(node)
	if node is Label:
		var color:Color=node.get_theme_color("font_color")
		if maxf(color.r,maxf(color.g,color.b))<.65:node.add_theme_color_override("font_color",Color("dce9f3"))
		node.add_theme_constant_override("outline_size",0)
	if node is Button:apply_button(node,kind)
	if node is LineEdit or node is TextEdit:node.theme=theme()
	for child in node.get_children():
		if not child is FrostedGlass:apply_tree(child,kind)
