extends Node
## Звук без внешних файлов: все эффекты синтезируются при запуске в AudioStreamWAV.
## Sfx.play("shot", позиция_в_мире) — позиционный звук; без позиции — обычный (интерфейс).

const RATE := 22050
const POOL_2D := 12
const POOL_3D := 28

var _bank: Dictionary = {}        # имя -> Array[AudioStreamWAV] (варианты)
var _last: Dictionary = {}        # имя -> время последнего запуска (защита от «каши»)
var _p2: Array[AudioStreamPlayer] = []
var _p3: Array[AudioStreamPlayer3D] = []
var _rng := RandomNumberGenerator.new()
var _ambient: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _ready_done := false


func _ready() -> void:
	_rng.seed = 20260930
	if DisplayServer.get_name() == "headless":
		return   # без аудиоустройства синтез не нужен
	_build_bus()
	_synthesize()
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_p2.append(p)
	for i in POOL_3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.unit_size = 9.0
		p3.max_distance = 70.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p3)
		_p3.append(p3)
	_ready_done = true


func _build_bus() -> void:
	if AudioServer.get_bus_index("SFX") != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, "SFX")
	AudioServer.set_bus_send(idx, "Master")
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.55
	rev.damping = 0.6
	rev.wet = 0.16
	rev.dry = 0.95
	AudioServer.add_bus_effect(idx, rev)
	var comp := AudioEffectLimiter.new()
	comp.ceiling_db = -1.0
	AudioServer.add_bus_effect(idx, comp)


## Запуск ambient-петель (ветер и низкий гул). Вызывать при входе в игру.
func start_ambient() -> void:
	if not _ready_done or _ambient != null:
		return
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = _bank["wind"][0]
	_ambient.bus = "SFX"
	_ambient.volume_db = -14.0
	add_child(_ambient)
	_ambient.play()
	_drone = AudioStreamPlayer.new()
	_drone.stream = _bank["drone"][0]
	_drone.bus = "SFX"
	_drone.volume_db = -20.0
	add_child(_drone)
	_drone.play()


func stop_ambient() -> void:
	for p in [_ambient, _drone]:
		if p != null:
			p.queue_free()
	_ambient = null
	_drone = null


## Проиграть звук. pos — Vector3 (позиционный) или null.
func play(sound: String, pos: Variant = null, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _ready_done or not _bank.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var min_gap := 0.02
	match sound:
		"shot": min_gap = 0.045
		"mg": min_gap = 0.055
		"ak": min_gap = 0.05
		"step": min_gap = 0.12
		"flame": min_gap = 0.09
		"groan": min_gap = 0.4
		"hurt": min_gap = 0.08
	if now - float(_last.get(sound, -1.0)) < min_gap:
		return
	_last[sound] = now
	var variants: Array = _bank[sound]
	var stream: AudioStreamWAV = variants[_rng.randi() % variants.size()]
	pitch *= _rng.randf_range(0.94, 1.06)
	if pos is Vector3:
		for p in _p3:
			if not p.playing:
				p.stream = stream
				p.global_position = pos
				p.volume_db = vol_db
				p.pitch_scale = pitch
				p.play()
				return
	else:
		for p in _p2:
			if not p.playing:
				p.stream = stream
				p.volume_db = vol_db
				p.pitch_scale = pitch
				p.play()
				return


# ───────────────────────── синтез ─────────────────────────

func _synthesize() -> void:
	_add("shot", 3, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.16)
		_noise(b, 0.0, 0.07, 0.55, 1800.0 + i * 260.0, 900.0)
		_tone(b, 0.0, 0.10, 330.0 - i * 20.0, 90.0, 0.5, 0)
		return b)
	_add("shot_manual", 2, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.28)
		_noise(b, 0.0, 0.12, 0.8, 1200.0, 500.0)
		_tone(b, 0.0, 0.18, 260.0, 55.0, 0.75, 0)
		_noise(b, 0.0, 0.25, 0.25, 500.0, 150.0)
		return b)
	_add("mg", 3, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.1)
		_noise(b, 0.0, 0.05, 0.55, 2400.0 + i * 200.0, 1200.0)
		_tone(b, 0.0, 0.06, 240.0, 110.0, 0.35, 1)
		return b)
	_add("rocket", 2, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.7)
		_noise(b, 0.0, 0.6, 0.6, 700.0, 200.0)
		_tone(b, 0.0, 0.5, 180.0, 460.0, 0.32, 2)
		_tone(b, 0.0, 0.25, 90.0, 60.0, 0.5, 0)
		return b)
	_add("flame", 3, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.2)
		_noise(b, 0.0, 0.16, 0.45, 520.0 + i * 90.0, 160.0)
		return b)
	_add("hit", 2, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.08)
		_tone(b, 0.0, 0.06, 190.0, 110.0, 0.5, 1)
		_noise(b, 0.0, 0.04, 0.3, 1400.0, 600.0)
		return b)
	_add("hurt", 3, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.16)
		_noise(b, 0.0, 0.08, 0.3, 900.0, 300.0)
		_tone(b, 0.0, 0.14, 210.0 + i * 25.0, 120.0, 0.25, 2)
		return b)
	_add("kill", 3, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.42)
		_tone(b, 0.0, 0.32, 170.0 - i * 15.0, 35.0, 0.55, 2)
		_noise(b, 0.0, 0.18, 0.4, 500.0, 150.0)
		return b)
	_add("groan", 4, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.9)
		var f := 78.0 + i * 11.0
		_tone(b, 0.0, 0.8, f * 1.4, f * 0.8, 0.5, 2)
		_tone(b, 0.05, 0.7, f * 2.1, f * 1.2, 0.22, 2)
		_noise(b, 0.0, 0.8, 0.12, 380.0, 120.0)
		return b)
	_add("coin", 1, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.25)
		_tone(b, 0.0, 0.09, 880.0, 880.0, 0.35, 0)
		_tone(b, 0.07, 0.15, 1320.0, 1320.0, 0.35, 0)
		return b)
	_add("build", 2, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.3)
		_tone(b, 0.0, 0.12, 200.0, 140.0, 0.6, 3)
		_noise(b, 0.0, 0.07, 0.5, 700.0, 250.0)
		return b)
	_add("sell", 1, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.3)
		_tone(b, 0.0, 0.16, 1200.0, 600.0, 0.35, 0)
		_tone(b, 0.08, 0.14, 900.0, 900.0, 0.3, 0)
		return b)
	_add("upgrade", 1, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.6)
		var notes := [523.0, 659.0, 784.0, 1046.0]
		for k in 4:
			_tone(b, k * 0.07, 0.16, notes[k], notes[k], 0.35, 3)
		return b)
	_add("error", 1, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.25)
		_tone(b, 0.0, 0.18, 130.0, 105.0, 0.5, 1)
		return b)
	_add("click", 1, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.06)
		_tone(b, 0.0, 0.03, 900.0, 500.0, 0.25, 3)
		return b)
	_add("wave_start", 1, func(i: int) -> PackedFloat32Array:
		var b := _buf(1.4)
		_tone(b, 0.0, 0.8, 110.0, 110.0, 0.5, 2)
		_tone(b, 0.0, 0.8, 165.0, 165.0, 0.25, 2)
		_tone(b, 0.45, 0.9, 147.0, 147.0, 0.5, 2)
		_tone(b, 0.45, 0.9, 220.0, 220.0, 0.25, 2)
		return b)
	_add("game_over", 1, func(i: int) -> PackedFloat32Array:
		var b := _buf(2.0)
		_tone(b, 0.0, 1.4, 300.0, 40.0, 0.55, 2)
		_tone(b, 0.3, 1.2, 200.0, 30.0, 0.35, 1)
		_noise(b, 0.0, 1.6, 0.25, 260.0, 90.0)
		return b)
	_add("enter", 1, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.25)
		_tone(b, 0.0, 0.16, 300.0, 600.0, 0.4, 0)
		return b)
	# личное оружие «Свободного FPS»
	_add("ak", 3, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.3)
		_noise(b, 0.0, 0.05, 0.9, 3600.0, 700.0)
		_noise(b, 0.0, 0.22, 0.5, 900.0 + i * 120.0, 120.0)
		_tone(b, 0.0, 0.12, 200.0, 48.0, 0.7, 0)
		return b)
	_add("swing", 2, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.3)
		_noise(b, 0.0, 0.26, 0.4, 2600.0 + i * 500.0, 500.0)
		return b)
	_add("chop", 3, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.2)
		_tone(b, 0.0, 0.09, 140.0 - i * 10.0, 60.0, 0.7, 1)
		_noise(b, 0.0, 0.1, 0.7, 1800.0, 250.0)
		return b)
	_add("reload", 1, func(i: int) -> PackedFloat32Array:
		var b := _buf(2.3)
		_tone(b, 0.15, 0.05, 1500.0, 600.0, 0.5, 1)
		_noise(b, 0.15, 0.06, 0.5, 4000.0, 1200.0)
		_noise(b, 1.25, 0.05, 0.6, 3000.0, 800.0)
		_tone(b, 1.25, 0.06, 900.0, 400.0, 0.5, 1)
		_tone(b, 1.85, 0.06, 500.0, 250.0, 0.6, 1)
		_noise(b, 1.85, 0.08, 0.6, 2500.0, 500.0)
		return b)
	_add("empty", 1, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.08)
		_tone(b, 0.0, 0.04, 1800.0, 900.0, 0.35, 1)
		return b)
	_add("step", 3, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.14)
		_noise(b, 0.0, 0.1, 0.5, 500.0 + i * 60.0, 90.0)
		return b)
	_add("pain", 2, func(i: int) -> PackedFloat32Array:
		var b := _buf(0.3)
		_tone(b, 0.0, 0.22, 240.0 + i * 30.0, 120.0, 0.5, 2)
		_noise(b, 0.0, 0.12, 0.3, 800.0, 200.0)
		return b)
	_add("boom", 3, func(i: int) -> PackedFloat32Array:
		var b := _buf(1.1)
		_noise(b, 0.0, 0.9, 0.9, 320.0 - i * 40.0, 60.0)
		_tone(b, 0.0, 0.9, 110.0, 24.0, 0.85, 2)
		_tone(b, 0.0, 0.5, 60.0, 30.0, 0.7, 0)
		return b)
	_add("wind", 1, func(i: int) -> PackedFloat32Array: return _loop_wind(6.0))
	_add("drone", 1, func(i: int) -> PackedFloat32Array: return _loop_drone(8.0))
	# петли
	for name in ["wind", "drone"]:
		var s: AudioStreamWAV = _bank[name][0]
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2


func _add(name: String, variants: int, maker: Callable) -> void:
	var list: Array = []
	for i in variants:
		var samples: PackedFloat32Array = maker.call(i)
		list.append(_to_wav(samples))
	_bank[name] = list


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := clampi(int(samples[i] * 32000.0), -32768, 32767)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


## Тон с экспоненциальным изменением частоты и спадом громкости. wave: 0 sin, 1 square, 2 saw, 3 triangle.
func _tone(b: PackedFloat32Array, t0: float, dur: float, f0: float, f1: float, vol: float, wave: int) -> void:
	var start := int(t0 * RATE)
	var n := int(dur * RATE)
	var phase := 0.0
	var ratio: float = maxf(f1, 1.0) / maxf(f0, 1.0)
	for i in n:
		if start + i >= b.size():
			break
		var t := float(i) / float(n)
		var f: float = f0 * pow(ratio, t)
		phase += f / RATE
		var ph: float = phase - floorf(phase)
		var s: float
		match wave:
			1: s = 1.0 if ph < 0.5 else -1.0
			2: s = 2.0 * ph - 1.0
			3: s = 4.0 * absf(ph - 0.5) - 1.0
			_: s = sin(ph * TAU)
		var env: float = pow(1.0 - t, 2.0) * minf(1.0, float(i) / 60.0)
		b[start + i] += s * env * vol


## Шум, пропущенный через полосу [hp, lp] (два однополюсных фильтра), со спадом громкости.
func _noise(b: PackedFloat32Array, t0: float, dur: float, vol: float, lp: float, hp: float) -> void:
	var start := int(t0 * RATE)
	var n := int(dur * RATE)
	var a_lp := 1.0 - exp(-TAU * lp / RATE)
	var a_hp := 1.0 - exp(-TAU * hp / RATE)
	var y1 := 0.0
	var y2 := 0.0
	for i in n:
		if start + i >= b.size():
			break
		var x := _rng.randf_range(-1.0, 1.0)
		y1 += a_lp * (x - y1)
		y2 += a_hp * (y1 - y2)
		var t := float(i) / float(n)
		var env: float = pow(1.0 - t, 1.6) * minf(1.0, float(i) / 40.0)
		b[start + i] += (y1 - y2) * env * vol * 2.2


func _loop_wind(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var y1 := 0.0
	var y2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var gust := 0.5 + 0.5 * sin(t * TAU / seconds * 2.0) * sin(t * TAU / seconds * 3.0 + 1.0)
		var cutoff := 260.0 + 300.0 * gust
		var a := 1.0 - exp(-TAU * cutoff / RATE)
		y1 += a * (_rng.randf_range(-1.0, 1.0) - y1)
		y2 += 0.02 * (y1 - y2)
		b[i] = (y1 - y2) * (0.5 + 0.7 * gust) * 0.9
	# плавное «склеивание» концов петли
	var fade := int(0.4 * RATE)
	for i in fade:
		var k := float(i) / fade
		b[i] = b[i] * k + b[n - fade + i] * (1.0 - k)
	return b


func _loop_drone(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		var t := float(i) / RATE
		var lfo := 0.6 + 0.4 * sin(t * TAU / seconds * 2.0)
		var s := sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 82.4 * t) * 0.3 + sin(TAU * 110.7 * t + sin(t * 0.7)) * 0.18
		b[i] = s * lfo * 0.35
	return b
