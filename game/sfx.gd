extends Node
## Procedurally generated placeholder sounds. Autoloaded as "Sfx".
## Swap any entry in `streams` for a real .wav/.ogg later; play calls stay the same.

const RATE := 22050
var streams := {}
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _i3 := 0
var _i2 := 0

func _ready() -> void:
	seed(1234)
	streams.pistol = _shot(0.75, 0.5, 0.95, 95.0, 0.10)
	streams.uzi = _shot(0.40, 0.6, 0.8, 120.0, 0.06)
	streams.rifle = _shot(0.95, 0.62, 1.0, 72.0, 0.14)
	streams.shotgun = _shot(1.1, 0.32, 1.0, 52.0, 0.20)
	streams.engine = _engine()
	streams.swing = _swing()
	streams.hit = _thud(140.0, 0.12)
	streams.chop = _click(260.0, 0.14)
	streams.rock = _click(900.0, 0.12)
	streams.build = _build()
	streams.groan = _groan()
	streams.scream = _scream()
	streams.crackle = _crackle()
	streams.hurt = _thud(90.0, 0.25)
	streams.click = _click(2400.0, 0.03)
	streams.ping = _chirp()
	streams.craft = _click(600.0, 0.08)
	randomize()
	for i in 24:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 6.0
		p.max_distance = 140.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool3d.append(p)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool2d.append(p)

func play(name: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not streams.has(name):
		return
	var p := _pool2d[_i2]
	_i2 = (_i2 + 1) % _pool2d.size()
	p.stream = streams[name]
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()

func play3d(name: String, pos: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	if not streams.has(name):
		return
	var p := _pool3d[_i3]
	_i3 = (_i3 + 1) % _pool3d.size()
	p.stream = streams[name]
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.92, 1.08)
	p.play()

# ---------------------------------------------------------------- synthesis
func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func _buf(sec: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(sec * RATE))
	return s

## Gunshot: sharp crack, low body thump, then a muffled outdoor echo tail.
func _shot(sec: float, lp: float, vol: float, thump: float, crack_len: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var y := 0.0
	var tail := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var n := randf_range(-1, 1)
		y += lp * (n - y)
		tail += 0.04 * (n - tail)
		var crack := (n * 0.9 + y) * exp(-t / crack_len * 5.0)
		var body := sin(TAU * thump * t * (1.0 - t * 0.6)) * exp(-t * 18.0) * 1.1
		var echo := tail * 3.0 * exp(-t * 4.5) * smoothstep(0.02, 0.09, t)
		s[i] = (crack + body + echo) * vol * 0.85
	return _wav(s)

## Engine loop for vehicles (pitch follows speed).
func _engine() -> AudioStreamWAV:
	var s := _buf(0.2)
	var y := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var ph := fmod(t * 55.0, 1.0)
		var pulse := exp(-ph * 9.0)
		y += 0.2 * (randf_range(-1, 1) - y)
		s[i] = (pulse * 0.8 + sin(TAU * 110.0 * t) * 0.25 + y * 0.25 * pulse) * 0.7
	var w := _wav(s)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = s.size()
	return w

func _swing() -> AudioStreamWAV:
	var s := _buf(0.25)
	var y := 0.0
	for i in s.size():
		var t := float(i) / s.size()
		y += 0.15 * (randf_range(-1, 1) - y)
		s[i] = y * sin(PI * t) * 1.4
	return _wav(s)

func _thud(f: float, sec: float) -> AudioStreamWAV:
	var s := _buf(sec)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = (sin(TAU * f * t) * 0.9 + randf_range(-0.3, 0.3)) * exp(-t * 30.0)
	return _wav(s)

func _click(f: float, sec: float) -> AudioStreamWAV:
	var s := _buf(sec)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = (sin(TAU * f * t) * 0.6 + randf_range(-0.6, 0.6) * exp(-t * 80.0)) * exp(-t * 40.0)
	return _wav(s)

func _build() -> AudioStreamWAV:
	var s := _buf(0.6)
	for i in s.size():
		var t := float(i) / RATE
		var k := fmod(t, 0.2)
		s[i] = (sin(TAU * 80.0 * k) + randf_range(-0.4, 0.4)) * exp(-k * 25.0) * 0.8
	return _wav(s)

func _groan() -> AudioStreamWAV:
	var s := _buf(1.1)
	var ph := 0.0
	var y := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := 78.0 + sin(t * 9.0) * 6.0 - t * 12.0
		ph = fmod(ph + f / RATE, 1.0)
		var saw := ph * 2.0 - 1.0
		y += 0.08 * (saw - y)
		s[i] = y * 2.2 * sin(PI * t / 1.1)
	return _wav(s)

func _scream() -> AudioStreamWAV:
	var s := _buf(0.9)
	var ph := 0.0
	var y := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := 420.0 + 500.0 * sin(PI * t / 0.9) + sin(t * 45.0) * 40.0
		ph = fmod(ph + f / RATE, 1.0)
		y += 0.3 * (randf_range(-1, 1) - y)
		s[i] = (sin(TAU * ph) * 0.5 + (ph * 2.0 - 1.0) * 0.3 + y * 0.5) * sin(PI * t / 0.9) * 0.9
	return _wav(s)

func _crackle() -> AudioStreamWAV:
	var s := _buf(0.5)
	var amp := 0.0
	for i in s.size():
		if randf() < 0.0025:
			amp = randf_range(0.5, 1.0)
		amp *= 0.993
		s[i] = randf_range(-1, 1) * amp
	return _wav(s)

func _chirp() -> AudioStreamWAV:
	var s := _buf(0.22)
	for i in s.size():
		var t := float(i) / RATE
		var f := 1200.0 if t < 0.1 else 1650.0
		s[i] = sin(TAU * f * t) * 0.5 * (1.0 - fmod(t, 0.11) / 0.11)
	return _wav(s)
