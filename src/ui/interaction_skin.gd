class_name InteractionSkin
extends RefCounted
# Source layers remain available to the developer's cutout tool, but live controls use no art plates.
const ROOT:="res://assets/ui_interaction_v02/"
static var _textures:Dictionary={}
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
	for state in ["normal","hover","pressed","disabled","focus"]:
		var box:=StyleBoxFlat.new();box.set_corner_radius_all(8);box.set_border_width_all(1)
		var selected:=bool(button.get_meta("interaction_selected",false))
		box.bg_color=Color(.74,.86,.96,.08 if state=="disabled" else (.20 if state=="hover" else (.25 if state=="pressed" or selected else .10)))
		box.border_color=Color(.75,.88,.98,.12 if state=="disabled" else (.80 if state=="focus" else (.48 if selected else .26)))
		if state=="focus":box.bg_color=Color.TRANSPARENT;box.set_border_width_all(2)
		if button.has_meta("quality_slot"):
			box.border_color=button.get_meta("quality_slot");box.set_border_width_all(4 if selected or state=="focus" else 3);box.bg_color=Color(.12,.20,.28,.64) if selected or state=="hover" else Color(.04,.08,.12,.48)
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:box.set_content_margin(side,10 if side in [SIDE_LEFT,SIDE_RIGHT] else 6)
		button.add_theme_stylebox_override(state,box)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,Color("edf4fa"))
	button.add_theme_color_override("font_disabled_color",Color(.68,.74,.80,.68));button.add_theme_constant_override("outline_size",0)
	button.add_theme_font_size_override("font_size",int(button.get_meta("art_layout_font_size",clampi(button.get_theme_font_size("font_size"),14,22))));button.clip_text=true;button.alignment=HORIZONTAL_ALIGNMENT_CENTER
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	if button is OptionButton:
		var popup:PopupMenu=button.get_popup();popup.add_theme_stylebox_override("panel",style("popup"));popup.add_theme_color_override("font_color",Color("edf4fa"))
static func apply_tree(node:Node,kind:String,_paper:=false)->void:
	if node is PanelContainer or node is Panel:
		node.add_theme_stylebox_override("panel",style(kind,"frame",node.get_theme_stylebox("panel")))
		if node.has_meta("ui_layout_canvas") or node.get_parent() is Control and node.get_parent().has_meta("ui_layout_canvas") or node.has_meta("interaction_paper"):attach_glass(node)
	if node is Label:
		var color:Color=node.get_theme_color("font_color")
		if maxf(color.r,maxf(color.g,color.b))<.65:node.add_theme_color_override("font_color",Color("dce9f3"))
		node.add_theme_constant_override("outline_size",0)
	if node is Button:apply_button(node,kind)
	for child in node.get_children():
		if not child is FrostedGlass:apply_tree(child,kind)
