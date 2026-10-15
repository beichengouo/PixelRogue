class_name IlyuaDecoy
extends CharacterBody2D

var runtime: IlyuaRuntime
var hp := 1.0
var remaining := 3.0
var radius := 144.0
var leaves_left := 0
var leaf_clock := 0.0
var exploded := false
var death_volley := false

func _ready() -> void:
	add_to_group("ilyua_decoys")
	collision_layer = Layers.PLAYER
	collision_mask = 0
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	collider.shape = circle
	add_child(collider)
	IlyuaFX.spawn(self, Vector2.ZERO, "decoy", 42.0, remaining)

func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0: expire()

func take_damage(amount: float, _from: Vector2 = Vector2.ZERO, _source: Node = null) -> void:
	if amount <= 0.0 or exploded: return
	hp = 0.0
	expire(true)

func expire(killed:=false) -> void:
	if exploded: return
	exploded = true
	hp=0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is EnemyBase and enemy.aggro==self:enemy.aggro=null;enemy._aggro_timer=0;enemy.reset_path()
	if is_instance_valid(runtime):
		if killed and death_volley:runtime.fire_decoy_volley(global_position)
		IlyuaFX.spawn(runtime.actor.get_parent(), global_position, "decoy_burst", 144.0, 0.35)
		runtime.area_proc(global_position, 72.0, 0.35)
		for i in leaves_left:
			var target:=runtime.nearest_enemy(global_position,144)
			if target!=null:runtime.spawn_arrow(&"leaf",global_position,(target.global_position-global_position).normalized(),.15,false,false,null,target)
	queue_free()

func snapshot() -> Dictionary:
	return {"at": [global_position.x, global_position.y], "remaining": remaining, "hp": hp, "leaves_left": leaves_left, "leaf_clock": leaf_clock,"death_volley":death_volley}
