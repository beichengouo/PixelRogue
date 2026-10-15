class_name EnvironmentAudio
extends RefCounted
static var streams: Dictionary = {}
static func sound(kind: String) -> AudioStreamWAV:
	if streams.has(kind): return streams[kind]
	if kind=="rain":
		# Ninja Adventure CC0 ambient rain, isolated from the music playlists.
		var source:=load("res://assets/quality_20261011/weather/Rain2.wav") as AudioStreamWAV
		if source!=null:
			var rain:=source.duplicate() as AudioStreamWAV
			rain.loop_mode=AudioStreamWAV.LOOP_FORWARD
			rain.loop_begin=0
			rain.loop_end=int(round(rain.get_length()*rain.mix_rate))
			streams[kind]=rain
			return rain
	var rate := 16000
	var duration := 2.0 if kind in ["rain","wind"] else 0.09
	var count := int(rate*duration)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var low := 0.0
	for i in count:
		var noise := rng.randf_range(-1,1)
		low = lerpf(low,noise,0.08 if kind=="wind" else 0.3)
		var sample := low*0.32
		if kind not in ["rain","wind"]:
			var t := float(i)/rate
			sample = (noise*0.15+sin(t*(1200 if kind=="wood" else 700))*0.15)*exp(-t*65)
		var value := clampi(int(sample*32767),-32768,32767)
		bytes.encode_s16(i*2,value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	if kind in ["rain","wind"]:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	streams[kind] = stream
	return stream
