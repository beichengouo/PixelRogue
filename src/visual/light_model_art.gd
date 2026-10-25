class_name LightModelArt
extends RefCounted
## Every cell contains the complete source model with the same immutable canvas.
const ROOT:="res://assets/light_models_v16/"
static var _manifest:Dictionary={}
static var _cache:Dictionary={}
static var _order:Array[String]=[]
static func frames(source:Texture2D)->Array[Texture2D]:
 var result:Array[Texture2D]=[]
 if source==null or source.resource_path.is_empty():return result
 if _manifest.is_empty():
  var file:=ROOT+"models.json"
  if not FileAccess.file_exists(file):return result
  _manifest=JSON.parse_string(FileAccess.get_file_as_string(file))
 var key:=source.resource_path
 if not _manifest.has(key):return result
 if _cache.has(key):return _cache[key]
 var record:Dictionary=_manifest[key];var file:=str(record.file);var atlas:=load(file if file.begins_with("res://") else ROOT+file) as Texture2D
 var cell:=Vector2(float(record.cell[0]),float(record.cell[1]))
 for index in 4:
  var frame:=AtlasTexture.new();frame.atlas=atlas;frame.region=Rect2(Vector2(index%2,index/2)*cell,cell);frame.filter_clip=true;result.append(frame)
 _cache[key]=result;_order.append(key)
 while _order.size()>12:_cache.erase(_order.pop_front())
 return result
