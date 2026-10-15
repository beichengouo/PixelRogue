extends Node
var root:Window
var main
var gs
var errors:Array[String]=[]
var checks:=0
var reward_signals:=0
func reward_item_count(item_id: String) -> int:
 var count:=0
 for item:Dictionary in gs.items:
  if str(item.get("id", "")) == item_id: count+=1
 return count
func check(ok:bool,why:String)->void:
 checks+=1
 if not ok:
  errors.append(why);printerr("FAIL ",why)
  for entry in UIFlow._stack:
   var owner:Node=entry.owner.get_ref()
   printerr("PAUSE_OWNER ",owner.get_path() if is_instance_valid(owner) else "released")
func _ready()->void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 root=get_tree().root
 call_deferred("run")
 get_tree().create_timer(150,true,false,true).timeout.connect(func():
  printerr("FLOW_WATCHDOG timeout");get_tree().quit(1))
func wait(seconds:float)->void:await get_tree().create_timer(seconds,true,false,true).timeout
func wait_until(predicate:Callable,seconds:float=3.0)->bool:
 var deadline:int=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<deadline:
  if predicate.call():return true
  await wait(.05)
 return predicate.call()
func await_reward()->void:
 var deadline:int=Time.get_ticks_msec()+12000
 while Time.get_ticks_msec()<deadline and not main.choice_ui.is_open():
  if main.dialogue.is_open():main.dialogue._skip_story()
  await wait(.1)
func connect_room(direction:Vector2i,kind:String,template_id:String="")->void:
 var old:String=main.graph.current
 var record:Dictionary=main.graph._allocate(RoomGraph.cell(old)+direction,kind,"")
 if not template_id.is_empty():
  var template:Dictionary=RoomTemplateCodec.read_file("res://assets/room_templates/"+template_id+".json")
  record.terrain_layout=RoomTemplateCodec.to_layout(template);record.biome=template.theme
 main.graph.rooms[record.id]=record;main.graph._connect(old,record.id)
 main._door_lock=0
 await main._change_room(direction)
func capture_room(label:String)->void:
 main.world_clock.minutes=720
 await wait(.6)
 await RenderingServer.frame_post_draw
 # Render the actual game frame without producing screenshots.
 check(not label.is_empty(),"rendered gameplay "+label)
func run()->void:
 gs=root.get_node("GameState")
 root.get_node("Outpost").data.active={};root.get_node("SaveService").data.run={}
 Characters.set_current(&"xixifu");PassiveDefinitions.select(&"xixifu",&"xixifu_revival")
 main=load("res://src/room_mode/room_main.tscn").instantiate();main.show_menu_on_ready=false;root.add_child(main)
 main.menu.open();check(get_tree().paused,"menu owns pause");main.menu.close();await wait(.4)
 main.camp_ui.open();check(main.camp_ui.is_open(),"camp preparation opens");main.camp_ui.close();await wait(.3)
 main._begin_run({});main.player.hp=10000;main.player.max_hp=10000;main.player._invuln=1000
 check(gs.passive_id==&"xixifu_revival","departure locks selected passive")
 await connect_room(Vector2i.RIGHT,"normal","forest_bone_glade")
 await capture_room("bone-glade-closed-gameplay")
 main.director._queue.clear();main.director.room_pending.clear();main.director.phase=WaveDirector.Phase.FIGHT
 for e in get_tree().get_nodes_in_group("enemies"):
  if not e.is_queued_for_deletion():e.take_damage(100000,false,e.global_position,main.player,false)
 await await_reward()
 check(main.choice_ui.is_open(),"actual clear delay leads to reward")
 var before:int=gs.items.size();var received:Dictionary=main.choice_ui.offers[0]
 var reward_before:=reward_item_count(str(received.get("id", "")))
 var reward_hired_before:int=gs.hired.size()
 main.choice_ui.item_chosen.connect(func(_item:Dictionary):reward_signals+=1)
 main.choice_ui.choose(0);main.choice_ui.choose(1);await wait(.5)
 check(not main.choice_ui.is_open() and not get_tree().paused,"reward releases pause")
 check(main.graph.rooms[main.graph.current].rewarded,"reward marks room once")
 var reward_delivered:bool=gs.hired.size()==reward_hired_before+1 if received.get("hire_token",false) else reward_item_count(str(received.get("id", "")))>=reward_before+1
 check(reward_signals==1 and reward_delivered,"reward commits once")
 await capture_room("bone-glade-open-gameplay")
 main.inventory_ui.open();check(get_tree().paused and main.inventory_ui.is_open(),"bag pause owns lease")
 main.inventory_ui.close();main.inventory_ui.close()
 await wait_until(func():return not main.inventory_ui.is_open())
 check(not get_tree().paused,"bag repeated close releases lease")
 gs.add_coins(10000);gs.talent_points=10
 check(gs.spend_talent_point(&"contract_might"),"first summoning prerequisite upgrades")
 check(gs.spend_talent_point(&"contract_vitality") and gs.spend_talent_point(&"contract_vitality"),"summon duration prerequisites upgrade")
 main.talent_ui.open();main.talent_ui._selected=&"contract_duration";main.talent_ui._upgrade_selected();await wait(.15)
 check(gs.talent_rank(&"contract_duration")==1,"tree upgrades selected talent")
 check(SummonerTalents.ordinary_capacity(gs.talent_rank(&"contract_duration"))==5,"upgrade changes actual summon capacity")
 var old_coins:int=gs.coins;check(gs.reset_talents(),"paid talent reset succeeds")
 check(gs.coins==old_coins-100 and SummonerTalents.ordinary_capacity(gs.talent_rank(&"contract_duration"))==4,"reset restores seats and charges exactly100")
 main.talent_ui.close(true);await wait(.2)
 await connect_room(Vector2i.DOWN,"normal","wetland_curve")
 await capture_room("flower-bend-closed-gameplay")
 main.director._queue.clear();main.director.room_pending.clear();main.director.phase=WaveDirector.Phase.FIGHT
 for e in get_tree().get_nodes_in_group("enemies"):
  if not e.is_queued_for_deletion():e.take_damage(100000,false,e.global_position,main.player,false)
 await await_reward();check(main.choice_ui.is_open(),"second new illustrated room clears into reward")
 main.choice_ui.choose(0);await wait(.5)
 check(not get_tree().paused,"second room reward releases pause")
 await capture_room("flower-bend-open-gameplay")
 await connect_room(Vector2i.DOWN,"shop","shop_garden")
 main.open_room_shop();await wait(.4)
 check(main.shop_ui.is_open() and get_tree().paused,"independent shop pauses")
 check(not main.shop_ui._offers.is_empty(),"shop presents buyable offers")
 if main.shop_ui._offers.is_empty():
  root.get_node("AudioManager").shutdown();get_tree().quit(1);return
 before=gs.items.size();old_coins=gs.coins;var price:int=main.shop_ui._offers[0].cost
 main.shop_ui.buy(0);main.shop_ui.buy(0)
 check(gs.items.size()==before+1 and gs.coins==old_coins-price,"shop consecutive purchase commits once")
 main.shop_ui.close(true);await wait(.2)
 await connect_room(Vector2i.LEFT,"tavern","tavern_waterfront")
 await capture_room("tavern-gameplay")
 main.open_room_tavern();await wait(.4);var hired_before:int=gs.hired.size()
 main.tavern_ui._hire(0);main.tavern_ui._hire(0)
 check(gs.hired.size()==hired_before+1,"tavern consecutive hire commits once")
 main.tavern_ui.close(true);await wait(.2)
 var saved:Dictionary=gs.snapshot();var saved_rng:int=gs.passive_rng.state
 Characters.set_current(&"sylphiette");PassiveDefinitions.select(&"sylphiette",&"sylphiette_aoe")
 main._begin_run(saved)
 check(Characters.current_id()==&"xixifu" and gs.passive_id==&"xixifu_revival","continue ignores another character's preparation choice")
 check(gs.passive_rng.state==saved_rng,"continue preserves passive RNG")
 main.player.velocity=Vector2.ZERO;main.player._dash_timer=0
 var extraction=main.expedition.extraction
 check(extraction.request(),"cleared special room allows prayer")
 await wait(3.3);check(extraction.state=="waiting","actual prayer reaches30s wait")
 await wait(30.4);check(extraction.state=="receiving","actual30s wait reaches reception")
 await wait(5)
 check(main.camp_ui.is_open() and not gs.run_active,"actual goddess transfer settles and returns camp")
 check(not root.get_node("TransitionLayer").busy,"no leftover transfer cover")
 main.camp_ui.close();await wait(.2);check(not get_tree().paused,"camp close releases final pause")
 print("INTEGRATION_FLOW_CHECKS ",checks," FAILURES ",errors.size())
 root.get_node("AudioManager").shutdown();get_tree().quit(0 if errors.is_empty() else 1)


