class_name PixelMeleeFX
extends AnimatedSprite2D
const SOURCE:="res://assets/pixel_batch11/melee_slash.png"
static var _frames:SpriteFrames
func setup(radius:float,color:Color,life:float)->void:
	if _frames==null:
		var texture:=load(SOURCE) as Texture2D
		var cell:=Vector2(texture.get_width()/4.0,texture.get_height()/2.0)
		_frames=SpriteFrames.new()
		_frames.remove_animation(&"default")
		_frames.add_animation(&"slash")
		_frames.set_animation_loop(&"slash",false)
		_frames.set_animation_speed(&"slash",8.0)
		for i in 8:
			var frame_texture:=AtlasTexture.new()
			frame_texture.atlas=texture
			frame_texture.region=Rect2(Vector2(i%4,i/4)*cell,cell)
			frame_texture.filter_clip=true
			_frames.add_frame(&"slash",frame_texture)
	sprite_frames=_frames
	scale=Vector2.ONE*(radius*2.0/(_frames.get_frame_texture(&"slash",0).get_height()*0.82))
	modulate=color.lightened(0.3)
	speed_scale=1.0/maxf(0.04,life)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	material=PixelSpellArt.material()
	process_mode=Node.PROCESS_MODE_PAUSABLE
	z_index=5
	animation_finished.connect(queue_free,CONNECT_ONE_SHOT)
func _ready()->void:
	add_to_group("melee_slashes")
	play(&"slash")
