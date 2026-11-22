extends Node2D
class_name Creature
## Entidades de Ravenhill com IA própria.
##  Oco (hollow)      — patrulha; vê luz e movimento; persegue; perde o rastro se você se esconde.
##  Estática (static) — surge perto de postes que piscam; investidas curtas; some e reaparece.
##  Ouvinte (listener)— cego; reage a ruído (correr, portas); agachado você passa.
##  Maestro (conductor) — chefe: persegue sempre, mais lento; derrotado pelos relés da torre.

enum S { DORMANT, PATROL, ALERT, CHASE, SEARCH, RETREAT }

var id: String = "hollow"
var data: Dictionary = {}
var actor: Actor
var world: Node
var state: int = S.PATROL
var patrol_a: float = 0.0
var patrol_b: float = 0.0
var target_x: float = 0.0
var last_seen_x: float = 0.0
var _t: float = 0.0
var _search_t: float = 0.0
var _retreat_t: float = 0.0
var _growl_t: float = 0.0
var sight: float = 380.0
var hearing: float = 300.0
var spd_patrol: float = 45.0
var spd_chase: float = 190.0
var damage: float = 34.0
var light_sensitive: bool = true
var form: String = "hollow"
var aware: float = 0.0          # 0..1 barra de suspeita antes de perseguir


func setup(creature_id: String, a: float, b: float, w: Node) -> void:
	id = creature_id
	data = Data.creatures.get(id, {})
	world = w
	form = data.get("form", "hollow")
	sight = float(data.get("sight", 380))
	hearing = float(data.get("hearing", 300))
	spd_patrol = float(data.get("speed", 45))
	spd_chase = float(data.get("chase_speed", 190))
	damage = float(data.get("damage", 34))
	light_sensitive = data.get("light_sensitive", true)
	patrol_a = minf(a, b)
	patrol_b = maxf(a, b)
	target_x = patrol_b
	actor = Actor.new()
	add_child(actor)
	actor.setup(id, "creature")
	if form == "static":
		state = S.DORMANT
		visible = false
	if form == "conductor":
		state = S.CHASE


func _process(delta: float) -> void:
	_t += delta
	var p: Player = world.player
	if p == null or world.cutscene_running:
		return
	var dx := p.position.x - position.x
	var dist := absf(dx)
	match state:
		S.DORMANT:
			_dormant(p, dist, delta)
		S.PATROL:
			_move_to(target_x, spd_patrol, delta, "walk")
			if absf(position.x - target_x) < 8.0:
				target_x = patrol_a if target_x == patrol_b else patrol_b
			_perceive(p, dx, dist, delta)
		S.ALERT:
			_move_to(target_x, spd_patrol * 1.8, delta, "walk")
			if absf(position.x - target_x) < 10.0:
				state = S.SEARCH
				_search_t = 5.0
			_perceive(p, dx, dist, delta)
		S.CHASE:
			if p.is_hidden and dist > 70.0:
				state = S.SEARCH
				_search_t = 3.0 if form == "conductor" else 6.0
				target_x = last_seen_x
			else:
				last_seen_x = p.position.x
				_move_to(p.position.x, spd_chase, delta, "chase")
				if dist < 46.0 and not p.is_hidden:
					p.hurt(damage, position.x)
					world.fx.shake(10.0)
					if form == "static":
						_vanish()
					elif form != "conductor":
						state = S.RETREAT
						_retreat_t = 2.5
				var lose := sight * 1.6 if form != "listener" else hearing * 1.4
				if dist > lose and form != "conductor":
					state = S.SEARCH
					_search_t = 5.0
					target_x = last_seen_x
			_growl_t -= delta
			if _growl_t <= 0.0:
				_growl_t = randf_range(2.5, 5.0)
				Sfx.play("creature", 0.6)
		S.SEARCH:
			_search_t -= delta
			var sx := last_seen_x + sin(_t * 0.9) * 140.0
			_move_to(sx, spd_patrol * 1.4, delta, "walk")
			_perceive(p, dx, dist, delta)
			if _search_t <= 0.0:
				if form == "static":
					_vanish()
				else:
					state = S.PATROL
		S.RETREAT:
			_retreat_t -= delta
			_move_to(position.x - signf(dx) * 300.0, spd_patrol * 2.0, delta, "walk")
			if _retreat_t <= 0.0:
				state = S.PATROL
	# medo do jogador cresce com proximidade/visibilidade
	if state == S.CHASE:
		p.scare(delta * 0.8)
	elif dist < 500.0 and visible:
		p.scare(delta * 0.15 * (1.0 - dist / 500.0))


func _perceive(p: Player, dx: float, dist: float, delta: float) -> void:
	if p.is_hidden:
		aware = maxf(0.0, aware - delta)
		return
	var facing_player := signf(dx) == float(actor.facing) or dist < 90.0
	var see := sight
	if light_sensitive and p.flashlight_on:
		see *= 1.7
	if p.crouching:
		see *= 0.55
	see *= lerpf(1.0, 0.75, Clock.darkness()) if not p.flashlight_on else 1.0
	var seen := form != "listener" and facing_player and dist < see
	var heard := dist < hearing * p.noise
	if seen:
		aware += delta * (2.4 if dist < see * 0.5 else 1.1)
	elif heard:
		aware += delta * 1.5
		target_x = p.position.x
		if state == S.PATROL:
			state = S.ALERT
			actor.set_facing(int(signf(dx)))
	else:
		aware = maxf(0.0, aware - delta * 0.35)
	if aware >= 1.0:
		aware = 1.0
		_start_chase(p)


func _start_chase(p: Player) -> void:
	if state == S.CHASE:
		return
	state = S.CHASE
	last_seen_x = p.position.x
	Sfx.play("stinger", 0.9)
	world.on_chase_started(self)


func notify_noise(x: float, loud: float) -> void:
	if state in [S.PATROL, S.SEARCH] and absf(x - position.x) < hearing * loud * 1.2:
		target_x = x
		state = S.ALERT


func _dormant(p: Player, dist: float, delta: float) -> void:
	# Estática: desperta à noite perto do jogador, junto a um poste piscando
	if not Clock.is_night():
		return
	_search_t -= delta
	if _search_t > 0.0:
		return
	if dist < 600.0 and randf() < delta * 0.25:
		var side := -1.0 if randf() < 0.5 else 1.0
		position.x = clampf(p.position.x + side * randf_range(260.0, 380.0), 60.0, world.stage_width - 60.0)
		visible = true
		actor.set_facing(int(-side))
		Sfx.play("glitch", 0.8)
		world.fx.set_glitch(0.6)
		world.flicker_lamps(1.2)
		get_tree().create_timer(0.8).timeout.connect(_end_glitch)
		aware = 0.6
		state = S.SEARCH
		_search_t = 4.0
		last_seen_x = p.position.x


func _end_glitch() -> void:
	if is_instance_valid(world) and world.fx:
		world.fx.set_glitch(0.0)


func _vanish() -> void:
	visible = false
	state = S.DORMANT
	_search_t = randf_range(18.0, 35.0)
	aware = 0.0
	world.on_chase_ended(self)


func _move_to(x: float, spd: float, delta: float, anim: String) -> void:
	var d := x - position.x
	if absf(d) < 3.0:
		actor.play("idle")
		return
	position.x = clampf(position.x + signf(d) * minf(absf(d), spd * delta), 30.0, world.stage_width - 30.0)
	actor.set_facing(int(signf(d)))
	actor.play(anim)
	actor.speed_scale = spd / 60.0 if anim == "walk" else 1.0


func is_chasing() -> bool:
	return state == S.CHASE
