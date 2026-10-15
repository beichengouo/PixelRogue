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
	var gold:=Color("efd391");var white:=Color("fffdf0");var blue:=Color("a9dafa")
	if feather:
		if HolyFX.paint(self,"feather",Rect2(-19,-10,38,20),fposmod(holy_time*3,1)):
			return
		draw_colored_polygon(PackedVector2Array([Vector2(-11,0),Vector2(-4,-5),Vector2(7,-3),Vector2(12,0),Vector2(-1,4)]),white)
		draw_line(Vector2(-9,1),Vector2(10,0),gold,2)
		for i in 3:draw_line(Vector2(-5+i*4,-1),Vector2(-8+i*4,-4),gold,1)
	else:
		draw_circle(Vector2.ZERO,5.5,blue);draw_circle(Vector2(1,-1),3.5,white);draw_arc(Vector2.ZERO,8,holy_time*3,holy_time*3+PI*1.4,18,gold,1.5)
		if weapon_fx=="staff_cloud_radiance":
			for i in 3:draw_arc(Vector2.RIGHT.rotated(i*TAU/3)*4,7,holy_time*4+i*TAU/3,holy_time*4+i*TAU/3+PI,20,gold,2)
		if not ComicMotion.reduced():draw_line(Vector2(-13,0),Vector2(-6,0),Color(gold,.55),2)
func _hit_enemy(enemy:EnemyBase)->bool:
	var hp_before:=enemy.hp;var shield_before:=enemy.affix_shield;var result:=super._hit_enemy(enemy)
	if feather and mechanic_tag==&"character_proc" and not is_basic_attack and is_instance_valid(enemy) and (enemy.hp<hp_before or enemy.affix_shield<shield_before) and GameState.player is RoomPlayer:
		var runtime:HolyRuntime=(GameState.player as RoomPlayer).holy_runtime
		if is_instance_valid(runtime):runtime.on_feather_hit(enemy,generation,split_left)
	return result
func _hit_effect(_hit_target:bool)->void:
	HolyFX.spawn(get_parent(),global_position,"ring",14,.22);queue_free()
