extends SceneTree
## 用代码合成 8-bit 风格音效，输出到 assets/sfx/。
##
## 为什么自己合成：免费音效站点的授权经常说不清楚，
## 而方波/噪声合成出来的复古音效完全无版权问题，也够用。
## 想换正式音效，把同名 wav 文件替换掉即可，代码不用动。
##
## 用法：
##   "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" ^
##       --headless --path . --script res://tools/build_sfx.gd

const OUT_DIR := "res://assets/sfx/"
const RATE := 22050


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# 起跳：方波向上扫频
	_write("jump", _sweep(220.0, 700.0, 0.13, 0.38, 0.5, 0.0))
	# 落地：低频闷响
	_write("land", _sweep(170.0, 70.0, 0.09, 0.32, 0.5, 0.0))
	# 挥砍：噪声扫频
	_write("swing", _noise_sweep(0.11, 0.20, 3.0))
	# 命中：短促的方波下坠 + 噪声
	_write("hit", _mix(_sweep(520.0, 180.0, 0.08, 0.34, 0.5, 0.0), _noise(0.08, 0.16)))
	# 受伤：下行的痛感音
	_write("hurt", _sweep(380.0, 110.0, 0.22, 0.36, 0.5, 0.0))
	# 敌人死亡：更长的下坠
	_write("enemy_die", _sweep(600.0, 90.0, 0.28, 0.30, 0.25, 0.0))
	# 拾取金币：两声上行
	_write("coin", _mix(_tone(988.0, 0.06, 0.30, 0.5), _tone(1319.0, 0.10, 0.26, 0.5), 0.0, 0.05))
	# UI 点击
	_write("ui_click", _tone(1200.0, 0.045, 0.24, 0.25))
	# 波次开始：三音上行
	_write("wave_start", _arpeggio([392.0, 523.0, 659.0], 0.10, 0.32))
	# 波次清场：四音大调琶音
	_write("wave_clear", _arpeggio([523.0, 659.0, 784.0, 1047.0], 0.11, 0.30))
	# 冲刺：噪声上扫
	_write("dash", _noise_sweep(0.16, 0.22, 1.6))
	# 敌人开火
	_write("enemy_shoot", _sweep(700.0, 240.0, 0.12, 0.26, 0.5, 0.0))
	quit(0)


# ------------------------------------------------------------------ 合成器


func _frames(seconds: float) -> int:
	return int(seconds * float(RATE))


func _square(phase: float, duty := 0.5) -> float:
	return 1.0 if fmod(phase, 1.0) < duty else -1.0


func _envelope(i: int, total: int, decay := 2.0) -> float:
	var t := float(i) / float(maxi(1, total))
	return pow(1.0 - t, decay)


func _sweep(f0: float, f1: float, seconds: float, volume: float, duty: float, _pad: float) -> PackedFloat32Array:
	## 频率从 f0 扫到 f1 的方波
	var n := _frames(seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var freq := lerpf(f0, f1, t)
		phase += freq / float(RATE)
		out[i] = _square(phase, duty) * _envelope(i, n) * volume
	return out


func _tone(freq: float, seconds: float, volume: float, duty := 0.5) -> PackedFloat32Array:
	return _sweep(freq, freq, seconds, volume, duty, 0.0)


func _noise(seconds: float, volume: float) -> PackedFloat32Array:
	var n := _frames(seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261006
	for i in n:
		out[i] = (rng.randf() * 2.0 - 1.0) * _envelope(i, n, 1.6) * volume
	return out


func _noise_sweep(seconds: float, volume: float, highpass: float) -> PackedFloat32Array:
	## 用「上采样保持」再差分，做出带高频质感的噪声扫频
	var n := _frames(seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7777
	var hold := 0.0
	var prev := 0.0
	var counter := 0
	for i in n:
		var t := float(i) / float(n)
		var period := int(maxf(1.0, lerpf(9.0, 2.0, t) / maxf(0.5, highpass)))
		if counter <= 0:
			hold = rng.randf() * 2.0 - 1.0
			counter = period
		counter -= 1
		var v := hold - prev * 0.6
		prev = v
		out[i] = clampf(v, -1.0, 1.0) * _envelope(i, n, 1.4) * volume
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, delay_a := 0.0, delay_b := 0.0) -> PackedFloat32Array:
	var off_a := _frames(delay_a)
	var off_b := _frames(delay_b)
	var n := maxi(off_a + a.size(), off_b + b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var v := 0.0
		if i >= off_a and i - off_a < a.size():
			v += a[i - off_a]
		if i >= off_b and i - off_b < b.size():
			v += b[i - off_b]
		out[i] = clampf(v, -1.0, 1.0)
	return out


func _arpeggio(freqs: Array, step: float, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f: float in freqs:
		out.append_array(_tone(f, step, volume, 0.5))
	return out


# ------------------------------------------------------------------ 写文件


func _write(name: String, samples: PackedFloat32Array) -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	stream.data = data
	var path := OUT_DIR + name + ".wav"
	var err := stream.save_to_wav(ProjectSettings.globalize_path(path))
	print("  %-14s %.2f 秒 -> %s（%d）" % [name, float(samples.size()) / float(RATE), path, err])
