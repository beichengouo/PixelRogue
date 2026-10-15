class_name BossConstruct
extends EnemyBase
## Destructible emitters are targets, never terrain or solid unit bodies.
var room:RoomLevel
var construct_kind:="crystal"
var boss_family:="mage"
var owner_tag:=""
var wave_tag:=0
var lifetime:=10.0
var shooting_left:=1.5
var shot_count:=0
var resonance:=false
var shield_orbit:=false
var orbit_angle:=0.0
var orbit_radius:=92.0
var _boss:RoomBoss
var _art:Sprite2D
func _ready()->void:
	uses_gravity=false;collides_with_world=false;body_size=Vector2(24,28);base_coins=0;loot_origin="boss_construct"
	super._ready();collision_layer=Layers.BOSS_OBJECT;collision_mask=0;add_to_group("boss_constructs")
	if is_instance_valid(contact_area):contact_area.monitoring=false
func _build_body_collider()->void:
	var shape:=CircleShape2D.new();shape.radius=12;var collider:=CollisionShape2D.new();collider.shape=shape;add_child(collider)
func _build_visual()->void:
	_art=Sprite2D.new();_art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(_art);visual=_art
	var frames:=HostileAttackFX.frames(boss_family,"construct")
	if frames.is_empty():frames=HostileAttackFX.frames(boss_family,"cast")
	if not frames.is_empty():_art.texture=frames[0];_art.scale=Vector2.ONE*48/HostileAttackFX.cell_size(boss_family,"construct")
	_art.position.y=-12
	_apply_clone_art()
func _apply_clone_art()->void:
	if construct_kind=="clone" and is_instance_valid(_boss) and _boss.visual is AnimatedSprite2D:
		var animation:=_boss.visual as AnimatedSprite2D;_art.texture=animation.sprite_frames.get_frame_texture(&"idle",0);_art.scale=animation.scale;_art.self_modulate=Color(.6,.8,1,.5)
func _physics_process(dt:float)->void:
	if _dead:return
	if not is_instance_valid(_boss):
		for node in get_tree().get_nodes_in_group("bosses"):
			if node is RoomBoss and node.owner_tag==owner_tag:_boss=node;_apply_clone_art();break
	if not is_instance_valid(_boss) or _boss._dead:queue_free();return
	lifetime-=dt
	if lifetime<=0:
		if construct_kind=="prison":_boss.prison_expired(self)
		retire();return
	if shield_orbit:
		orbit_angle+=dt*.55;global_position=_boss.global_position+Vector2.from_angle(orbit_angle)*orbit_radius
	advance_slow(dt);_flash=maxf(0,_flash-dt)
	if _burn_time>0:
		_burn_time=maxf(0,_burn_time-dt);_burn_tick+=dt
		if _burn_tick>=.5:_burn_tick-=.5;take_damage(_burn_dps*.5,false,global_position,_burn_source.get_ref() if _burn_source!=null else null,false)
	if _dead:return
	shooting_left-=dt
	if shooting_left<=0:
		shooting_left=3.6 if construct_kind=="bud" else 4.5
		if _boss.can_construct_fire(self):_boss.warn_construct_shot(self)
	if _art!=null:
		var frames:=HostileAttackFX.frames(boss_family,"construct")
		if not frames.is_empty() and construct_kind!="clone":_art.texture=frames[int(lifetime*6)%frames.size()]
	queue_redraw()
func _die()->void:
	if _dead:return
	_dead=true;collision_layer=0
	HostileAttackFX.pulse(_fx(),global_position,boss_family,"impact",60,.55,0,room)
	if is_instance_valid(_boss):_boss.construct_destroyed(self)
	queue_free()
func retire()->void:
	if is_instance_valid(_boss) and resonance and wave_tag==_boss.active_wave:_boss.active_wave=0
	_dead=true;collision_layer=0;queue_free()
