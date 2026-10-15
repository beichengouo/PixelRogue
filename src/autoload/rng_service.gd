extends Node
## 统一随机源。
##
## 肉鸽里所有随机都必须经过这里，原因有两个：
##   1. 出 bug 时能靠种子复现（打印出的 seed 就是那局的身份证）
##   2. 以后想做「每日挑战 / 固定种子跑图」，换个种子就行

var run_seed: int = 0

var _rng := RandomNumberGenerator.new()


func start_run(seed_value: int = 0) -> void:
	if seed_value == 0:
		run_seed = int(Time.get_unix_time_from_system()) & 0x7FFFFFFF
	else:
		run_seed = seed_value
	_rng.seed = run_seed
	print("[RNG] 本局种子 = %d" % run_seed)


func stream() -> RandomNumberGenerator:
	return _rng


func next_int(from: int, to: int) -> int:
	## 闭区间 [from, to]
	return _rng.randi_range(from, to)


func next_float() -> float:
	return _rng.randf()


func chance(probability: float) -> bool:
	return _rng.randf() < probability


func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[_rng.randi_range(0, items.size() - 1)]


func shuffle(items: Array) -> Array:
	var out := items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out
