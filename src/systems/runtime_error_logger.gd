extends Logger
## Engine callbacks may run concurrently. Only strings enter this bounded queue.
var _mutex:=Mutex.new()
var _pending:Array[Dictionary]=[]
const MAX_PENDING:=128
func _log_error(function:String,file:String,line:int,code:String,rationale:String,_editor_notify:bool,error_type:int,script_backtraces:Array[ScriptBacktrace])->void:
	if error_type==Logger.ERROR_TYPE_WARNING:return
	var frames:PackedStringArray=[]
	for backtrace in script_backtraces:
		frames.append(backtrace.format().left(8000))
	var entry:Dictionary={"function":function,"file":file,"line":line,"code":code.left(4096),"detail":rationale.left(4096),"trace":"\n".join(frames).left(12000),"type":error_type,"time":Time.get_datetime_string_from_system()}
	_mutex.lock()
	if _pending.size()<MAX_PENDING:_pending.append(entry)
	_mutex.unlock()
func drain()->Array[Dictionary]:
	_mutex.lock()
	var result:Array[Dictionary]=_pending
	_pending=[]
	_mutex.unlock()
	return result
