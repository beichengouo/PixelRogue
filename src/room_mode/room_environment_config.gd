class_name RoomEnvironmentConfig
extends RefCounted
## One place for environmental timing, visibility and bounded effect budgets.
const MINUTES_PER_SECOND := 1.0
const DAY_START := 360.0
const DUSK_START := 1080.0
const NIGHT_START := 1200.0
const DAWN_START := 300.0
const PLAYER_LIGHT_RADIUS := 144.0
const ALLY_LIGHT_RADIUS_RATIO := 0.5
const MAX_OBSCURITY := 0.95
const FOG_BUILD_SECONDS := 35.0
const FOG_CLEAR_SECONDS := 5.0
const MAX_LIGHTS := 32
const LIGHT_SCAN_SECONDS := 0.25
const MAX_DROPS := 240
const MAX_IMPACTS := 96
const RAIN_RATE := 150.0
const SNOW_RATE := 55.0
const RAIN_ALPHA := 0.75
const SNOW_ALPHA := 0.70
# Layered illustrations need authored snow masks before accumulation can return.
# Falling snow and weather state remain active independently.
const SNOW_ACCUMULATION_ENABLED := false
const FOOTPRINT_DISTANCE := 20.0
const FOOTPRINT_LIFETIME := 12.0
const MAX_FOOTPRINTS := 160
const FOOTPRINT_SNOW_THRESHOLD := 0.10
const FOOTPRINT_TELEPORT_DISTANCE := 80.0
const LIGHT_KINDS := ["torch", "lamp", "plant", "crystal", "fire"]
const LIGHT_SIZES := [Vector2i.ONE, Vector2i(2,2), Vector2i(1,2), Vector2i(2,1)]
const LIGHTS := {
	"torch": {"radius":108.0,"strength":0.95,"color":Color("ffbf74"),"flicker":true,"always_on":true,"dispels_fog":true},
	"lamp": {"radius":180.0,"strength":1.0,"color":Color("ffe5b0"),"flicker":false,"always_on":false,"dispels_fog":true},
	"plant": {"radius":90.0,"strength":0.8,"color":Color("99e8c6"),"flicker":false,"always_on":true,"dispels_fog":true},
	"crystal": {"radius":144.0,"strength":1.0,"color":Color("b5c9ff"),"flicker":false,"always_on":true,"dispels_fog":true},
	"fire": {"radius":216.0,"strength":1.0,"color":Color("ffd09a"),"flicker":true,"always_on":true,"dispels_fog":true},
}
