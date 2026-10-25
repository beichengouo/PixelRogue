extends Node
class ProbeRoom:
 extends "res://src/room_mode/room_main.gd"
 func _ready()->void:pass
 func _autoplay_requested()->bool:return true
var main:ProbeRoom
var actor:RoomPlayer
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",message)
func _ready()->void:
 process_mode=Node.PROCESS_MODE_ALWAYS;call_deferred("run")
func begin(character:StringName)->void:
 SaveService.data.control_setup_done=true;SaveService.data.run={};Outpost.data.active={};Characters.set_current(character)
 main=ProbeRoom.new();add_child(main);main._build_world();main._build_ui();main.set_process(false)
 await main._begin_run({"departure":{"loadout":[],"carried":0,"difficulty":1,"initial_level":1}})
 GameState.fate.star_pending=false;actor=main.player
 GameState.set_process(false);actor.set_physics_process(false);actor.caster.set_physics_process(false);actor.equipment_mechanics.set_process(false);main.director.set_process(false);main.special_rooms.set_process(false);main.expansion.set_process(false);main.expedition.set_process(false)
 if is_instance_valid(actor.holy_runtime):actor.holy_runtime.set_process(false)
 if is_instance_valid(actor.ilyua_runtime):actor.ilyua_runtime.set_process(false)
func settle_actor()->void:
 main.inventory_ui._finish_close();GameState.run_active=false;actor.caster.clear_input_buffer()
 await get_tree().create_timer(1.4,true,false,true).timeout
 main.queue_free();await get_tree().process_frame;await get_tree().process_frame;Outpost.pending_checkpoint=false
func frames(n:=3)->void:
 for index in n:await get_tree().process_frame
func run()->void:
 if not OS.get_user_data_dir().begins_with("E:/CodexWorkspace/PixelRogue/"):push_error("Isolated saves required");get_tree().quit(1);return
 AchievementTracker.set_process(false);SaveService.data.reduced_motion=true
 for character in [&"sylphiette",&"xixifu",&"ilyua"]:
  await begin(character);await inventory_checks();await prayer_checks(character);await settle_actor()
 AudioManager.shutdown();await frames()
 print("INVENTORY_V17 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
func inventory_checks()->void:
 var bag:=main.inventory_ui;var tree:=main.talent_ui
 check(tree==bag.talent_view and tree.embedded_host==bag,"one tree instance shared by all entry points")
 for id:StringName in [&"staff_cloud_radiance",&"relic_spentmatch",&"potion_capacity"]:
  var sample:=ItemDB.by_id(id).duplicate(true)
  if not sample.is_empty():GameState.items.append(sample)
 var material:=ItemDB.mushroom_item(0);material.stack_count=999;GameState.items.append(material)
 bag.open();await frames(4)
 check(UIFlow.is_top(bag) and get_tree().paused,"bag owns pause and input")
 for category in [&"gear",&"relic",&"potion",&"material"]:
  bag._filter=category;bag._rebuild();await frames()
  check(bag._grid.columns==10 and bag._grid.get_child_count()>=24,"ten-column item category "+str(category))
  check(bag._grid.size.x<=bag._grid.get_parent().size.x+1,"ten item columns fit available width")
 for index in bag._tab_buttons.size():
  var button:Button=bag._tab_buttons[index];var art:=button.get_node("CategoryLettering") as Control
  check(button.text.is_empty() and art.get_child(0).texture!=null,"all seven tabs have symbol + painted lettering")
  check(art.get_combined_minimum_size().x<=button.size.x+1,"tab art and count fit "+str(index))
 GameState.talents.clear();GameState.talent_points=10
 bag.open_talent_page();await frames(5)
 check(UIFlow.is_top(bag) and tree.is_open() and tree._root.get_parent()==bag._talent_mount,"talent tree is physically inside bag")
 check(bag._page_box.get_child_count()==0 and not bag._shell.get_node("Panel/Content/Body/Detail").visible,"old summary rows and duplicate details removed")
 check(tree._canvas.get_global_rect().size.x>bag._grid.size.x,"embedded tree uses full content width")
 var node_id:=tree._default_pick();tree._upgrade_branch(node_id);await frames()
 check(GameState.talent_points==9 and TalentGraph.owned(node_id,GameState.talents),"embedded tree activation spends exactly one point")
 tree._upgrade_branch(node_id);check(GameState.talent_points==9,"repeat activation cannot duplicate spending")
 var next_id:=tree._default_pick();bag._closing=true;tree._upgrade_branch(next_id)
 check(GameState.talent_points==9,"closing bag rejects late talent activation")
 bag._closing=false
 tree._set_zoom(.65);tree._on_node_selected(node_id)
 bag._filter=&"gear";bag._rebuild();await frames()
 check(not tree.is_open() and UIFlow.is_top(bag),"switching tab hides tree without releasing pause")
 bag.open_talent_page();await frames()
 check(is_equal_approx(tree._zoom,.65) and tree._selected==node_id,"talent zoom and selection retained across tabs")
 bag._finish_close();await frames()
 check(not UIFlow.has_screen() and not get_tree().paused and not tree.is_open(),"closing bag releases input and hides embedded tree")
 tree.open();await frames()
 check(bag.is_open() and bag._filter==&"talent" and UIFlow.is_top(bag),"legacy talent shortcut opens bag tab")
 bag._finish_close();await frames()
func prayer_checks(character:StringName)->void:
 var fx:=GoddessExtractionFX.new();main.add_child(fx);await frames()
 for form in [false,true]:
  GameState.legendary_looks[str(character)]={"set":form}
  actor._sprite.sprite_frames=RedrawnHeroArt.frames(character);actor._sprite.play(&"prayer");RoomHeroArt.align(actor._sprite)
  actor.set_extraction_pose(&"prayer")
  var model:=actor._sprite.sprite_frames
  var foot:Vector2=model.get_meta("hd_foot",RedrawnHeroArt.FOOT)
  var cell:=float(model.get_meta("hd_cell",RedrawnHeroArt.CELL))
  var feet:=actor._sprite.to_global(foot-Vector2.ONE*cell*.5)
  for index in 8:
   actor.facing=-1 if index%2 else 1
   fx.present("praying",float(index)*.15,0,0,actor.global_position,actor)
   var pivot:=ExtractionSpriteArt.FOOT-ExtractionSpriteArt.LOGICAL_SIZE*.5
   if fx.prayer.flip_h:pivot.x=-pivot.x
   var actual:=fx.prayer.to_global(pivot)
   check(actual.distance_to(feet)<.01,"prayer sole matches actor "+str(character)+" form="+str(form)+" frame="+str(index))
   check(fx.prayer.scale.is_equal_approx(actor._sprite.scale),"prayer preserves exact current actor scale")
 actor.set_extraction_pose(&"");fx.queue_free();await frames()
