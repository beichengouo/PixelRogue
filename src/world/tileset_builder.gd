class_name TileSetBuilder
extends RefCounted
## 用代码构建 Kenney 素材的 TileSet（只负责画面）。
##
## 为什么碰撞不写进 TileSet：
##   悬空平台需要「单向碰撞」，而这是由格子在地图里的上下文决定的
##   （它是不是一段横向平台的其中一格），TileSet 里的瓦片表达不了这件事。
##   所以地形画面走 TileSet，碰撞仍由 Level 根据字符地图生成，两者都来自同一份地图。
##
## 瓦片编号是从 Kenney 图集里定位出来的（识图 + 逐像素比对双重确认）：
##   2  = 左右都实心、可无缝平铺的草顶  ← 用来画地面表层
##   4  = 左右都实心、可无缝平铺的泥土  ← 用来画地面填充
##   151/152 = 金币旋转两帧
## 注意：0/1/3 也是草顶，但它们带透明边缘（端块），平铺会露出缺口，所以不用。

const TILE_SIZE := 36
const TILES_PATH := "res://assets/kenney/tiles_36px.png"
const TILES_COLUMNS := 20

const COIN_FRAMES: Array[int] = [151, 152]


static func texture() -> Texture2D:
	return load(TILES_PATH)


static func region_for(index: int, size: int = TILE_SIZE, columns: int = TILES_COLUMNS) -> Rect2:
	## 给 Sprite2D 用的图集裁剪区域（金币、背景装饰都用它）
	return Rect2(
		float((index % columns) * size),
		float((index / columns) * size),
		float(size),
		float(size)
	)
