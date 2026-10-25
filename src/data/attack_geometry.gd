class_name AttackGeometry
extends RefCounted
## One immutable attack footprint shared by damage, telegraphs and impact art.
static func contains(spec:Dictionary,point:Vector2)->bool:
	var origin:Vector2=spec.get("at",Vector2.ZERO)
	var delta:=point-origin;var radius:=float(spec.get("radius",60))
	var direction:Vector2=spec.get("dir",Vector2.RIGHT)
	match str(spec.get("shape","circle")):
		"line":
			var span:Vector2=spec.get("end",origin+direction*radius)-origin
			var along:=delta.dot(span.normalized())
			return along>=0 and along<=span.length() and absf(delta.cross(span.normalized()))<=float(spec.get("width",18))
		"fan":return delta.length()<=radius and (delta.length()<10 or absf(direction.angle_to(delta))<=float(spec.get("spread",1))*.5)
		_:return delta.length()<=radius
static func outline(spec:Dictionary)->PackedVector2Array:
	var points:=PackedVector2Array();var origin:Vector2=spec.get("at",Vector2.ZERO)
	var radius:=float(spec.get("radius",60));var direction:Vector2=spec.get("dir",Vector2.RIGHT)
	match str(spec.get("shape","circle")):
		"line":
			var span:Vector2=spec.get("end",origin+direction*radius)-origin
			var normal:=span.normalized().orthogonal()*float(spec.get("width",18))
			var steps:=maxi(2,ceili(span.length()/7.0))
			for index in steps+1:
				var along:=span*float(index)/steps;points.append(along+normal);points.append(along-normal)
			for index in 5:
				var cap:=normal*lerpf(-1,1,index/4.0);points.append(cap);points.append(span+cap)
		"fan":
			var spread:=float(spec.get("spread",1));var steps:=maxi(12,ceili(radius*spread/6))
			for index in steps+1:points.append(direction.rotated(spread*(float(index)/steps-.5))*radius)
			for side in [-.5,.5]:
				for step in range(10,int(radius),7):points.append(direction.rotated(spread*side)*step)
		"ring":
			var gap:Vector2=spec.get("gap",direction);var opening:=float(spec.get("opening",.8))
			for index in 96:
				var ray:=Vector2.from_angle(index*TAU/96)
				if bool(spec.get("opposite_gap",false)) and absf((-gap).angle_to(ray))<opening*.5:continue
				if absf(gap.angle_to(ray))>=opening*.5:points.append(ray*radius)
		_:
			for index in 80:points.append(Vector2.from_angle(index*TAU/80)*radius)
	return points
