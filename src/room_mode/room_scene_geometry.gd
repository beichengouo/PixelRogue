class_name RoomSceneGeometry
extends RefCounted
## World-space footprints. The art rectangle is never a collision rectangle.
static func polygon(points:Array,origin:=Vector2.ZERO)->PackedVector2Array:
	var result:=PackedVector2Array()
	for point in points:
		if point is Array and point.size()==2:result.append(origin+Vector2(float(point[0]),float(point[1])))
	return result
static func centroid(shape:PackedVector2Array)->Vector2:
	if shape.is_empty():return Vector2.ZERO
	# Work relative to the first vertex to keep area calculations stable when
	# editable footprints are far from the room origin.
	var origin:=shape[0];var weighted:=Vector2.ZERO;var area:=0.0
	for index in shape.size():
		var a:=shape[index]-origin;var b:=shape[(index+1)%shape.size()]-origin;var cross:=a.cross(b)
		area+=cross;weighted+=(a+b)*cross
	if absf(area)>.0001:return origin+weighted/(3.0*area)
	var average:=Vector2.ZERO
	for point in shape:average+=point
	return average/shape.size()
static func closest_boundary_point(at:Vector2,shape:PackedVector2Array)->Vector2:
	if shape.is_empty():return at
	var result:=shape[0];var best:=INF
	for index in shape.size():
		var point:=Geometry2D.get_closest_point_to_segment(at,shape[index],shape[(index+1)%shape.size()])
		var distance:=at.distance_squared_to(point)
		if distance<best:best=distance;result=point
	return result
static func circle_overlaps(center:Vector2,radius:float,shape:PackedVector2Array)->bool:
	if shape.size()<3:return false
	if Geometry2D.is_point_in_polygon(center,shape):return true
	for index in shape.size():
		var a:=shape[index];var b:=shape[(index+1)%shape.size()]
		if maxf(a.x,b.x)<center.x-radius or minf(a.x,b.x)>center.x+radius or maxf(a.y,b.y)<center.y-radius or minf(a.y,b.y)>center.y+radius:continue
		var near:=Geometry2D.get_closest_point_to_segment(center,a,b)
		if near.distance_squared_to(center)<=radius*radius:return true
	return false
static func segment_intersects(from:Vector2,to:Vector2,shape:PackedVector2Array)->bool:
	if shape.size()<3:return false
	if Geometry2D.is_point_in_polygon(from,shape) or Geometry2D.is_point_in_polygon(to,shape):return true
	for index in shape.size():
		if Geometry2D.segment_intersects_segment(from,to,shape[index],shape[(index+1)%shape.size()])!=null:return true
	return false
static func swept_circle_overlaps(from:Vector2,to:Vector2,radius:float,shape:PackedVector2Array)->bool:
	if shape.size()<3:return false
	if Geometry2D.is_point_in_polygon(from,shape) or Geometry2D.is_point_in_polygon(to,shape):return true
	var radius_squared:=radius*radius
	var low:=from.min(to)-Vector2.ONE*radius
	var high:=from.max(to)+Vector2.ONE*radius
	for index in shape.size():
		var a:=shape[index];var b:=shape[(index+1)%shape.size()]
		if maxf(a.x,b.x)<low.x or minf(a.x,b.x)>high.x or maxf(a.y,b.y)<low.y or minf(a.y,b.y)>high.y:continue
		if Geometry2D.segment_intersects_segment(from,to,a,b)!=null:return true
		for point in [a,b]:
			if Geometry2D.get_closest_point_to_segment(point,from,to).distance_squared_to(point)<=radius_squared:return true
		for point in [from,to]:
			if Geometry2D.get_closest_point_to_segment(point,a,b).distance_squared_to(point)<=radius_squared:return true
	return false
