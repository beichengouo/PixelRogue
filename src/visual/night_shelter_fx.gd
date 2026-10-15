class_name NightShelterFX
extends Sprite2D
var age:=0.0
var _geometry:=RoomSceneOcclusion.new()
var fit_age:=0.0
var fading:=false
var fade_age:=0.0
func _ready()->void:
	texture=load("res://assets/fx/night_shelter.png")
	hframes=8;vframes=3;position=Vector2(0,-15);z_index=1
	_fit_owner_model()
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

func _fit_owner_model()->void:
	var width:=76.0
	var height:=76.0
	var owner:=get_parent()
	if owner is HiredAlly:
		var rect:Rect2=_geometry.unit_visual_rect(owner)
		width=clampf(rect.size.x+12,28,170)
		height=clampf(rect.size.y+14,38,190)
		position=owner.to_local(rect.get_center())
	scale=Vector2(width/(texture.get_width()/8.0),height/(texture.get_height()/3.0))
func _process(dt:float)->void:
	var player:=get_parent() as Player
	var ally:=get_parent() as HiredAlly
	if not is_instance_valid(player) and not is_instance_valid(ally):queue_free();return
	if ally!=null:
		fit_age+=dt
		if fit_age>=.25:fit_age=0;_fit_owner_model()
	var duration:float=player._shield_time if player!=null else ally.shield_time
	var health:float=player.hp if player!=null else ally.hp
	var shield:float=player.shield_hp if player!=null else ally.shield_hp
	var active:=health>0 and shield>0 and duration>0
	if active:
		fading=false;fade_age=0;age+=dt
		frame=clampi(int(age/.32*8),0,7) if age<.32 else 8+posmod(int((age-.32)*(3 if ComicMotion.reduced() else 6)),8)
		modulate.a=.68*PixelSpellArt.strength()
	else:
		if not fading:fading=true;fade_age=0
		fade_age+=dt
		frame=16+clampi(int(fade_age/.32*8),0,7)
		modulate.a=.68*maxf(0,1-fade_age/.32)*PixelSpellArt.strength()
		if fade_age>=.32:queue_free()
