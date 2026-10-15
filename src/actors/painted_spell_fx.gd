class_name PaintedSpellFX
extends RefCounted
## 保留旧调用入口；表现统一转交原创像素特效，不再加载旧绘画图集。

static func spawn(parent: Node, where: Vector2, path: String, width := 96.0, duration := 0.48, angle := 0.0) -> PixelSpellFX:
	var family := "nature" if "nature" in path else ("star" if "star" in path else "fire")
	return PixelSpellFX.spawn(parent, where, family, "impact", width, duration, angle, width >= 200)
