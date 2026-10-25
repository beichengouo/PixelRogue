class_name LightSpriteArt
extends RefCounted
## Intensity only. The painted model owns its animation; no auxiliary VFX layer.
const KINDS:=["torch","fire","lamp","plant","crystal","arcane","loot","aura"]
static func energy(kind:String,seconds:float,reduced:bool=false)->float:
 if reduced:return 1.0
 if kind in ["torch","fire"]:return .94+.04*sin(seconds*7.4)+.02*sin(seconds*11.3)
 return .97+.03*sin(seconds*(1.5 if kind in ["lamp","aura"] else 2.2))
