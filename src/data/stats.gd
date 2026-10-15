class_name StatBlock
extends RefCounted
## 属性块：基础值 + 一堆道具叠上来的加法 / 乘法。
##
## 最终值 = (基础 + 所有加法) * (1 + 所有乘法)
## 一个道具就是一组 flat / mult，这就是整个肉鸽构筑系统的地基。

var _base: Dictionary = {}
var _flat: Dictionary = {}
var _mult: Dictionary = {}
## Weak owner binds only the live player block; previews and enemy blocks stay independent.
var status_owner: WeakRef


func clear() -> void:
	_base.clear()
	_flat.clear()
	_mult.clear()


func set_base(stat: StringName, value: float) -> void:
	_base[stat] = value


func add_flat(stat: StringName, value: float) -> void:
	_flat[stat] = float(_flat.get(stat, 0.0)) + value


func add_mult(stat: StringName, value: float) -> void:
	_mult[stat] = float(_mult.get(stat, 0.0)) + value


func get_value(stat: StringName) -> float:
	var base := float(_base.get(stat, 0.0))
	var flat := float(_flat.get(stat, 0.0))
	var mult := float(_mult.get(stat, 0.0))
	var owner: Player = status_owner.get_ref() as Player if status_owner != null else null
	var factor := PlayerDebuffs.multiplier(owner,stat) if stat in [&"attack",&"attack_speed",&"mp_regen"] else 1.0
	return (base + flat) * (1.0 + mult) * factor


func describe() -> Dictionary:
	## 调试用：把每个属性的最终值列出来
	var out := {}
	for stat: StringName in _base:
		out[stat] = get_value(stat)
	return out

