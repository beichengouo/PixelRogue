class_name Level
extends Node2D
## Shared spatial interface. RoomLevel implements gameplay; level.tscn remains an editor asset palette.
const TILE:=36
@export var playable_cells:=Rect2i()
@export var map_version:=0
@export_range(0,2,.25) var ground_grass_density:=0.0
var tiles:TileMapLayer
var player_spawn:=Vector2.ZERO
var shop_spawn:=Vector2.ZERO
var tavern_spawn:=Vector2.ZERO
var solid:Dictionary={}
var _rect:=Rect2i()
var environment
func _ready()->void:
	tiles=get_node_or_null("Tiles")
	if tiles==null:return
	_rect=playable_cells if playable_cells.has_area() else tiles.get_used_rect()
	for cell in tiles.get_used_cells():
		if tiles.get_cell_source_id(cell)%4==0:solid[cell]=true
func background_index()->int:return 0
func set_background(_index:int,_fade:=.9)->void:pass
func is_solid(x:int,y:int)->bool:return is_solid_cell(Vector2i(x,y))
func is_solid_cell(cell:Vector2i)->bool:return solid.has(cell)
func is_blocking_cell(cell:Vector2i)->bool:return is_solid_cell(cell)
func is_ground_cell(cell:Vector2i)->bool:return is_solid_cell(cell)
func is_one_way_cell(_cell:Vector2i)->bool:return false
func is_one_way_at(_at:Vector2)->bool:return false
func tile_origin()->Vector2:return tiles.position if tiles!=null else Vector2.ZERO
func playable_cell_rect()->Rect2i:return _rect
func cell_center(x:int,y:int)->Vector2:return tile_origin()+(Vector2(x,y)+Vector2.ONE*.5)*TILE
func world_to_cell(at:Vector2)->Vector2i:return Vector2i((at-tile_origin())/TILE)
func bounds()->Rect2:return Rect2(tile_origin()+Vector2(_rect.position)*TILE,Vector2(_rect.size)*TILE)
func kill_floor_y()->float:return INF
func clear_sight(from:Vector2,to:Vector2)->bool:
	for i in range(1,ceili(from.distance_to(to)/8)):
		if is_solid_cell(world_to_cell(from.move_toward(to,i*8))):return false
	return true
func spawn_candidates(_need_ground:bool)->Array[Vector2]:return []
func sample_surface(_at:Vector2)->Dictionary:return {}
func trace_surface(_from:Vector2,_to:Vector2)->Dictionary:return {}
func apply_impulse(_at:Vector2,_radius:float,_impulse:Vector2)->void:pass
func start_environment(_data:Dictionary)->void:pass
func environment_snapshot()->Dictionary:return {}
func stop_environment()->void:pass
