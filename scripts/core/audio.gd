extends Node
## Áudio 100% original, sintetizado no início do jogo (sem arquivos externos).
## Ambientes em camadas com volume contínuo (cidade, vento, chuva, drone noturno,
## estática de rádio, interior, perseguição) + efeitos pontuais com variação de pitch.
## Se existir res://audio/<nome>.ogg ele substitui o som sintetizado (dublagem/trilha futura).

const SR := 16000
const LOOP_SECONDS := 9.0

var _layers: Dictionary = {}      # nome -> AudioStreamPlayer
var _target: Dictionary = {}      # nome -> volume alvo linear 0..1
var _sfx: Dictionary = {}         # nome -> AudioStream
var _pool: Array = []
var _rng := RandomNumberGenerator.new()
var _one_shot_timer: float = 6.0
var ready_done: bool = false
var context: Dictionary = {"interior": false, "night": false, "rain": false, "chase": 0.0, "static": 0.0, "tension": 0.0, "outdoor_city": true}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 20041031
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_build_sfx()
	_build_layers()
	ready_done = true


func _process(delta: float) -> void:
	if not ready_done:
		return
	_update_targets()
	var mus: float = Game.settings.get("music", 0.8)
	for n in _layers:
		var p: AudioStreamPlayer = _layers[n]
		var cur := db_to_linear(p.volume_db) if p.volume_db > -79.0 else 0.0
		var tgt: float = _target.get(n, 0.0) * mus
		cur = move_toward(cur, tgt, delta * 0.6)
		p.volume_db = linear_to_db(maxf(cur, 0.0001))
		if cur > 0.001 and not p.playing:
			p.play(_rng.randf() * LOOP_SECONDS * 0.9)
		elif cur <= 0.001 and p.playing:
			p.stop()
	# eventos sonoros esparsos para quebrar a repetição dos loops
	_one_shot_timer -= delta
	if _one_shot_timer <= 0.0:
		_one_shot_timer = _rng.randf_range(7.0, 18.0)
		_ambient_event()


func _update_targets() -> void:
	var night: bool = context["night"]
	var inside: bool = context["interior"]
	var rain: bool = context["rain"]
	var t: float = context["tension"]
	_target["city"] = 0.0 if (night or inside or not context["outdoor_city"]) else 0.35
	_target["wind"] = (0.12 if inside else (0.45 if night else 0.18))
	_target["rain"] = (0.0 if not rain else (0.18 if inside else 0.55))
	_target["drone"] = clampf((0.35 if night else 0.06) + t * 0.4, 0.0, 0.8)
	_target["room"] = 0.25 if inside else 0.0
	_target["static"] = clampf(context["static"], 0.0, 0.7)
	_target["chase"] = clampf(context["chase"], 0.0, 0.9)


func set_context(key: String, value) -> void:
	context[key] = value


func play(name: String, volume: float = 1.0, pitch_var: float = 0.08) -> void:
	if not _sfx.has(name):
		return
	var vol: float = Game.settings.get("sfx", 0.9) * volume
	if vol <= 0.001:
		return
	for p in _pool:
		if not p.playing:
			p.stream = _sfx[name]
			p.volume_db = linear_to_db(vol)
			p.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
			p.play()
			return


func _ambient_event() -> void:
	if context["interior"]:
		play(["creak", "creak", "drip", "knock"][_rng.randi() % 4], 0.35, 0.2)
	elif context["night"]:
		play(["far_call", "creak", "dog", "whisper", "far_call"][_rng.randi() % 5], 0.3, 0.15)
		if context["rain"] and _rng.randf() < 0.35:
			play("thunder", 0.55, 0.1)
	else:
		play(["car", "bird", "bird", "dog"][_rng.randi() % 4], 0.25, 0.12)


# ------------------------------------------------------------- síntese
func _override(name: String) -> AudioStream:
	var p := "res://audio/%s.ogg" % name
	if ResourceLoader.exists(p):
		return load(p)
	return null


func _wav(s: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var b := PackedByteArray()
	b.resize(s.size() * 2)
	for i in s.size():
		b.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = b
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w


## Fecha o loop sem estalo: mistura o final no começo.
func _seamless(s: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := s.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = s[i]
	for i in fade:
		var t := float(i) / fade
		out[i] = s[n + i] * (1.0 - t) + s[i] * t
	return out


func _normalize(s: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in s:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in s.size():
		s[i] *= k
	return s


func _layer(name: String, s: PackedFloat32Array) -> void:
	var p := AudioStreamPlayer.new()
	var ov := _override(name)
	p.stream = ov if ov else _wav(_normalize(_seamless(s, int(SR * 0.5)), 0.8), true)
	p.volume_db = -80.0
	add_child(p)
	_layers[name] = p


func _build_layers() -> void:
	var n := int(SR * (LOOP_SECONDS + 0.5))
	var r := _rng
	# vento: ruído marrom com rajadas lentas
	var wind := PackedFloat32Array(); wind.resize(n)
	var br := 0.0
	for i in n:
		br = clampf(br + r.randf_range(-0.02, 0.02), -1.0, 1.0) * 0.998
		var gust := 0.55 + 0.45 * sin(TAU * i / SR * 0.11) * sin(TAU * i / SR * 0.037 + 1.3)
		wind[i] = br * gust
	_layer("wind", wind)
	# chuva: ruído branco com passa-alta simples + gotas
	var rain := PackedFloat32Array(); rain.resize(n)
	var lp := 0.0
	for i in n:
		var w := r.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.25
		var drop := 0.0
		if r.randf() < 0.0025:
			drop = r.randf_range(0.4, 0.9)
		rain[i] = (w - lp) * 0.6 + drop * (1.0 if r.randf() < 0.5 else -1.0)
	_layer("rain", rain)
	# drone noturno: acordes graves desafinados com batimento
	var drone := PackedFloat32Array(); drone.resize(n)
	for i in n:
		var t := float(i) / SR
		var a := sin(TAU * 55.0 * t) + 0.8 * sin(TAU * 55.37 * t) + 0.5 * sin(TAU * 82.6 * t + sin(TAU * 0.2 * t))
		a += 0.25 * sin(TAU * 116.5 * t) * (0.5 + 0.5 * sin(TAU * 0.07 * t))
		drone[i] = a * 0.3
	_layer("drone", drone)
	# cidade de dia: zumbido distante + tráfego filtrado
	var city := PackedFloat32Array(); city.resize(n)
	var c1 := 0.0
	for i in n:
		c1 += (r.randf_range(-1.0, 1.0) - c1) * 0.03
		var t := float(i) / SR
		city[i] = c1 * (0.7 + 0.3 * sin(TAU * t * 0.15)) + 0.05 * sin(TAU * 120.0 * t)
	_layer("city", city)
	# interior: ar parado, geladeira, madeira
	var room := PackedFloat32Array(); room.resize(n)
	var rl := 0.0
	for i in n:
		rl += (r.randf_range(-1.0, 1.0) - rl) * 0.01
		var t := float(i) / SR
		room[i] = rl * 2.0 + 0.04 * sin(TAU * 60.0 * t) + 0.02 * sin(TAU * 180.0 * t)
	_layer("room", room)
	# estática de rádio: chiado + estalos + tom de portadora
	var stat := PackedFloat32Array(); stat.resize(n)
	for i in n:
		var t := float(i) / SR
		var crackle := 0.0
		if r.randf() < 0.004:
			crackle = r.randf_range(-1.0, 1.0)
		stat[i] = r.randf_range(-0.5, 0.5) * (0.6 + 0.4 * sin(TAU * t * 3.1)) + crackle + 0.1 * sin(TAU * 717.0 * t) * (0.5 + 0.5 * sin(TAU * t * 0.5))
	_layer("static", stat)
	# perseguição: pulso grave + cluster agudo
	var chase := PackedFloat32Array(); chase.resize(n)
	for i in n:
		var t := float(i) / SR
		var beat := pow(maxf(0.0, sin(TAU * t * 2.2)), 8.0)
		var hi := (sin(TAU * 622.0 * t) + sin(TAU * 659.0 * t) + sin(TAU * 698.0 * t)) * 0.08 * (0.6 + 0.4 * sin(TAU * t * 0.3))
		chase[i] = sin(TAU * 41.0 * t) * beat * 1.2 + hi + r.randf_range(-0.05, 0.05) * beat
	_layer("chase", chase)


func _env(i: int, n: int, attack: float, rel: float) -> float:
	var t := float(i) / SR
	var dur := float(n) / SR
	if t < attack:
		return t / attack
	return clampf(1.0 - (t - attack) / maxf(rel, 0.0001), 0.0, 1.0) * (1.0 if t < dur else 0.0)


func _make(name: String, seconds: float, fn: Callable) -> void:
	var ov := _override(name)
	if ov:
		_sfx[name] = ov
		return
	var n := int(SR * seconds)
	var s := PackedFloat32Array(); s.resize(n)
	var state := {"lp": 0.0, "ph": 0.0}
	for i in n:
		s[i] = fn.call(i, n, state)
	_sfx[name] = _wav(_normalize(s, 0.9), false)


func _build_sfx() -> void:
	var r := _rng
	_make("step", 0.12, func(i, n, st):
		var w := r.randf_range(-1.0, 1.0)
		st["lp"] += (w - st["lp"]) * 0.12
		return st["lp"] * exp(-float(i) / (SR * 0.025))
	)
	_make("door", 1.1, func(i, n, st):
		var t := float(i) / SR
		var f := 300.0 + 180.0 * sin(TAU * t * 1.7) + 60.0 * sin(TAU * t * 13.0)
		st["ph"] += TAU * f / SR
		var creak := sin(st["ph"]) * (0.5 + 0.5 * sin(TAU * t * 31.0))
		var thud := r.randf_range(-1.0, 1.0) * exp(-(t - 0.95) * 30.0) if t > 0.95 else 0.0
		return creak * _env(i, n, 0.05, 0.9) * 0.6 + thud
	)
	_make("creak", 0.9, func(i, n, st):
		var t := float(i) / SR
		st["ph"] += TAU * (180.0 + 90.0 * sin(TAU * t * 2.3)) / SR
		return sin(st["ph"]) * (0.5 + 0.5 * sin(TAU * t * 23.0)) * _env(i, n, 0.1, 0.8)
	)
	_make("knock", 0.6, func(i, n, st):
		var t := float(i) / SR
		var k := 0.0
		for o in [0.0, 0.18, 0.36]:
			if t >= o:
				k += sin(TAU * 110.0 * (t - o)) * exp(-(t - o) * 40.0)
		return k
	)
	_make("drip", 0.3, func(i, n, st):
		var t := float(i) / SR
		return sin(TAU * (1400.0 - 2600.0 * t) * t) * exp(-t * 25.0)
	)
	_make("pickup", 0.7, func(i, n, st):
		var t := float(i) / SR
		return (sin(TAU * 523.0 * t) + 0.6 * sin(TAU * 784.0 * t) * (1.0 if t > 0.12 else 0.0)) * exp(-t * 5.0)
	)
	_make("mission", 1.2, func(i, n, st):
		var t := float(i) / SR
		return (sin(TAU * 220.0 * t) + sin(TAU * 277.0 * t) + sin(TAU * 330.0 * t)) * _env(i, n, 0.3, 0.9) * 0.5
	)
	_make("stinger", 1.6, func(i, n, st):
		var t := float(i) / SR
		var c := sin(TAU * 466.0 * t) + sin(TAU * 494.0 * t) + sin(TAU * 523.0 * t * (1.0 + t * 0.02))
		var low := sin(TAU * 46.0 * t) * 1.5
		return (c * 0.4 + low + r.randf_range(-0.3, 0.3)) * _env(i, n, 0.02, 1.5)
	)
	_make("heartbeat", 0.8, func(i, n, st):
		var t := float(i) / SR
		var a := sin(TAU * 50.0 * t) * exp(-t * 18.0)
		var b := sin(TAU * 45.0 * (t - 0.22)) * exp(-(t - 0.22) * 18.0) if t > 0.22 else 0.0
		return a + b * 0.8
	)
	_make("photo", 0.5, func(i, n, st):
		var t := float(i) / SR
		var click := r.randf_range(-1.0, 1.0) * exp(-t * 90.0)
		var whir := sin(TAU * 900.0 * t) * 0.2 * (1.0 if t > 0.1 and t < 0.45 else 0.0)
		return click + whir
	)
	_make("radio_on", 0.6, func(i, n, st):
		var t := float(i) / SR
		return r.randf_range(-1.0, 1.0) * _env(i, n, 0.01, 0.55) * (0.6 + 0.4 * sin(TAU * t * 40.0))
	)
	_make("whisper", 2.2, func(i, n, st):
		var t := float(i) / SR
		var w := r.randf_range(-1.0, 1.0)
		st["lp"] += (w - st["lp"]) * 0.35
		var hp: float = w - st["lp"]
		var syll := pow(maxf(0.0, sin(TAU * t * 3.3 + sin(TAU * t * 0.7))), 2.0)
		return hp * syll * _env(i, n, 0.3, 1.9)
	)
	_make("far_call", 2.6, func(i, n, st):
		var t := float(i) / SR
		var f := 380.0 + 140.0 * sin(TAU * t * 0.35) - 60.0 * t
		st["ph"] += TAU * f / SR
		var v: float = sin(st["ph"]) + 0.4 * sin(st["ph"] * 2.01) + 0.2 * sin(st["ph"] * 3.02)
		return v * _env(i, n, 0.4, 2.2) * 0.4
	)
	_make("thunder", 4.0, func(i, n, st):
		var t := float(i) / SR
		st["lp"] += (r.randf_range(-1.0, 1.0) - st["lp"]) * 0.02
		var crack := r.randf_range(-1.0, 1.0) * exp(-t * 12.0) * 0.4
		return st["lp"] * 6.0 * (0.4 + 0.6 * absf(sin(TAU * t * 1.3))) * exp(-t * 0.8) + crack
	)
	_make("dog", 0.9, func(i, n, st):
		var t := float(i) / SR
		var bark := 0.0
		for o in [0.0, 0.35]:
			if t >= o and t < o + 0.18:
				st["ph"] += TAU * (520.0 - 900.0 * (t - o)) / SR
				bark = (sin(st["ph"]) + r.randf_range(-0.4, 0.4)) * exp(-(t - o) * 14.0)
		return bark
	)
	_make("bird", 0.5, func(i, n, st):
		var t := float(i) / SR
		return sin(TAU * (2600.0 + 900.0 * sin(TAU * t * 18.0)) * t) * _env(i, n, 0.02, 0.4) * (1.0 if fmod(t, 0.16) < 0.09 else 0.0)
	)
	_make("car", 3.0, func(i, n, st):
		var t := float(i) / SR
		st["lp"] += (r.randf_range(-1.0, 1.0) - st["lp"]) * 0.05
		var dop := 1.0 - absf(t - 1.5) / 1.5
		return (st["lp"] * 3.0 + 0.3 * sin(TAU * (90.0 + 20.0 * dop) * t)) * dop * dop
	)
	_make("ui_move", 0.08, func(i, n, st):
		var t := float(i) / SR
		return sin(TAU * 880.0 * t) * exp(-t * 60.0)
	)
	_make("ui_ok", 0.35, func(i, n, st):
		var t := float(i) / SR
		return (sin(TAU * 440.0 * t) + sin(TAU * 660.0 * t) * (1.0 if t > 0.07 else 0.0)) * exp(-t * 9.0)
	)
	_make("ui_back", 0.25, func(i, n, st):
		var t := float(i) / SR
		return sin(TAU * (500.0 - 600.0 * t) * t) * exp(-t * 12.0)
	)
	_make("hurt", 0.6, func(i, n, st):
		var t := float(i) / SR
		return (r.randf_range(-1.0, 1.0) * 0.5 + sin(TAU * 70.0 * t)) * exp(-t * 6.0)
	)
	_make("creature", 1.8, func(i, n, st):
		var t := float(i) / SR
		var f := 95.0 + 40.0 * sin(TAU * t * 5.0) + r.randf_range(-15.0, 15.0)
		st["ph"] += TAU * f / SR
		var growl: float = signf(sin(st["ph"])) * 0.4 + sin(st["ph"] * 0.5)
		return growl * _env(i, n, 0.2, 1.5) * (0.6 + 0.4 * r.randf())
	)
	_make("glitch", 0.7, func(i, n, st):
		var t := float(i) / SR
		var seg := int(t * 40.0)
		return (sin(TAU * (200.0 + float(seg % 7) * 180.0) * t) * 0.6 + r.randf_range(-0.5, 0.5)) * (1.0 if seg % 3 != 0 else 0.1) * _env(i, n, 0.01, 0.65)
	)
	_make("hide", 0.4, func(i, n, st):
		var t := float(i) / SR
		st["lp"] += (r.randf_range(-1.0, 1.0) - st["lp"]) * 0.2
		return st["lp"] * 2.0 * _env(i, n, 0.05, 0.35)
	)
	_make("flashlight", 0.12, func(i, n, st):
		var t := float(i) / SR
		return r.randf_range(-1.0, 1.0) * exp(-t * 120.0) + sin(TAU * 2000.0 * t) * exp(-t * 80.0) * 0.3
	)
