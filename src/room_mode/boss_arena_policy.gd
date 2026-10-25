class_name BossArenaPolicy
extends RefCounted
## Runtime-only arena projection. Never changes authored templates or save deltas.
static func active(record:Dictionary)->bool:return str(record.get("kind","")) in ["boss","boss_rush"]
static func objects(source:Array)->Array:
	var result:Array=[]
	for item:Dictionary in source:
		var light:=str(item.get("kind",""))=="light"
		if not light and (str(item.get("kind","")) in ["crate","stone"] or item.get("collision_polygon_px",[]).size()>=3):continue
		var copy:=item.duplicate(true)
		if light:copy["collision_polygon_px"]=[]
		result.append(copy)
	return result
static func layout(source:Dictionary)->Dictionary:
	var result:=source.duplicate(true)
	result["props"]=[];result["crates"]=[];result["stones"]=[]
	result["scene_objects"]=objects(result.get("scene_objects",[]))
	result["service_props"]=[]
	return result
