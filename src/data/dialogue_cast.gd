class_name DialogueCast
extends RefCounted
## Dialogue-only art. Inventory, selection and battle sprites keep their own resources.
const ROOT := "res://assets/dialogue_portraits_v21/"
const EXPRESSIONS := ["neutral", "happy", "thoughtful", "surprised", "determined", "sad", "angry"]
const NAMES := {
	"sylphiette":"希露媞雅", "xixifu":"希希芙", "ilyua":"伊露雅", "iris":"伊莉丝",
	"merchant":"姜糖", "tavern":"温阮", "surveyor":"希尔薇娅", "carpenter":"布琳娜",
	"herbalist":"艾莉娅", "minstrel":"闻铃", "verena":"维蕾娜", "sephra":"塞芙菈",
	"king":"林之骸王", "mage":"晶化术士", "tide":"潮汐之根", "nameless":"无名录仪",
}
static var _textures: Dictionary = {}
static var _recent: Array[String] = []

static func actor(who: String, hero: StringName = &"") -> String:
	if who.is_empty(): return ""
	if who == "player": return str(Characters.current_id() if hero == &"" else hero)
	if NAMES.has(who): return who
	for id: String in NAMES:
		if str(NAMES[id]) == who: return id
	if who in ["希露提雅", "希露媞娅"]: return "sylphiette"
	if who == "执印巡卫·塞芙菈": return "sephra"
	if who == "千页司书·维蕾娜": return "verena"
	return ""

static func expression(value: String, text := "", legacy_path := "") -> String:
	var tag := value
	if tag.is_empty():
		for key: String in ["controlled", "relief", "regret", "doubt", "happy", "surprised", "sad", "thoughtful", "proud", "welcome", "warning", "inspect", "shortage", "success"]:
			if legacy_path.get_file().contains(key): tag = key; break
	var aliases := {"calm":"neutral", "welcome":"happy", "success":"happy", "relief":"happy", "proud":"happy", "inspect":"thoughtful", "doubt":"thoughtful", "point":"neutral", "warning":"thoughtful", "controlled":"neutral", "regret":"sad", "shortage":"sad"}
	tag = str(aliases.get(tag, tag))
	if tag in EXPRESSIONS: return tag
	# Untagged local conversations select faces by meaning, never by line number.
	if text.contains("谢谢") or text.contains("笑") or text.contains("喜欢"): return "happy"
	if text.contains("对不起") or text.contains("歉") or text.contains("遗憾"): return "sad"
	if text.contains("？") or text.contains("思考"): return "thoughtful"
	return "neutral"

static func set_form(id: String, live := true) -> bool:
	# Match the actual run's persistent costume, not the inventory portrait carousel.
	return live and StringName(id) == Characters.current_id() and LegendarySets.form_unlocked(StringName(id))

static func portrait_path(id: String, face := "neutral", live := true) -> String:
	if not NAMES.has(id): return ""
	var folder := ROOT + id + ("_set" if set_form(id, live) else "") + "/"
	var specific := folder + face + ".png"
	if ResourceLoader.exists(specific): return specific
	var mapped := "happy" if face == "happy" else "neutral" if face == "neutral" else "concerned"
	var candidate := folder + mapped + ".png"
	if ResourceLoader.exists(candidate): return candidate
	var neutral := folder + "neutral.png"
	return neutral if ResourceLoader.exists(neutral) else ""

static func portrait(id: String, face := "neutral", live := true, thumbnail := false) -> Texture2D:
	var path := portrait_path(id, face, live)
	if path.is_empty() or not ResourceLoader.exists(path): return null
	var key := path + ":" + face + (":head" if thumbnail else "")
	if _textures.has(key):
		_recent.erase(key)
		_recent.append(key)
		return _textures[key]
	var source := load(path) as Texture2D
	if source == null: return null
	if not thumbnail:
		_remember(key, source)
		return source
	var extent := source.get_size()
	var crop := AtlasTexture.new()
	crop.atlas = source
	crop.region = Rect2(extent * Vector2(.16, .025), extent * Vector2(.68, .48))
	crop.filter_clip = true
	_remember(key, crop)
	return crop

static func _remember(key: String, texture: Texture2D) -> void:
	_textures[key] = texture
	_recent.erase(key)
	_recent.append(key)
	while _recent.size() > 32: _textures.erase(_recent.pop_front())

static func clear_cache() -> void:
	_textures.clear()
	_recent.clear()
