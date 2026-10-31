class_name GameFonts
extends RefCounted
const BODY := "res://assets/fonts/MaoMaoPengYouTiGaiEr.ttf"
const BUTTON := BODY
const TITLE := BODY
static var _cache: Dictionary = {}
static var _song_fallback:Font

static func song_fallback()->Font:
	if _song_fallback==null:
		var song:=SystemFont.new()
		song.font_names=PackedStringArray(["SimSun","宋体","NSimSun"])
		_song_fallback=song
	return _song_fallback

static func get_font(role := "body") -> Font:
	if _cache.has(role): return _cache[role]
	var path := TITLE if role == "title" else BUTTON if role == "button" else BODY
	var base: FontFile = load(path)
	var face := FontVariation.new()
	face.base_font = base
	face.variation_embolden = 0.35 if role == "title" else 0.12
	if role == "body":face.fallbacks=[song_fallback(),load("res://assets/fonts/AllSeto.ttf") as Font] as Array[Font]
	else:face.fallbacks = [get_font("body")] as Array[Font]
	_cache[role] = face
	return face
