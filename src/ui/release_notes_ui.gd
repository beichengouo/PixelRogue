class_name ReleaseNotesUI
extends CanvasLayer
signal closed
var _root:Control
var _canvas:Control
var _panel:PanelContainer
var _glow:ReleaseNotesGlow
var _body:VBoxContainer
var _scroll:ScrollContainer
var _heading:Label
var _selector:OptionButton
var _closing:=false
func _ready()->void:
	layer=46;process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true);set_meta("show_previous_screen",true)
	_root=UiFactory.full_rect();_root.theme=PixelUi.theme();add_child(_root)
	_root.add_child(UiFactory.dim_layer(.42))
	_canvas=StarUi.frame(_root,Vector2(960,660))
	_panel=PanelContainer.new();_panel.name="AnnouncementGlass";_canvas.add_child(_panel);_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style:=InteractionSkin.style("announcement");style.set_content_margin_all(28);_panel.add_theme_stylebox_override("panel",style)
	InteractionSkin.attach_glass(_panel)
	var column:=UiFactory.vbox(14);_panel.add_child(column)
	var top:=UiFactory.hbox(16);column.add_child(top)
	_heading=PixelUi.title("更新公告",32);_heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(_heading)
	_selector=OptionButton.new();_selector.name="ReleaseHistory";_selector.custom_minimum_size=Vector2(176,44);top.add_child(_selector)
	for release in ReleaseNotes.RELEASES:_selector.add_item("V"+str(release.version))
	_selector.item_selected.connect(_show_release);InteractionSkin.apply_button(_selector,"announcement")
	_scroll=ScrollContainer.new();_scroll.name="ReleaseNotesScroll";_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;_scroll.follow_focus=true;column.add_child(_scroll)
	_body=UiFactory.vbox(14);_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_scroll.add_child(_body)
	var close:=PixelUi.button("阅毕 · 返回",22,0,50);close.name="CloseReleaseNotes";InteractionSkin.apply_button(close,"announcement");column.add_child(close);close.pressed.connect(dismiss)
	_glow=ReleaseNotesGlow.new();_canvas.add_child(_glow);_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show_release(0);UIFlow.push_screen(self);close.grab_focus.call_deferred();ComicMotion.reveal(_canvas,.25)
func _paragraph(text:String,font_size:int,color:Color)->Label:
	var label:=PixelUi.label(text,font_size,color);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.add_theme_constant_override("line_spacing",6);return label
func _show_release(index:int)->void:
	for child in _body.get_children():_body.remove_child(child);child.queue_free()
	var release:Dictionary=ReleaseNotes.RELEASES[index]
	_heading.text="V%s · %s"%[release.version,release.title]
	_body.add_child(_paragraph(str(release.date),17,PixelUi.MUTED))
	_body.add_child(_paragraph(str(release.intro),21,Color("e6eef5")))
	for section in release.sections:
		_body.add_child(_paragraph(str(section.title),24,PixelUi.GOLD))
		_body.add_child(_paragraph(str(section.text),20,Color("e1eaf2")))
	_scroll.scroll_vertical=0
func dismiss()->void:
	if _closing:return
	_closing=true;ReleaseNotes.acknowledge();UIFlow.pop_screen(self);closed.emit();queue_free()
func _unhandled_input(event:InputEvent)->void:
	if not UIFlow.is_top(self) or event.is_echo():return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled();dismiss()
