class_name CampTutorial
extends Node2D
const STEPS := [
	{"role":"","mode":"auto","pose":"point","text":"欢迎来到星辉回廊。我是伊莉丝。这里的灯会等你归来。让我陪你认识这里，好吗？移动与交互的按键都能在设置里更改。"},
	{"role":"relations","mode":"interact","pose":"point","text":"先去星灯酒馆吧。温阮会听你说旅途里的事，也会替归来的人留一盏灯。跟着你身旁的箭头，靠近门口后按交互键；看完再返回营地。"},
	{"role":"shop","mode":"interact","pose":"point","text":"这是姜糖的星灯商铺。这里可以买装备和药剂、兑换材料，也能查看下一批货到来的时间。这里只使用营地金库，买到的东西会进入仓库。进去看一看就好，不必购买。"},
	{"role":"warehouse","mode":"interact","pose":"thoughtful","text":"回廊仓库替你保存撤回的物资。在这里可以分类查看、出售、保护锁、扩容和管理配装方案。训练时试穿装备不会扣库存；真正出发要在准备台选好携带清单。"},
	{"role":"contracts","mode":"interact","pose":"point","text":"冒险者工会保存调查与委托记录。有些委托由希尔薇娅、布琳娜和艾莉娅亲自发布，完成后也要找本人交付。头顶金色标识表示有委托，蓝色表示进行中，绿色表示材料已齐。先看看工会的记录吧。"},
	{"role":"iris","mode":"interact","pose":"thoughtful","text":"这座灯坛是我与你的契约相接的地方。你可以来这里与我交谈、了解旧约和回廊的往事。准备冒险之外，也可以给自己留一点问问题的时间。"},
	{"role":"result","mode":"interact","pose":"point","text":"旅途记事台会记下上一趟出征的收获和损失。若想知道物资去了哪里，先查看这里；尚未撤回的收获不能当作已经入库的物资。"},
	{"role":"training","mode":"approach","pose":"point","text":"前面是训练场。稻草人不会反击，攻击后会在头顶显示伤害与DPS。训练告示牌可以临时调整等级、技能和天赋，也能恢复状态、重置冷却。走近看看即可，这次不要求你攻击或打开面板。"},
	{"role":"prepare","mode":"interact","pose":"thoughtful","text":"准备出发时，在这张桌上选好真实携带的装备、药剂、金币、战斗难度和被动。确认准备不会立刻扣物资；离开大门时才正式提交。进入战斗会按确认购买的初始等级出发，并恢复初始技能；训练配置不会带出去。先查看准备台吧，现在不必出发。"},
	{"role":"gates","mode":"auto","pose":"proud","text":"准备确认后，四座大门会一起打开。从任何一门走出去，都会开始同一段冒险。中途更改携带清单，需要重新确认。愿你每一次走出去，都记得灯火在等你。"}
]
var world:Node
var active:=false
var step:=0
var phase:="delay"
var _generation:=-1
var _delay:=.8
var _opened:=false
var _clock:=0.0
var _arrow:AnimatedSprite2D
var _hud:CanvasLayer
var _root:Control
var _caption:Label
var _row:HBoxContainer
var _pending_advance:=false
func _ready()->void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	_arrow=AnimatedSprite2D.new();var frames:=SpriteFrames.new();frames.add_animation(&"guide");frames.set_animation_speed(&"guide",8);frames.set_animation_loop(&"guide",true)
	var texture:=load(CampResidents.ROOT+"guide_arrow.png") as Texture2D
	for index in 4:
		var frame:=AtlasTexture.new();frame.atlas=texture;frame.region=Rect2(index*96,0,96,96);frame.filter_clip=true;frames.add_frame(&"guide",frame)
	_arrow.sprite_frames=frames;_arrow.scale=Vector2.ONE*(30.0/96);_arrow.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;_arrow.z_index=40;add_child(_arrow);_arrow.play(&"guide")
	var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;_arrow.material=ink
	_hud=CanvasLayer.new();_hud.layer=8;add_child(_hud);_root=UiFactory.full_rect();_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;_hud.add_child(_root)
	var row:=UiFactory.hbox(14);row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);row.position=Vector2(-270,12);row.size=Vector2(540,45);_root.add_child(row)
	_row=row
	_caption=PixelUi.label("",17,Color.WHITE);_caption.add_theme_color_override("font_outline_color",Color("14211c"));_caption.add_theme_constant_override("outline_size",4);row.add_child(_caption)
	var skip:=PixelUi.compact_button("结束引导",15);row.add_child(skip);skip.pressed.connect(_finish.bind(true))
	UIFlow.stack_changed.connect(_sync_visibility);world.connect("facility_opened",_on_opened);world.connect("facility_closed",_on_closed)
	_read_profile();_sync_visibility()
static func restart()->bool:
	var old:Dictionary=SaveService.data.duplicate(true);var previous:Dictionary=SaveService.data.get("camp_tutorial",{})
	SaveService.data.camp_tutorial={"generation":int(previous.get("generation",0))+1,"step":0,"completed":false,"enabled":true}
	if not SaveService.save_data():SaveService.data=old;return false
	return true
func _read_profile()->void:
	var profile:Dictionary=SaveService.data.get("camp_tutorial",{})
	_generation=int(profile.get("generation",1));step=clampi(int(profile.get("step",0)),0,STEPS.size()-1)
	active=not bool(world.get("editor_validation")) and bool(profile.get("enabled",true)) and not bool(profile.get("completed",false))
	phase="delay";_delay=.8;_opened=false;_pending_advance=false
func _process(dt:float)->void:
	if not is_instance_valid(world) or not is_instance_valid(world.get("player")):return
	var profile:Dictionary=SaveService.data.get("camp_tutorial",{})
	if int(profile.get("generation",1))!=_generation:_read_profile()
	if not active:_sync_visibility();return
	var view:=get_viewport().get_visible_rect().size
	_row.position=Vector2(-minf(270,(view.x-30)*.5),view.y-250 if view.x<1100 else 12);_row.size.x=minf(540,view.x-30)
	if UIFlow.has_screen() or TransitionLayer.busy:return
	if not bool(SaveService.data.get("input_guide_seen",false)):
		phase="key_guide";_sync_visibility()
		var guide:=CampKeyGuideUI.new();world.add_child(guide)
		guide.dismissed.connect(func():phase="delay";_delay=.35)
		return
	_clock+=dt
	if _pending_advance:
		_delay-=dt
		if _delay<=0:_advance()
	elif phase=="delay":
		_delay-=dt
		if _delay<=0:_introduce()
	elif phase=="follow":
		_update_arrow()
		if STEPS[step].mode=="approach" and origin().distance_to(approach_target())<105:_queue_advance()
	_sync_visibility()
func _introduce()->void:
	phase="dialogue";_sync_visibility()
	var info:Dictionary=STEPS[step];var text:String=str(info.text)
	if info.mode=="interact":text+="\n交互键："+KeyBindings.label("interact")+"。"
	var dialogue:DialogueUI=world.get("dialogue")
	dialogue.finished.connect(_introduced,CONNECT_ONE_SHOT)
	dialogue.play_local_lines([{"who":"伊莉丝","text":text,"portrait":CampResidents.ROOT+"iris_"+str(info.pose)+".png"}],"伊莉丝 · 营地引导")
func _introduced()->void:
	if not active:return
	if STEPS[step].mode=="auto":_queue_advance()
	else:phase="follow";_opened=false;_update_arrow();_sync_visibility()
func target()->Vector2:
	if not is_instance_valid(world):return Vector2.ZERO
	var role:String=str(STEPS[step].role)
	if role=="gates":return (world.get("level") as RoomLevel).door_point(Vector2i.DOWN)
	return world.call("facility_guide_center",role)
func origin()->Vector2:
	return world.call("player_collision_center")
func approach_target()->Vector2:
	var role:String=str(STEPS[step].role)
	# Keep the editor's interaction point as the accessible destination. The
	# center of a solid footprint itself is not somewhere the player can stand.
	return (world.get("facilities") as Dictionary).get(role,target())
func _update_arrow()->void:
	var room:RoomLevel=world.get("level");var from:=origin();var goal:=target();var approach:=approach_target()
	var direction:Vector2
	if float(world.call("facility_interaction_distance",str(STEPS[step].role)))<72:direction=(goal-from).normalized()
	else:direction=room.path_direction(from,approach,12,false)
	if direction.is_zero_approx():direction=(goal-from).normalized()
	if direction.is_zero_approx():direction=Vector2.DOWN
	var heading:=room.global_transform.basis_xform(direction).normalized()
	_arrow.global_position=room.to_global(from)+heading*40+Vector2(0,-10+sin(_clock*5)*2);_arrow.global_rotation=heading.angle()
	_caption.text="营地引导 %d/%d · %s · %s 交互"%[step,STEPS.size()-2,CampWorld.FACILITY_NAMES.get(str(STEPS[step].role),"营地"),KeyBindings.label("interact")]
func _on_opened(role:String)->void:
	if active and phase=="follow" and str(STEPS[step].role)==role:_opened=true
func _on_closed(role:String)->void:
	if active and phase=="follow" and _opened and str(STEPS[step].role)==role:_queue_advance()
func _queue_advance()->void:
	phase="delay";_delay=.55;_pending_advance=true;_sync_visibility()
func _advance()->void:
	if step+1>=STEPS.size():_finish(false);return
	var old:Dictionary=SaveService.data.duplicate(true);var profile:Dictionary=SaveService.data.get("camp_tutorial",{}).duplicate(true)
	profile.step=step+1;SaveService.data.camp_tutorial=profile
	if not SaveService.save_data():SaveService.data=old;_delay=3;return
	step+=1;_pending_advance=false;phase="delay";_delay=.1
func _finish(skipped:bool)->void:
	if not active:return
	var old:Dictionary=SaveService.data.duplicate(true);var profile:Dictionary=SaveService.data.get("camp_tutorial",{}).duplicate(true)
	profile.completed=true;profile.step=STEPS.size();profile.skipped=skipped;SaveService.data.camp_tutorial=profile
	if not SaveService.save_data():SaveService.data=old;_delay=3;return
	active=false;_pending_advance=false;_sync_visibility()
	var notice:=CampNotice.new();notice.message=("营地引导已关闭。" if skipped else "营地介绍完成，接下来可以自由准备与训练。")+"\n下次若忘记操作，可在「设置 → 重新开启营地引导」再次观看。";world.add_child(notice)
func _sync_visibility()->void:
	var shown:=active and phase=="follow" and not UIFlow.has_screen()
	if is_instance_valid(_arrow):_arrow.visible=shown
	if is_instance_valid(_root):_root.visible=shown
func shutdown()->void:
	active=false;_sync_visibility();set_process(false)
