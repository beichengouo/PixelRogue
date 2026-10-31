class_name CampResidentArt
extends RefCounted
const HANDDRAWN_ROOT := "res://assets/camp_npcs_handdrawn_v37/"
static var _metadata:Dictionary={}
static var _frames:Dictionary={}
static func metadata(id:String)->Dictionary:
	if _metadata.is_empty():
		var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(CampResidents.ROOT+"metadata.json"))
		if value is Dictionary:_metadata=value
	return _metadata.get(id,{"extents":[104,100]})
static func frames(id:String)->SpriteFrames:
	if _frames.has(id):return _frames[id]
	var authored_path:=HANDDRAWN_ROOT+id+"/"+id+".tres"
	if ResourceLoader.exists(authored_path):
		var authored:=load(authored_path) as SpriteFrames
		if authored!=null and bool(authored.get_meta("handdrawn",false)) and str(authored.get_meta("resident_id",""))==id:
			_frames[id]=authored;return authored
	var texture:=load(CampResidents.ROOT+id+".png") as Texture2D
	var result:=SpriteFrames.new();result.remove_animation(&"default")
	var actions:=["idle_south","walk_south","idle_north","walk_north","rest","talk"]
	for row in actions.size():
		var positions:Array=[]
		for column in 4:positions.append(Vector2(column,row))
		var speed:=8.0 if str(actions[row]).begins_with("walk") else (5.0 if actions[row]=="talk" else (1.25 if actions[row]=="rest" else .75))
		PixelEnemyArt._add(result,StringName(actions[row]),texture,Vector2(128,128),positions,speed,actions[row]!="rest")
	_frames[id]=result;return result
static func align(sprite:AnimatedSprite2D,id:String)->void:
	if bool(sprite.sprite_frames.get_meta("handdrawn",false)):
		HanddrawnHeroArt.place(sprite,sprite.sprite_frames,32.0,12.0);return
	var extent:Array=metadata(id).get("extents",[104,100]);var scale_value:=minf(38.0/maxf(1,extent[0]),32.0/maxf(1,extent[1]))
	sprite.scale=Vector2.ONE*scale_value;sprite.position=Vector2(0,12-52*scale_value)

static func pose(sprite:AnimatedSprite2D,id:String,action:StringName,facing:Vector2)->void:
	var wanted:=action
	if bool(sprite.sprite_frames.get_meta("handdrawn",false)):
		var direction:=RoomHeroArt.direction_name(facing)
		if str(action).begins_with("idle") or str(action).begins_with("walk"):
			var kind:="walk" if str(action).begins_with("walk") else "idle"
			wanted=StringName(kind+"_"+direction)
			sprite.flip_h=RoomHeroArt.flip_for(kind,direction)
		else:
			# Rest/talk have one authored front-diagonal source. Mirroring changes
			# only its facing; navigation and patrol state remain owned by actor.
			sprite.flip_h=facing.x>0.0
	else:sprite.flip_h=facing.x<0.0
	if sprite.animation!=wanted:
		sprite.play(wanted);align(sprite,id)

static func clear()->void:
	_frames.clear();_metadata.clear()
