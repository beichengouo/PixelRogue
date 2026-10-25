class_name GlowMushroom
extends Node2D
## Retired actor. Old authored references remain loadable but never spawn gameplay.
const SIT_OFFSET:=10.6875
static var _frames:Dictionary={}
var kind:=0
var player:Node2D
var level:Level
var in_range:=false
var _harvested:=true
func setup(room:Level,actor:Node2D,index:int)->void:level=room;player=actor;kind=index
func _ready()->void:queue_free()
func try_interact()->bool:return false
