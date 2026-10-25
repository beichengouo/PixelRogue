extends Node
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _ready()->void:call_deferred("run")
func frames(n:=2)->void:
 for index in n:await get_tree().process_frame
func run()->void:
 if not OS.get_user_data_dir().begins_with("E:/CodexWorkspace/PixelRogue/"):push_error("Isolated saves required");get_tree().quit(1);return
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LightModelArt.ROOT+"models.json"))
 check(manifest.size()==117,"105 existing and 12 new independent model sources prepared")
 for path:String in manifest:
  var source:=load(path) as Texture2D;var cells:=LightModelArt.frames(source)
  check(cells.size()==4,"four complete model cells "+path)
  var first:=cells[0] as AtlasTexture;var sizes:Vector2=first.get_size();var hashes:Array=[]
  for raw:Texture2D in cells:
   var frame:=raw as AtlasTexture
   check(frame.filter_clip and Rect2(Vector2.ZERO,frame.atlas.get_size()).encloses(frame.region) and frame.get_size()==sizes,"clipped equal frame canvas")
   hashes.append(hash(frame.atlas.get_image().get_region(Rect2i(frame.region)).get_data()))
  check(hashes[0]!=hashes[1] or hashes[1]!=hashes[2],"actual painted light changes across cells "+path)
 check(LightModelArt._cache.size()<=12,"bounded model texture cache")
 for kind:String in RoomEnvironmentConfig.LIGHT_KINDS:
  for footprint:Vector2i in RoomEnvironmentConfig.LIGHT_SIZES:
   var light:=RoomLightProp.new();light.kind=kind;light.footprint=footprint;add_child(light)
   var model:=light.art;var rect_before:Rect2=model.transform*model.get_rect();var offset:=light.light_offset
   var controller:=model.get_node("ModelFramePlayback") as LightModelMotion
   controller.set_process(false);controller._process(.3)
   check(model.texture is AtlasTexture and not light.has_node("AnimatedLightSprite"),"model texture itself animates; no auxiliary effect")
   check((model.transform*model.get_rect()).is_equal_approx(rect_before) and light.light_offset==offset,"frame animation preserves full model world bounds and emitter "+kind)
   var age:=controller._age;SaveService.data.reduced_motion=true;controller._process(.3)
   check(controller._age==age and model.texture==controller._cells[0],"reduced motion uses static complete model")
   SaveService.data.reduced_motion=false;light.queue_free()
 await frames();AudioManager.shutdown();await frames()
 print("LIGHT_MODELS_V16 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
