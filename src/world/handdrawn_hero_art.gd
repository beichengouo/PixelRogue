class_name HanddrawnHeroArt
extends RefCounted
## High-definition painted animation stays separate from pixel actors and gameplay.
const ROOT:="res://assets/heroes_handdrawn_v35/"
const DIRECTIONS:=["s","sw","w","nw","n","ne","e","se"]
const SOURCE:=["s","sw","w","nw","n","nw","w","sw"]
static var _cache:SpriteFrames
static var _form:=""
static var _materials:Dictionary={}
static func available(id:StringName)->bool:
 var path:=ROOT+str(id)+"/normal/"
 return ResourceLoader.exists(path+"s.png") and FileAccess.file_exists(path+"metadata.json")
static func frames(set_form:bool,id:StringName=&"sylphiette")->SpriteFrames:
 var form:="set" if set_form else "normal"
 var form_key:=str(id)+"/"+form
 if _cache!=null and _form==form_key:return _cache
 var path:=ROOT+form_key+"/"
 var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"metadata.json"))
 var result:=SpriteFrames.new();result.remove_animation(&"default")
 result.set_meta("handdrawn",true);result.set_meta("redrawn_character",id);result.set_meta("set_form",set_form)
 result.set_meta("core_height",float(profile.height));result.set_meta("utility_height",float(profile.height))
 result.set_meta("hd_cell",int(profile.cell));result.set_meta("hd_foot",Vector2(profile.foot[0],profile.foot[1]))
 result.set_meta("utility_facing",str(profile.get("utility_facing","e")))
 var sheets:Dictionary={}
 for key:String in ["s","sw","w","nw","n","utility"]:sheets[key]=load(path+key+".png") as Texture2D;sheets[key].set_meta("hd_bounds",profile.bounds[key])
 for direction in 8:
  var texture:Texture2D=sheets[SOURCE[direction]]
  for action:String in ["idle","walk","attack","move_attack","back_attack","skill_cast"]:
   var row:=0 if action=="idle" else 1 if action=="walk" else 3 if action in ["move_attack","back_attack"] else 2
   var fps:=5.0 if action=="idle" else 7.5 if action=="walk" else 12.5
   # Retreat reuses the authored lateral footwork, never reverses casting hands.
   # An authored ready pose is stable; unrelated blink/lean poses do not form
   # a coherent breathing cycle. Locomotion remains independently animated.
   var order:Array[int]=[0,1,2,3]
   if action=="idle":order.resize(1)
   _add(result,StringName(action+"_"+DIRECTIONS[direction]),texture,row,order,fps,action in ["idle","walk"],int(profile.cell))
 var utility:Texture2D=sheets.utility
 for spec:Array in [["prayer",0,8.0,true],["hurt",1,12.0,false],["death",2,5.0,false],["interact",3,12.5,false]]:
  _add(result,StringName(spec[0]),utility,int(spec[1]),[0,1,2,3],float(spec[2]),bool(spec[3]),int(profile.cell))
 _add(result,&"jump",sheets.s,1,[0,1,2,3],12,false,int(profile.cell))
 _add(result,&"land",sheets.s,1,[1,0,3,0],20,false,int(profile.cell))
 var aliases:={"idle":"idle_w","run":"walk_w","cast":"attack_w","attack":"attack_w","move_attack":"move_attack_w","move_cast":"move_attack_w","dash":"walk_w","fall":"idle_w","double_jump":"jump","brake":"land","victory":"interact","heal":"attack_w","shield":"attack_w","blink_in":"attack_w","blink_out":"attack_w","air_attack":"attack_w","air_cast":"attack_w","block":"hurt"}
 for name:String in aliases:
  var source:=StringName(aliases[name]);result.add_animation(name)
  result.set_animation_speed(name,result.get_animation_speed(source));result.set_animation_loop(name,result.get_animation_loop(source))
  for index in result.get_frame_count(source):result.add_frame(name,result.get_frame_texture(source,index))
 # Keep only the current form cached; living decoys retain their own snapshot.
 _form=form_key;_cache=result;return result
static func _add(result:SpriteFrames,name:StringName,sheet:Texture2D,row:int,order:Array[int],fps:float,loop:bool,cell:int)->void:
 result.add_animation(name);result.set_animation_speed(name,fps);result.set_animation_loop(name,loop)
 for index in order:
  var texture:=AtlasTexture.new();texture.atlas=sheet;texture.region=Rect2(index*cell,row*cell,cell,cell);texture.filter_clip=true
  var raw:Array=sheet.get_meta("hd_bounds")[row*4+index];texture.set_meta("painted_bounds",Rect2(raw[0],raw[1],raw[2],raw[3]));result.add_frame(name,texture)
static func place(sprite:Node2D,frames_value:SpriteFrames,height:=32.0,floor_y:=14.0)->void:
 var factor:=height/float(frames_value.get_meta("core_height",240.0))
 var cell:=float(frames_value.get_meta("hd_cell",448));var foot:Vector2=frames_value.get_meta("hd_foot",Vector2(224,392))
 sprite.scale=Vector2.ONE*factor;sprite.position=Vector2(0,floor_y)-(foot-Vector2.ONE*cell*.5)*factor
 sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 sprite.material=cloth_material(frames_value.get_meta("redrawn_character")) if frames_value.get_meta("set_form",false) else null
static func align(sprite:AnimatedSprite2D,height:=32.0,floor_y:=14.0)->void:
 place(sprite,sprite.sprite_frames,height,floor_y)

static func clear()->void:
 _cache=null;_form="";_materials.clear()

static func cloth_material(id:StringName)->ShaderMaterial:
 if not _materials.has(id):
  var material:=ShaderMaterial.new();material.shader=preload("res://src/world/handdrawn_cloth.gdshader")
  material.set_shader_parameter("palette",1 if id==&"xixifu" else 2 if id==&"ilyua" else 0)
  _materials[id]=material
 var result:ShaderMaterial=_materials[id]
 result.set_shader_parameter("motion_enabled",not ComicMotion.reduced())
 return result
