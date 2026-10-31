class_name RoomSceneLife
extends RefCounted
## Optional visual-only patches in the illustration's native source coordinates.
## Original planes remain underneath, so a missing pair never erases scenery.
const ROOT:="res://assets/room_life_v43/"
var entries:Array[Dictionary]=[]
var age:=0.0
var enabled:=true

static func definition(scene_id:String)->Dictionary:
	var path:=ROOT+scene_id+"/animation.json"
	if not FileAccess.file_exists(path):return {}
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary and int(parsed.get("version",0))==1 and bool(parsed.get("enabled",true)) else {}

static func texture_paths(scene_id:String)->Array[String]:
	var result:Array[String]=[]
	for value:Variant in definition(scene_id).get("patches",[]):
		if not value is Dictionary:continue
		var item:Dictionary=value
		for key:String in ["repair","atlas"]:
			var path:=ROOT+scene_id+"/"+str(item.get(key,""))
			if ResourceLoader.exists(path) and not result.has(path):result.append(path)
	return result

func configure(host:RoomSceneArtwork,scene_id:String,layer_anchors:Dictionary)->void:
	entries.clear();age=0.0
	if Engine.is_editor_hint():return
	var parsed:=definition(scene_id)
	configure_data(host,parsed,ROOT+scene_id+"/",layer_anchors)

func configure_data(host:RoomSceneArtwork,parsed:Dictionary,root:String,layer_anchors:Dictionary)->void:
	if parsed.get("canvas",[])!=host.data.get("canvas",[]):return
	for value:Variant in parsed.get("patches",[]):
		if not value is Dictionary:continue
		var item:Dictionary=value
		var layer:=str(item.get("layer","background"))
		if not layer_anchors.has(layer):continue
		var box:Variant=item.get("rect_px",[])
		var size:Variant=item.get("frame_size",[])
		if not box is Array or box.size()!=4 or not size is Array or size.size()!=2:continue
		var cell:=Vector2i(int(size[0]),int(size[1]))
		var count:=int(item.get("frames",0));var columns:=int(item.get("columns",0))
		if cell.x<=0 or cell.y<=0 or count!=8 or columns<=0 or count%columns!=0:continue
		if float(box[2])<=0 or float(box[3])<=0:continue
		var source_rect:=Rect2(float(box[0]),float(box[1]),float(box[2]),float(box[3]))
		if not source_rect.is_finite() or not Rect2(Vector2.ZERO,Vector2(float(host.data.canvas[0]),float(host.data.canvas[1]))).encloses(source_rect):continue
		var fps:=float(item.get("fps",6.0))
		if not is_finite(fps) or fps<=0 or fps>24:continue
		var repair_path:=root+str(item.get("repair",""))
		var atlas_path:=root+str(item.get("atlas",""))
		if not ResourceLoader.exists(repair_path) or not ResourceLoader.exists(atlas_path):continue
		var repair:=load(repair_path) as Texture2D
		var atlas:=load(atlas_path) as Texture2D
		if repair==null or atlas==null:continue
		if repair.get_size()!=Vector2(cell) or atlas.get_size()!=Vector2(cell.x*columns,cell.y*(count/columns)):continue
		# Only create either node once the entire pair has passed validation.
		var rect:=RoomSceneArtwork.plane_rect({"rect_px":box},host.frame_rect(),Vector2(float(host.data.canvas[0]),float(host.data.canvas[1])))
		var clean:=_sprite(repair,rect);clean.name=str(item.get("id","patch"))+"Repair"
		var moving:=_sprite(atlas,rect);moving.name=str(item.get("id","patch"))+"Leaves"
		moving.hframes=columns;moving.vframes=count/columns;moving.scale=rect.size/Vector2(cell)
		host.add_child(clean);host.add_child(moving)
		var anchor:Node=layer_anchors[layer]
		host.move_child(clean,anchor.get_index()+1);host.move_child(moving,clean.get_index()+1)
		layer_anchors[layer]=moving
		host.ground_planes.append(clean);host.ground_planes.append(moving)
		WeatherSurfaceArt.apply(clean,0,0,layer=="background")
		WeatherSurfaceArt.apply(moving,0,0,layer=="background")
		entries.append({"id":str(item.get("id","")),"repair":clean,"sprite":moving,"phase":posmod(int(item.get("phase",0)),count),"count":count,"fps":fps,"ground":layer=="background"})
	update(0.0,false,true)

func _sprite(texture:Texture2D,rect:Rect2)->Sprite2D:
	var node:=Sprite2D.new();node.texture=texture;node.centered=false
	node.position=rect.position;node.scale=rect.size/texture.get_size()
	node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	return node

func update(delta:float,advance:bool,reduced:bool)->void:
	if advance and enabled and not reduced:age+=delta
	for item:Dictionary in entries:
		item.repair.visible=enabled;item.sprite.visible=enabled
		item.sprite.frame=0 if reduced else posmod(floori(age*float(item.fps))+int(item.phase),int(item.count))

func apply_weather(snow:float,wet:float)->void:
	for item:Dictionary in entries:
		WeatherSurfaceArt.apply(item.repair,snow,wet,bool(item.ground))
		WeatherSurfaceArt.apply(item.sprite,snow,wet,bool(item.ground))
