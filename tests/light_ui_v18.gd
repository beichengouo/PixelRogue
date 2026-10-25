extends Node2D
class ProbeMenu:
 extends "res://src/ui/main_menu.gd"
 func _ready()->void:pass
class ProbeEditor:
 extends "res://src/room_editor/editor.gd"
 func _ready()->void:pass
var player:Node2D
var checks:=0
var failures:=0
const NEW_KINDS:=["moon_lantern","ember_brazier","star_bloom"]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _ready()->void:
 process_mode=Node.PROCESS_MODE_ALWAYS;call_deferred("run")
func frames(n:=2)->void:
 for index in n:await get_tree().process_frame
func listeners()->int:return UIFlow.navigation_mode_changed.get_connections().size()
func toggle()->void:UIFlow.set_pointer_active(not UIFlow.pointer_active)
func run()->void:
 if not OS.get_user_data_dir().begins_with("E:/CodexWorkspace/PixelRogue/"):push_error("Isolated saves required");get_tree().quit(1);return
 AchievementTracker.set_process(false);SaveService.data.control_setup_done=true
 await ui_lifecycle()
 await editor_tools()
 await decor_integration()
 await model_integrity()
 AudioManager.shutdown();await frames()
 print("LIGHT_UI_V18 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
func editor_tools()->void:
 var editor:=ProbeEditor.new();add_child(editor);editor._build_ui()
 editor.document=RoomTemplateCodec.blank();editor.document.id="light_v18_editor_fixture";editor._sync();editor._changed()
 check(editor._light_kind.item_count==8 and editor._light_size.item_count==4,"actual editor exposes all eight light models and four footprints")
 check(editor.canvas.light_asset_id=="light:moon_lantern:1x1","new light selected by default")
 editor.canvas.tool="light"
 var number:=0
 for kind:String in NEW_KINDS:
  for size:Vector2i in RoomEnvironmentConfig.LIGHT_SIZES:
   editor.canvas.light_asset_id="light:%s:%dx%d"%[kind,size.x,size.y]
   editor._gesture("light",Vector2i(1+number%6*3,2+number/6*4),Vector2i.ZERO,[]);number+=1
 check(editor.document.layers.entities.size()==12,"actual editor places twelve model variants")
 var before:=editor.document.duplicate(true)
 editor._gesture("light",Vector2i(-1,-1),Vector2i.ZERO,[])
 editor._gesture("light",Vector2i(1,2),Vector2i.ZERO,[])
 check(editor.document==before,"out-of-bounds and overlapping placements do not alter template")
 var target:Dictionary=editor.document.layers.entities[0].duplicate(true)
 editor._move_entry("entities",str(target.id),Vector2i(0,7))
 check(editor.document.layers.entities[0].at==[1,9],"light handle moves whole entity footprint")
 editor._undo_edit();check(editor.document.layers.entities[0].at==target.at,"move supports undo")
 editor._redo_edit();check(editor.document.layers.entities[0].at==[1,9],"move supports redo")
 editor._gesture("light_erase",Vector2i(1,9),Vector2i.ZERO,[])
 check(editor.document.layers.entities.size()==11,"erase removes only selected light")
 editor._undo_edit();check(editor.document.layers.entities.size()==12,"light erase supports undo")
 check(editor.canvas._handles().size()==12,"dedicated light handles available without restoring old decoration tools")
 editor._preview.show();editor._preview.set_document(editor.document);await frames(3)
 editor._preview.set_environment(2);editor._preview._update_environment(.3)
 check(editor._preview.light_field.sources(editor._preview.level,editor._preview.world_clock,0).size()==12,"night editor preview runs actual twelve animated sources")
 editor._preview.set_layer_visible("lights",false)
 check(editor._preview.level.decor_root.get_children().all(func(node:Node)->bool:return not node.visible),"light-layer toggle controls new decorations")
 var camp:=editor.document.duplicate(true);camp.room_kinds=["camp"];var errors:=RoomTemplateValidator.validate(camp)
 check(not errors.has("营地不允许随机敌人或刷怪点"),"camp permits decorative light entities")
 camp.layers.entities.append({"id":"forbidden_chest","asset_id":"chest","at":[21,10]})
 check(RoomTemplateValidator.validate(camp).has("营地不允许随机敌人或刷怪点"),"camp still rejects unrelated gameplay entities")
 editor.queue_free();await frames(3)
func ui_lifecycle()->void:
 var baseline:=listeners()
 for index in 60:
  var orphan:=Button.new();ComicMotion.bind_button(orphan);orphan.free()
  var art:=PixelUi.art_menu_button("启程","start",Vector2(260,64));art.free()
 check(listeners()==baseline,"never-mounted ordinary and artwork buttons create no global subscriptions")
 for index in 8:toggle()
 var button:=Button.new();button.size=Vector2(220,60);button.add_theme_stylebox_override("focus",StyleBoxFlat.new());ComicMotion.bind_button(button);add_child(button);await frames()
 check(listeners()==baseline+1,"mounted button owns exactly one global listener")
 UIFlow.set_pointer_active(true)
 check(button.get_theme_stylebox("focus") is StyleBoxEmpty,"pointer hides keyboard outline")
 UIFlow.set_pointer_active(false);button.grab_focus()
 var marker:=button.get_child(0) as Control
 check(button.get_theme_stylebox("focus") is StyleBoxFlat and marker.active,"keyboard focus retains original style and marker")
 remove_child(button);check(listeners()==baseline,"detached button disconnects immediately")
 add_child(button);await frames()
 check(listeners()==baseline+1,"re-entered button reconnects without duplication")
 button.queue_free();toggle();await frames()
 check(listeners()==baseline,"queued button tolerates same-frame mode change and frees listener")
 var holder:=Control.new();var watched:=Button.new();holder.add_child(watched)
 var guarded:=NavigationModeBinding.attach(holder,func()->void:watched.add_theme_stylebox_override("focus",StyleBoxEmpty.new()),[watched])
 add_child(holder);await frames()
 watched.free();toggle();guarded.refresh()
 check(listeners()==baseline+1,"independently freed captured child is never invoked")
 holder.queue_free();await frames();check(listeners()==baseline,"guarded binding releases subscription")
 for index in 6:
  var art:=PixelUi.art_menu_button("设置","settings",Vector2(220,64));add_child(art);await frames(1);toggle()
  art.queue_free();toggle();await frames(1)
 check(listeners()==baseline,"art menu rebuild cycles release every binding")
 var menu:=ProbeMenu.new();add_child(menu)
 var menu_button:=menu._star_menu_button("启程赴星",Vector2(300,76),"start")
 add_child(menu_button);await frames()
 check(menu_button.has_node("MenuLettering"),"real main-menu lettering binding exercised")
 menu.free();toggle();menu_button.queue_free();await frames()
 check(listeners()==baseline,"menu owner freed before a reparented button is guarded")
 var choices:=ItemChoiceUI.new();add_child(choices)
 var offers:Array=[ItemDB.by_id(&"staff_cloud_radiance").duplicate(true)]
 check(not offers[0].is_empty(),"real reward fixture exists")
 for index in 6:
  choices.open(offers);await frames(4);toggle();choices._rebuild();toggle();await frames()
  check(choices._cards.size()==1 and is_instance_valid(choices._cards[0]),"reward card rebuild keeps live focus "+str(index))
 choices.cancel();choices.queue_free();toggle();await frames(4)
 check(listeners()==baseline and not UIFlow.has_screen() and not get_tree().paused,"closing rewards leaves no pause lease or callback")
func decor_integration()->void:
 var template:=RoomTemplateCodec.blank();template.id="light_v18_fixture"
 var expected:=0
 for kind:String in NEW_KINDS:
  for footprint:Vector2i in RoomEnvironmentConfig.LIGHT_SIZES:
   var id:="light:%s:%dx%d"%[kind,footprint.x,footprint.y]
   var entry:=RoomEditorCatalog.get_entry(id)
   check(not entry.is_empty() and RoomEditorCatalog.available(entry) and entry.category=="光源","editor exposes "+id)
   check(entry.size==[footprint.x,footprint.y] and entry.collision=="none","editor footprint and decorative collision "+id)
   template.layers.entities.append({"id":"light_"+str(expected),"asset_id":id,"at":[1+expected%6*3,2+expected/6*4],"config":{"radius":200+expected,"range_animation":true}})
   expected+=1
 var file:="user://light-v18-template.json"
 check(RoomTemplateCodec.write_file(file,template)==OK,"new decorators save through existing codec")
 var restored:=RoomTemplateCodec.read_file(file)
 check(RoomTemplateValidator.load_errors(restored).is_empty(),"valid persisted light data: "+str(RoomTemplateValidator.load_errors(restored)))
 var layout:=RoomTemplateCodec.to_layout(restored)
 check(not layout.is_empty() and layout.entities==restored.layers.entities,"saved light kinds, footprints and config round-trip")
 for index in restored.layers.entities.size():
  var actual:Dictionary=restored.layers.entities[index];var original:Dictionary=template.layers.entities[index]
  check(actual.asset_id==original.asset_id and int(actual.at[0])==original.at[0] and int(actual.at[1])==original.at[1] and is_equal_approx(float(actual.config.radius),float(original.config.radius)) and actual.config.range_animation,"stable IDs, coordinates and values survive JSON numeric decoding")
 if layout.is_empty():return
 var level:=RoomLevel.new();add_child(level);level.set_process(false);level._load_room_entities(layout)
 check(level.decor_root.get_child_count()==12,"runtime loads all twelve catalog variants")
 var field:=RoomLightField.new();field.refresh(self,.3)
 for raw in level.decor_root.get_children():
  var lamp:=raw as RoomLightProp
  check(lamp!=null and lamp.get_child_count()==1 and lamp.art.texture!=null,"one complete model without secondary overlay")
  var motion:=lamp._model_motion;motion.set_process(false)
  var config:=lamp.light_config();var initial_position:=lamp.position;var initial_scale:=lamp.art.scale
  var low:=INF;var high:=-INF;var low_visibility:=0.0;var high_visibility:=0.0
  for index in 4:
   motion._age=float(index)/LightModelMotion.rate(lamp.kind);motion._process(0)
   var sample:=lamp.light_motion_sample()
   check(sample.frame==index and lamp.art.texture==motion._cells[index],"model and radius use identical phase "+lamp.kind)
   var sources:=field.sources(self,null,1.0);var found:Dictionary={}
   for source:Dictionary in sources:
    if source.position.is_equal_approx(lamp.source_position()):found=source;break
   check(not found.is_empty() and is_equal_approx(found.radius,float(config.radius)*sample.radius),"shader/fog descriptors read actual animated radius")
   check(found.radius>=float(config.radius)*.89 and found.radius<=float(config.radius)*1.11,"subtle bounded range")
   var visibility:=RoomLightField.visibility_at(lamp.source_position()+Vector2(float(config.radius)*.95,0),[found],true)
   if index==1:low_visibility=visibility
   if index==2:high_visibility=visibility
   low=minf(low,found.radius);high=maxf(high,found.radius)
  check(high>low and high_visibility>low_visibility,"visible and fog-clearing edge breathes with painted light")
  check(lamp.position==initial_position and lamp.art.scale==initial_scale,"animation never moves world anchor or changes footprint")
  motion.set_process(true)
  var age:=motion._age;get_tree().paused=true;await frames(2)
  check(motion._age==age,"pause stops painted light clock");get_tree().paused=false;motion.set_process(false)
  SaveService.data.reduced_motion=true;motion._process(.3)
  var still:=lamp.light_motion_sample()
  check(motion._age==age and still.radius==1.0 and still.energy==1.0 and lamp.art.texture==motion._cells[0],"reduced motion freezes model, radius and energy")
  SaveService.data.reduced_motion=false;lamp.animate_light_range=false
  check(lamp.light_motion_sample().radius==1.0,"explicit range-animation override remains available")
  lamp.animate_light_range=true
 var sources:=field.sources(self,null,1.0);var first:Dictionary=sources[0]
 check(is_equal_approx(RoomLightField.visibility_at(first.position,[first,first]),RoomLightField.visibility_at(first.position,[first])),"strongest-light blending unchanged")
 for index in 40:
  var extra:=Node2D.new();level.add_child(extra);field.register(extra,{"radius":100,"always_on":true})
 check(field.sources(self,null,1).size()==RoomEnvironmentConfig.MAX_LIGHTS,"existing 32-source budget retained")
 level.queue_free();await frames();field.refresh(self,.3)
 check(field.entries.is_empty(),"destroyed room releases models and all light descriptors")
func model_integrity()->void:
 var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/light_models_v18/metadata.json"))
 for kind:String in NEW_KINDS:
  var record:Dictionary=metadata[kind];var center:=Vector2(record.core[0],record.core[1]);var radius:=Vector2(record.core[2],record.core[3])
  for footprint:Vector2i in RoomEnvironmentConfig.LIGHT_SIZES:
   var path:="res://assets/room_mode/lights/%s_%dx%d.png"%[kind,footprint.x,footprint.y]
   var texture:=load(path) as Texture2D;var cells:=LightModelArt.frames(texture)
   check(cells.size()==4,"exactly four authored frames "+path)
   var images:Array[Image]=[];var hashes:Array=[]
   for cell:Texture2D in cells:
    var atlas:=cell as AtlasTexture;var picture:=atlas.atlas.get_image().get_region(Rect2i(atlas.region))
    images.append(picture);hashes.append(hash(picture.get_data()))
    var rect:=picture.get_used_rect()
    check(rect.position.y>=8 and rect.end.y<=picture.get_height()-8 and rect.position.x>=8 and rect.end.x<=picture.get_width()-8,"complete silhouettes with transparent gutters")
    check(picture.get_size()==footprint*256 and atlas.filter_clip,"fixed canvases and clipped atlas sampling")
   check(hashes[0]!=hashes[1] and hashes[1]!=hashes[2] and hashes[2]!=hashes[3],"four distinct original model poses")
   var stable:=true
   for index in range(1,4):
    for y in range(0,images[0].get_height(),4):
     for x in range(0,images[0].get_width(),4):
      var local:=Vector2(x%256+.5,y%256+.5)
      if ((local-center)/radius).length()<1.02:continue
      # Importer alpha-border repair can change RGB under fully invisible pixels.
      var a:=images[index].get_pixel(x,y);var b:=images[0].get_pixel(x,y)
      if a.a<=.01 and b.a<=.01:continue
      if a!=b:stable=false
   check(stable,"rigid metal, stone, foliage and feet never change outside luminous core "+path)
 check(LightModelArt._cache.size()<=12,"animation atlas cache remains bounded")
