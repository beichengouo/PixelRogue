class_name CampPatrolRoutes
extends RefCounted
## Authored stone-road centerlines; coordinates follow the camp painting, not
## editable collision bounds. Only clear road edges enter the patrol graph.
const REFERENCE_SIZE:=Vector2(3840,2560)
const STEP:=12.0
const RADIUS:=9.0
const LANES:=[
 [[500,1280],[700,1280],[1000,1280],[1660,1280],[1920,1280],[2180,1280],[2780,1280],[3400,1280]],
 [[1920,500],[1920,1040],[1920,1280],[1920,1500],[1920,1940]],
 [[1920,1040],[2180,1280],[1920,1500],[1660,1280],[1920,1040]],
 [[700,1280],[1010,980],[1010,820],[1450,845],[1920,1040]],
 [[2780,860],[2780,1280],[2780,1550]],
 [[1010,820],[1010,640]],
 [[1000,1940],[1500,1960],[1920,1940],[2160,1900]]]
var graph:=AStar2D.new()
var segments:Array[PackedVector2Array]=[]
var components:Dictionary={}
func build(room:RoomLevel)->void:
 graph.clear();segments.clear();components.clear()
 if not room.illustration.active():return
 var frame:=room.illustration.frame_rect()
 for lane:Array in LANES:
  for i in range(1,lane.size()):
   var from:=frame.position+Vector2(lane[i-1][0],lane[i-1][1])/REFERENCE_SIZE*frame.size
   var to:=frame.position+Vector2(lane[i][0],lane[i][1])/REFERENCE_SIZE*frame.size
   segments.append(PackedVector2Array([from,to]))
   var count:=maxi(1,ceili(from.distance_to(to)/STEP));var previous:=-1
   for j in count+1:
    var point:=from.lerp(to,float(j)/count)
    if not _legal(room,point):previous=-1;continue
    var node:=_insert(point)
    if previous>=0 and previous!=node and room.segment_clear(graph.get_point_position(previous),point,RADIUS):graph.connect_points(previous,node)
    previous=node
 # At intersections two sampled centerlines can differ by a few pixels.
 var ids:=graph.get_point_ids()
 for i in ids.size():
  for j in range(i+1,ids.size()):
   var left:int=ids[i];var right:int=ids[j]
   var a:=graph.get_point_position(left);var b:=graph.get_point_position(right)
   if a.distance_squared_to(b)<=STEP*STEP and on_road(a.lerp(b,.5),2.0) and room.segment_clear(a,b,RADIUS):graph.connect_points(left,right)
 for node in ids:
  if components.has(node):continue
  var reached:Array[int]=[node];var cursor:=0
  while cursor<reached.size():
   var current:=reached[cursor];cursor+=1
   for next in graph.get_point_connections(current):
    if not reached.has(next):reached.append(next)
  for current in reached:components[current]=reached.size()
func _legal(room:RoomLevel,point:Vector2)->bool:
 if not room.bounds().has_point(point) or not room.body_clear(point,RADIUS):return false
 for direction:Vector2i in RoomGraph.DIRECTIONS:
  if point.distance_to(room.door_point(direction))<110:return false
 return true
func _insert(point:Vector2)->int:
 var near:=graph.get_closest_point(point)
 if near>=0 and graph.get_point_position(near).distance_squared_to(point)<4:return near
 var id:=graph.get_available_point_id();graph.add_point(id,point);return id
func on_road(point:Vector2,tolerance:float=3.0)->bool:
 for segment in segments:
  if Geometry2D.get_closest_point_to_segment(point,segment[0],segment[1]).distance_to(point)<=tolerance:return true
 return false
func route_for(home:Vector2)->PackedVector2Array:
 var start:=-1;var nearest:=INF
 for id in graph.get_point_ids():
  if int(components.get(id,0))<5:continue
  var gap:=graph.get_point_position(id).distance_squared_to(home)
  if gap<nearest:start=id;nearest=gap
 if start<0:return PackedVector2Array()
 var route:=PackedVector2Array([graph.get_point_position(start)]);var best:=0.0
 for id in graph.get_point_ids():
  var distance:=graph.get_point_position(start).distance_to(graph.get_point_position(id))
  if distance>260 or distance<=best:continue
  var path:=graph.get_point_path(start,id)
  if path.size()<2:continue
  var length:=0.0
  for i in range(1,path.size()):length+=path[i-1].distance_to(path[i])
  if length>340:continue
  best=distance;route=path
 return route
