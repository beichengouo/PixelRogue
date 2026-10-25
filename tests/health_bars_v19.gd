extends Node
class ProbeEnemy:
 extends "res://src/actors/enemy_base.gd"
 func _ready()->void:pass
class ProbeBoss:
 extends "res://src/room_mode/room_boss.gd"
 func _ready()->void:pass
class ProbeDirector:
 extends "res://src/room_mode/room_director.gd"
 func _ready()->void:pass
var checks:=0
var failures:=0
var notices:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _ready()->void:process_mode=Node.PROCESS_MODE_ALWAYS;call_deferred("run")
func frames(n:=2)->void:
 for index in n:await get_tree().process_frame
func _notice()->void:notices+=1
func run()->void:
 if not OS.get_user_data_dir().begins_with("E:/CodexWorkspace/PixelRogue/"):push_error("Isolated saves required");get_tree().quit(1);return
 AchievementTracker.set_process(false);GameState.set_process(false)
 assets()
 await pressure()
 await bosses()
 if DisplayServer.get_name()!="headless":await render()
 GameState.run_active=false;AudioManager.shutdown();await frames()
 print("HEALTH_BARS_V19 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
func assets()->void:
 var hashes:Dictionary={}
 for id:String in UnitHealthArt.STYLES:
  var entry:=UnitHealthArt.profile(id)
  check(entry.frame_texture!=null and entry.fill_texture!=null,"separate frame and fill "+id)
  check(entry.frame_texture.get_size()==Vector2(1024,256),"consistent layered canvas "+id)
  var picture:Image=entry.frame_texture.get_image();var slot:=UnitHealthArt.slot(Rect2(0,0,1024,256),entry)
  check(picture.get_pixelv(Vector2i(slot.get_center())).a<.01,"frame channel truly transparent "+id)
  var box:=picture.get_used_rect()
  check(box.position.x>=8 and box.position.y>=1 and box.end.x<=1016 and box.end.y<255,"full unclipped frame silhouette "+id)
  hashes[hash(picture.get_data())]=true
  for width in [34,54,160,380,720]:
   var channel:=UnitHealthArt.slot(Rect2(0,0,width,44),entry)
   check(channel.size.x>0 and Rect2(0,0,width,44).encloses(channel),"channel remains inside compact and wide bars")
 check(hashes.size()==9,"nine independently authored health models including elites")
 var ordinary:=ProbeEnemy.new()
 check(ordinary.health_bar_style()=="enemy","ordinary enemy keeps common health model")
 ordinary.affixes.assign([EnemyAffixes.HASTE])
 check(ordinary.is_elite() and ordinary.health_bar_style()=="elite","affix elite in any room gets dedicated health model")
 ordinary.affixes.clear();ordinary.room_pressure_growth=5
 check(ordinary.health_bar_style()=="enemy","rage alone does not turn an ordinary enemy into an elite")
 ordinary.free()
 for id:String in ["king","mage","tide","sephra","verena","nameless"]:
  var boss:=ProbeBoss.new();boss.boss_id=StringName(id);boss.affixes.assign([EnemyAffixes.CRUEL])
  check(boss.health_bar_style()==id,"BossRush cruel affix retains boss-specific model")
  boss.free()
 var skull_hashes:Dictionary={}
 for level in range(1,6):
  var skull:=UnitHealthArt.skull(level);var image:=skull.get_image();var box:=image.get_used_rect()
  check(skull.get_size()==Vector2(128,128) and box.position.x>=4 and box.position.y>=4 and box.end.x<=124 and box.end.y<=124,"complete transparent rage skull "+str(level))
  check(box.size.x>65 and box.size.y>80,"skull fills readable icon canvas "+str(level))
  skull_hashes[hash(image.get_data())]=true
 check(skull_hashes.size()==5 and UnitHealthArt.skull(0)==null and UnitHealthArt.skull(9)==UnitHealthArt.skull(5),"distinct five-level badges and no zero-level marker")
func new_enemy()->ProbeEnemy:
 var unit:=ProbeEnemy.new();unit.hp=100;unit.max_hp=100;unit.damage=10;unit.move_speed=20;unit._damage_scale=1;unit._speed_scale=1
 return unit
func pressure()->void:
 var original_difficulty:=GameState.difficulty;EventBus.enemies_enraged.connect(_notice)
 for difficulty in range(1,5):
  var root:=Node2D.new();add_child(root)
  var director:=ProbeDirector.new();add_child(director);director.set_process(false);director.enemies_root=root;director.phase=WaveDirector.Phase.FIGHT
  var unit:=new_enemy();root.add_child(unit);unit.set_physics_process(false)
  GameState.run_active=true;GameState.difficulty=difficulty;notices=0
  var grace:float=director.pressure_grace()
  director.advance_room_pressure(grace-.01)
  check(director.room_pressure_step==0 and unit.damage==10,"difficulty grace retained "+str(difficulty))
  director.advance_room_pressure(.01)
  check(director.room_pressure_step==1 and is_equal_approx(unit.damage,11),"first rage exactly at grace")
  for level in range(2,6):
   director.advance_room_pressure(RoomDirector.PRESSURE_INTERVAL)
   check(director.room_pressure_step==level and unit.room_pressure_growth==level,"twenty-second rage step "+str(level))
   check(is_equal_approx(unit.damage,10.0*RoomDirector.PRESSURE_ATTACK[level]) and is_equal_approx(unit.move_speed,20*RoomDirector.PRESSURE_SPEED[level]),"same per-step attack/speed growth")
  director.advance_room_pressure(600)
  check(director.room_pressure_step==5 and is_equal_approx(unit.damage,16.5) and is_equal_approx(unit.move_speed,24),"fifth level is hard cap for stats and display")
  check(notices==1,"only initial rage announcement")
  get_tree().paused=true;var age:=director.room_pressure_elapsed;director.advance_room_pressure(RoomDirector.PRESSURE_INTERVAL)
  check(director.room_pressure_elapsed==age,"pause does not advance rage");get_tree().paused=false
  director.phase=WaveDirector.Phase.REST;director.advance_room_pressure(RoomDirector.PRESSURE_INTERVAL)
  check(director.room_pressure_elapsed==age,"trial/rush rest does not advance rage")
  var runtime:=RoomRuntime.new();var fields:=runtime._fields(director);var restored:=ProbeDirector.new();runtime._apply_fields(restored,fields)
  check(restored.room_pressure_step==5 and restored.room_pressure_elapsed==director.room_pressure_elapsed,"room clock and capped growth survive snapshot")
  restored.free();runtime.free();director.queue_free();root.queue_free();await frames()
 EventBus.enemies_enraged.disconnect(_notice);GameState.difficulty=original_difficulty;GameState.run_active=false
 var runtime:=RoomRuntime.new();var old:=new_enemy()
 var saved:={"balance_revision":4,"room_pressure_growth":9,"damage":100.0,"_damage_scale":10.0,"move_speed":40.0,"_speed_scale":2.0}
 runtime._apply_fields(old,saved)
 check(old.room_pressure_growth==5 and is_equal_approx(old.damage,16.5) and is_equal_approx(old._damage_scale,1.65),"legacy over-cap enemy stats normalized")
 runtime._apply_fields(old,saved)
 check(is_equal_approx(old.damage,16.5) and is_equal_approx(old._damage_scale,1.65) and is_equal_approx(old.move_speed,24),"repeated field restoration does not compound conversion")
 var fields:=runtime._fields(old);var second:=new_enemy();runtime._apply_fields(second,fields)
 check(is_equal_approx(second.damage,16.5) and second.room_pressure_growth==5,"new-format read/save/read preserves normalized stats")
 var old_director:=ProbeDirector.new();runtime._apply_fields(old_director,{"room_pressure_step":9,"room_pressure_elapsed":500.0})
 check(old_director.room_pressure_step==5,"legacy director normalized with enemy")
 old_director.free();second.free();old.free();runtime.free()
func bosses()->void:
 var hud:=BossBar.new();add_child(hud);hud.set_process(false)
 for id:String in ["king","mage","tide","sephra","verena","nameless"]:
  var boss:=ProbeBoss.new();boss.configure(StringName(id));boss.max_hp=1000;boss.hp=1000
  add_child(boss);boss.add_to_group("bosses");boss.set_physics_process(false)
  hud._on_boss_started(StringName(id));hud._process(0);await frames()
  check(hud._bar is BossVitalBar and (hud._bar as BossVitalBar).style_id==id,"boss and Rush use correct dedicated health model "+id)
  check(hud._icon.texture!=null and hud._hp_label.text.contains("阶段"),"existing portrait, phase and health values retained")
  check(not hud._pressure_icon.visible,"no rage icon before growth")
  for level in range(1,6):
   boss.room_pressure_growth=level;hud._process(0)
   check(hud._pressure_icon.visible and hud._pressure_icon.texture==UnitHealthArt.skull(level),"boss rage icon follows current level")
  boss.hp=100;hud._process(0)
  var health:=boss.phase_health()
  check(hud._phase==health.phase and is_equal_approx(hud._bar._max_value,health.max_hp) and is_equal_approx(hud._bar._value,health.hp),"phase-specific HP never becomes whole-life HP")
  boss.queue_free();await frames()
 var host:=SubViewport.new();host.size=Vector2i(1280,720);add_child(host);hud.reparent(host)
 for dimensions:Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(720,1280)]:
  host.size=dimensions;hud._on_boss_started(&"nameless");hud._pressure_icon.texture=UnitHealthArt.skull(5);hud._pressure_icon.show()
  hud._hp_label.text="阶段 3/3 · 900000 / 1000000";hud._fit_layout();await frames(4)
  check(Rect2(Vector2.ZERO,dimensions).encloses(hud._panel.get_global_rect()),"boss model fits viewport "+str(dimensions))
  check(hud._panel.get_global_rect().grow(1).encloses(hud._bar.get_global_rect()),"flowing bar remains inside its panel")
 hud._on_boss_defeated(&"nameless");await get_tree().create_timer(.2,true,false,true).timeout
 check(not hud._root.visible,"defeated boss bar closes")
 host.queue_free();await frames()
func render()->void:
 var unit_view:=SubViewport.new();unit_view.size=Vector2i(180,140);unit_view.transparent_bg=true;unit_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(unit_view)
 var unit:=new_enemy();unit.position=Vector2(90,95);unit.hp=50;unit.max_hp=100;unit_view.add_child(unit);unit.set_physics_process(false);unit.queue_redraw()
 await frames();await RenderingServer.frame_post_draw
 var common:=unit_view.get_texture().get_image()
 unit.affixes.assign([EnemyAffixes.HASTE]);unit.queue_redraw();await frames();await RenderingServer.frame_post_draw
 var elite:=unit_view.get_texture().get_image();var differences:=0
 for y in range(40,100):
  for x in range(40,140):
   if common.get_pixel(x,y)!=elite.get_pixel(x,y):differences+=1
 check(differences>30,"actual elite overhead bar differs in colour and frame silhouette at game size")
 unit.room_pressure_growth=5;unit.queue_redraw();await frames();await RenderingServer.frame_post_draw
 var angry:=unit_view.get_texture().get_image();var skull_pixels:=0
 for y in range(45,85):
  for x in range(40,70):
   if angry.get_pixel(x,y).a>elite.get_pixel(x,y).a+.1:skull_pixels+=1
 check(skull_pixels>10,"elite bar retains fifth-level skull beside its frame")
 unit._show_hp_bar=false;unit.queue_redraw();await frames();await RenderingServer.frame_post_draw
 check(unit_view.get_texture().get_image().get_used_rect().size==Vector2i.ZERO,"enemy health visibility setting still hides elite frame and badge")
 unit_view.queue_free();await frames()
 var viewport:=SubViewport.new();viewport.size=Vector2i(680,120);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
 var bar:=BossVitalBar.new();bar.setup(Color.WHITE,80);bar.position=Vector2(20,20);bar.size=Vector2(640,80);viewport.add_child(bar);bar.set_process(false)
 var rng_before:=Rng.stream().state
 for id:String in ["king","mage","tide","sephra","verena","nameless"]:
  bar.configure(id);bar.set_max_value(100);bar.set_value(100,true);bar._sync_flow();await frames();await RenderingServer.frame_post_draw
  var full:=viewport.get_texture().get_image()
  bar.set_value(50,true);bar._sync_flow();await frames();await RenderingServer.frame_post_draw
  var half:=viewport.get_texture().get_image();var channel:=UnitHealthArt.slot(Rect2(bar.position,bar.size),UnitHealthArt.profile(id))
  var at:=Vector2i(channel.position+channel.size*Vector2(.75,.6));var filled:=full.get_pixelv(at);var empty:=half.get_pixelv(at)
  check(Vector3(filled.r,filled.g,filled.b).length()>Vector3(empty.r,empty.g,empty.b).length()+.1,"actual fill is clipped to HP "+id)
  bar.set_value(0,true);bar._sync_flow();await frames();await RenderingServer.frame_post_draw;var zero:=viewport.get_texture().get_image()
  var center:=Vector2i(channel.get_center());var dark:=zero.get_pixelv(center)
  check(maxf(dark.r,maxf(dark.g,dark.b))<.15,"zero HP has no painted full-life residue")
  SaveService.data.reduced_motion=false;bar.set_value(100,true);bar._flow_age=0;bar._sync_flow();await frames();await RenderingServer.frame_post_draw;var before:=viewport.get_texture().get_image()
  bar._flow_age=1.7;bar._sync_flow();await frames();await RenderingServer.frame_post_draw;var after:=viewport.get_texture().get_image()
  var changed:=0;var outside:=0
  for y in range(0,120,2):
   for x in range(0,680,2):
    if before.get_pixel(x,y)==after.get_pixel(x,y):continue
    if channel.grow(1).has_point(Vector2(x,y)):changed+=1
    else:outside+=1
  check(changed>30 and outside==0,"flow animates only liquid, not ornaments or depleted range "+id)
  var age:=bar._flow_age;get_tree().paused=true;bar._process(.5);get_tree().paused=false
  check(bar._flow_age==age,"pause freezes boss flow")
  SaveService.data.reduced_motion=true;bar._sync_flow();await frames();await RenderingServer.frame_post_draw;var still:=viewport.get_texture().get_image()
  bar._flow_age+=4;bar._sync_flow();await frames();await RenderingServer.frame_post_draw
  check(still.get_data()==viewport.get_texture().get_image().get_data(),"reduced motion uses static painted liquid")
  SaveService.data.reduced_motion=false
 check(rng_before==Rng.stream().state,"health-bar animation never consumes gameplay randomness")
 viewport.queue_free();await frames()
