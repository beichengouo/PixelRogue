class_name DamageContext
extends Node
## Stable ownership survives impact projectile deletion and delayed damage ticks.
var owner_kind:StringName=&"environment"
static func reflection(actor:Node)->Node:
 return _context(actor,&"reflection")
static func equipment(actor:Node)->Node:
 return _context(actor,&"equipment")
static func skill(actor:Node)->Node:
 return _context(actor,&"skill")
static func field(actor:Node)->Node:
 var context:=_context(actor,&"skill_field")
 if context!=null:context.owner_kind=&"skill_field"
 return context
static func is_skill(source:Node,actor:Node)->bool:
 return source is DamageContext and source.get_parent()==actor and source.owner_kind in [&"skill",&"skill_field"]
static func dot(actor:Node)->Node:
 return _context(actor,&"dot")
static func spread_burn(actor:Node)->Node:
 return _context(actor,&"spread_burn")
static func basic_splash(actor:Node)->Node:
 return _context(actor,&"basic_splash")
static func ally(actor:Node)->Node:
 return _context(actor,&"ally")
static func character_proc(actor:Node)->Node:
 return _context(actor,&"character_proc")
static func _context(actor:Node,kind:StringName)->Node:
 if not is_instance_valid(actor):return null
 var name_value:="DamageContext_"+str(kind)
 var found:=actor.get_node_or_null(name_value)
 if found!=null:return found
 var context:=DamageContext.new();context.owner_kind=kind;context.name=name_value;actor.add_child(context)
 return context
static func stable_source(source:Node)->Node:
 if not is_instance_valid(source):return null
 if source is RoomProjectile and source.damage_owner==&"player":return GameState.player
 return source
static func player_owned(source:Node)->bool:
 if not is_instance_valid(source):return false
 if source is DamageContext:return source.owner_kind in [&"player",&"skill",&"skill_field",&"equipment",&"dot",&"spread_burn",&"basic_splash",&"character_proc"]
 if source is Player:return true
 if source is RoomProjectile:return source.damage_owner==&"player"
 return false
