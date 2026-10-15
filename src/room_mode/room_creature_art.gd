class_name RoomCreatureArt
extends RefCounted
const GUARDIAN_BODY_HEIGHT:=132.0
const GUARDIAN_FOOT_Y:=166.0
const GUARDIAN_DIRECTION_ROOT:="res://assets/next_revision/creatures/guardian_directions/"
const GUARDIAN_DIRECTIONS:=["","southwest","west","northwest","north","northwest","west","southwest"]
const GUARDIAN_GEOMETRY:={"north":[454.0,481.0,465.0],"west":[446.0,484.0,468.0],"northwest":[407.0,485.0,446.0],"southwest":[428.0,485.0,452.0]}
const ACTIONS := [&"spawn",&"idle",&"walk",&"attack",&"hurt",&"death"]
static var cache:Dictionary={}
static func frames(id:String)->SpriteFrames:
	if id=="spirit_bone":return PixelEnemyArt.make_frames(&"walker")
	if cache.has(id):return cache[id]
	var path:="res://assets/room_mode/creatures/%s.png"%id
	if id=="spirit_tree_v2" and ResourceLoader.exists("res://assets/next_revision/creatures/amethyst_guardian.png"):path="res://assets/next_revision/creatures/amethyst_guardian.png"
	if not ResourceLoader.exists(path):return null
	var texture:Texture2D=load(path)
	var actions:Array=ACTIONS.duplicate()
	if id=="spirit_tree_v2":actions.append_array([&"root_cast",&"burst_cast"])
	var result:=SpriteFrames.new();result.remove_animation(&"default")
	var size:=Vector2(texture.get_width()/8.0,texture.get_height()/float(actions.size()))
	for row in actions.size():
		var action:StringName=actions[row];result.add_animation(action)
		result.set_animation_speed(action,[8.0,4.0,7.0,12.0,12.0,8.0,14.0,12.0][row])
		result.set_animation_loop(action,action in [&"idle",&"walk"])
		for col in 8:
			var frame:=AtlasTexture.new();frame.atlas=texture;frame.filter_clip=true
			var source_row:int=[5,0,1,2,3,4,6,7][row] if path=="res://assets/next_revision/creatures/amethyst_guardian.png" else row
			frame.region=Rect2(Vector2(col,source_row)*size,size)
			result.add_frame(action,frame)
	if id=="spirit_tree_v2":_add_guardian_directions(result)
	cache[id]=result
	return result
static func _add_guardian_directions(result:SpriteFrames)->void:
	for direction in 8:
		var key:String=GUARDIAN_DIRECTIONS[direction]
		var texture:Texture2D=null
		if not key.is_empty():
			var path:=GUARDIAN_DIRECTION_ROOT+key+".png"
			if not ResourceLoader.exists(path):continue
			texture=load(path)
		for action:StringName in [&"idle",&"walk",&"attack",&"hurt",&"root_cast",&"burst_cast"]:
			var name:=StringName("%s_d%d"%[action,direction])
			result.add_animation(name)
			result.set_animation_loop(name,action in [&"idle",&"walk"])
			if texture==null:
				result.set_animation_speed(name,result.get_animation_speed(action))
				for index in result.get_frame_count(action):result.add_frame(name,result.get_frame_texture(action,index))
				continue
			var sequence:Array=[0,1,2,1] if action==&"walk" else ([0,0,1,1,2,2] if action in [&"attack",&"root_cast",&"burst_cast"] else [1])
			var speed:float=6.0 if action==&"walk" else (float(sequence.size())/({&"root_cast":.55,&"burst_cast":.7}.get(action,.42)) if sequence.size()>1 else 1.0)
			result.set_animation_speed(name,speed)
			var cell:=Vector2(texture.get_width()/3.0,texture.get_height()/2.0)
			var row:=1 if action in [&"attack",&"root_cast",&"burst_cast"] else 0
			for index:int in sequence:
				var frame:=AtlasTexture.new();frame.atlas=texture;frame.filter_clip=true
				frame.region=Rect2(Vector2(index,row)*cell,cell)
				# The rear strike extends into its gutter, never into the recovery body.
				# Keep the original grid foot anchor, not a per-frame bounding-box centre.
				if key=="north" and row==1 and index in [1,2]:
					var overlap:=cell.x*56.0/512.0
					if index==1:frame.region.size.x+=overlap
					else:frame.region.position.x+=overlap;frame.region.size.x-=overlap
					frame.set_meta("guardian_foot_x",cell.x*.5-(overlap if index==2 else 0.0))
				result.add_frame(name,frame)
static func guardian_geometry(frame:Texture2D,action:StringName)->Vector2:
	var atlas:=frame as AtlasTexture
	if atlas!=null and atlas.atlas.resource_path.begins_with(GUARDIAN_DIRECTION_ROOT):
		var key:=atlas.atlas.resource_path.get_file().get_basename()
		var data:Array=GUARDIAN_GEOMETRY[key]
		var attacking:=str(action).begins_with("attack") or str(action).begins_with("root_cast") or str(action).begins_with("burst_cast")
		return Vector2(float(data[0]),float(data[2] if attacking else data[1]))*(frame.get_height()/512.0)
	return Vector2(GUARDIAN_BODY_HEIGHT,GUARDIAN_FOOT_Y)
static func spirit_id(kind:StringName)->String:
	return {&"walker":"spirit_bone",&"caster":"spirit_lantern",&"treant":"spirit_tree",&"guard":"spirit_guard"}.get(kind,"spirit_bone")

