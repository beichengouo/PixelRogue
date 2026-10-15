class_name Shapes
extends RefCounted
## 用代码画图形的小工具。
##
## 原型阶段不依赖任何图片素材，纯色块也能看出玩法。
## 以后换成真正的像素美术时，把 build_* 里的 Polygon2D 换成 Sprite2D 即可。

static func rect(size: Vector2, color: Color, offset := Vector2.ZERO) -> Polygon2D:
	var half := size * 0.5
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		offset + Vector2(-half.x, -half.y),
		offset + Vector2(half.x, -half.y),
		offset + Vector2(half.x, half.y),
		offset + Vector2(-half.x, half.y),
	])
	poly.color = color
	return poly


static func circle(radius: float, color: Color, offset := Vector2.ZERO, segments := 16) -> Polygon2D:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(offset + Vector2(cos(angle), sin(angle)) * radius)
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	return poly


static func triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([a, b, c])
	poly.color = color
	return poly


static func node_with(parts: Array) -> Node2D:
	## 把一堆图形打包成一个 Node2D，方便整体翻转 / 缩放
	var root := Node2D.new()
	for part in parts:
		if part is Node:
			root.add_child(part)
	return root

