class_name ContractorNarrative
extends RefCounted
## Revision is presentation-only; stable IDs and committed story effects remain unchanged.
const REVISION := 13
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
	if not repeated:
		for line:Dictionary in raw.get("hero_lines",{}).get(str(hero.id),[]):
			var rendered:=line.duplicate(true)
			if str(rendered.get("who",""))=="hero":rendered.who=str(hero.name)
			entries.append(rendered)
	var response: String = str(raw.get("responses", {}).get(str(hero.id), ""))
	if not response.is_empty(): entries.append({"who":str(hero.name),"text":response,"expression":str(raw.get("response_expression","neutral"))})
	var choices: Array = []
	if id == &"intro_wake":
		choices = [
			{"text":"我建议先查清出口和路标。","next":&"","reply":[{"who":str(hero.name),"text":"好，先弄清路是怎么被堵住的。","expression":"neutral"}]},
			{"text":"我更想听你记下那些熟悉的细节。","next":&"","reply":[{"who":str(hero.name),"text":"我会把细节记下来，想不起的先留空。","expression":"thoughtful"}]},
			{"text":"我最在意你平安，别为了线索硬撑。","next":&"","reply":[{"who":str(hero.name),"text":"知道了。准备好了再走下一段，不硬撑。","expression":"neutral"}]}]
	var result := {"narrative_revision":REVISION,"title":str(raw.title),"portrait":"","lines":entries,"choices":choices,"next":&""}
	if id == &"intro_wake":result.choice_prompt=entries.back().duplicate(true)
	if id == &"forest_tide_before": result.source_scenes=[&"cp_90"]
	return result
