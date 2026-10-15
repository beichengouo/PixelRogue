class_name DialoguePortraits
extends RefCounted
## 动作与剧情节点配置。角色资源由 Characters 提供，公共 NPC 共用此表。
const GODDESS := {
	"neutral": "res://assets/characters/goddess_portrait.png",
	"warning": "res://assets/characters/goddess_portrait.png",
	"welcome": "res://assets/characters/dialogue/goddess_welcome_pose_v1.png",
	"regret": "res://assets/characters/dialogue/goddess_regret_pose_v1.png",
}
const POSES := {
	&"intro_wake": {
		"lines": ["happy", "surprised", "welcome", "surprised", "welcome", "thoughtful"],
		"repeat": ["determined", "welcome", "determined", "welcome"],
		"replies": {
			0: ["welcome", "determined"], 1: ["welcome", "welcome"],
			2: ["neutral", "welcome", "warning"], 3: ["welcome"],
			4: ["thoughtful", "warning"],
		},
	},
	&"intro_weapon": {"lines": ["determined", "thoughtful", "warning", "determined"], "repeat": ["determined", "determined", "warning", "warning"], "replies": {0: ["warning"], 1: ["warning"], 2: ["warning"]}},
	&"death_first": {"lines": ["sad", "sad", "welcome"]},
	&"death_hall": {"lines": ["sad", "sad", "sad", "sad", "welcome", "welcome", "welcome"], "replies": {0: ["regret", "warning"], 1: ["regret", "regret"], 2: ["regret", "neutral"], 3: ["warning", "welcome"], 4: ["neutral", "welcome"]}},
	&"death_hall_intro": {"lines": ["thoughtful", "regret", "regret", "regret", "regret", "welcome", "welcome"]},
	&"death_reenter": {"lines": ["welcome", "warning", "determined", "welcome", "welcome"]},
	&"cp_10": {"lines": ["thoughtful", "warning", "warning"]},
	&"cp_20": {"lines": ["sad", "regret", "regret"]},
	&"cp_30": {"lines": ["sad", "regret", "welcome"]},
	&"cp_40": {"lines": ["surprised", "warning", "welcome"]},
	&"cp_50": {"lines": ["determined", "welcome", "warning"]},
	&"cp_60": {"lines": ["determined", "welcome", "warning"]},
	&"cp_70": {"lines": ["sad", "regret", "regret"]},
	&"cp_80": {"lines": ["determined", "welcome", "welcome"]},
	&"cp_90": {"lines": ["determined", "warning", "welcome"]},
	&"cp_100": {"lines": ["determined", "happy", "welcome", "welcome", "determined"], "replies": {0: ["welcome"], 1: ["happy"]}},
}

static func decorate(scene: Dictionary, id: StringName, repeated: bool,character_id:StringName=&"") -> Dictionary:
	# 未来角色可直接在自己的台词中指定 expression，不被首发角色覆盖。
	if str(Characters.DATA.get(character_id,Characters.current()).get("story_profile", "")) != "sylphiette": return scene
	var config: Dictionary = POSES.get(id, {})
	var tags: Array = config.get("repeat" if repeated and config.has("repeat") else "lines", [])
	_stamp(scene.get("lines", []), tags)
	var replies: Dictionary = config.get("replies", {})
	var choices: Array = scene.get("choices", [])
	for index in choices.size():
		_stamp(choices[index].get("reply", []), replies.get(index, []))
	return scene

static func _stamp(lines: Array, tags: Array) -> void:
	for index in mini(lines.size(), tags.size()):
		if not lines[index].has("expression"): lines[index]["expression"] = tags[index]
