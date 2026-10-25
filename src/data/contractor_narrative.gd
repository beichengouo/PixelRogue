class_name ContractorNarrative
extends RefCounted
## Revision is presentation-only; stable IDs and committed story effects remain unchanged.
const REVISION := 12
static var _scenes: Dictionary = {}
static func scene(id: StringName, repeated: bool, character_id: StringName) -> Dictionary:
	if _scenes.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/narrative_v11.json"))
		if parsed is Dictionary: _scenes = parsed
	if not _scenes.has(str(id)): return {}
	var raw: Dictionary = _scenes[str(id)]
	var hero: Dictionary = Characters.DATA.get(character_id, Characters.current())
	var entries: Array = raw.lines.duplicate(true)
	if repeated and not str(raw.get("repeat", "")).is_empty():
		entries = [{"who":"", "text":str(raw.repeat)}]
	var response: String = str(raw.get("responses", {}).get(str(hero.id), ""))
	if not response.is_empty(): entries.append({"who":str(hero.name),"text":response,"expression":str(raw.get("response_expression","neutral"))})
	var choices: Array = []
	if id == &"intro_wake":
		choices = [
			{"text":"先检查旧路标。","next":&"","reply":[{"who":str(hero.name),"text":"好，先弄清路是怎么被堵住的。","expression":"neutral"}]},
			{"text":"记下熟悉的地方，回来一起核对。","next":&"","reply":[{"who":str(hero.name),"text":"我会把细节记下来，想不起的先留空。","expression":"thoughtful"}]},
			{"text":"安全第一，找到线索就可以回来。","next":&"","reply":[{"who":str(hero.name),"text":"知道了。准备好了再走下一段，不硬撑。","expression":"neutral"}]}]
	var result := {"narrative_revision":REVISION,"title":str(raw.title),"portrait":"","lines":entries,"choices":choices,"next":&""}
	if id == &"forest_tide_before": result.source_scenes=[&"cp_90"]
	return result
