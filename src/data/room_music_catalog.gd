class_name RoomMusicCatalog
extends RefCounted
## User-provided originals are copied unchanged to ASCII paths.
## Scene groups use expedition clock minutes, never the computer's wall clock.
const ROOT := "res://assets/music/environment/"
const PERIODS := ["morning","noon","night"]
const WEATHER := ["rain","snow","fog","clear"]
const MORNING_START := 300.0
const NOON_START := 720.0
const NIGHT_START := 1080.0
const CROSSFADE_SECONDS := 0.8

static func period(minutes: float) -> String:
	var clock := fposmod(minutes,1440.0)
	if clock>=MORNING_START and clock<NOON_START:return "morning"
	if clock>=NOON_START and clock<NIGHT_START:return "noon"
	return "night"

static func weather(kind: String) -> String:
	var value := kind.to_lower()
	if value=="storm":return "rain"
	return value if value in WEATHER else "clear"

static func group(minutes: float, kind: String) -> StringName:
	var condition := weather(kind)
	return StringName(period(minutes)+"_"+condition)

static func tracks(group_id: StringName) -> PackedStringArray:
	if group_id==&"":return PackedStringArray()
	var valid := false
	for day in PERIODS:
		for condition in WEATHER:
			if String(group_id)==day+"_"+condition:valid=true
	if not valid:return PackedStringArray()
	return PackedStringArray(["environment_"+String(group_id)+"_1","environment_"+String(group_id)+"_2"])

static func entries() -> Dictionary:
	var result := {}
	for day in PERIODS:
		for condition in WEATHER:
			for id in tracks(StringName(day+"_"+condition)):result[id]=ROOT+id+".mp3"
	return result
