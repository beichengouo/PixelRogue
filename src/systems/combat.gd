class_name Combat
extends RefCounted
## 伤害结算。
##
## 故意写成「不依赖任何节点」的纯函数：这样以后想加
## 「元素克制 / 护盾 / 减伤」等规则时，都在这一处加，
## 而且可以直接写单元测试，不用启动游戏。

static func roll_attack(stats: StatBlock, rng: RandomNumberGenerator) -> Dictionary:
	var damage := stats.get_value(&"attack")
	var crit := rng.randf() < stats.get_value(&"crit_chance")
	if crit:
		damage *= stats.get_value(&"crit_mult")
	return {"damage": damage, "crit": crit}


static func apply_lifesteal(stats: StatBlock) -> float:
	return clampf(stats.get_value(&"lifesteal"), 0.0, 3.0)


static func thorns_damage(stats: StatBlock) -> float:
	return stats.get_value(&"thorns")


static func coin_drop(base: int, stats: StatBlock) -> int:
	return maxi(0, int(round(float(base) * stats.get_value(&"coin_gain"))))

