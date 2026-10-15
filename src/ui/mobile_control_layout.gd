class_name MobileControlLayout
extends RefCounted
const STICK_RADIUS:=104.0
static func defaults(area:Rect2)->Dictionary:
	var rects:Dictionary={};var edge:=area.end
	rects.move=Rect2(Vector2(area.position.x+118,edge.y-126)-Vector2.ONE*STICK_RADIUS,Vector2.ONE*STICK_RADIUS*2)
	rects.aim=Rect2(Vector2(edge.x-118,edge.y-126)-Vector2.ONE*STICK_RADIUS,Vector2.ONE*STICK_RADIUS*2)
	for index in 4:rects[["pause_menu","room_map","talents","inventory"][index]]=Rect2(Vector2(edge.x-82-index*92,area.position.y+126),Vector2(82,60))
	rects.call_goddess=Rect2(Vector2(area.position.x+18,area.position.y+160),Vector2(94,64))
	for pair in [["dash",290,126],["interact",290,228]]:rects[str(pair[0])]=Rect2(Vector2(edge.x-float(pair[1])-44,edge.y-float(pair[2])-44),Vector2(88,88))
	for index in 4:rects[["skill_1","skill_2","skill_3","ultimate"][index]]=Rect2(Vector2(area.get_center().x-194+index*100,edge.y-172),Vector2(88,88))
	for index in 3:rects["potion_%d"%(index+1)]=Rect2(Vector2(area.get_center().x-138+index*96,edge.y-72),Vector2(84,64))
	return rects
static func decode(saved:Dictionary,area:Rect2)->Dictionary:
	var rects:=defaults(area)
	for key in saved:
		var data:Variant=saved[key]
		if not rects.has(key) or not data is Array or data.size()!=4:continue
		var box:=Rect2(area.position+Vector2(float(data[0]),float(data[1]))*area.size,Vector2(float(data[2]),float(data[3]))*area.size)
		if not is_finite(box.position.x+box.position.y+box.size.x+box.size.y):continue
		rects[key]=box
	return rects if error(rects,area).is_empty() else defaults(area)
static func encode(rects:Dictionary,area:Rect2)->Dictionary:
	var saved:Dictionary={}
	for key in rects:
		var box:Rect2=rects[key];var position:Vector2=(box.position-area.position)/area.size;var size:Vector2=box.size/area.size
		saved[key]=[position.x,position.y,size.x,size.y]
	return saved
static func error(rects:Dictionary,area:Rect2)->String:
	var keys:=rects.keys()
	for index in keys.size():
		var box:Rect2=rects[keys[index]]
		if box.size.x<48 or box.size.y<48:return "轮盘和按钮不能小于48像素。"
		if not area.encloses(box):return "控件不能移出屏幕安全范围。"
		for other in range(index+1,keys.size()):
			if box.grow(2).intersects(rects[keys[other]]):return "控件不能互相重叠，请留出间隔。"
	return ""
