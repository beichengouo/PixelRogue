class_name GameFonts
extends RefCounted
const BODY := "res://assets/fonts/AllSeto.ttf"
const BUTTON := "res://assets/fonts/MaoMao_Complete.ttf"
const TITLE := "res://assets/fonts/MeiRen_Complete.ttf"
static var _cache: Dictionary = {}

static func get_font(role := "body") -> Font:
	if _cache.has(role): return _cache[role]
	var path := TITLE if role == "title" else BUTTON if role == "button" else BODY
	var base: FontFile = load(path)
	var face := FontVariation.new()
	face.base_font = base
	face.variation_embolden = 0.35 if role == "title" else 0.12
	if role != "body": face.fallbacks = [get_font("body")] as Array[Font]
	_cache[role] = face
	return face
