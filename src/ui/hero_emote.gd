class_name HeroEmote
extends CanvasLayer
## Cosmetic only: owns no combat state, uses its own RNG, never enters saves.
const ROOT:="res://assets/hero_emotes_v01/"
const RULES:={
 "chest":{"mood":"happy","chance":.7,"gap":20.0},
 "hurt":{"mood":"sad","chance":.35,"gap":22.0},
 "heal":{"mood":"happy","chance":.3,"gap":30.0},
 "level":{"mood":"happy","chance":.65,"gap":25.0},
 "victory":{"mood":"confident","chance":.35,"gap":28.0},
 "boss_win":{"mood":"confident","chance":.85,"gap":30.0},
 "boss_enter":{"mood":"curious","chance":.5,"gap":35.0},
 "legendary":{"mood":"confident","chance":.65,"gap":30.0},
 "no_mana":{"mood":"curious","chance":.4,"gap":35.0},
 "camp":{"mood":"curious","chance":.3,"gap":30.0}}
const GLOBAL_GAP:=10.0
var actor:RoomPlayer
var hero_id:=""
var _root:Control
var _bubble:TextureRect
var _animation:Tween
var _rng:=RandomNumberGenerator.new()
var _textures:Dictionary={}
var _cooldowns:Dictionary={}
var _gap:=0.0
var _active:=false
var _camp_menu:=false
var last_event:=""
var last_mood:=""
var shown_count:=0
func _ready()->void:
 layer=9;name="HeroEmote";hero_id=str(Characters.current_id());_rng.randomize()
 _root=Control.new();_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_root)
 _bubble=TextureRect.new();_bubble.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_bubble.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;_bubble.mouse_filter=Control.MOUSE_FILTER_IGNORE;_bubble.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;_root.add_child(_bubble)
 for mood in ["happy","sad","curious","confident"]:_textures[mood]=load(ROOT+hero_id+"_"+mood+".png")
 clear()
 EventBus.chest_opened.connect(func(_loot:Dictionary)->void:react("chest"))
 EventBus.player_damaged.connect(func(amount:float,hp:float,_max:float)->void:
  if amount>0 and hp>0:react("hurt"))
 EventBus.player_healed.connect(func(amount:float,_hp:float,_max:float)->void:
  if amount>0:react("heal"))
 EventBus.level_changed.connect(func(_level:int,gained:int)->void:
  if gained>0 and not CampSession.active:react("level"))
 EventBus.wave_cleared.connect(func(_wave:int)->void:react("victory"))
 EventBus.boss_defeated.connect(func(_id:StringName)->void:react("boss_win"))
 EventBus.boss_started.connect(func(_id:StringName)->void:react("boss_enter"))
 EventBus.item_acquired.connect(func(item:Dictionary)->void:
  if int(item.get("rarity",0))>=3 and not CampSession.active:react("legendary"))
 EventBus.player_died.connect(clear)
 UIFlow.stack_changed.connect(_screen_changed)
func available()->bool:
 return is_instance_valid(actor) and actor==GameState.player and actor.is_inside_tree() and actor.is_visible_in_tree() and actor.hp>0 and actor.extraction_pose==&"" and (CampSession.active or GameState.run_active) and not UIFlow.has_screen() and not get_tree().paused and not TransitionLayer.busy
func react(event:String,force_probability:bool=false)->bool:
 if not RULES.has(event) or not available() or _active or _gap>0 or float(_cooldowns.get(event,0))>0:return false
 var rule:Dictionary=RULES[event]
 # Also limit failed rolls, so repeated damage/pickups cannot reroll every frame.
 _cooldowns[event]=float(rule.gap)
 if not force_probability and _rng.randf()>float(rule.chance):return false
 _gap=GLOBAL_GAP;last_event=event;last_mood=str(rule.mood);shown_count+=1
 _show(str(rule.mood));return true
func _show(mood:String)->void:
 if _animation!=null and _animation.is_valid():_animation.kill()
 _active=true;_bubble.texture=_textures[mood];_root.show();_bubble.modulate=Color.WHITE
 var extent:=get_viewport().get_visible_rect().size
 var side:=72.0*clampf(minf(extent.x/1280.0,extent.y/720.0),.75,1.35)
 _bubble.size=Vector2.ONE*side;_bubble.position=Vector2(-side*.5,-side);_bubble.pivot_offset=Vector2(side*.5,side)
 _follow()
 var reduced:=ComicMotion.reduced()
 _bubble.scale=Vector2.ONE if reduced else Vector2(.25,.20);_bubble.modulate.a=0
 _animation=create_tween().set_parallel(true)
 _animation.tween_property(_bubble,"modulate:a",1.0,.10 if reduced else .14)
 if not reduced:_animation.tween_property(_bubble,"scale",Vector2.ONE,.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
 _animation.chain().tween_interval(1.65)
 _animation.chain().tween_property(_bubble,"modulate:a",0.0,.22)
 if not reduced:_animation.parallel().tween_property(_bubble,"scale",Vector2.ONE*.92,.22)
 _animation.chain().tween_callback(clear)
 AudioManager.play(StringName("emote_"+mood),-14,0)
func _follow()->void:
 if not is_instance_valid(actor):return
 var anchor:=actor.get_global_transform_with_canvas()*Vector2(0,-25)
 var extent:=get_viewport().get_visible_rect().size;var side:=_bubble.size.x
 _root.position=Vector2(clampf(anchor.x,side*.5+6,maxf(side*.5+6,extent.x-side*.5-6)),clampf(anchor.y,side+6,maxf(side+6,extent.y-6)))
func _process(dt:float)->void:
 _gap=maxf(0,_gap-dt)
 for event in _cooldowns:_cooldowns[event]=maxf(0,float(_cooldowns[event])-dt)
 if not _active:return
 if not available():clear();return
 _follow()
func _screen_changed()->void:
 if UIFlow.has_screen():
  if CampSession.active:_camp_menu=true
  clear()
 elif _camp_menu:
  _camp_menu=false
  if CampSession.active:react("camp")
func clear()->void:
 if _animation!=null and _animation.is_valid():_animation.kill()
 _animation=null;_active=false
 if is_instance_valid(_root):_root.hide()
func _exit_tree()->void:clear();_textures.clear()
