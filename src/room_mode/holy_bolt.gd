class_name HolyBolt
extends RoomProjectile
var feather:=false
var generation:=0
var split_left:=0
var holy_time:=0.0
func _build_orb()->void:
	var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;material=ink
	set_process(true)
func _build_weapon_effect()->void:
	if weapon_fx in ["staff_cloud_radiance","wand_arcane"]:_build_orb()
	else:super._build_weapon_effect()
func _process(delta:float)->void:holy_time+=delta;queue_redraw()
func _draw()->void:
	if _sprite!=null:return
	var phase:=.3 if ComicMotion.reduced() else fposmod(holy_time*3,1)
	if feather:
		HolyFX.paint(self,"feather",Rect2(-19,-10,38,20),phase)
	else:
		HolyFX.paint(self,"bolt",Rect2(-19,-12,38,24),phase)
func _hit_enemy(enemy:EnemyBase)->bool:
	var hp_before:=enemy.hp;var shield_before:=enemy.affix_shield;var result:=super._hit_enemy(enemy)
	if feather and mechanic_tag==&"character_proc" and not is_basic_attack and is_instance_valid(enemy) and (enemy.hp<hp_before or enemy.affix_shield<shield_before) and GameState.player is RoomPlayer:
		var runtime:HolyRuntime=(GameState.player as RoomPlayer).holy_runtime
		if is_instance_valid(runtime):runtime.on_feather_hit(enemy,generation,split_left)
	return result
func _hit_effect(_hit_target:bool)->void:
	HolyFX.spawn(get_parent(),global_position,"ring",14,.22);queue_free()
