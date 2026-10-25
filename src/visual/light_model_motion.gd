class_name LightModelMotion
extends Node
## Animates the original model's texture; no additive sprite or detached halo.
var model:Sprite2D
var kind:="lamp"
var _original:Texture2D
var _cells:Array[Texture2D]=[]
var _shown:Texture2D
var _age:=0.0
var _original_scale:=Vector2.ONE
const RANGE_AMPLITUDE:={"torch":.055,"fire":.07,"lamp":.03,"plant":.035,"crystal":.04,"moon_lantern":.05,"ember_brazier":.10,"star_bloom":.075}
static func rate(type:String)->float:return 7.0 if type in ["torch","fire","ember_brazier"] else 2.0
func phase_sample()->Dictionary:
 if ComicMotion.reduced() or _cells.is_empty():return {"radius":1.0,"energy":1.0,"frame":0}
 var phase:=fposmod(_age*rate(kind),4.0);var index:=floori(phase);var next:=(index+1)%4
 var amount:=smoothstep(0,1,fposmod(phase,1.0));var levels:=[0.0,-1.0,1.0,-.35]
 var wave:=lerpf(float(levels[index]),float(levels[next]),amount)
 return {"frame":index,"radius":1.0+wave*float(RANGE_AMPLITUDE.get(kind,.035)),"energy":1.0+wave*.045}
static func attach(sprite:Sprite2D,type:String)->LightModelMotion:
 if sprite.has_node("ModelFramePlayback"):return sprite.get_node("ModelFramePlayback") as LightModelMotion
 var motion:=LightModelMotion.new();motion.name="ModelFramePlayback";motion.model=sprite;motion.kind=type;sprite.add_child(motion);return motion
func _ready()->void:
 process_mode=Node.PROCESS_MODE_PAUSABLE
 _age=float(get_instance_id()%37)*.017
 _load_source()
func _load_source()->void:
 _original=model.texture;_original_scale=model.scale;_cells=LightModelArt.frames(_original);_shown=null
func _process(delta:float)->void:
 if not is_instance_valid(model):return
 if model.texture!=_shown and model.texture!=_original:_load_source()
 if _cells.is_empty() or not model.is_visible_in_tree() or UIFlow.has_screen() or TransitionLayer.busy:return
 if not ComicMotion.reduced():_age+=delta
 var index:=0 if ComicMotion.reduced() else floori(_age*rate(kind))%4
 var frame:=_cells[index]
 if model.texture!=frame:
  # Replacement frames have identical dimensions, scale and foot origin.
  model.texture=frame;model.scale=_original_scale*_original.get_size()/frame.get_size();_shown=frame
