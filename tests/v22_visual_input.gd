extends "res://tests/v21_dialogue_input.gd"
class Harness:
 extends "res://tests/inventory_v17.gd"
 func _ready()->void:pass

func run()->void:
 if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
 AchievementTracker.set_process(false);SaveService.data.reduced_motion=true
 var harness:=Harness.new();add_child(harness);await harness.begin(&"ilyua")
 var main=harness.main;var bar:BossBar=main.boss_bar
 var chooser:=FateChoiceUI.new();main.add_child(chooser);await frames()
 for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
  get_window().size=extent;await frames(5)
  for id:StringName in [&"king",&"mage",&"tide",&"sephra",&"verena",&"nameless"]:
   bar._on_boss_started(id);await frames(3)
   check(bar._panel.get_theme_stylebox("panel") is StyleBoxEmpty,"no boss backdrop "+str(extent)+str(id))
   check(bar._bar.size.y>=30,"at least 28 pixels actual fill "+str(extent)+str(id))
   check(get_viewport().get_visible_rect().grow(1).encloses(bar._panel.get_global_rect()),"boss panel within viewport "+str(extent)+str(id))
  bar._root.hide();bar._boss_id=&""
  for mode:String in ["keyboard","gamepad","mouse","touch"]:
   var room:Dictionary={"id":"visual","seed":42,"kind":"altar","cleared":true,"rewarded":true,"delta":{"fate_reading":{"offers":["moon","fool","world"],"reverse":false,"done":false}}}
   chooser.open_reading(room);await frames(6);chooser._input_ready_at=0
   check(chooser._reward_icons.size()==3,"three face images")
   for icon in chooser._reward_icons:
    check(icon.size==Vector2(300,450),"equal card face size "+mode+str(extent))
   check(chooser._cards[0].find_children("*","Label",true,false).any(func(node:Node)->bool:return node is Label and node.text=="角色共鸣"),"own-card resonance visible")
   await activate(chooser._cards[0],mode)
   check(chooser.confirmation._open,"card opens preview "+mode+str(extent))
   check(chooser.confirmation.dialog_text.contains("伊露雅") and chooser.confirmation.dialog_text.contains("0.35"),"preview shows character ability")
   chooser.confirmation.close();chooser.cancel();await frames(3)
   check(not UIFlow.has_screen(),"cancel restores combat focus "+mode)
 chooser.queue_free();await harness.settle_actor();harness.queue_free()
 AudioManager.shutdown();await frames()
 print("V22_VISUAL_INPUT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
