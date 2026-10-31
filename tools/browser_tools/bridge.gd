extends Node
## Browser tools use the same codecs, validation and transactions as the game.
var request: Dictionary
var _mailbox := ""
var _working := false
func _ready()->void:
	var args:=OS.get_cmdline_user_args()
	var index:=args.find("--browser-daemon")
	if index>=0 and index+1<args.size():
		_mailbox=str(args[index+1]);return
	call_deferred("_run")
func _process(_dt:float)->void:
	if _mailbox.is_empty() or _working or not FileAccess.file_exists(_mailbox):return
	_working=true
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(_mailbox))
	DirAccess.remove_absolute(_mailbox)
	var result:Dictionary={"error":"请求格式错误"}
	if parsed is Dictionary:
		request=parsed;result=await _dispatch()
	var output:=FileAccess.open(_mailbox+".result.tmp",FileAccess.WRITE)
	if output!=null:
		output.store_string(JSON.stringify(result));output.close()
		DirAccess.rename_absolute(_mailbox+".result.tmp",_mailbox+".result")
	_working=false
func _run()->void:
	var args:=OS.get_cmdline_user_args();var index:=args.find("--browser-request")
	if index<0 or index+1>=args.size():get_tree().quit(1);return
	var path:=str(args[index+1]);var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	var result:Dictionary={"error":"请求格式错误"}
	if parsed is Dictionary:
		request=parsed;result=await _dispatch()
	var file:=FileAccess.open(path+".result",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(result));file.close()
	get_tree().quit()
func _dispatch()->Dictionary:
	match str(request.get("action","")):
		"export_codex":
			var entries:Array=[]
			for item:Dictionary in ItemDB.all():
				var kind:=str(item.get("kind",""))
				if kind not in ["weapon","armor","accessory","buff"]:continue
				var entry:Dictionary=item.duplicate(true)
				entry["kind"]=kind
				entry["category"]="relic" if kind=="buff" else "equipment"
				entry["description"]=str(item.get("desc",""))
				var texture:=ItemDB.icon_texture(item)
				if texture==null:return {"error":"物品图标缺失："+str(item.get("id",""))}
				var image:=texture.get_image()
				var region:=ItemDB.icon_region(item)
				if region.size.x>0 and region.size.y>0:image=image.get_region(Rect2i(region))
				if image.get_width()>256 or image.get_height()>256:
					var ratio:=256.0/maxf(image.get_width(),image.get_height())
					image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
				entry["image"]="data:image/png;base64,"+Marshalls.raw_to_base64(image.save_png_to_buffer())
				entries.append(entry)
			return {"format":"pixelrogue-codex","schemaVersion":1,"exportedAt":Time.get_datetime_string_from_system(),"items":entries}
		"story_catalog":return {"ids":_story_ids(),"metadata":preload("res://tools/browser_tools/story_catalog.gd").metadata()}
		"story_bundle":
			var revision:=_stamp("res://data/story_overrides.json")
			var variants:Dictionary={}
			var heroes:Array=[str(request.hero)] if request.has("hero") else ["sylphiette","xixifu","ilyua"]
			var replays:Array=[bool(request.replay)] if request.has("replay") else [false,true]
			for hero:String in heroes:
				for replay:bool in replays:
					var scenes:Dictionary={}
					for id:String in _story_ids():
						var scene:=Story.get_scene(StringName(id),replay,StringName(hero))
						if not scene.is_empty():scenes[id]=scene
					variants[hero+("|repeat" if replay else "|first")]=scenes
			if revision!=_stamp("res://data/story_overrides.json"):return {"error":"导出期间剧情发生变化，请重试。"}
			return {"revision":revision,"format":"pixelrogue.story-export","version":2,"variants":variants,"metadata":preload("res://tools/browser_tools/story_catalog.gd").metadata(),"scope":"主线两章、命运观察、营地固定关系事件、居民生活委托三阶段对白"}
		"story_scene":
			return {"scene":Story.get_scene(StringName(request.id),bool(request.get("replay",false)),StringName(request.hero))}
		"catalog":
			UnitBalance.reload();UiArtLayout.reload()
			var pool:=RoomTemplatePool.new();pool.reload()
			var templates:Array=[]
			for doc:Dictionary in pool.templates:
				var chapter:=str(ChapterCatalog.map_chapter(str(doc.id)))
				if doc.room_kinds.has("boss"):
					for tag in doc.tags:
						if str(tag).begins_with("boss:"):chapter=str(ChapterCatalog.NEXT if str(tag).trim_prefix("boss:") in ChapterCatalog.bosses(ChapterCatalog.NEXT) else ChapterCatalog.FIRST)
				templates.append({"id":doc.id,"name":doc.name,"kinds":doc.room_kinds,"chapter":chapter})
			var items:Array=[]
			for item:Dictionary in ItemDB.all():items.append(_item(item))
			for id in ExpeditionData.MATERIALS:items.append(_item(ExpeditionData.resolve(str(id))))
			for id in MaterialWorkshopCatalog.BOSS_MATERIALS:items.append(_item(ExpeditionData.resolve(str(id))))
			for mushroom in 4:items.append(_item(ItemDB.mushroom_item(mushroom)))
			return {"legendary_sets":LegendarySets.DATA,"templates":templates,"units":UnitBalance.catalog(),"balance":UnitBalance.snapshot(),"balance_revision":_stamp(UnitBalance.PATH),"items":items,"user_templates":ProjectSettings.globalize_path(RoomTemplatePool.USER),"save_path":ProjectSettings.globalize_path(SaveService.SAVE_PATH),"lights":RoomEnvironmentConfig.LIGHT_NAMES}
		"map":
			var doc:Dictionary=request.get("document",{})
			if doc.is_empty():
				var pool:=RoomTemplatePool.new();pool.reload()
				for candidate:Dictionary in pool.templates:
					if str(candidate.id)==str(request.get("id","")):doc=candidate;break
			if doc.is_empty():return {"error":"模板不存在"}
			return _map(doc)
		"validate":return {"errors":RoomTemplateValidator.validate(request.document),"load_errors":RoomTemplateValidator.load_errors(request.document)}
		"save_map":
			var doc:Dictionary=request.document
			var errors:=RoomTemplateValidator.load_errors(doc)
			if not errors.is_empty():return {"error":"模板结构无法读取："+"；".join(errors)}
			var id:=str(doc.id)
			if id.validate_filename()!=id or id.contains("/") or id.contains("\\"):return {"error":"模板ID无效"}
			var path:=RoomTemplatePool.USER+"/"+id+".json"
			var builtin:=RoomTemplatePool.BUILTIN+"/"+id+".json"
			# Protect a template edited in another browser or the native editor.
			var current:=RoomTemplateCodec.read_file(path)
			if current.is_empty():current=RoomTemplateCodec.read_file(builtin)
			if not current.is_empty() and int(current.revision)!=int(request.get("revision",doc.revision)):return {"error":"模板已被其他窗口修改，请重新载入后合并修改。"}
			doc=doc.duplicate(true);doc.revision=maxi(int(doc.revision),int(current.get("revision",0)))+1
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RoomTemplatePool.USER))
			var error:=RoomTemplateCodec.write_file(path,doc)
			if error!=OK:return {"error":error_string(error)}
			# Keep authoring data in the project too, so future exports use this edit.
			error=RoomTemplateCodec.write_file(builtin,doc)
			return {"document":doc,"errors":RoomTemplateValidator.validate(doc),"message":"已存入模板池，并同步工程模板。" if error==OK else "模板池已保存，但同步工程失败："+error_string(error)}
		"playtest":
			var code:=RoomEditorPlaytest.launch(request.document,bool(request.get("enemies",false)))
			return {"error":error_string(code)} if code!=OK else {"message":"已开启独立、无敌的游戏验证窗口。"}
		"art":
			for script in ["res://src/ui/inventory_ui.gd","res://src/ui/shop_ui.gd","res://src/ui/tavern_ui.gd"]:
				var ui:Node=load(script).new();add_child(ui)
				await get_tree().process_frame
				ui.queue_free()
			await get_tree().process_frame
			return {"documents":LayerArtCatalog.documents(),"layout":UiArtLayout.snapshot(),"layout_revision":_stamp(UiArtLayout.PATH)}
		"save_layout":
			if str(request.get("revision",_stamp(UiArtLayout.PATH)))!=_stamp(UiArtLayout.PATH):return {"error":"界面布局已被其他窗口修改，请重新载入后再编辑。"}
			if not request.get("layout") is Dictionary:return {"error":"布局须为对象"}
			for id in request.layout:
				var entry:Variant=request.layout[id]
				if not entry is Dictionary:return {"error":"控件布局无效"}
				if entry.has("position"):
					if not entry.position is Array or entry.position.size()!=2:return {"error":"控件位置须为两个数值"}
					for number in entry.position:
						if not (number is int or number is float) or not is_finite(float(number)):return {"error":"控件位置无效"}
			var error:=UiArtLayout.save(request.layout)
			return {"error":error_string(error)} if error!=OK else {"message":"界面布局已保存。重新打开游戏对应页面生效。","revision":_stamp(UiArtLayout.PATH)}
		"save_units":
			if str(request.get("revision",_stamp(UnitBalance.PATH)))!=_stamp(UnitBalance.PATH):return {"error":"单位数值已被其他窗口修改，请重新载入。"}
			var error:=UnitBalance.save(request.units)
			return {"error":error_string(error)} if error!=OK else {"message":"基础数值已保存，新启动游戏生效。","revision":_stamp(UnitBalance.PATH)}
		"load_save", "grant":
			var console:=DeveloperSaveTool.new()
			var error:=console.open_file(str(request.get("path","")))
			if not error.is_empty():return {"error":error}
			if str(request.action)=="grant":
				if console.fingerprint!=str(request.get("fingerprint","")):return {"error":"存档已变化，请先重新载入。"}
				error=console.grant(str(request.kind),str(request.get("id","")),int(request.amount))
				if not error.is_empty():return {"error":error}
			return {"fingerprint":console.fingerprint,"gold":int(console.data.outpost.get("gold",0)),"active":not console.data.get("run",{}).is_empty(),"backup":console.last_backup}
	return {"error":"未知工具操作"}
func _story_ids()->Array:
	return preload("res://tools/browser_tools/story_catalog.gd").ids()
func _item(item:Dictionary)->Dictionary:
	return {"id":str(item.get("id","")),"name":str(item.get("name","")),"rarity":int(item.get("rarity",0)),"icon":str(item.get("icon",""))}
func _stamp(path:String)->String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
func _map(doc:Dictionary)->Dictionary:
	var shapes:Array=[]
	for target:Dictionary in RoomEditorCollision.targets(doc):
		var origin:=RoomEditorCollision.origin(doc,str(target.key))
		shapes.append({"key":target.key,"label":target.label,"origin":[origin.x,origin.y],"polygon":RoomEditorCollision.shape(doc,str(target.key))})
	var rect:=RoomEditorCollision.bounds(doc)
	var placed:Array=[]
	for layer in ["decor","obstacles","entities"]:
		for entry:Dictionary in doc.layers[layer]:
			var asset:=RoomEditorCatalog.get_entry(str(entry.asset_id))
			var texture:=RoomEditorCatalog.texture(str(entry.asset_id))
			if texture==null:continue
			var art_rect:Rect2
			if RoomEditorCatalog.is_service(str(entry.asset_id)):art_rect=RoomEditorCatalog.service_art_rect(entry,texture.get_size())
			else:
				var footprint:=Vector2(float(asset.get("size",[1,1])[0]),float(asset.get("size",[1,1])[1]))*36
				var dimensions:=Vector2(texture.get_size())*(footprint.x/maxf(1,texture.get_width()))
				art_rect=Rect2(Vector2(float(entry.at[0]),float(entry.at[1]))*36+Vector2(0,footprint.y-dimensions.y),dimensions)
			var path:=str(asset.get("path",""));var crop:Array=[]
			if texture is AtlasTexture:
				path=texture.atlas.resource_path;var region:Rect2=texture.region;crop=[region.position.x,region.position.y,region.size.x,region.size.y]
			placed.append({"id":entry.id,"layer":layer,"asset_id":entry.asset_id,"at":entry.at,"path":path,"crop":crop,"rect":[art_rect.position.x,art_rect.position.y,art_rect.size.x,art_rect.size.y]})
	return {"document":doc,"scene":RoomEditorCollision.definition(doc),"shapes":shapes,"placed":placed,"bounds":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]}
