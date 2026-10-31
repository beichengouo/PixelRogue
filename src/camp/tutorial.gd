class_name CampTutorial
extends Node2D
const STEPS := [
	{
		"role": "",
		"mode": "auto",
		"pose": "point",
		"text": "这里是星辉回廊，你们现在可以休息和归来的地方。我叫伊莉丝，照看归航灯。你们四人记得名字和本领，却想不起共同的旧经历；先别急着替空白编答案。你留在这里准备行囊和记录，三位伙伴亲自出征；回来以后，你们再一起核对找到的线索。"
	},
	{
		"role": "relations",
		"mode": "interact",
		"pose": "point",
		"text": "先去酒馆认识大家。温阮准备了热茶，也能帮你找到想交谈的伙伴。跟着箭头走，靠近门口后交互，看看再回来。"
	},
	{
		"role": "shop",
		"mode": "interact",
		"pose": "point",
		"text": "这是姜糖的商铺，出售装备、药剂，也能兑换材料。花的是营地金库里的金币，买到的东西先放进仓库。这次看看就好，不必买。"
	},
	{
		"role": "warehouse",
		"mode": "interact",
		"pose": "thoughtful",
		"text": "成功撤离带回的物资放在仓库。这里能整理、出售和保护物品，也能打开工坊制作与研究。正式出征装备、药剂和技能在营地背包调整，点击出发前不会扣库存。"
	},
	{
		"role": "contracts",
		"mode": "interact",
		"pose": "point",
		"text": "工会里可以查看调查与委托。金色标识是有新委托，蓝色是进行中，绿色是材料齐了；交付时去找发布委托的人。先进去看看。"
	},
	{
		"role": "iris",
		"mode": "interact",
		"pose": "thoughtful",
		"text": "有关于过去的问题，就到灯坛找我。能确认的我会讲清楚，不能确认的会告诉你还缺什么证据。你们想起彼此的片段，也可以在这里一起核对。"
	},
	{
		"role": "result",
		"mode": "interact",
		"pose": "thoughtful",
		"text": "记事台记录上一趟的收获和损失。成功撤离才带回物资，死亡损失本趟尚未入库的东西；以前存在仓库里的不受影响。"
	},
	{
		"role": "training",
		"mode": "approach",
		"pose": "point",
		"text": "这里仅是独立训练场的入口。进去以后可以打桩、试穿、调整临时等级和天赋；回营会恢复正式准备。现在走近看看即可，不必进去。"
	},
	{
		"role": "prepare",
		"mode": "interact",
		"pose": "point",
		"text": "先在营地背包调装备、药剂和技能，再到出发台选目的地与难度。点击出发就提交物资、直接进入冒险，不用再走大门。这里先看看，看完返回即可。"
	},
	{
		"role": "gates",
		"mode": "auto",
		"pose": "proud",
		"text": "设施就介绍到这里。第一趟去苏醒林地查旧路标，核对与你们旧物相似的标记；找到线索后可以先回来，不必一口气走到底。准备好了，到出发台点击出发。"
	}
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
	var entries:Array=[{"who":"伊莉丝","text":text,"expression":"neutral","portrait":CampResidents.ROOT+"iris_"+str(info.pose)+".png"}]
	if step==0:
		entries.append({"who":"","text":"你把黑斗篷拢好。你和希露媞雅、希希芙、伊露雅都记得自己的名字与本领，却想不起个人经历和共同过去。今天发生的事能够记住，不会每天重新忘掉。"})
		entries.append({"who":"伊莉丝","text":"旧灾难后，不少地方留下了失控的守卫和记录。黑晶会保存、重复声音和动作，内容有时残缺或被拼接。看见熟悉的东西先记下，回来和本人核对。","expression":"thoughtful"})
		entries.append({"who":"伊莉丝","text":"目前先查苏醒林地的旧路标，那里有与你们旧物相似的标记。归航联系能让我接回仍连着回廊的人，但死亡时遗落的物资带不回来。","expression":"neutral"})
		entries.append({"who":"伊莉丝","text":"今天先认识大家、整理行囊。移动与交互按键可以在设置里更改，接下来我带你看几个地方。","expression":"happy"})
	dialogue.play_local_lines(entries,"伊莉丝 · 营地引导")
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
