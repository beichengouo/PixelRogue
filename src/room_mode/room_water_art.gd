class_name RoomWaterArt
extends RefCounted
const PATH:="res://assets/room_mode/terrain_v4/water_autotiles.png"
const AROUND:=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(-1,-1)]
static var texture:Texture2D
static var _frames:Array[Texture2D]=[]
const FRAME_RATE:=4.0
static func clear_cache()->void:
	texture=null
	_frames.clear()
static func frame_texture(clock:float=0)->Texture2D:
	if texture==null:
		_frames.clear()
		if ResourceLoader.exists(PATH):texture=load(PATH)
	if texture==null:return null
	if _frames.is_empty():
		_frames.append(texture)
		# Install atomically: an old or partially supplied atlas stays static.
		var animated:Array[Texture2D]=[texture]
		for index in range(1,4):
			var path:=PATH.trim_suffix(".png")+"_%d.png"%index
			if not ResourceLoader.exists(path):return texture
			var frame:=load(path) as Texture2D
			if frame==null or frame.get_size()!=Vector2(576,576) or frame.get_size()!=texture.get_size():return texture
			animated.append(frame)
		_frames=animated
	return _frames[posmod(int(floor(clock*FRAME_RATE)),_frames.size())]
static func mask(cells:Dictionary,at:Vector2i)->int:
	var result:=0
	for i in AROUND.size():
		if cells.has(at+AROUND[i]):result|=1<<i
	return result
static func draw_cells(canvas:CanvasItem,cells:Dictionary,clock:float=0)->void:
	var frame:=frame_texture(clock)
	if frame==null:return
	for at:Vector2i in cells:
		var index:=mask(cells,at)
		canvas.draw_texture_rect_region(frame,Rect2(Vector2(at)*36,Vector2.ONE*36),Rect2(posmod(index,16)*36,int(index/16)*36,36,36))
