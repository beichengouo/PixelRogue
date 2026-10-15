class_name DefeatMotion
extends Node
signal finished
var running = false
var elapsed = 0.0
var _clock = 0
var _previous = 1.0
var _duration = 1.0
var _slow = 0.18

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func play() -> void:
	if running: return
	_previous = Engine.time_scale
	_duration = 0.35 if ComicMotion.reduced() else 1.0
	_slow = 0.55 if ComicMotion.reduced() else 0.18
	elapsed = 0.0
	_clock = Time.get_ticks_usec()
	running = true
	Engine.time_scale = _slow

func _process(_delta: float) -> void:
	if not running: return
	var now = Time.get_ticks_usec()
	var dt = minf(0.1,(now-_clock)/1000000.0)
	_clock = now
	if get_tree().paused: return
	elapsed += dt
	var restore = _duration*0.7
	if elapsed >= restore:
		Engine.time_scale = lerpf(_slow,_previous,clampf((elapsed-restore)/(_duration-restore),0,1))
	if elapsed >= _duration: cancel()

func snapshot() -> Dictionary:
	return {"elapsed":elapsed,"previous":_previous,"duration":_duration,"slow":_slow} if running else {}

func restore(data: Dictionary) -> void:
	if data.is_empty(): return
	_previous=maxf(0.01,float(data.get("previous",1.0)))
	_duration=maxf(0.1,float(data.get("duration",1.0)))
	_slow=maxf(0.01,float(data.get("slow",0.18)))
	elapsed=clampf(float(data.get("elapsed",0)),0,_duration)
	if elapsed>=_duration: return
	_clock=Time.get_ticks_usec()
	running=true
	Engine.time_scale=lerpf(_slow,_previous,clampf((elapsed-_duration*0.7)/(_duration*0.3),0,1))

func cancel() -> void:
	if not running: return
	running = false
	Engine.time_scale = _previous
	finished.emit()

func _exit_tree() -> void:
	if running: Engine.time_scale = _previous
