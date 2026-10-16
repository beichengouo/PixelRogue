class_name RoomWorldClock
extends RefCounted
## Pseudo world time belongs to one expedition; no wall-clock or offline advancement.
var minutes := 720.0
var elapsed_days := 0
var minutes_per_second := RoomEnvironmentConfig.MINUTES_PER_SECOND
var day_start := RoomEnvironmentConfig.DAY_START
var dusk_start := RoomEnvironmentConfig.DUSK_START
var night_start := RoomEnvironmentConfig.NIGHT_START
var dawn_start := RoomEnvironmentConfig.DAWN_START
var seed_value := 0

func setup(seed: int, saved: Dictionary = {}) -> void:
	seed_value=seed
	elapsed_days=0
	minutes_per_second=RoomEnvironmentConfig.MINUTES_PER_SECOND
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed ^ 0x45D192A
	minutes=rng.randf_range(day_start,dusk_start-1.0)
	if not saved.is_empty():restore(saved)

func tick(delta: float) -> void:
	if delta<=0:return
	var total:=minutes+delta*maxf(0,minutes_per_second)
	elapsed_days+=floori(total/1440.0)
	minutes=fposmod(total,1440.0)

func phase() -> String:
	if minutes>=day_start and minutes<dusk_start:return "day"
	if minutes>=dusk_start and minutes<night_start:return "dusk"
	if minutes>=dawn_start and minutes<day_start:return "dawn"
	return "night"

func darkness() -> float:
	match phase():
		"day":return 0.0
		"dusk":return smoothstep(dusk_start,night_start,minutes)
		"dawn":return 1.0-smoothstep(dawn_start,day_start,minutes)
	return 1.0

func time_label() -> String:
	var value:=floori(minutes)
	return "%02d:%02d" % [value/60,value%60]

func snapshot() -> Dictionary:
	return {"version":2,"seed":seed_value,"minutes":minutes,"days":elapsed_days,"speed":minutes_per_second,
		"day_start":day_start,"dusk_start":dusk_start,"night_start":night_start,"dawn_start":dawn_start}

func restore(data: Dictionary) -> void:
	day_start=RoomEnvironmentConfig.DAY_START;dusk_start=RoomEnvironmentConfig.DUSK_START
	night_start=RoomEnvironmentConfig.NIGHT_START;dawn_start=RoomEnvironmentConfig.DAWN_START
	seed_value=int(data.get("seed",seed_value))
	minutes=fposmod(float(data.get("minutes",minutes)),1440.0)
	elapsed_days=maxi(0,int(data.get("days",0)))
	minutes_per_second=clampf(float(data.get("speed",RoomEnvironmentConfig.MINUTES_PER_SECOND)),0,120)
	# Invalid phase ordering in a save must not create abrupt or undefined transitions.
	var dawn:=float(data.get("dawn_start",RoomEnvironmentConfig.DAWN_START))
	var day:=float(data.get("day_start",RoomEnvironmentConfig.DAY_START))
	var dusk:=float(data.get("dusk_start",RoomEnvironmentConfig.DUSK_START))
	var night:=float(data.get("night_start",RoomEnvironmentConfig.NIGHT_START))
	if int(data.get("version",1))>=2 and dawn>=0 and dawn<day and day<dusk and dusk<night and night<1440:
		dawn_start=dawn;day_start=day;dusk_start=dusk;night_start=night
