extends Node
## Capture diagnostics without touching player saves or sending network traffic.
const LOG_PATH:="user://diagnostics/latest-error.txt"
const MAX_ERRORS:=32
const MAX_REPORT_LENGTH:=96000
var logger:Logger
var entries:Array[Dictionary]=[]
var dialog
var interactive:=false
var _dirty:=false
var _persist_after:=0
var _pending_popup:=false
var _show_after:=0
var _acknowledged:Dictionary={}
func _enter_tree()->void:
	logger=preload("res://src/systems/runtime_error_logger.gd").new()
	OS.add_logger(logger)
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	interactive=DisplayServer.get_name()!="headless" and not Engine.is_editor_hint()
func _process(_delta:float)->void:
	var batch:Array[Dictionary]=logger.drain()
	var new_error:=false
	for entry:Dictionary in batch:
		var key:="%s:%d:%s:%s"%[entry.file,entry.line,entry.function,entry.code]
		entry.key=key
		var found:=false
		for previous:Dictionary in entries:
			if previous.key==key:previous.count=int(previous.count)+1;previous.time=entry.time;found=true;break
		if not found:
			new_error=true;entry.count=1;entries.append(entry)
			if entries.size()>MAX_ERRORS:entries.pop_front()
			if not _acknowledged.has(key):_pending_popup=true
		_dirty=true
	if _dirty and (new_error or Time.get_ticks_msec()>=_persist_after):
		_dirty=false;_persist_after=Time.get_ticks_msec()+1000
		var report:=report_text()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://diagnostics"))
		var file:=FileAccess.open(LOG_PATH,FileAccess.WRITE)
		if file!=null:file.store_string(report)
		if is_instance_valid(dialog) and dialog.is_open():dialog.show_report(report)
	if interactive and _pending_popup and Time.get_ticks_msec()>=_show_after:open_report()
func report_text()->String:
	var text:="游戏报错反馈\n版本 V%s · %s · Godot %s\n角色 %s · 等级 %d · 场次 %d · 种子 %s\n请补充：发生前进行了什么操作？\n"%[str(ProjectSettings.get_setting("application/config/version","unknown")),OS.get_name(),Engine.get_version_info().string,str(Characters.current_id()),GameState.level,GameState.wave,str(Rng.run_seed)]
	for index in range(entries.size()-1,-1,-1):
		var entry:Dictionary=entries[index]
		var piece:="\n[%s] 类型 %d · 出现 %d 次\n%s:%d @ %s\n%s\n%s\n%s\n"%[entry.time,entry.type,entry.count,entry.file,entry.line,entry.function,entry.code,entry.detail,entry.trace]
		if text.length()+piece.length()>MAX_REPORT_LENGTH:break
		text+=piece
	return text
func open_report()->void:
	if entries.is_empty():return
	if not is_instance_valid(dialog):
		dialog=preload("res://src/ui/error_report_ui.gd").new();add_child(dialog)
		dialog.closed.connect(_on_closed)
	_pending_popup=false;dialog.show_report(report_text())
func _on_closed()->void:
	for entry:Dictionary in entries:_acknowledged[entry.key]=true
	if _acknowledged.size()>256:_acknowledged.clear()
	_show_after=Time.get_ticks_msec()+5000
func _exit_tree()->void:
	if logger!=null:OS.remove_logger(logger)
