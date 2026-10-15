extends Node2D
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _ready()->void:call_deferred("run")
func run()->void:
 var kind_set:Dictionary={}
 for id in RoomSceneArtCatalog.IDS:
  for object in RoomSceneArtCatalog.definition(id).get("objects",[]):
   if not object.get("light",{}) is Dictionary or object.get("light",{}).is_empty():continue
   var descriptor:Dictionary=object.light
   check(RoomEnvironmentConfig.LIGHTS.has(str(descriptor.kind)),id+" actual runtime light kind supported")
   kind_set[str(descriptor.kind)]=true
   var path:String=RoomSceneArtCatalog.ROOT+str(id)+"/"+str(object.texture)
   var piece:Dictionary={}
   for entry in RoomSceneArtCatalog.definition(id).get("pieces",[]):
    if str(entry.path)==path:piece=entry;break
   check(not piece.is_empty(),id+" light appears in editor palette")
   if piece.is_empty():continue
   var placed:=RoomTemplateCodec._placed_scene_object({"id":"copied_light","at":[11,6],"config":{}},piece)
   check(placed.light==descriptor,id+" palette keeps authored color/radius/light behavior")
   var changed:=RoomTemplateCodec._placed_scene_object({"id":"copied_light","at":[11,6],"config":{"radius":99}},piece)
   check(changed.light.kind==descriptor.kind and changed.light.radius==99,id+" editor override preserves authored defaults")
 check(kind_set.size()>=4,"maps use varied supported runtime light types")
 print("SCENE_LIGHT_PALETTE checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
