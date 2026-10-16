class_name PlayerStatusStrip
extends GridContainer
## Only used in player HUDs. Icons are cached, timers come from the actor snapshot.
const CELL_WIDTH := 34.0
const CELL_HEIGHT := 41.0
var _cells: Dictionary = {}
var _textures: Dictionary = {}
var available_width := 336.0
var _pulses:Dictionary={}
var _pulse_last:Dictionary={}

func _ready() -> void:
	name = "PlayerTimedStatuses"
	add_to_group("player_status_strips")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_constant_override("h_separation", 2)
	add_theme_constant_override("v_separation", 3)
	set_process_priority(40)

func _process(_delta: float) -> void:
	for id in _pulses.keys():
		_pulses[id]=maxf(0,float(_pulses[id])-_delta)
		if _pulses[id]<=0:_pulses.erase(id)
	refresh(GameState.player as Player if is_instance_valid(GameState.player) else null)

func pulse(key:String)->void:
	var now:=Time.get_ticks_msec()
	if now-int(_pulse_last.get(key,-1000))<450:return
	_pulse_last[key]=now
	var id:=key.trim_prefix("status:") if key.begins_with("status:") else "fate_"+key.trim_prefix("fate:") if key.begins_with("fate:") else "material_tide" if key in ["etch:tide","etch:memory"] else "shield" if key in ["etch:moss","etch:bone","etch:gate"] else ""
	if id.is_empty():return
	refresh(GameState.player as Player)
	if _cells.has(id):_pulses[id]=.26

func refresh(actor: Player) -> void:
	var rows := PlayerStatusCatalog.snapshot(actor)
	var active: Dictionary = {}
	columns = maxi(1, floori(available_width / (CELL_WIDTH + 2.0)))
	for index in rows.size():
		var row: Dictionary = rows[index]
		var id: String = row.id
		active[id] = true
		if not _cells.has(id): _cells[id] = _make_cell()
		var cell := _cells[id] as Control
		move_child(cell, index)
		var icon := cell.get_node("Icon") as TextureRect
		if str(cell.get_meta("icon", "")) != str(row.icon):
			if not _textures.has(row.icon): _textures[row.icon] = load(row.icon)
			icon.texture = _textures[row.icon]
			cell.set_meta("icon", row.icon)
		var text := cell.get_node("Time") as Label
		text.text = "常驻" if bool(row.get("permanent",false)) else time_text(float(row.remaining))
		text.add_theme_color_override("font_color", Color("ff9992") if row.debuff else Color("e5f7dc"))
		var stacks := cell.get_node("Stacks") as Label
		stacks.text = str(row.get("badge",str(row.stacks) if int(row.stacks)>0 else ""))
		cell.tooltip_text = "%s\n%s"%[row.name,row.description] if bool(row.get("permanent",false)) else "%s\n%s\n剩余 %.1f 秒" % [row.name, row.description, row.remaining]
	for id in _cells.keys():
		var cell:Control=_cells[id];var icon:TextureRect=cell.get_node("Icon")
		icon.modulate=Color(1.0,1.0,1.0).lerp(Color(1.55,1.35,.8),float(_pulses.get(id,0))/.26*clampf(float(SaveService.data.get("flash_strength",1)),0,1)) if not ComicMotion.reduced() else Color.WHITE
		if not active.has(id) and _pulses.has(id):(cell.get_node("Time") as Label).text="已用"
		if not active.has(id) and not _pulses.has(id):
			remove_child(cell); cell.queue_free(); _cells.erase(id)
	visible = not _cells.is_empty()

static func time_text(seconds: float) -> String:
	return "%.1fs" % seconds if seconds < 1.0 else "%ds" % ceili(seconds)

func _make_cell() -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(CELL_WIDTH, CELL_HEIGHT)
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(cell)
	var icon := TextureRect.new()
	icon.name = "Icon"; icon.position = Vector2(3, 0); icon.size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE; cell.add_child(icon)
	var text := PixelUi.label("", 10, Color.WHITE)
	text.name = "Time"; text.position = Vector2(0, 27); text.size = Vector2(CELL_WIDTH, 14)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_color_override("font_outline_color", Color("101726")); text.add_theme_constant_override("outline_size", 2); cell.add_child(text)
	var stacks := PixelUi.label("", 10, Color("fff1ad"))
	stacks.name = "Stacks"; stacks.position = Vector2(19, 0); stacks.size = Vector2(14, 14)
	stacks.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; stacks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stacks.add_theme_color_override("font_outline_color", Color("101726")); stacks.add_theme_constant_override("outline_size", 2); cell.add_child(stacks)
	return cell
