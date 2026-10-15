class_name IlyuaField
extends Node2D

var runtime: IlyuaRuntime
var kind: StringName = &"seed"
var radius := 72.0
var remaining := 4.0
var tick_every := 1.0
var tick_clock := 0.0
var damage_ratio := 0.0
var generation := 0
var owner_enemy: WeakRef
var entered: Dictionary = {}
var spread_budget := 0
var spread_used := 0
var plant_count := 0
var nearby_seed := false
var root_time := 0.0
var slow_strength := 0.0
var leaf_clock:=0.0
var plants:Array[Vector2]=[]
var next_spread:=0.0

func _ready() -> void:
	add_to_group("ilyua_fields")
	IlyuaFX.spawn(self, Vector2.ZERO, str(kind),maxf(32,radius * 2.0),remaining)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(runtime) or is_queued_for_deletion():queue_free();return
	var active_delta:=minf(delta,maxf(0,remaining))
	remaining = maxf(0,remaining-delta)
	if kind in [&"seed",&"spread_vine"]:
		var enemy: EnemyBase = owner_enemy.get_ref() as EnemyBase if owner_enemy != null else null
		if not runtime.live(enemy):queue_free();return
		global_position = enemy.global_position
	if kind == &"trap":
		for enemy in runtime.enemies_in(global_position, radius):
			var id := enemy.get_instance_id()
			if entered.has(id): continue
			entered[id] = true
			if not enemy is BossBase: runtime.root_enemy(enemy, root_time)
			enemy.apply_slow(slow_strength, remaining)
	if kind == &"tree":
		leaf_clock+=active_delta
		if leaf_clock>=1.0:leaf_clock-=1.0;runtime.tree_leaves(self)
		for enemy in runtime.enemies_in(global_position, radius):
			var id := enemy.get_instance_id()
			if not entered.has(id):
				entered[id] = true
				if not enemy is BossBase: runtime.root_enemy(enemy, root_time)
			enemy.apply_slow(slow_strength, 0.65)
	tick_clock += active_delta
	while tick_clock+.000001 >= tick_every:
		tick_clock -= tick_every
		runtime.field_tick(self)
	if remaining<=0:
		if kind==&"tree":runtime.finish_tree(self)
		if kind==&"seed" and owner_enemy!=null:
			var owner:EnemyBase=owner_enemy.get_ref() as EnemyBase
			if is_instance_valid(owner):runtime.seed_marks.erase(owner.get_instance_id())
		queue_free()

func snapshot() -> Dictionary:
	var target_id := ""
	if owner_enemy != null and is_instance_valid(owner_enemy.get_ref()): target_id = str(owner_enemy.get_ref().get_instance_id())
	var saved_plants:Array=[]
	for plant in plants:saved_plants.append([plant.x,plant.y])
	var saved_entered:Array=[]
	for id in entered:saved_entered.append(str(id))
	return {"kind": str(kind), "at": [global_position.x, global_position.y], "remaining": remaining, "radius": radius, "tick_every": tick_every, "tick_clock": tick_clock, "ratio": damage_ratio, "generation": generation, "owner": target_id, "entered":saved_entered, "spread_budget": spread_budget, "spread_used": spread_used, "plant_count": plant_count, "root_time": root_time, "slow_strength": slow_strength,"plants":saved_plants,"leaf_clock":leaf_clock,"next_spread":next_spread}
