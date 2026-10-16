class_name FateChoiceUI
extends ItemChoiceUI
## Uses the same reveal / chosen / dissolve animation and pointer guards as loot.
## Card selection only opens a preview. The service commits after confirmation.
var room:Dictionary={}
var confirmation:GlassConfirmUI
var pending_index:=-1
var _committing:=false

func _ready()->void:
	super._ready()
	confirmation=GlassConfirmUI.new();add_child(confirmation)
	confirmation.confirmed.connect(_confirm_card)
	var title:=_column.get_child(0) as Label
	title.text="命运祭坛 · 选择命运"
	var tip:=_column.get_child(_column.get_child_count()-1) as Label
	tip.text="选择卡牌查看完整效果 · 确认后缔结\n%s / %s 切换 · %s 预览 · %s 暂时离开"%[KeyBindings.label("ui_left"),KeyBindings.label("ui_right"),KeyBindings.label("ui_accept"),KeyBindings.label("ui_cancel")]
	if MobileControls.enabled():tip.text="轻点卡牌查看完整效果 · 确认后缔结"

func open_reading(record:Dictionary)->void:
	room=record;pending_index=-1;_committing=false
	var reading:Dictionary=room.delta.get("fate_reading",{})
	var choices:Array[Dictionary]=[]
	for value in reading.get("offers",[]):choices.append({"fate_id":str(value),"reverse":FateService.orientation(room)})
	(_column.get_child(0) as Label).text="命运祭坛 · "+("逆位" if FateService.orientation(room) else "正位")
	open(choices)

func choose(index:int,defer_resume:=false)->void:
	if not UIFlow.is_top(self) or _choosing or index<0 or index>=offers.size() or not is_open():return
	if _committing:super.choose(index,defer_resume);return
	pending_index=index
	var card:Dictionary=offers[index]
	confirmation.title=str(FateCatalog.CARDS[card.fate_id].name)+(" · 逆位" if card.reverse else " · 正位")
	confirmation.dialog_text=FateCatalog.description(card.fate_id,card.reverse)+"\n\n"+BuildInsight.fate(card.fate_id,card.reverse)+"\n\n确认后本祭坛占卜结束，卡牌在本次出征中持续生效。"
	confirmation.popup_centered()

func _confirm_card()->void:
	if not is_open() or pending_index<0 or pending_index>=offers.size() or _committing:return
	var card:Dictionary=offers[pending_index]
	if not FateService.claim(room,str(card.fate_id),bool(card.reverse)):
		# Reopening the same confirm synchronously inside its confirmed signal
		# lets one key edge activate the new dialog. Leave the cards interactive.
		pending_index=-1
		(_column.get_child(0) as Label).text="保存失败 · 未获得卡牌，请重新选择"
		return
	_committing=true
	super.choose(pending_index,true)

func cancel()->void:
	if _committing:return
	confirmation.close();super.cancel()

func _build_card(index:int,item:Dictionary)->Control:
	var id:=str(item.fate_id);var reverse:=bool(item.reverse)
	var color:=Color("cd9aef") if reverse else Color("e8cf8b")
	var holder:=Button.new();holder.name="FateCard%d"%index;holder.button_mask=0
	holder.focus_mode=Control.FOCUS_ALL;holder.set_meta("glass_skip_style",true);holder.set_meta("focus_token","fate:"+id)
	holder.custom_minimum_size=CARD_SIZE+Vector2.ONE*24;holder.pivot_offset=holder.custom_minimum_size*.5
	for state in ["normal","hover","pressed","disabled","focus"]:holder.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	_cards.append(holder)
	if not ComicMotion.reduced():holder.add_child(_build_glow(color))
	var card:=Control.new();card.name="FateFace";card.size=CARD_SIZE;card.position=Vector2(12,12);card.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(card)
	var art:=TextureRect.new();art.texture=load(FateCatalog.art(id,reverse));art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position=Vector2(0,0);art.size=Vector2(300,450);art.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(art);_reward_icons.append(art)
	var name_label:=UiFactory.outlined_label(str(FateCatalog.CARDS[id].name)+(" · 逆位" if reverse else " · 正位"),22,color,4)
	name_label.position=Vector2(8,450);name_label.size=Vector2(284,36);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(name_label)
	holder.tooltip_text=FateCatalog.description(id,reverse)
	# The inherited pointer drag handler expects one scroll slot per card.
	var scroll:=ScrollContainer.new();scroll.position=Vector2(0,0);scroll.size=Vector2(300,450);scroll.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(scroll);_scrolls.append(scroll)
	holder.pressed.connect(func()->void:_choose_from_input(index,_selection_epoch,true))
	holder.focus_entered.connect(func()->void:_hover(holder,true));holder.focus_exited.connect(func()->void:_hover(holder,false))
	holder.mouse_entered.connect(func()->void:_hover(holder,true));holder.mouse_exited.connect(func()->void:_hover(holder,false))
	var effect:=RewardCardFX.new();holder.add_child(effect);effect.size=holder.custom_minimum_size;effect.configure(card,color);_card_effects.append(effect);_visuals.append(card)
	var back:=TextureRect.new();back.texture=load(FateCatalog.art("back"));back.position=Vector2(12,12);back.size=CARD_SIZE;back.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;back.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;back.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(back);_backs.append(back)
	holder.modulate.a=0;return holder

func _input(event:InputEvent)->void:
	if is_open() and UIFlow.is_top(self) and not _committing and not event.is_echo() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		cancel();get_viewport().set_input_as_handled();return
	super._input(event)
