class_name CampResidentArt
extends RefCounted
static var _metadata:Dictionary={}
static var _frames:Dictionary={}
static func metadata(id:String)->Dictionary:
	if _metadata.is_empty():
		var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(CampResidents.ROOT+"metadata.json"))
		if value is Dictionary:_metadata=value
	return _metadata.get(id,{"extents":[104,100]})
static func frames(id:String)->SpriteFrames:
	if _frames.has(id):return _frames[id]
	var texture:=load(CampResidents.ROOT+id+".png") as Texture2D
	var result:=SpriteFrames.new();result.remove_animation(&"default")
	var actions:=["idle_south","walk_south","idle_north","walk_north","rest","talk"]
	for row in actions.size():
		var positions:Array=[]
		for column in 4:positions.append(Vector2(column,row))
		var speed:=8.0 if str(actions[row]).begins_with("walk") else (5.0 if actions[row]=="talk" else 2.0)
		PixelEnemyArt._add(result,StringName(actions[row]),texture,Vector2(128,128),positions,speed,true)
	_frames[id]=result;return result
static func align(sprite:AnimatedSprite2D,id:String)->void:
	var extent:Array=metadata(id).get("extents",[104,100]);var scale_value:=minf(38.0/maxf(1,extent[0]),32.0/maxf(1,extent[1]))
	sprite.scale=Vector2.ONE*scale_value;sprite.position=Vector2(0,12-52*scale_value)
