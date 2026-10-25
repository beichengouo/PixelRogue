class_name BossPhaseUI
extends CanvasLayer
## Boss-owned presentation; the UIFlow pause lease freezes all gameplay clocks.
var boss:RoomBoss
var elapsed:=0.0
var duration:=1.5
var active:=false
var _root:Control
var _title:TextureRect
var _phase_name:Label
var _skip:Button
var _ghost:AnimatedSprite2D
var _old_ghost:AnimatedSprite2D
var _shade:ColorRect
var _released:=false
var _was_visible:=true
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;layer=35;set_meta("blocking_screen",true)
	_root=UiFactory.full_rect();_root.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(_root)
	_shade=UiFactory.dim_layer(.38);_root.add_child(_shade)
	_title=TextureRect.new();_title.texture=BossEntranceArt.pack(str(boss.boss_id)).title;_title.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_title.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;_root.add_child(_title)
	_phase_name=PixelUi.title("第%d阶段 · %s"%[boss.phase,BossPhaseRules.title(boss.boss_id,boss.phase)],24);_phase_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_root.add_child(_phase_name)
	_skip=PixelUi.compact_button("跳过",16);_skip.pressed.connect(finish);_root.add_child(_skip)
	_root.resized.connect(_layout);_layout()
	duration=.6 if ComicMotion.reduced() else 1.5
	_ghost=AnimatedSprite2D.new();_ghost.process_mode=Node.PROCESS_MODE_ALWAYS;_ghost.sprite_frames=BossStageArt.frames(boss.boss_id,boss.phase);_ghost.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;_ghost.material=PixelSpellArt.material();_ghost.z_index=810;_ghost.z_as_relative=false
	boss.get_parent().add_child(_ghost);_ghost.global_position=boss.global_position
	_ghost.play(&"transform" if _ghost.sprite_frames.has_animation(&"transform") else &"windup");_ghost.pause();_ghost.flip_h=boss._facing<0
	if _ghost.sprite_frames.get_meta("boss_stage_art",false):BossStageArt.align(_ghost,boss.boss_id,boss.body_size)
	else:PixelBossArt.align(_ghost,boss.boss_id,boss.body_size)
	_ghost.position+=boss.position
	_old_ghost=AnimatedSprite2D.new()
	# A burst may skip a threshold. Fade from the form actually displayed,
	# rather than an intermediate form that the fight never entered.
	_old_ghost.sprite_frames=(boss.visual as AnimatedSprite2D).sprite_frames if boss.visual is AnimatedSprite2D else BossStageArt.frames(boss.boss_id,maxi(1,boss.phase-1))
	_old_ghost.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;_old_ghost.material=PixelSpellArt.material();_old_ghost.z_index=811;_old_ghost.z_as_relative=false;boss.get_parent().add_child(_old_ghost);_old_ghost.play(&"idle");_old_ghost.pause();_old_ghost.flip_h=_ghost.flip_h
	if _old_ghost.sprite_frames.get_meta("boss_stage_art",false):BossStageArt.align(_old_ghost,boss.boss_id,boss.body_size)
	else:PixelBossArt.align(_old_ghost,boss.boss_id,boss.body_size)
	_old_ghost.position+=boss.position
	_was_visible=boss.visible;boss.hide();active=true;UIFlow.push_screen(self);AudioManager.set_presentation_duck(self,true)
func _layout()->void:
	if not is_instance_valid(_root):return
	var area:=MobileControls.safe_rect() if MobileControls.enabled() else get_viewport().get_visible_rect()
	_title.position=area.position+Vector2(area.size.x*.25,area.size.y*.12);_title.size=Vector2(area.size.x*.5,area.size.y*.12)
	_phase_name.position=area.position+Vector2(area.size.x*.15,area.size.y*.25);_phase_name.size=Vector2(area.size.x*.7,44)
	_skip.size=Vector2(150,46);_skip.position=area.end-_skip.size-Vector2(24,24)
func _process(dt:float)->void:
	if not active:return
	if not is_instance_valid(boss) or boss._dead or not boss.is_inside_tree():finish();return
	if not UIFlow.is_top(self):return
	elapsed+=dt
	if not Input.is_action_pressed("ui_accept") and not Input.is_action_pressed("ui_cancel"):_released=true
	var progress:=clampf(elapsed/duration,0,1)
	_ghost.frame=mini(_ghost.sprite_frames.get_frame_count(_ghost.animation)-1,int(progress*_ghost.sprite_frames.get_frame_count(_ghost.animation)))
	_old_ghost.modulate.a=1-smoothstep(.15,.55,progress);_ghost.modulate.a=smoothstep(.2,.6,progress)
	_root.modulate.a=minf(1,progress*8)*minf(1,(1-progress)*10)
	if progress>=1:finish()
func finish()->void:
	if not active:return
	active=false
	if is_instance_valid(boss):boss.visible=_was_visible;boss.finish_phase_presentation()
	if is_instance_valid(_ghost):_ghost.queue_free()
	if is_instance_valid(_old_ghost):_old_ghost.queue_free()
	AudioManager.set_presentation_duck(self,false);UIFlow.pop_screen(self);queue_free()
func _input(event:InputEvent)->void:
	if active and UIFlow.is_top(self) and _released and elapsed>=.2 and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		if not event.is_echo():finish()
		get_viewport().set_input_as_handled()
func _exit_tree()->void:
	if is_instance_valid(_ghost):_ghost.queue_free()
	if is_instance_valid(_old_ghost):_old_ghost.queue_free()
	if active and is_instance_valid(boss):boss.visible=_was_visible;boss.finish_phase_presentation()
	AudioManager.set_presentation_duck(self,false)
