extends ItemChoiceUI
## Initial-room stars reuse the existing tarot reveal/selection/dissolve pipeline.
var _committed:=false
var confirmation:GlassConfirmUI
var pending_index:=-1
func _ready()->void:
	super._ready()
	confirmation=GlassConfirmUI.new();add_child(confirmation)
	confirmation.confirmed.connect(_confirm_star)
	set_meta("starting_star_choice",true)
	(_column.get_child(0) as Label).text="初星启程 · 选择本次出征星象"
	(_column.get_child(_column.get_child_count()-1) as Label).text="悬停查看效果 · 点击预览并确认星象"
func open_stars()->void:
	if is_open() or not bool(GameState.fate.get("star_pending",false)):return
	_committed=false;pending_index=-1
	var values:Array[Dictionary]=[]
	for id in FateCatalog.STARS:values.append({"star_id":str(id)})
	open(values)
func choose_star(id:String)->bool:
	if not is_open() or _committed or not FateCatalog.STARS.has(id) or not bool(GameState.fate.get("star_pending",false)):return false
	var before:=GameState.fate.duplicate(true)
	GameState.fate.star=id;GameState.fate.star_pending=false
	var evidence:=AchievementTracker.stage("departure",{"star":id})
	if not SaveService.save_run(GameState.snapshot()):
		AchievementTracker.finish_stage(evidence,false);GameState.fate=before;(_column.get_child(0) as Label).text="保存失败 · 星象未改变，请重新选择";return false
	AchievementTracker.finish_stage(evidence,true)
	_committed=true;EventBus.player_stats_changed.emit();return true
func choose(index:int,defer_resume:=false)->void:
	if not UIFlow.is_top(self) or _choosing or index<0 or index>=offers.size():return
	if not is_open() or _committed:return
	pending_index=index
	var star:Dictionary=FateCatalog.STARS[str(offers[index].star_id)]
	confirmation.title=str(star.name)+" · "+str(star.theme)
	confirmation.dialog_text=str(star.description)+"\n\n确认后在本次出征持续生效。取消可返回选择其他星象。"
	confirmation.popup_centered()
func _confirm_star()->void:
	if pending_index<0 or pending_index>=offers.size() or _committed:return
	if choose_star(str(offers[pending_index].star_id)):super.choose(pending_index,true)
func cancel()->void:
	if _committed:return
	confirmation.close();pending_index=-1;super.cancel()
func _build_card(index:int,item:Dictionary)->Control:
	var id:=str(item.star_id);var reverse:=false
	var color:=Color("cd9aef") if reverse else Color("e8cf8b")
	var holder:=Button.new();holder.name="StarCard%d"%index;holder.button_mask=0
	holder.focus_mode=Control.FOCUS_ALL;holder.set_meta("glass_skip_style",true);holder.set_meta("focus_token","fate:"+id)
	holder.custom_minimum_size=CARD_SIZE+Vector2.ONE*24;holder.pivot_offset=holder.custom_minimum_size*.5
	for state in ["normal","hover","pressed","disabled","focus"]:holder.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	_cards.append(holder)
	if not ComicMotion.reduced():holder.add_child(_build_glow(color))
	var card:=Control.new();card.name="StarFace";card.size=CARD_SIZE;card.position=Vector2(12,12);card.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(card)
	var art:=TextureRect.new();art.texture=load(FateCatalog.art(id,reverse));art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position=Vector2(0,0);art.size=Vector2(300,450);art.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(art);_reward_icons.append(art)
	var name_art:=TextureRect.new();name_art.name="StarNameArt";name_art.texture=load(FateCatalog.star_wordmark(id))
	name_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;name_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	name_art.position=Vector2(8,433);name_art.size=Vector2(284,55);name_art.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(name_art)
	holder.tooltip_text=str(FateCatalog.STARS[id].name)+"\n"+str(FateCatalog.STARS[id].description)+"\n点击查看并确认 · 本次出征持续生效"
	holder.theme=InteractionSkin.theme()
	# The inherited pointer drag handler expects one scroll slot per card.
	var scroll:=ScrollContainer.new();scroll.position=Vector2(0,0);scroll.size=Vector2(300,450);scroll.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(scroll);_scrolls.append(scroll)
	holder.pressed.connect(func()->void:_choose_from_input(index,_selection_epoch,true))
	holder.focus_entered.connect(func()->void:_hover(holder,true));holder.focus_exited.connect(func()->void:_hover(holder,false))
	holder.mouse_entered.connect(func()->void:_hover(holder,true));holder.mouse_exited.connect(func()->void:_hover(holder,false))
	var effect:=RewardCardFX.new();holder.add_child(effect);effect.size=holder.custom_minimum_size;effect.configure(card,color);_card_effects.append(effect);_visuals.append(card)
	var back:=TextureRect.new();back.name="TarotBack";back.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;back.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;back.texture=load(FateCatalog.art("back"));back.position=Vector2(12,12);back.size=CARD_SIZE;back.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(back);_backs.append(back)
	holder.modulate.a=0;return holder

func _input(event:InputEvent)->void:
	if is_open() and UIFlow.is_top(self) and not _committed and not event.is_echo() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		cancel();get_viewport().set_input_as_handled();return
	super._input(event)
