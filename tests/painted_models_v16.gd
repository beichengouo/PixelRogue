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
 if not OS.get_user_data_dir().begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(1);return
 var definitions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/light_models_v16/painted_anchors.json"))
 for scene:String in definitions:
  var artwork:=RoomSceneArtwork.new();artwork.data=RoomSceneArtCatalog.definition(scene);add_child(artwork);artwork.set_process(false)
  for plane:Dictionary in artwork.data.planes:
   var sprite:=Sprite2D.new();artwork.add_child(sprite);artwork._configure_painted_light(sprite,plane,scene)
   var expected:Array=definitions[scene].get("plane_centers",{}).get(str(plane.path),[])
   if expected.is_empty():check(sprite.material==null,"unverified/transparent plane not modified")
   else:
    check(sprite.material is ShaderMaterial and int(sprite.material.get_shader_parameter("model_light_count"))==expected.size(),"only real luminous pixels bind to their actual plane")
    var material:=sprite.material as ShaderMaterial;WeatherSurfaceArt.apply(sprite,.4,.7,true)
    check(sprite.material==material and is_equal_approx(material.get_shader_parameter("wet_amount"),.7),"weather preserved alongside model animation")
   sprite.queue_free()
  if not artwork._painted_light_materials.is_empty():
   SaveService.data.reduced_motion=false;artwork._process(.6)
   check(artwork._painted_light_frame==1,"four-step model timing")
   SaveService.data.reduced_motion=true;var age:=artwork._painted_light_age;artwork._process(.7)
   check(artwork._painted_light_age==age and artwork._painted_light_frame==0,"reduced motion restores original still model")
   SaveService.data.reduced_motion=false
  artwork.queue_free();await frames()
 if DisplayServer.get_name()!="headless":await render_check(definitions)
 AudioManager.shutdown();await frames();print("PAINTED_MODELS_V16 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
func render_check(definitions:Dictionary)->void:
 var id:="city_boss_sephra_v01";var profile:Dictionary=definitions[id]
 var artwork:=RoomSceneArtwork.new();artwork.data=RoomSceneArtCatalog.definition(id);add_child(artwork);artwork.set_process(false)
 var plane:Dictionary={}
 for item:Dictionary in artwork.data.planes:
  if profile.plane_centers.has(str(item.path)):plane=item;break
 var source:=load(RoomSceneArtCatalog.ROOT+id+"/"+str(plane.path)) as Texture2D
 var viewport:=SubViewport.new();viewport.size=Vector2i(source.get_size());viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
 var sprite:=Sprite2D.new();sprite.centered=false;sprite.texture=source;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;viewport.add_child(sprite);artwork._configure_painted_light(sprite,plane,id)
 sprite.material.set_shader_parameter("model_light_frame",0.0);await frames();await RenderingServer.frame_post_draw;var before:=viewport.get_texture().get_image()
 sprite.material.set_shader_parameter("model_light_frame",1.0);await frames();await RenderingServer.frame_post_draw;var after:=viewport.get_texture().get_image()
 var changed:=0;var wrong:=0;var box:Array=plane.rect_px
 for center:Array in profile.plane_centers[str(plane.path)]:
  var x:=roundi((float(center[0])-float(box[0]))*before.get_width()/float(box[2]));var y:=roundi((float(center[1])-float(box[1]))*before.get_height()/float(box[3]))
  for py in range(maxi(0,y-10),mini(before.get_height(),y+11)):
   for px in range(maxi(0,x-10),mini(before.get_width(),x+11)):
    if before.get_pixel(px,py)!=after.get_pixel(px,py):changed+=1
 for y in range(0,before.get_height(),23):
  for x in range(0,before.get_width(),23):
   if before.get_pixel(x,y)==after.get_pixel(x,y):continue
   var at:=Vector2(float(box[0])+float(x)*float(box[2])/before.get_width(),float(box[1])+float(y)*float(box[3])/before.get_height());var valid:=false
   for center:Array in profile.plane_centers[str(plane.path)]:
    if ((at-Vector2(center[0],center[1]))/Vector2(center[2],center[3])).length()<=1.05:valid=true
   if not valid:wrong+=1
 check(changed>0,"actual wall-model lamp cores animate under GPU shader")
 check(wrong==0,"map pixels outside authored model cores remain byte-identical")
 viewport.queue_free();artwork.queue_free();await frames()
