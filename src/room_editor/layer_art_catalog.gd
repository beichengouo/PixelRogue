class_name LayerArtCatalog
extends RefCounted
static func _pngs(root:String)->Array[String]:
	var result:Array[String]=[];var dir:=DirAccess.open(root)
	if dir==null:return result
	for file in dir.get_files():
		if file.to_lower().ends_with(".png"):result.append(root+"/"+file)
	for folder in dir.get_directories():result.append_array(_pngs(root+"/"+folder))
	return result
static func documents()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for id:String in RoomSceneArtCatalog.IDS:
		var data:=RoomSceneArtCatalog.definition(id)
		if data.is_empty():continue
		var root:=RoomSceneArtCatalog.ROOT+id;var layers:Array=[];var used:Dictionary={}
		var canvas:Array=data.get("canvas",[1536,1024])
		for plane in data.get("planes",[]):
			var path:=root+"/"+str(plane.get("path",""));var label:=str(plane.get("layer","background" if layers.is_empty() else path.get_file()));used[path]=true;layers.append({"name":label,"path":path,"rect":[0,0,canvas[0],canvas[1]],"locked":label=="background","visible":true})
		for direction in data.get("gates",{}):
			var gate:Dictionary=data.gates[direction];var path:=root+"/"+str(gate.path);used[path]=true;layers.append({"name":"门 · "+direction,"path":path,"rect":gate.get("rect_px",[0,0,100,100]),"locked":false,"visible":true})
		for object in data.get("objects",[]):
			var path:=root+"/"+str(object.get("texture",""))
			if not path.ends_with(".png"):continue
			used[path]=true;layers.append({"name":str(object.get("id","物件")),"path":path,"rect":object.get("source_rect_px",[0,0,100,100]),"locked":false,"visible":true})
		for path in _pngs(root):
			if used.has(path):continue
			var image_size:=_size(path)
			if image_size.x>0:layers.append({"name":path.get_file(),"path":path,"rect":[0,0,image_size.x,image_size.y],"locked":path.get_file().contains("background"),"visible":false})
		result.append({"id":id,"name":"地图 · "+id,"canvas":canvas,"layers":layers,"controls":[]})
	for kind in ["inventory","shop","tavern"]:
		var layers:Array=[];var root:String=InteractionSkin.ROOT+kind
		for path in _pngs(root):
			var extent:=_size(path)
			if extent.x<=0:continue
			var filename:=path.get_file();var rect:Array=[0,0,extent.x,extent.y];var visible:=false
			if kind=="inventory":
				if filename=="layout_frame.png":rect=[0,0,1536,1024];visible=true
				elif filename=="left_frame.png":rect=[47,235,894,636];visible=true
				elif filename=="paper.png":rect=[948,235,545,635];visible=true
			else:
				if filename=="frame.png":rect=[0,0,1280,720];visible=true
			layers.append({"name":"旧绘制图层 · "+path.trim_prefix(root+"/"),"path":path,"rect":rect,"locked":false,"visible":false})
		if kind in ["shop","tavern"]:
			var background:=ShopUI.BACKDROP if kind=="shop" else NpcArt.background("tavern").resource_path
			layers.insert(0,{"name":"保留背景","path":background,"rect":[0,0,1280,720],"locked":true,"visible":true})
			layers.insert(1,{"name":"NPC立绘","path":NpcArt.portrait_path("merchant" if kind=="shop" else "tavern"),"rect":[839,22,400,548] if kind=="shop" else [38,96,410,525],"locked":false,"visible":true})
		var controls:Array=[]
		for control:Dictionary in UiArtLayout.defaults.values():
			if control.kind==kind:controls.append(control.duplicate(true))
		result.append({"id":kind,"name":"交互界面 · "+{"inventory":"背包","shop":"姜糖商店","tavern":"温阮酒馆"}[kind],"canvas":[1536,1024] if kind=="inventory" else [1280,720],"layers":layers,"controls":controls})
	var art_root:="res://assets/ui_art";var art_dir:=DirAccess.open(art_root)
	if art_dir!=null:
		for folder in art_dir.get_directories():
			var layers:Array=[];var extent:=Vector2i(1280,720)
			for path in _pngs(art_root+"/"+folder):
				var image_size:=_size(path)
				if image_size.x<=0:continue
				var base:=path.get_file().contains("background") or path.get_file().contains("backdrop")
				if base:extent=image_size
				layers.append({"name":path.get_file(),"path":path,"rect":[0,0,image_size.x,image_size.y],"locked":base,"visible":base})
			if not layers.is_empty():result.append({"id":"ui_art_"+folder,"name":"界面图层 · "+folder,"canvas":[extent.x,extent.y],"layers":layers,"controls":[]})
	return result

static func _size(path:String)->Vector2i:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<24:return Vector2i.ZERO
	file.big_endian=true;file.seek(16);return Vector2i(file.get_32(),file.get_32())
