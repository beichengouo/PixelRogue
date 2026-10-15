extends SceneTree
## 用代码合成 8-bit 芯片音乐（BGM），输出到 assets/music/。
##
## 为什么自己合成：网上音乐素材的授权大多说不清，而方波/三角波/噪声拼出来的
## 8-bit 曲子完全无版权问题，风格也和像素画面搭。想换正式 BGM，替换同名 wav 即可。
##
## 曲子：
##   music_forest     平时波次：悠闲、大调、慢速（松快但不吵）
##   music_boss_king  第 30 波 Boss：低沉压迫、行进的八分音符
##   music_boss_mage  第 60 波 Boss：奥术感、快速十六分琶音
##   music_boss_slime 第 100 波 Boss：跳动、俏皮又危险
##
## 用法：
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/build_music.gd

const OUT_DIR := "res://assets/music/"
const RATE := 22050

## 音阶（半音偏移）：大调五声 / 自然小调
const MAJOR_PENTA := [0, 2, 4, 7, 9, 12, 14, 16, 19]
const MINOR := [0, 2, 3, 5, 7, 8, 10, 12, 14, 15, 17, 19]

var _buf: PackedFloat32Array = PackedFloat32Array()
var _length := 0.0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_render("music_forest", 92.0, MAJOR_PENTA, 45, [0, 7, 5, 9],
		[0, -1, 2, 4, -1, 4, 2, 0], [4, -1, 5, 4, 2, -1, 0, -1], 0.30, 0.26, false)
	_render("music_boss_king", 152.0, MINOR, 33, [0, 0, 3, 5],
		[0, 0, 3, 2, 0, 0, -1, 5], [7, 5, 3, 2, 0, 3, 5, 7], 0.34, 0.34, true)
	_render("music_boss_mage", 138.0, MINOR, 40, [0, 5, 3, 7],
		[0, 2, 4, 6, 4, 2, 7, 5], [9, 7, 6, 4, 6, 7, 9, 11], 0.28, 0.30, true)
	_render("music_boss_slime", 164.0, MAJOR_PENTA, 36, [0, 5, 7, 5],
		[0, 2, 4, 2, 0, 4, 6, 4], [6, 4, 2, 4, 6, 7, 4, 2], 0.30, 0.30, true)
	print("BGM 生成完毕 → %s" % OUT_DIR)
	quit(0)


func _render(
	file_name: String, bpm: float, scale: Array, root_midi: int, prog: Array,
	phrase_a: Array, phrase_b: Array, lead_gain: float, bass_gain: float, boss: bool
) -> void:
	## 8 小节循环：4 小节 A 段 + 4 小节 B 段；Boss 曲多一层十六分琶音和鼓
	var beat := 60.0 / bpm
	var bars := 8
	_length = float(bars) * 4.0 * beat
	_buf = PackedFloat32Array()
	_buf.resize(int(_length * RATE) + 1)

	for bar in bars:
		var chord: int = prog[bar % prog.size()]
		var phrase: Array = phrase_a if bar < 4 else phrase_b
		var t0 := float(bar) * 4.0 * beat
		# 低音：每拍一下（Boss 曲走八分音符，更冲）
		var bass_step := beat if not boss else beat * 0.5
		var steps := int(4.0 * beat / bass_step)
		for i in steps:
			var bass_midi := root_midi - 12 + chord
			_note(t0 + float(i) * bass_step, bass_step * 0.92, _freq(bass_midi), bass_gain, "tri")
		# 主旋律：八分音符
		for i in 8:
			var step: int = phrase[i % phrase.size()]
			if step < 0:
				continue
			var midi := root_midi + chord + int(scale[mini(step, scale.size() - 1)])
			_note(t0 + float(i) * beat * 0.5, beat * 0.46, _freq(midi), lead_gain, "sq25" if not boss else "sq12")
		if boss:
			# 十六分琶音铺底 + 鼓
			for i in 8:
				var midi := root_midi + chord + int(scale[(i * 2) % scale.size()]) + 12
				_note(t0 + float(i) * beat * 0.25, beat * 0.20, _freq(midi), lead_gain * 0.34, "sq50")
			_kick(t0)
			_snare(t0 + beat * 2.0)
			for i in 8:
				_hat(t0 + float(i) * beat * 0.5)
		else:
			_kick(t0)
			_hat(t0 + beat * 2.0)
			_hat(t0 + beat * 3.0)
	_write(file_name)


func _freq(midi: int) -> float:
	return 440.0 * pow(2.0, (float(midi) - 69.0) / 12.0)


func _add(at: float, value: float) -> void:
	var idx := int(at * RATE)
	if idx >= 0 and idx < _buf.size():
		_buf[idx] += value


func _note(at: float, dur: float, freq: float, gain: float, wave: String) -> void:
	if freq <= 0.0:
		return
	var frames := int(dur * RATE)
	var phase := 0.0
	var inc := freq / float(RATE)
	for i in frames:
		var env := pow(1.0 - float(i) / float(maxi(1, frames)), 1.6)
		var v := 0.0
		match wave:
			"tri":
				var p := fmod(phase, 1.0)
				v = 4.0 * absf(p - 0.5) - 1.0
			"sq12":
				v = 1.0 if fmod(phase, 1.0) < 0.125 else -1.0
			"sq25":
				v = 1.0 if fmod(phase, 1.0) < 0.25 else -1.0
			_:
				v = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		_add(at + float(i) / float(RATE), v * env * gain)
		phase += inc


func _kick(at: float) -> void:
	var frames := int(0.11 * RATE)
	var phase := 0.0
	for i in frames:
		var t := float(i) / float(frames)
		var freq := lerpf(150.0, 45.0, t)
		_add(at + float(i) / float(RATE), sin(TAU * phase) * pow(1.0 - t, 2.0) * 0.34)
		phase += freq / float(RATE)


func _snare(at: float) -> void:
	_noise_burst(at, 0.12, 0.22)


func _hat(at: float) -> void:
	_noise_burst(at, 0.035, 0.10)


func _noise_burst(at: float, dur: float, gain: float) -> void:
	var frames := int(dur * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in frames:
		var env := pow(1.0 - float(i) / float(maxi(1, frames)), 2.2)
		_add(at + float(i) / float(RATE), rng.randf_range(-1.0, 1.0) * env * gain)


func _write(file_name: String) -> void:
	## 归一化 + 软削波，再写成 16bit 单声道 WAV（循环播放）
	var peak := 0.0
	for i in _buf.size():
		peak = maxf(peak, absf(_buf[i]))
	var norm := 0.86 / maxf(0.0001, peak)
	var data := PackedByteArray()
	data.resize(_buf.size() * 2)
	for i in _buf.size():
		var v := clampf(_buf[i] * norm, -1.0, 1.0)
		var s := int(round(v * 32000.0))
		data.encode_s16(i * 2, s)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = _buf.size()
	var path := ProjectSettings.globalize_path(OUT_DIR + file_name + ".wav")
	stream.save_to_wav(path)
	print("  %s  %.1f 秒" % [file_name, _length])
