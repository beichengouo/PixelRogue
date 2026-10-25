class_name StageRules
extends RefCounted
## One source of truth for the staged expedition. No change to difficulty multipliers.
const DEFAULT_ROOMS:=24
const RETRIES:=16
const SERVICE_DEPTH_BIAS:=0.5
const SPECIALS:=["reward","game","altar","trial","event"]
const EXTREME_MATERIAL:="starbound_sigil"
const EXTREME_MATERIAL_MIN:=2
const EXTREME_MATERIAL_MAX:=4
const EXTREME_BONUS_COUNT:=1
const EXTREME_BONUS_MIN_RARITY:=2
static func maximum_strength(stage:int)->int:return 50 if stage>=4 else clampi(stage,1,3)*10

static func strength(stage:int,depth:int,terminal_depth:int,terminal:bool=false)->int:
	if terminal:return 50 if stage==4 else stage*10
	var base:=(stage-1)*10+1
	return clampi(base+roundi(float(depth)*8.0/maxi(1,terminal_depth)),base,50 if stage==4 else stage*10-1)

static func experience(stage:int,strength_value:int,kind:String,boss:bool=false)->float:
	# Fixed spawn strength, independent of the player's purchased or trained level.
	var budget:=0.0
	for level_value in range((stage-1)*10+1,stage*10+1):budget+=WaveTable.experience_needed(level_value)
	if boss:return budget*(0.22 if stage==4 else 0.45)
	var expected:=maxi(6,int(RoomLayout.encounter(strength_value).total))
	var weight:=1.2 if kind=="elite" else 1.0
	return maxf(1.0,budget*0.16*weight/expected)
