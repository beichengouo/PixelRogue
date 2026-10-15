class_name UltimateCutin
extends CanvasLayer
## A committed cast owns one pause lease; the effect is released only after dismissal.
const ART := {
	&"meteor":"res://assets/characters/sylphiette_holy_v01/ultimate_radiance.png",
	&"starfall":"res://assets/characters/sylphiette_holy_v01/ultimate_sanctuary.png",
	&"forest_guardian":"res://assets/characters/ultimates/xixifu_guardian.png",
	&"spirit_parade":"res://assets/characters/ultimates/xixifu_parade.png",
	&"ilyua_thousand_winds":"res://assets/characters/ilyua/ultimate_winds.png",
	&"ilyua_ancient_tree":"res://assets/characters/ilyua/ultimate_tree.png",
}
const PRESENTATION_SECONDS := 0.79
const REDUCED_PRESENTATION_SECONDS := 0.55
static var portraits:Dictionary={}
var actor:WeakRef
var release:Callable
var cast_epoch:=0
var _root:Control
var _motion:Control
var _animation:Tween
var _ticket:=0
var _finishing:=false
var _elapsed:=0.0
var _exit_elapsed:=0.0
var _edge_frames:=0
var skill_id:StringName

static func warm(character:StringName)->void:
	var ids:Array=[&"ilyua_thousand_winds",&"ilyua_ancient_tree"] if character==&"ilyua" else ([&"forest_guardian",&"spirit_parade"] if character==&"xixifu" else [&"meteor",&"starfall"])
	for id in ids:
		if not portraits.has(id) and ResourceLoader.exists(ART[id]):portraits[id]=load(ART[id])

static func present(owner:Player,id:StringName,effect:Callable)->bool:
	if not ART.has(id):return false
	var cutin:=UltimateCutin.new()
	cutin.actor=weakref(owner);cutin.skill_id=id;cutin.release=effect
	cutin.cast_epoch=GameState.run_epoch
	owner.add_child(cutin)
	return true

func _ready()->void:
	layer=36;process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true)
	_root=UiFactory.full_rect();add_child(_root)
	_motion=UiFactory.full_rect();_root.add_child(_motion)
	var portrait:=TextureRect.new();portrait.texture=portraits.get(skill_id,load(ART[skill_id]))
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_motion.add_child(portrait);portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.anchor_left=.22;portrait.anchor_right=.78;portrait.anchor_top=.015;portrait.anchor_bottom=.79
	var title:=TextureRect.new()
	var title_path:=HolySkills.ROOT+("title_judgment.png" if skill_id==&"meteor" else "title_sanctuary.png") if skill_id in [&"meteor",&"starfall"] else "res://assets/next_revision/ultimate_titles/%s.png"%skill_id
	if ResourceLoader.exists(title_path):title.texture=load(title_path)
	title.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_motion.add_child(title);title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.anchor_left=.30;title.anchor_right=.70;title.anchor_top=.82;title.anchor_bottom=.98
	EventBus.player_died.connect(cancel)
	EventBus.run_started.connect(func(_id:int)->void:cancel())
	UIFlow.push_screen(self)
	_ticket+=1
	var reduced:=ComicMotion.reduced()
	_motion.position.y=0 if reduced else -get_viewport().get_visible_rect().size.y*.35
	_motion.modulate.a=0
	_animation=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true).set_parallel(true)
	_animation.tween_property(_motion,"position:y",0,.03 if reduced else .10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animation.tween_property(_motion,"modulate:a",1,.03 if reduced else .08)
	# Count displayed simulation frames, not wall-clock time spent uploading art.
	# A cold shader/texture upload must not consume the entire presentation.

func _process(dt:float)->void:
	if not valid_cast():cancel();return
	if not UIFlow.is_top(self):return
	var real_dt:=dt/maxf(.001,Engine.time_scale)
	if not _finishing:
		_elapsed+=real_dt
		if _elapsed>=(REDUCED_PRESENTATION_SECONDS if ComicMotion.reduced() else PRESENTATION_SECONDS):_finish()
		return
	_exit_elapsed+=real_dt
	if _exit_elapsed<(.02 if ComicMotion.reduced() else .06):return
	# Retain the lease for two further frames so skip input cannot escape.
	_edge_frames+=1
	if _edge_frames<2:return
	var effect:=release;release=Callable()
	UIFlow.pop_screen(self)
	if valid_cast() and effect.is_valid():effect.call()
	queue_free();set_process(false)

func valid_cast()->bool:
	var owner:Variant=actor.get_ref() if actor!=null else null
	return is_instance_valid(owner) and not owner.is_queued_for_deletion() and owner.hp>0 and (GameState.run_active or CampSession.active) and GameState.run_epoch==cast_epoch

func _input(event:InputEvent)->void:
	if not UIFlow.is_top(self):return
	get_viewport().set_input_as_handled()
	# The cast and its pause/input lease must last through the full presentation.
	if _elapsed >= (REDUCED_PRESENTATION_SECONDS if ComicMotion.reduced() else PRESENTATION_SECONDS):
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu") or (event is InputEventMouseButton and event.pressed):_finish()

func _finish()->void:
	if _finishing:return
	_finishing=true;_ticket+=1
	if _animation!=null and _animation.is_valid():_animation.kill()
	_animation=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	_animation.tween_property(_root,"modulate:a",0,.02 if ComicMotion.reduced() else .06)

func cancel()->void:
	_ticket+=1;_finishing=true;release=Callable()
	if _animation!=null and _animation.is_valid():_animation.kill()
	UIFlow.pop_screen(self);queue_free()
	set_process(false)

func _exit_tree()->void:
	release=Callable()
