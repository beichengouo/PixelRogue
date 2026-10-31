class_name BossEntranceUI
extends CanvasLayer
signal finished
var _root:Control
var _card:Control
var _title:Label
var _subtitle:Label
var _subtitle_art:TextureRect
var _icon:TextureRect
var _skip:Button
var _shade:ColorRect
var _motif:TextureRect
var _foreground:TextureRect
var _name_art:TextureRect
var _counter:Label
var _voice:AudioStreamPlayer
var _epoch:=0
var _active:=false
var _running:=false
var _finishing:=false
var _elapsed:=0.0
var _ending_age:=0.0
var _duration:=3.0
var _short:=false
var _rush:=false
var _sound_played:=false
var _released:=false
var _id:StringName=&""
var _pack:Dictionary={}
var _boss:WeakRef
var _main:WeakRef
var _room_id:=""
var _receipt:=""
var _stage:Node2D
var _ghost:AnimatedSprite2D
var _floor:Sprite2D
var _boss_visible:=true
var _camera_state:Dictionary={}
var _portrait_at:=Vector2.ZERO
var _name_at:=Vector2.ZERO
var _save_seen:Callable

func _ready()->void:
	set_meta("blocking_screen",true);set_meta("wait_for_previous_screen",true);layer=35;process_mode=Node.PROCESS_MODE_ALWAYS
	_root=UiFactory.full_rect();_root.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(_root)
	_shade=UiFactory.dim_layer(.55);_root.add_child(_shade)
	_motif=_texture();_root.add_child(_motif)
	_card=Control.new();_card.mouse_filter=Control.MOUSE_FILTER_IGNORE;_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_root.add_child(_card)
	_icon=_texture();_card.add_child(_icon);_foreground=_texture();_card.add_child(_foreground);_name_art=_texture();_card.add_child(_name_art)
	_title=PixelUi.title("",42);_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_title.mouse_filter=Control.MOUSE_FILTER_IGNORE;_card.add_child(_title)
	_subtitle=PixelUi.label("",22);_subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_subtitle.mouse_filter=Control.MOUSE_FILTER_IGNORE;_card.add_child(_subtitle)
	_subtitle_art=_texture();_card.add_child(_subtitle_art)
	_counter=PixelUi.label("",18,PixelUi.GOLD);_counter.mouse_filter=Control.MOUSE_FILTER_IGNORE;_root.add_child(_counter)
	_skip=PixelUi.compact_button("跳过",16);_skip.pressed.connect(_skip_intro);_root.add_child(_skip);InteractionSkin.apply_button(_skip,"boss_entrance")
	_voice=AudioStreamPlayer.new();_voice.name="BossEntranceAccent";add_child(_voice)
	_root.resized.connect(_layout);_root.hide()
	EventBus.boss_started.connect(_legacy_start);EventBus.run_started.connect(func(_value:int)->void:cancel());EventBus.player_died.connect(cancel)
	UIFlow.input_device_changed.connect(_refresh_skip_hint)
func _refresh_skip_hint()->void:
	if is_instance_valid(_skip):_skip.text="跳过" if MobileControls.enabled() else "%s · 跳过"%UIFlow.hint(&"ui_accept")
func _texture()->TextureRect:
	var node:=TextureRect.new();node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;node.mouse_filter=Control.MOUSE_FILTER_IGNORE;return node
func _legacy_start(id:StringName)->void:
	if not GameState.runtime_node is RoomRuntime:play(id)
func present(boss:RoomBoss)->void:
	if not is_instance_valid(boss) or boss.get_meta("boss_entrance_requested",false):return
	var host:Node=boss.director.get_parent() if is_instance_valid(boss.director) else null
	if not is_instance_valid(host) or not is_instance_valid(GameState.runtime_node) or GameState.runtime_node._restoring:return
	var record:Dictionary=host.graph.rooms[host.graph.current]
	var key:="%s:%d"%[boss.boss_id,host.director.rush_index if record.kind=="boss_rush" else -1]
	if bool(record.delta.get("boss_entrances",{}).get(key,false)):return
	boss.set_meta("boss_entrance_requested",true)
	play(boss.boss_id,{"boss":boss,"main":host,"room":str(host.graph.current),"receipt":key,"rush":record.kind=="boss_rush","index":host.director.rush_index})
func play(id:StringName,context:Dictionary={})->void:
	if is_instance_valid(GameState.runtime_node) and GameState.runtime_node._restoring:return
	cancel();_epoch+=1;var ticket:=_epoch
	_id=id;_pack=BossEntranceArt.pack(str(id));_rush=bool(context.get("rush",false));_short=_rush or bool(SaveService.data.get("boss_entrances_seen",{}).get(str(id),false));_duration=1.0 if _short else 3.0
	_boss=weakref(context.boss) if is_instance_valid(context.get("boss")) else null;_main=weakref(context.main) if is_instance_valid(context.get("main")) else null
	_room_id=str(context.get("room",""));_receipt=str(context.get("receipt",""))
	if _boss!=null:_boss_visible=context.boss.visible;context.boss.hide()
	var data:=BossRoster.get_data(id)
	_icon.texture=_pack.portrait;_name_art.texture=_pack.title;_title.text=str(data.title);_title.visible=_pack.title==null
	_title.add_theme_color_override("font_color",_pack.color);_subtitle.text=str(data.subtitle);_subtitle.visible=not _short
	_subtitle_art.texture=_pack.get("subtitle");_subtitle_art.visible=not _short and _subtitle_art.texture!=null;_subtitle.visible=not _short and _subtitle_art.texture==null
	_motif.texture=_pack.motif[mini(1,_pack.motif.size()-1)] if not _pack.motif.is_empty() else null;_foreground.texture=_pack.foreground[mini(1,_pack.foreground.size()-1)] if not _pack.foreground.is_empty() else _motif.texture
	_counter.text="BOSS RUSH · %d / 3"%(int(context.get("index",0))+1) if _rush else "强敌来袭"
	_refresh_skip_hint()
	_active=true;_running=false;_finishing=false;_elapsed=0;_ending_age=0;_released=false;_sound_played=false
	_root.modulate.a=1;_root.hide();UIFlow.push_screen(self)
	while ticket==_epoch:
		var host:Node=_main.get_ref() if _main!=null else null
		if _main!=null and (not is_instance_valid(host) or str(host.graph.current)!=_room_id):cancel();return
		if UIFlow.is_top(self) and (host==null or (not host._room_transfer and not host._navigation_pending and host._story_context.is_empty() and host._story_queue.is_empty())):break
		await get_tree().process_frame
	if ticket!=_epoch:return
	_running=true;_root.show();_layout();_paint();AudioManager.set_presentation_duck(self,true)
func _layout()->void:
	if not is_instance_valid(_root):return
	var view:=_root.size
	if view.x<=0 or view.y<=0:view=get_viewport().get_visible_rect().size
	_portrait_at=Vector2(view.x*.48,view.y*.055);_icon.position=_portrait_at;_icon.size=Vector2(view.x*.50,view.y*.89)
	_name_at=Vector2(view.x*.045,view.y*.38);_name_art.position=_name_at;_name_art.size=Vector2(view.x*.53,view.y*.20)
	_title.position=_name_at;_title.size=_name_art.size;_title.add_theme_font_size_override("font_size",clampi(roundi(view.x/34),22,52))
	_subtitle.position=Vector2(view.x*.065,view.y*.61);_subtitle.size=Vector2(view.x*.40,view.y*.16);_subtitle.add_theme_font_size_override("font_size",clampi(roundi(view.x/72),15,25))
	_subtitle_art.position=Vector2(view.x*.055,view.y*.60);_subtitle_art.size=Vector2(view.x*.43,view.y*.085)
	_counter.position=Vector2(view.x*.065,view.y*.23);_counter.size=Vector2(view.x*.6,32);_counter.add_theme_font_size_override("font_size",clampi(roundi(view.x/95),14,20))
	_motif.position=Vector2(view.x*.19,-view.y*.10);_motif.size=Vector2(view.x*.85,view.y*1.2)
	_foreground.position=Vector2(view.x*.42,view.y*.35);_foreground.size=Vector2(view.x*.56,view.y*.64)
	_skip.size=Vector2(clampf(view.x*.18,150,280),maxf(44,view.y*.055));_skip.position=view-_skip.size-Vector2(maxf(28,view.x*.035),maxf(24,view.y*.04))
	if MobileControls.enabled():
		var safe:=MobileControls.safe_rect().intersection(Rect2(Vector2.ZERO,view))
		if safe.has_area():
			_skip.position.x=clampf(_skip.position.x,safe.position.x,maxf(safe.position.x,safe.end.x-_skip.size.x));_skip.position.y=clampf(_skip.position.y,safe.position.y,maxf(safe.position.y,safe.end.y-_skip.size.y))
			_name_at.x=maxf(_name_at.x,safe.position.x+12);_name_art.position=_name_at;_title.position=_name_at
			_counter.position.x=maxf(_counter.position.x,safe.position.x+12);_subtitle.position.x=maxf(_subtitle.position.x,safe.position.x+12)
			_subtitle_art.position.x=maxf(_subtitle_art.position.x,safe.position.x+12)
func _process(dt:float)->void:
	if not _active or not _running:return
	if _main!=null:
		var host:Node=_main.get_ref();var body:Node=_boss.get_ref() if _boss!=null else null
		if not is_instance_valid(host) or not is_instance_valid(body) or body._dead or str(host.graph.current)!=_room_id:cancel();return
	_elapsed+=dt
	if not Input.is_action_pressed("ui_accept") and not Input.is_action_pressed("ui_cancel") and not Input.is_action_pressed("pause_menu") and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):_released=true
	_skip.disabled=not _released or _elapsed<.2 or _finishing;_paint()
	if _finishing:_ending_age+=dt;_root.modulate.a=1-clampf(_ending_age/.15,0,1);return
	if _elapsed>=_duration-.15:_finish()
func _paint()->void:
	var reduced:=ComicMotion.reduced();var enter:=smoothstep(0,.18 if _short else .70,maxf(0,_elapsed-(0 if _short else .35)))
	var arena_at:=.55 if _short else 2.05;var arena:=smoothstep(arena_at,arena_at+(.3 if _short else .70),_elapsed)
	_shade.color=Color(.025,.035,.06,.55*(1-arena*.88));_icon.position=_portrait_at+Vector2(0 if reduced else (1-enter)*65,0);_icon.modulate.a=enter*(1-arena)
	_motif.modulate=Color(_pack.color,.18*smoothstep(0,.3,_elapsed)*(1-arena));_motif.rotation=0 if reduced else sin(_elapsed*.45)*.025
	_foreground.modulate=Color(_pack.color,.20*enter*(1-arena));_foreground.position.y=_root.size.y*.35+(0 if reduced else sin(_elapsed)*9)
	var naming:=smoothstep(.05 if _short else 1.05,.18 if _short else 1.30,_elapsed)
	_name_art.modulate.a=naming*(1-arena);_title.modulate.a=_name_art.modulate.a;_subtitle.modulate.a=naming*(1-arena)
	_subtitle_art.modulate.a=_subtitle.modulate.a
	_name_art.position=_name_at+Vector2(0 if reduced else (1-naming)*-20,0);_counter.modulate.a=enter*(1-arena)
	if naming>0 and not _sound_played:
		_sound_played=true
		if _pack.sound!=null:_voice.stream=_pack.sound;_voice.volume_db=-8+linear_to_db(maxf(.0001,AudioManager.sfx_volume()));_voice.play()
	if _elapsed>=arena_at:_show_arena();_stage_tick(clampf((_elapsed-arena_at)/(.30 if _short else .80),0,1))
func _show_arena()->void:
	if is_instance_valid(_stage) or _boss==null or _main==null:return
	var body:RoomBoss=_boss.get_ref();var host:Node=_main.get_ref()
	if not is_instance_valid(body) or not is_instance_valid(host):return
	_stage=Node2D.new();_stage.name="BossEntranceVisualOnly";_stage.process_mode=Node.PROCESS_MODE_ALWAYS;host.fx_root.add_child(_stage);_stage.global_position=body.global_position
	_floor=Sprite2D.new();_floor.texture=_motif.texture;_floor.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	if _floor.texture!=null:_floor.scale=Vector2.ONE*100/maxf(1,_floor.texture.get_width())
	_floor.position=Vector2(0,body.body_size.y*.5);_floor.modulate.a=.6;_stage.add_child(_floor)
	_ghost=AnimatedSprite2D.new();_ghost.sprite_frames=BossStageArt.frames(_id,1);_ghost.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;_stage.add_child(_ghost)
	_ghost.play(&"windup");_ghost.pause();PixelBossArt.align(_ghost,_id,body.body_size)
	var camera:RoomCamera=host.camera
	_camera_state={"position":camera.global_position,"offset":camera.offset,"follow":camera._follow_position,"shake":camera.shake_amount,"process":camera.is_processing()};camera.set_process(false);camera.offset=Vector2.ZERO
func _stage_tick(progress:float)->void:
	if not is_instance_valid(_stage) or _main==null:return
	var host:Node=_main.get_ref();var body:RoomBoss=_boss.get_ref() if _boss!=null else null
	if not is_instance_valid(host) or not is_instance_valid(body):return
	var action:StringName=&"windup" if progress<.35 else &"release"
	if _ghost.animation!=action:_ghost.play(action);_ghost.pause()
	var phase:=progress/.35 if action==&"windup" else (progress-.35)/.65
	_ghost.frame=clampi(int(phase*_ghost.sprite_frames.get_frame_count(action)),0,_ghost.sprite_frames.get_frame_count(action)-1);PixelBossArt.align(_ghost,_id,body.body_size);_stage.modulate.a=smoothstep(0,.2,progress)
	var camera:RoomCamera=host.camera;var focus:Vector2=(_camera_state.position as Vector2).lerp(body.global_position,.6)
	focus=camera._clamp_to_background(focus,camera._background_frame(),camera.get_viewport_rect().size,camera.zoom.x)
	camera.global_position=(_camera_state.position as Vector2).lerp(focus,0 if ComicMotion.reduced() else smoothstep(0,.7,progress));camera.force_update_scroll()
func _finish()->void:
	if not _active or _finishing:return
	_finishing=true;_ending_age=0;_elapsed=maxf(_elapsed,_duration-.15);var ticket:=_epoch;_show_arena();_stage_tick(1);AudioManager.set_presentation_duck(self,false)
	await get_tree().create_timer(.15,true,false,true).timeout
	if ticket!=_epoch:return
	_running=false;_record_completion();_restore_stage();_root.hide();_voice.stop()
	await get_tree().process_frame;await get_tree().process_frame
	if ticket!=_epoch:return
	_active=false;_running=false;UIFlow.pop_screen(self);finished.emit()
func _record_completion()->void:
	if _main!=null:
		var host:Node=_main.get_ref()
		if is_instance_valid(host) and str(host.graph.current)==_room_id:
			var delta:Dictionary=host.graph.rooms[_room_id].delta
			if not delta.has("boss_entrances"):delta.boss_entrances={}
			delta.boss_entrances[_receipt]=true
	if _rush or _short:return
	var previous:Dictionary=SaveService.data.get("boss_entrances_seen",{}).duplicate(true);var next:=previous.duplicate(true);next[str(_id)]=true;SaveService.data.boss_entrances_seen=next
	var saved:bool=bool(_save_seen.call()) if _save_seen.is_valid() else SaveService.save_data()
	if not saved:SaveService.data.boss_entrances_seen=previous
func _restore_stage()->void:
	if is_instance_valid(_stage):_stage.queue_free()
	_stage=null;_ghost=null;_floor=null
	var body:Node=_boss.get_ref() if _boss!=null else null
	if is_instance_valid(body):body.visible=_boss_visible
	var host:Node=_main.get_ref() if _main!=null else null
	if is_instance_valid(host):
		if is_instance_valid(host.camera) and not _camera_state.is_empty():
			var camera:RoomCamera=host.camera
			camera.global_position=_camera_state.position;camera.offset=_camera_state.offset;camera._follow_position=_camera_state.follow;camera.shake_amount=_camera_state.shake;camera.set_process(bool(_camera_state.process));camera.force_update_scroll()
		if is_instance_valid(host.player):
			host.player.movement_override=Vector2.ZERO;host.player.aim_override=Vector2.ZERO;host.player.firing=false
			host.player.caster.clear_input_buffer()
			if RoomInput.using_mouse():host.player._mouse_attack_blocked=true
	_camera_state.clear()
func cancel()->void:
	var had:=_active;_epoch+=1;_active=false;_running=false;_finishing=false;_restore_stage();_boss=null;_main=null
	if is_instance_valid(_root):_root.hide()
	if is_instance_valid(_voice):_voice.stop()
	AudioManager.set_presentation_duck(self,false);UIFlow.pop_screen(self)
	if had:finished.emit()
func _exit_tree()->void:_epoch+=1;_restore_stage();AudioManager.set_presentation_duck(self,false)
func _skip_intro()->void:
	if _active and _running and not _finishing and _released and _elapsed>=.2:_finish()
func _input(event:InputEvent)->void:
	if not _active or not UIFlow.is_top(self):return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
		if not event.is_echo():_skip_intro()
		get_viewport().set_input_as_handled()
