class_name DeveloperSaveTool
extends RefCounted
const BACKUPS:="E:/CodexWorkspace/PixelRogue/archive/developer-saves"
var path:=""
var fingerprint:=""
var data:Dictionary={}
var last_backup:=""
func open_file(target:String)->String:
	path="";fingerprint="";data={}
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(target)) if FileAccess.file_exists(target) else null
	if not parsed is Dictionary or not parsed.get("outpost") is Dictionary:return "请选择包含营地数据的游戏存档 JSON。"
	path=target;fingerprint=FileAccess.get_sha256(path);data=parsed.duplicate(true)
	return ""
func preview(kind:String,id:String,amount:int)->Dictionary:
	if data.is_empty():return {"error":"请先载入存档。"}
	if amount<=0 or amount>1000000:return {"error":"数量必须在1至1000000之间。"}
	var draft:=data.duplicate(true)
	if kind=="gold":draft.outpost.gold=int(draft.outpost.get("gold",0))+amount
	elif kind in ["coins","keys"]:
		if not draft.get("run") is Dictionary or draft.run.is_empty():return {"error":"该存档没有可继续的出征；随身金币和钥匙仅能发给活跃出征。"}
		draft.run[kind]=int(draft.run.get(kind,0))+amount
	elif kind in ["warehouse","bag"]:
		var item:=ExpeditionData.resolve(id)
		if item.is_empty():return {"error":"未知物品。"}
		if kind=="warehouse":
			if ItemDB.is_relic(item):return {"error":"遗物请发至活跃出征背包，营地不能携带遗物出征。"}
			if not draft.outpost.get("inventory") is Dictionary:draft.outpost.inventory={}
			draft.outpost.inventory[id]=int(draft.outpost.inventory.get(id,0))+amount
		else:
			if not draft.get("run") is Dictionary or draft.run.is_empty():return {"error":"该存档没有可继续的出征。"}
			if amount>200:return {"error":"单次发至背包最多200件。"}
			if not draft.run.get("items") is Array:draft.run.items=[]
			if not draft.run.get("expedition_items") is Array:
				draft.run.expedition_items=[]
				for old_id in draft.run.items:
					var legacy:=ExpeditionData.pack(ExpeditionData.resolve(str(old_id)));legacy.erase("bound");draft.run.expedition_items.append(legacy)
			for index in amount:
				var record:=ExpeditionData.pack(item);record.uid="debug_"+Crypto.new().generate_random_bytes(12).hex_encode();draft.run.items.append(id);draft.run.expedition_items.append(record)
	else:return {"error":"未知发放类型。"}
	return {"data":draft,"error":""}
func grant(kind:String,id:String,amount:int)->String:
	var result:=preview(kind,id,amount)
	if not str(result.get("error","")).is_empty():return result.error
	if FileAccess.get_sha256(path)!=fingerprint:return "存档已被游戏或其他程序更新，请重新载入后操作。"
	if DirAccess.make_dir_recursive_absolute(BACKUPS)!=OK:return "无法建立工程外存档备份目录。"
	last_backup=BACKUPS+"/"+str(Time.get_unix_time_from_system()).replace(".","_")+"_"+str(Time.get_ticks_usec())+".json"
	if DirAccess.copy_absolute(path,last_backup)!=OK:return "备份失败，未修改存档。"
	var temporary:=path+".developer-writing";var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:return "无法写入存档。"
	file.store_string(JSON.stringify(result.data));file.flush();var error:=file.get_error();file.close()
	if error!=OK:return "写入失败，原存档保留。"
	if FileAccess.get_sha256(path)!=fingerprint:
		DirAccess.remove_absolute(temporary);return "存档在提交前发生变化，未覆盖新数据。"
	if DirAccess.rename_absolute(temporary,path)!=OK:return "替换失败，原存档保留。"
	data=result.data;fingerprint=FileAccess.get_sha256(path);return ""
