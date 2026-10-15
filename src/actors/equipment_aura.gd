class_name EquipmentAura
extends Node
var actor:Player
var _attack_wait:=0.0
var _hurt_wait:=0.0
var _crown:AnimatedSprite2D
var _crown_clock:=0.0
func _ready()->void:
	EventBus.player_damaged.connect(_on_hurt)
func _process(dt:float)->void:
	_attack_wait=maxf(0.0,_attack_wait-dt);_hurt_wait=maxf(0.0,_hurt_wait-dt)
	_sync_crown(dt)
func on_attack()->void:
	if _attack_wait>0 or not is_instance_valid(actor):return
	_attack_wait=1.2 if ComicMotion.reduced() else 0.8
	_show(GameState.equipped(&"accessory"),54.0)
func _on_hurt(_amount:float,_hp:float,_max_hp:float)->void:
	if _hurt_wait>0 or not is_instance_valid(actor) or actor.hp<=0:return
	_hurt_wait=0.8
	_show(GameState.equipped(&"armor"),72.0)
func _show(item:Dictionary,width:float)->void:
	var id:=str(item.get("legendary_fx",""))
	if id.is_empty():return
	if id=="gem_crown":return
	# Attached feedback follows the wearer and is freed with that run's actor.
	WeaponPulse.spawn(actor,actor.global_position+Vector2(0,-22),id,width*(0.85 if ComicMotion.reduced() else 1.0))

func _sync_crown(dt:float)->void:
	if not is_instance_valid(actor):return
	var worn:=str(GameState.equipped(&"accessory").get("legendary_fx",""))=="gem_crown" and actor.hp>0 and actor.extraction_pose==&""
	if not worn:
		if is_instance_valid(_crown):_crown.queue_free();_crown=null
		return
	if not is_instance_valid(_crown):
		_crown=AnimatedSprite2D.new();_crown.name="JewelCrownAura"
		var frames:=SpriteFrames.new();frames.set_animation_speed(&"default",5);frames.set_animation_loop(&"default",true)
		for texture in WeaponArt.frames("gem_crown_v03",128):frames.add_frame(&"default",texture)
		_crown.sprite_frames=frames;_crown.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		_crown.scale=Vector2.ONE*26.0/128.0;_crown.z_index=7;actor.add_child(_crown);_crown.play()
	_crown_clock+=dt
	_crown.position=Vector2(0,-28+(0 if ComicMotion.reduced() else sin(_crown_clock*2)*.6))
	_crown.speed_scale=.5 if ComicMotion.reduced() else 1.0
	_crown.modulate.a=clampf(float(SaveService.data.get("spell_fx_strength",1.0)),0,1)*.85
