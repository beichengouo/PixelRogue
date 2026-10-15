class_name WorldMapV2
extends RefCounted
## Compatibility region query for reusable environment decorations and native map palettes.
## Room layouts and collision are provided by RoomLayout/RoomLevel; no legacy map generator.
const VERSION := 2
const ZONES := [0,21,42,63,84]
static var _tileset: TileSet
static func zone_at(x: float) -> int:
	var cell := floori(x / 36.0)
	for i in 4:
		if cell < int(ZONES[i+1]): return i
	return 3