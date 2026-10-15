class_name AchievementToast
extends CanvasLayer
var achievement_id:=""
var _panel:PanelContainer
var _elapsed:=0.0
var _extent:=Vector2(400,130)
const DISPLAY_SCALE:=2.0/3.0
func _ready()->void:
	layer=60;process_mode=Node.PROCESS_MODE_ALWAYS
	_panel=PanelContainer.new();_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;_panel.add_theme_stylebox_override("panel",InteractionSkin.style("achievement"));add_child(_panel);InteractionSkin.attach_glass(_panel)
	var row:=UiFactory.hbox(14);row.mouse_filter=Control.MOUSE_FILTER_IGNORE;_panel.add_child(row)
	var art:=TextureRect.new();art.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.texture=AchievementCatalog.icon(achievement_id);art.custom_minimum_size=Vector2(64,64);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(art)
	var text:=UiFactory.vbox(4);text.mouse_filter=Control.MOUSE_FILTER_IGNORE;text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text)
	for entry in [["成就解锁",16,Color("a8c6d7")],[AchievementCatalog.DATA[achievement_id].name,23,Color("fff0c1")],[AchievementCatalog.DATA[achievement_id].description,16,Color("e5eef4")]]:
		var label:=PixelUi.label(str(entry[0]),int(entry[1]),entry[2]);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.add_child(label)
	get_viewport().size_changed.connect(_fit);_fit()
	AudioManager.play(&"achievement_unlock",-5,0)
	InteractionSkin.surface(_panel,"achievement")

func _fit()->void:
	var view:=get_viewport().get_visible_rect()
	var factor:=minf(DISPLAY_SCALE,(view.size.x-32)/400.0)
	_panel.scale=Vector2.ONE*factor;_panel.size=_extent
	_panel.position=view.end-_panel.size*factor-Vector2(16,16)
func _process(delta:float)->void:
	_elapsed+=minf(delta,.1);_fit()
	_panel.modulate.a=clampf(_elapsed/.2,0,1)*clampf((5-_elapsed)/.35,0,1)
	if not ComicMotion.reduced():_panel.position.x-=(1-clampf(_elapsed/.28,0,1))*30
	if _elapsed>=5:queue_free()
