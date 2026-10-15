class_name WeatherState
extends RefCounted
const KINDS := ["clear","rain","storm","fog","snow"]
const WEIGHTS := [25,20,15,10,15]
var random := RandomNumberGenerator.new()
var kind := "clear"
var previous := "clear"
var end_wave := 0
var last_wave := 0
var blend := 1.0
var time := 0.0
var seed_value := 0
var wetness := PackedFloat32Array([0,0,0,0])
var snow := PackedFloat32Array([0,0,0,0])
func setup(seed: int, saved: Dictionary = {}, wave := 1) -> void:
	seed_value = int(saved.get("seed",seed))
	random.seed = seed_value ^ 0x5A81C72
	kind = "clear"
	previous = "clear"
	end_wave = 0
	last_wave = 0
	blend = 1.0
	time = 0.0
	wetness = PackedFloat32Array([0,0,0,0])
	snow = PackedFloat32Array([0,0,0,0])
	if int(saved.get("version",0)) == 1 and str(saved.get("kind","")) in KINDS + ["wind"]:
		kind = "clear" if str(saved.kind)=="wind" else str(saved.kind)
		previous = str(saved.get("previous",kind))
		if previous not in KINDS: previous = kind
		end_wave = int(saved.get("end_wave",wave+2))
		last_wave = int(saved.get("last_wave",wave))
		blend = clampf(float(saved.get("blend",1)),0,1)
		time = maxf(0,float(saved.get("time",0)))
		random.state = int(str(saved.get("rng_state",random.state)))
		for i in 4:
			if saved.get("wetness",[]).size()>i: wetness[i]=clampf(float(saved.wetness[i]),0,1)
			if saved.get("snow",[]).size()>i: snow[i]=clampf(float(saved.snow[i]),0,1)
	else:
		for w in range(1,maxi(1,wave)+1): advance_wave(w)
		blend = 1.0
func advance_wave(wave: int) -> void:
	if wave <= last_wave: return
	last_wave = wave
	if wave < end_wave: return
	previous = kind
	var total := 0
	for i in KINDS.size():
		if end_wave == 0 or KINDS[i] != kind: total += WEIGHTS[i]
	var roll := random.randi_range(0,total-1)
	for i in KINDS.size():
		if end_wave != 0 and KINDS[i] == kind: continue
		roll -= WEIGHTS[i]
		if roll < 0:
			kind = KINDS[i]
			break
	end_wave = wave + random.randi_range(2,4)
	blend = 0.0
func intensity() -> float:
	return 0.45 if last_wave<=10 else 0.72 if last_wave<=30 else 1.0
func amount(type: String) -> float:
	return lerpf(1.0 if previous==type else 0.0,1.0 if kind==type else 0.0,smoothstep(0,1,blend))*intensity()
func wind() -> float:
	return 0.18+amount("storm")*0.5
func tick(delta: float) -> void:
	time += delta
	blend = minf(1.0,blend+delta/4.0)
	var rain := amount("rain")+amount("storm")
	var snowfall := amount("snow")
	for i in 4:
		wetness[i] = clampf(wetness[i]+delta*(rain*0.012+(1.0-snowfall)*snow[i]*0.002-0.003),0,1)
		snow[i] = clampf(snow[i]+delta*(snowfall*0.009-rain*0.013-(1.0-snowfall)*0.002),0,1)
func snapshot() -> Dictionary:
	return {"version":1,"seed":seed_value,"kind":kind,"previous":previous,"end_wave":end_wave,"last_wave":last_wave,"blend":blend,"time":time,"rng_state":str(random.state),"wetness":Array(wetness),"snow":Array(snow)}
func restore(data: Dictionary) -> void:
	setup(int(data.get("seed",seed_value)),data,int(data.get("last_wave",1)))
