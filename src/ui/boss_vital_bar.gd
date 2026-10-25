class_name BossVitalBar
extends StatBar
var style_id:="king"
var _flow:TextureRect
var _flow_material:ShaderMaterial
var _flow_age:=0.0
func _ready()->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 _flow=TextureRect.new();_flow.mouse_filter=Control.MOUSE_FILTER_IGNORE;_flow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 _flow.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(_flow)
 _flow_material=ShaderMaterial.new();_flow_material.shader=preload("res://src/ui/boss_vital_flow.gdshader");_flow.material=_flow_material
 resized.connect(_sync_flow);_sync_flow()
func configure(id:String)->void:
 style_id=id if id in UnitHealthArt.STYLES else "king";_sync_flow();queue_redraw()
func _process(delta:float)->void:
 super._process(delta)
 if not is_visible_in_tree():return
 if not get_tree().paused and not UIFlow.has_screen() and not ComicMotion.reduced():_flow_age+=delta
 _sync_flow()
func _sync_flow()->void:
 if not is_instance_valid(_flow):return
 var entry:=UnitHealthArt.profile(style_id);var channel:=Rect2(Vector2(1,1),size-Vector2(2,2))
 _flow.position=channel.position;_flow.size=channel.size;_flow.texture=entry.fill_texture
 _flow_material.set_shader_parameter("fill_ratio",clampf(_shown/maxf(.001,_max_value),0,1))
 _flow_material.set_shader_parameter("flow_age",_flow_age)
 _flow_material.set_shader_parameter("reduced_motion",ComicMotion.reduced())
func _draw()->void:
 var rect:=Rect2(Vector2.ZERO,size)
 if rect.size.x<=0 or rect.size.y<=0:return
 var entry:=UnitHealthArt.profile(style_id);var channel:=rect.grow(-1)
 draw_rect(channel,Color("10131d"))
 var ghost:=clampf(_ghost/maxf(.001,_max_value),0,1);var current:=clampf(_shown/maxf(.001,_max_value),0,1)
 if ghost>current+.002:draw_rect(Rect2(channel.position,Vector2(channel.size.x*ghost,channel.size.y)),Color(entry.tint,.32))
 draw_rect(rect,Color("c8b6a0"),false,1.0)
