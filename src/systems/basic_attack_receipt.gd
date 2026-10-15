class_name BasicAttackReceipt
extends RefCounted
## One shared receipt per attack, even when it emits several projectiles.
var epoch := -1
var owner: WeakRef
var claimed := false
var critical := false
var effects: Dictionary = {}

func _init(player: Node = null) -> void:
	epoch = GameState.run_epoch
	if player != null: owner = weakref(player)

func claim() -> float:
	if claimed or epoch != GameState.run_epoch or (not GameState.run_active and not CampSession.active): return 0.0
	if owner == null or owner.get_ref() != GameState.player: return 0.0
	claimed = true
	return Combat.apply_lifesteal(GameState.stats)

func claim_effect(key: StringName) -> bool:
	if epoch != GameState.run_epoch or (not GameState.run_active and not CampSession.active) or effects.has(key): return false
	if owner == null or owner.get_ref() != GameState.player: return false
	effects[key] = true
	return true
