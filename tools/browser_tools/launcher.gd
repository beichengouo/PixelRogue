extends RefCounted
static func launch()->int:
	var python:=OS.get_environment("PIXELROGUE_PYTHON")
	if python.is_empty():python="C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe"
	if not FileAccess.file_exists(python):python="python"
	var arguments:=PackedStringArray([ProjectSettings.globalize_path("res://tools/browser_tools/server.py"),"--project",ProjectSettings.globalize_path("res://"),"--godot",OS.get_executable_path()])
	return OS.create_process(python,arguments,false)
