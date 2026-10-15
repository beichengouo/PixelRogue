class_name RoomHeroArt
extends RefCounted
const ROOT := "res://assets/heroes_v04/"
const DIRECTIONS := ["s","sw","w","nw","n","ne","e","se"]
const CELL := 96
const WORLD_HEIGHT := 32.0
const ART_HEIGHT := 64.0
static var _frames: SpriteFrames

static func direction_name(direction: Vector2) -> String:
	var angle := posmod(roundi((direction.angle()-PI/2)/(PI/4)),8)
	return DIRECTIONS[angle]

static func make_frames() -> SpriteFrames:
	_frames=RedrawnHeroArt.frames(Characters.current_id())
	return _frames

static func flip_for(action:String,direction:String)->bool:
	var row:=DIRECTIONS.find(direction)
	if row<0:return false
	return row in [5,6,7]

static func align(sprite: AnimatedSprite2D) -> void:
	RedrawnHeroArt.align(sprite,WORLD_HEIGHT,14.0)
