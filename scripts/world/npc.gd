extends Node2D
class_name NPC
## Morador de Ravenhill. Segue a agenda (local/hora), anda, conversa, reage ao
## jogador. Espíritos disfarçados têm "sinais": sem reflexo, chiado no rádio,
## aparecem queimados na foto, brilham na Visão, comportamentos noturnos estranhos.

var id: String = ""
var data: Dictionary = {}
var actor: Actor
var world: Node
var target_x: float = 0.0
var home_x: float = 0.0
var pose: String = "idle"        # idle | wander | wall | sit | pace
var leaving: bool = false
var talking: bool = false
var _wander_t: float = 0.0
var _speed: float = 70.0
var revealed: float = 0.0


func setup(npc_id: String, entry: Dictionary, w: Node) -> void:
	id = npc_id
	data = Data.npcs.get(id, {})
	world = w
	actor = Actor.new()
	add_child(actor)
	actor.setup(id, "npc")
	home_x = float(entry.get("x", 400))
	target_x = home_x
	pose = entry.get("pose", "wander")
	_speed = float(data.get("walk_speed", 70))
	actor.set_facing(1 if randf() < 0.5 else -1)
	if pose == "wall":
		actor.set_facing(entry.get("face", 1))


func is_spirit() -> bool:
	return data.get("spirit", false)


func _process(delta: float) -> void:
	revealed = maxf(0.0, revealed - delta * 0.25)
	actor.spirit_glow = revealed if is_spirit() else 0.0
	if talking:
		actor.play("talk")
		return
	var player: Node2D = world.player if world else null
	if leaving:
		_walk_to(target_x, delta)
		if absf(position.x - target_x) < 6.0:
			queue_free()
		return
	match pose:
		"wall":
			# espíritos à noite: parados, encarando a parede, cabeça levemente trêmula
			actor.play("idle")
			if player and absf(player.position.x - position.x) < 140.0 and randf() < delta * 0.4:
				actor.set_facing(int(signf(player.position.x - position.x)))
		"sit", "idle", "counter":
			actor.play("idle")
			if player and absf(player.position.x - position.x) < 200.0:
				actor.set_facing(int(signf(player.position.x - position.x)))
		_:
			_wander_t -= delta
			if _wander_t <= 0.0:
				_wander_t = randf_range(4.0, 10.0)
				target_x = home_x + randf_range(-160.0, 160.0)
			if player and absf(player.position.x - position.x) < 110.0:
				actor.set_facing(int(signf(player.position.x - position.x)))
				actor.play("idle")
			else:
				_walk_to(target_x, delta)


func _walk_to(x: float, delta: float) -> void:
	var d := x - position.x
	if absf(d) < 4.0:
		actor.play("idle")
		return
	position.x += signf(d) * minf(absf(d), _speed * delta)
	actor.set_facing(int(signf(d)))
	actor.play("walk")


func leave_towards(x: float) -> void:
	leaving = true
	target_x = x
	_speed *= 1.2


func dialogue_id() -> String:
	# diálogos podem variar por capítulo/noite via lista condicional
	var opts = data.get("dialogue", "")
	if opts is String:
		return opts
	for o in opts:
		if Game.check(o.get("if", {})):
			return o.get("id", "")
	return ""
