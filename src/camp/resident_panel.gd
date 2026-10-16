class_name CampResidentPanel
extends CanvasLayer
var world:Node
var resident:CampResident
var _root:Control
var _body:VBoxContainer
var _status:Label
var _workshop:MaterialWorkshopUI
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
	var info:Dictionary=CampResidents.DATA[resident.resident_id]
	var lines:Array=info.greeting
	var index:=CampResidents.contract_index(resident.resident_id)
	if index>=0:
		var status:=Outpost.contract_status(ExpeditionData.CONTRACTS[index])
		if status=="accepted":lines=["你回来啦。"+("需要的材料已经备齐了，来核对一下仓库记录吧。" if CampResidents.progress(resident.resident_id)=="ready" else "我还记得你的委托，不必重新接取。"),info.chat]
		elif status=="completed":lines=["那份委托已经办妥，多谢你。",info.chat]
	_talk(lines,_show)
func _talk(lines:Array,then:Callable)->void:
	if not is_instance_valid(resident) or not is_instance_valid(world):return
	var output:Array=[];var info:Dictionary=CampResidents.DATA[resident.resident_id]
	for line in lines:output.append({"who":info.name,"text":str(line),"portrait":CampResidents.ROOT+resident.resident_id+"_portrait.png"})
	var dialogue:DialogueUI=world.get("dialogue")
	dialogue.finished.connect(then,CONNECT_ONE_SHOT);dialogue.play_local_lines(output)
func _show()->void:
	if not is_instance_valid(resident) or not is_inside_tree() or not is_instance_valid(world):return
	if UIFlow.has_screen():release_resident();return
	for node in _body.get_children():_body.remove_child(node);node.queue_free()
	var info:Dictionary=CampResidents.DATA[resident.resident_id];_body.add_child(PixelUi.title(str(info.name)+" · "+str(info.role),25))
	var index:=CampResidents.contract_index(resident.resident_id)
	if index<0:
		_text(str(info.chat));_button("再听一段故事",func()->void:close(false);_talk([info.chat],release_resident))
	else:
		var contract:Dictionary=ExpeditionData.CONTRACTS[index];var status:=Outpost.contract_status(contract)
		_text(str(contract.title),21);_text(str(contract.desc))
		_text("奖励 %d 金 · %s好感 +%d · 接取后 %d 小时内带回"%[contract.reward,BondRules.NAMES[contract.owner],contract.bond,contract.hours],16)
		for id in Outpost.contract_needs(contract):_text("%s：仓库 %d / 需要 %d"%[ExpeditionData.resolve(str(id)).name,int(Outpost.data.inventory.get(id,0)),int(Outpost.contract_needs(contract)[id])],16)
		if status=="available":_button("接取委托",_accept.bind(index))
		elif status=="accepted":
			_button("交付仓库材料",_claim.bind(index),CampResidents.progress(resident.resident_id)!="ready")
			_button("追踪委托",func()->void:Outpost.track_contract(str(contract.id));_status.text="已追踪 · 撤回后找我交付")
		else:_text({"completed":"这份委托已经完成，下次有新消息我会告诉你。","locked":"先完成前置调查，再来找我。","expired":"委托已超时，原有冷却结束后可以重新接取。"}.get(status,status))
	_status=PixelUi.label("",16,PixelUi.GOLD);_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_body.add_child(_status)
	if resident.resident_id=="carpenter":_button("布琳娜的制作与研究",_open_workshop)
	_button("返回营地",close)
	_root.show();UIFlow.push_screen(self);PixelUi.focus_button(_root)
func _text(value:String,font_size:=18)->void:
	var label:=PixelUi.label(value,font_size);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_body.add_child(label)
func _button(caption:String,callback:Callable,disabled:=false)->void:
	var button:=PixelUi.compact_button(caption,18);button.disabled=disabled;button.pressed.connect(callback);_body.add_child(button)
func _accept(index:int)->void:
	if not Outpost.accept_contract(index,-1,resident.resident_id,world.camp_ui.chapter_id):_status.text="暂时不能接取或保存失败，请重试。";return
	close(false);resident.refresh_badge();_talk(CampResidents.DATA[resident.resident_id].accepted,release_resident)
func _claim(index:int)->void:
	if not Outpost.claim_contract(index,-1,resident.resident_id):_status.text="材料不足、已超时或保存失败，物资未交付。";return
	close(false);resident.refresh_badge();_talk(CampResidents.DATA[resident.resident_id].finished,release_resident)
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
