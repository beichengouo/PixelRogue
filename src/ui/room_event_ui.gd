class_name RoomEventUI
extends DialogueUI
## Local dialogue uses shared story presentation without story side effects.
var controller:RoomExpansionController
var text:Label
var buttons:VBoxContainer
var _initializing:=true
func _ready()->void:
	super._ready();layer=44;text=_text_label;buttons=_choice_box
	var stage:=int(controller.state.get("dialogue",0));var id:=str(controller.state.event_id)
	_open();layer=44;_repeat_read_only=true;_scene_id=&"";_scene={};_tail_played=true;_pending_next=&""
	_chapter.text=str(controller.TITLES[id]);_skip_button.text="直接选择"
	_play_lines([{"who":"遗留之物","text":str(controller.INTRO[id])},{"who":"player","text":str(controller.REPLIES.get(str(Characters.current_id()),controller.REPLIES.sylphiette)[id])}],"local_event")
	if stage>=2:_after_lines()
	else:_show_line(clampi(stage,0,1))
	_initializing=false
func _show_line(index:int)->void:
	super._show_line(index)
	if not _initializing:controller.state.dialogue=index;controller._checkpoint()
func _after_lines()->void:
	controller.state.dialogue=2;controller._checkpoint()
	_name_label.text=Characters.current_name();_role.text="抉择";_progress.text="异闻回应"
	_full="留下怎样的回应？每间房只能选择一次，所有收益如下。";_text_label.text=_full;_text_label.visible_characters=-1
	var choices:Array=[]
	for index in controller.state.offers.size():
		var offer:Dictionary=controller.state.offers[index];choices.append({"index":index,"text":str(offer.name)+"\n"+str(offer.desc)})
	_show_choices(choices)
func _skip_story()->void:_after_lines()
func _pick(option:Dictionary)->void:
	if not UIFlow.is_top(self) or not _choosing or _closing or not option in _offered:return
	_claim(int(option.index))
func _claim(index:int)->void:
	if _closing:return
	if not controller.claim_event(index):_text_label.text="保存失败，奖励尚未发放。请重试。";_text_label.visible_characters=-1
func _refresh()->void:
	if int(controller.state.dialogue)>=2:_after_lines()
	else:_show_line(int(controller.state.dialogue))
func close(preserve_resume:=false)->void:
	if _closing:return
	if not preserve_resume:controller.state.event_panel_open=false;controller._checkpoint()
	cancel();_closing=true;queue_free()
func _input(event:InputEvent)->void:
	if UIFlow.is_top(self) and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		close();get_viewport().set_input_as_handled();return
	super._input(event)
