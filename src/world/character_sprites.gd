class_name CharacterSprites
extends RefCounted
## 把「横向一条」的角色图集转成 SpriteFrames。
##
## 图集由 tools/build_character_assets.gd 生成：每个动画一条横图，
## 帧宽固定，帧数 = 图宽 / 帧宽。这样加动画只要重新生成图集，代码不用动。

const DIR := "res://assets/characters/"

## 主角用的那一格 Tiny Dungeon 角色（100 号）。
## 想换形象：把 tools/build_character_assets.gd 里抠出来的其他候选
## （player_96 / 97 / 98 / 99）换到这里即可。
const PLAYER_TEXTURE := "res://assets/characters/player_100.png"

## ---------------- 女巫 Eleonore：当前使用的主角色 ----------------
## 原生 64x64（角色约 46x49），不需要缩放；只有待机动画 9 帧。
## 素材里的角色实际朝向【右】，和常规翻转规则一致：
## 朝右(facing=+1) 不翻转，朝左(facing=-1) 翻转（见 player.gd 的 _update_animation）。
## 以后换了朝向相反的素材，把这里改成 true 就行，别的代码不用动。
const WITCH_FRAME := Vector2i(64, 64)
const WITCH_FRAMES := 9
const WITCH_FEET_OFFSET := 57.0
const WITCH_ART_FACES_LEFT := false


static func make_witch_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_strip(frames, &"idle", DIR + "witch_idle.png", WITCH_FRAME, 8.0, true)
	return frames

## ---------------- kira：当前使用的主角色 ----------------
## 原生 256x256 一格，按 4 倍降采样成 64x64（角色约 48px 高，正好 1.33 格）
const KIRA_FRAME := Vector2i(64, 64)
## 脚底在图帧里的纵向位置（从帧顶部算起，实测 56/64）
const KIRA_FEET_OFFSET := 56.0
## 角色图里是否自带武器。Tiny Dungeon 的角色是空手的，所以挂载的武器正常显示；
## 如果以后换成自带武器的角色图（比如 kira），改成 true 就不会出现两把武器。
const PLAYER_ART_HAS_WEAPON := false
## 动画 -> [帧数, 帧率, 是否循环]
const KIRA_ANIMS := {
	&"idle": [24, 10.0, true],
	&"walk": [24, 14.0, true],
	&"run": [16, 16.0, true],
	&"jump": [20, 14.0, true],
	&"attack": [18, 45.0, false],
	&"hurt": [12, 30.0, false],
	&"death": [64, 40.0, false],
}


static func make_kira_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: StringName in KIRA_ANIMS:
		var info: Array = KIRA_ANIMS[anim]
		_add_strip(frames, anim, DIR + "kira_" + String(anim) + ".png", KIRA_FRAME, float(info[1]), bool(info[2]))
	return frames

## 主角：单帧 52x54（原生分辨率，已从 10 倍放大的精灵表缩回）
const ELF_FRAME := Vector2i(52, 54)
## 怪物：单帧 32x32（16x16 原生放大 2 倍，和地形的像素大小一致）
const MONSTER_FRAME := Vector2i(32, 32)

## 主角各动画的帧率。攻击要跟得上挥砍判定（0.26 秒），所以给得快一些。
const ELF_ANIM_FPS := {
	&"idle": 8.0,
	&"walk": 12.0,
	&"attack": 24.0,
	&"hurt": 10.0,
	&"death": 8.0,
}
const ELF_ANIM_LOOP := {
	&"idle": true,
	&"walk": true,
	&"attack": false,
	&"hurt": false,
	&"death": false,
}


static func make_player_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: StringName in ELF_ANIM_FPS:
		_add_strip(
			frames, anim,
			DIR + "elf_" + String(anim) + ".png",
			ELF_FRAME,
			float(ELF_ANIM_FPS[anim]),
			bool(ELF_ANIM_LOOP[anim])
		)
	return frames


static func boss_strip_exists(strip_name: String) -> bool:
	return ResourceLoader.exists(DIR + "boss_" + strip_name + ".png")


const BOSS_FRAMES := {"king": 32, "mage": 64, "tide": 64}


static func boss_frame_size(strip_name: String) -> int:
	return int(BOSS_FRAMES.get(strip_name, MONSTER_FRAME.x))


static func make_boss_frames(strip_name: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var size := boss_frame_size(strip_name)
	_add_strip(frames, &"idle", DIR + "boss_" + strip_name + ".png", Vector2i(size, size), 6.0, true)
	return frames


## 个别怪物帧比标准 32x32 大（树精是 48）
const MONSTER_FRAMES := {"treant": 64}


static func make_monster_frames(strip_name: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var size := int(MONSTER_FRAMES.get(strip_name, MONSTER_FRAME.x))
	_add_strip(frames, &"idle", DIR + "monster_" + strip_name + ".png", Vector2i(size, size), 6.0, true)
	return frames


static func _add_strip(
	frames: SpriteFrames,
	anim: StringName,
	path: String,
	frame_size: Vector2i,
	fps: float,
	loop: bool
) -> void:
	if not ResourceLoader.exists(path):
		push_warning("角色图集不存在：%s" % path)
		return
	var texture := load(path) as Texture2D
	var count := int(texture.get_width() / frame_size.x)
	frames.add_animation(anim)
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, fps)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(
			float(i * frame_size.x), 0.0, float(frame_size.x), float(frame_size.y)
		)
		frames.add_frame(anim, atlas)




