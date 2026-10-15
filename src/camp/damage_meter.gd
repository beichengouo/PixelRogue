class_name CampDamageMeter
extends RefCounted
var clock:=0.0
var started:=0.0
var last_hit:=0.0
var total:=0.0
var peak:=0.0
var running:=false
var entries:Array[Vector2]=[]
var by_source:Dictionary={}
func reset()->void:
	clock=0;started=0;last_hit=0;total=0;peak=0;running=false;entries.clear();by_source.clear()
func advance(dt:float)->void:
	clock+=dt
	if running and clock-last_hit>=5:running=false
	while not entries.is_empty() and entries[0].x<clock-5:entries.pop_front()
func record(amount:float,kind:StringName)->void:
	if amount<=0 or not is_finite(amount):return
	if not running:total=0;peak=0;entries.clear();by_source.clear();started=clock;running=true
	last_hit=clock;total+=amount;peak=maxf(peak,amount);entries.append(Vector2(clock,amount));by_source[kind]=float(by_source.get(kind,0))+amount
func recent_dps()->float:
	var damage:=0.0
	for entry in entries:damage+=entry.y
	return damage/maxf(.1,minf(5,clock-started))
func average_dps()->float:
	return total/maxf(.1,(clock if running else last_hit)-started)

