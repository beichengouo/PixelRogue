class_name CampResidentPanel
extends CanvasLayer
var world:Node
var resident:CampResident
var _root:Control
var _body:VBoxContainer
var _status:Label
var _workshop:MaterialWorkshopUI
var _selected:=-1
var _return_focus:Control
func _ready()->void:
	layer=32;process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true)
	_root=UiFactory.full_rect();add_child(_root);_root.add_child(UiFactory.dim_layer(0.42))
	var frame:=StarUi.frame(_root,Vector2(720,500))
	var scroll:=ScrollContainer.new();scroll.follow_focus=true;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;frame.add_child(scroll);scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body=UiFactory.vbox(14);_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(_body);_root.hide()
	InteractionSkin.mount(_root,"resident",frame)

func is_open()->bool:return _root.visible
func open_for(npc:CampResident)->void:
	if UIFlow.has_screen() or not is_instance_valid(npc):return
	resident=npc;resident.interacting=true
	_selected=CampResidents.contract_index(resident.resident_id)
	var info:Dictionary=CampResidents.DATA[resident.resident_id]
	var lines:Array=info.greeting
	var index:=CampResidents.contract_index(resident.resident_id)
	if index>=0:
		var status:=Outpost.contract_status(ExpeditionData.CONTRACTS[index])
		if status=="accepted":lines=["你回来啦。"+("需要的材料已经备齐了，来核对一下仓库记录吧。" if CampResidents.progress(resident.resident_id)=="ready" else "我还记得你的委托，不必重新接取。"),CampResidents.story_chat(resident.resident_id)]
		elif status=="completed":lines=["那份委托已经办妥，多谢你。",CampResidents.story_chat(resident.resident_id)]
	_talk(lines,_show)
func _talk(lines:Array,then:Callable)->void:
	if not is_instance_valid(resident) or not is_instance_valid(world):return
	var output:Array=[];var info:Dictionary=CampResidents.DATA[resident.resident_id]
	for line in lines:
		var row:Dictionary=line.duplicate(true) if line is Dictionary else {"text":str(line)}
		if not row.has("who"):row.who=info.name
		if not row.has("portrait"):row.portrait=CampResidents.ROOT+resident.resident_id+"_portrait.png"
		if not row.has("expression"):row.expression="neutral"
		output.append(row)
	var dialogue:DialogueUI=world.get("dialogue")
	dialogue.finished.connect(then,CONNECT_ONE_SHOT);dialogue.play_local_lines(output)
func _show()->void:
	if not is_instance_valid(resident) or not is_inside_tree() or not is_instance_valid(world):return
	if UIFlow.has_screen():release_resident();return
	for node in _body.get_children():_body.remove_child(node);node.queue_free()
	var info:Dictionary=CampResidents.DATA[resident.resident_id];_body.add_child(PixelUi.title(str(info.name)+" · "+str(info.role),25))
	var indices:=CampResidents.contract_indices(resident.resident_id)
	if _selected not in indices:_selected=CampResidents.contract_index(resident.resident_id)
	var index:=_selected
	var choices:=HFlowContainer.new();choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_body.add_child(choices)
	for choice in indices:
		var entry:Dictionary=ExpeditionData.CONTRACTS[choice];var state:=Outpost.contract_status(entry)
		var marker:String={"available":"可接","accepted":"进行中","completed":"已完成","locked":"未解锁","expired":"稍后重接"}.get(state,state)
		if CampResidents.ready(entry):marker="可交付"
		var button:=PixelUi.compact_button(str(entry.title)+" · "+marker,16)
		button.toggle_mode=true;button.button_pressed=choice==index;button.name="Commission_"+str(entry.id)
		button.pressed.connect(_select.bind(choice));choices.add_child(button)
	if index<0:
		_text(str(CampResidents.story_chat(resident.resident_id)));_button("再听一段故事",func()->void:close(false);_talk([CampResidents.story_chat(resident.resident_id)],release_resident))
	else:
		var contract:Dictionary=ExpeditionData.CONTRACTS[index];var status:=Outpost.contract_status(contract)
		_text(str(contract.title),21);_text(str(contract.desc))
		var job:Dictionary=Outpost.data.get("contract_jobs",{}).get(str(contract.id),{})
		if status=="accepted" and int(job.get("cost_revision",0))<34:_text("旧委托仍按接取时的数量交付，以下材料清单为准。",16)
		if bool(contract.get("story",false)):
			var phase:="finished" if status=="completed" else "offer"
			_button("回顾这段故事" if status=="completed" else "聊聊这份委托",_story.bind(index,phase))
			_text("生活委托 · 超时不扣好感 · 完成后解锁下一段",16)
		_text("奖励 %d 金 · %s好感 +%d · 接取后 %d 小时内带回"%[contract.reward,BondRules.NAMES[contract.owner],contract.bond,contract.hours],16)
		for id in Outpost.contract_needs(contract):_text("%s：仓库 %d / 需要 %d"%[ExpeditionData.resolve(str(id)).name,int(Outpost.data.inventory.get(id,0)),int(Outpost.contract_needs(contract)[id])],16)
		if status=="available":_button("接取委托",_accept.bind(index))
		elif status=="accepted":
			_button("交付仓库材料",_claim.bind(index),not CampResidents.ready(contract))
			_button("追踪委托",func()->void:Outpost.track_contract(str(contract.id));_status.text="已追踪 · 撤回后找我交付")
		else:
			var message:String={"completed":"这份委托已经完成。","locked":"先完成前置委托，再来找我。","expired":"委托已超时，一小时冷却结束后可以重新接取。"}.get(status,status)
			if status=="locked":
				for prior:Dictionary in ExpeditionData.CONTRACTS:
					if str(prior.id)==str(contract.get("require","")):message="先完成「%s」。"%str(prior.title);break
			_text(message)
	_status=PixelUi.label("",16,PixelUi.GOLD);_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_body.add_child(_status)
	if resident.resident_id=="carpenter":_button("布琳娜的制作与研究",_open_workshop)
	_button("返回营地",close)
	_root.show();UIFlow.push_screen(self);PixelUi.focus_button(_root)
func _select(index:int)->void:
	UIFlow.pop_screen(self);_selected=index;_show()
	_return_focus=_body.find_child("Commission_"+str(ExpeditionData.CONTRACTS[index].id),true,false) as Control
	if is_instance_valid(_return_focus):_return_focus.grab_focus()
func _story(index:int,phase:String)->void:
	_return_focus=get_viewport().gui_get_focus_owner()
	close(false);_talk(CampCommissionCatalog.story(str(ExpeditionData.CONTRACTS[index].id),phase),_resume)
func _resume()->void:
	_show()
	var selected:=_body.find_child("Commission_"+str(ExpeditionData.CONTRACTS[_selected].id),true,false) as Control
	if is_instance_valid(selected):selected.grab_focus()
func _text(value:String,font_size:=18)->void:
	var label:=PixelUi.label(value,font_size);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_body.add_child(label)
func _button(caption:String,callback:Callable,disabled:=false)->void:
	var button:=PixelUi.compact_button(caption,18);button.disabled=disabled;button.pressed.connect(callback);_body.add_child(button)
func _accept(index:int)->void:
	if not Outpost.accept_contract(index,-1,resident.resident_id,world.camp_ui.chapter_id):_status.text="暂时不能接取或保存失败，请重试。";return
	close(false);resident.refresh_badge()
	var story:=CampCommissionCatalog.story(str(ExpeditionData.CONTRACTS[index].id),"offer")
	story.append_array(CampCommissionCatalog.story(str(ExpeditionData.CONTRACTS[index].id),"accepted"))
	_talk(story if not story.is_empty() else CampResidents.DATA[resident.resident_id].accepted,release_resident)
func _claim(index:int)->void:
	if not Outpost.claim_contract(index,-1,resident.resident_id):_status.text="材料不足、已超时或保存失败，物资未交付。";return
	close(false);resident.refresh_badge()
	var story:=CampCommissionCatalog.story(str(ExpeditionData.CONTRACTS[index].id),"finished")
	_talk(story if not story.is_empty() else CampResidents.DATA[resident.resident_id].finished,release_resident)
func release_resident()->void:
	if is_instance_valid(resident):resident.interacting=false
func close(release:=true)->void:
	if is_instance_valid(_workshop):_workshop.close()
	_root.hide();UIFlow.pop_screen(self)
	if release:release_resident()
func _unhandled_input(event:InputEvent)->void:
	if is_open() and UIFlow.is_top(self) and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):close();get_viewport().set_input_as_handled()

func _open_workshop()->void:
	if not is_instance_valid(_workshop):_workshop=MaterialWorkshopUI.new();add_child(_workshop)
	_workshop.open_camp()
