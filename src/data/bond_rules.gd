class_name BondRules
extends RefCounted
const MAX := 500
const DAILY_GAIN := 8
const NAMES := {"sylphiette":"希露媞雅","iris":"伊莉丝","merchant":"姜糖","tavern":"温阮"}
const STAGES := [[0,50,"初识"],[50,100,"相知"],[100,200,"信任"],[200,300,"亲近"],[300,400,"默契"],[400,501,"羁绊"]]
static func stage(value:int)->String:
	for entry in STAGES:
		if value<int(entry[1]):return str(entry[2])
	return "羁绊"
static func range_text(value:int)->String:
	for entry in STAGES:
		if value<int(entry[1]):return "%d–%d · %s" % [entry[0],mini(500,int(entry[1])),entry[2]]
	return "400–500 · 羁绊"
static func now()->int:return int(Time.get_unix_time_from_system())

static func day_key(clock:int)->int:return (clock+int(Time.get_time_zone_from_system().bias)*60)/86400
static func next_day(clock:int)->int:return (day_key(clock)+1)*86400-int(Time.get_time_zone_from_system().bias)*60
