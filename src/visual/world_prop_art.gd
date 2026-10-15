class_name WorldPropArt
extends RefCounted
## Explicit cells and clipped atlas regions prevent neighboring sprites leaking.
const DIRECTORY := "res://assets/world_props_vnext/"
const FRAME_SIZE := 64
const CHEST_FRAMES := 5
const MUSHROOM_FRAMES := 4
const MUSHROOM_KINDS := 8
static var _frames: Dictionary = {}

static func chest_texture(frame: int) -> Texture2D:
	return _frame("chest_opening.png", Vector2i(clampi(frame, 0, CHEST_FRAMES - 1), 0), Vector2i(CHEST_FRAMES, 1))

static func mushroom_texture(kind: int, frame := MUSHROOM_FRAMES - 1) -> Texture2D:
	return _frame("mushroom_growth.png", Vector2i(clampi(frame, 0, MUSHROOM_FRAMES - 1), clampi(kind, 0, MUSHROOM_KINDS - 1)), Vector2i(MUSHROOM_FRAMES, MUSHROOM_KINDS))

static func _frame(filename: String, cell: Vector2i, grid: Vector2i) -> Texture2D:
	var key := filename + ":" + str(cell)
	if _frames.has(key): return _frames[key]
	var sheet := load(DIRECTORY + filename) as Texture2D
	if sheet == null or sheet.get_size() != Vector2(grid * FRAME_SIZE):
		push_error("Invalid world prop atlas dimensions: " + filename)
		return null
	var region := AtlasTexture.new()
	region.atlas = sheet
	region.region = Rect2(Vector2(cell * FRAME_SIZE), Vector2.ONE * FRAME_SIZE)
	region.filter_clip = true
	_frames[key] = region
	return region
