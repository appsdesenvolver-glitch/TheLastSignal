extends Node2D
class_name World
## Mundo jogável: monta cada local de Ravenhill a partir dos dados, controla câmera,
## luz do dia/noite, população por agenda, criaturas, interações, habilidades,
## eventos noturnos, transições, autosave e morte.

signal request_title

const VIEW_W := 1280.0

var player: Player
var camera: Camera2D
var backdrop: Backdrop
var props_node: Node2D
var npcs_node: Node2D
var creatures_node: Node2D
var canvas_mod: CanvasModulate
var sky_layer: CanvasLayer
var fx: ScreenFX
var hud: Node
var dialogue: Node
var notebook: Node
var cutscene: Node
var touch: Node
var stage_width: float = 2400.0
var loc_id: String = ""
var loc: Dictionary = {}
var cutscene_running: bool = false
var busy: bool = false
var vision_time: float = 0.0
var radio_time: float = 0.0
var near_prop: Prop = null
var near_npc: NPC = null
var _tick: float = 0.0
var _radio_t: float = 40.0
var _hb_t: float = 0.0
var _dead: bool = false
var cam_follow: bool = true
var _pending_card: int = 0


func _ready() -> void:
	sky_layer = CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	backdrop = Backdrop.new()
	add_child(backdrop)
	props_node = Node2D.new()
	add_child(props_node)
	npcs_node = Node2D.new()
	add_child(npcs_node)
	creatures_node = Node2D.new()
	add_child(creatures_node)
	player = Player.new()
	add_child(player)
	player.setup(Game.character, self)
	player.noise_made.connect(_on_noise)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)
	camera.make_current()
	fx = ScreenFX.new()
	fx.camera = camera
	add_child(fx)
	hud = preload("res://scripts/ui/hud.gd").new()
	hud.world = self
	add_child(hud)
	touch = preload("res://scripts/ui/touch.gd").new()
	add_child(touch)
	dialogue = preload("res://scripts/ui/dialogue.gd").new()
	add_child(dialogue)
	notebook = preload("res://scripts/ui/notebook.gd").new()
	notebook.world = self
	add_child(notebook)
	cutscene = preload("res://scripts/cutscene/cutscene.gd").new()
	cutscene.world = self
	add_child(cutscene)
	Clock.hour_changed.connect(_on_hour)
	Clock.phase_changed.connect(_on_phase)
	Game.health_changed.connect(_on_health)
	Game.chapter_changed.connect(_on_chapter)
	Clock.running = true


func start(new_game: bool) -> void:
	await load_location(Game.location, Game.player_x, false)
	if new_game:
		var opening: String = Data.characters.get(Game.character, {}).get("opening", "opening")
		var ch := Data.chapter_info(Game.chapter)
		if Game.chapter > 1 and ch.has("intro"):
			opening = ch["intro"]
		await play_cutscene(opening)
	else:
		await fx.fade(0.0, 0.8)


# ----------------------------------------------------------------- locais
func load_location(id: String, x: float, with_fade: bool = true) -> void:
	if not Data.locations.has(id):
		push_error("Local inexistente: %s" % id)
		id = Data.characters.get(Game.character, {}).get("start_location", "casa_vance")
	busy = true
	player.locked = true
	if with_fade:
		await fx.fade(1.0, 0.35)
	for n in [props_node, npcs_node, creatures_node]:
		for c in n.get_children():
			c.queue_free()
	for c in sky_layer.get_children():
		c.queue_free()
	backdrop.queue_free()
	backdrop = Backdrop.new()
	add_child(backdrop)
	move_child(backdrop, 2)
	loc_id = id
	loc = Data.locations[id]
	stage_width = float(loc.get("width", 2400))
	Game.location = id
	var first_visit := not Game.visited.has(id)
	Game.visited[id] = true
	backdrop.build(id, loc, sky_layer)
	for p in loc.get("props", []):
		var pr := Prop.new()
		pr.setup(p, self)
		props_node.add_child(pr)
	player.position = Vector2(clampf(x, 40.0, stage_width - 40.0), Backdrop.GROUND)
	player.bounds = Vector2(40.0, stage_width - 40.0)
	if player.is_hidden:
		player.leave_hide()
	camera.limit_left = 0
	camera.limit_right = int(stage_width)
	camera.limit_top = -400
	camera.limit_bottom = 760
	camera.position = Vector2(player.position.x, 380)
	camera.reset_smoothing()
	_refresh_population()
	_apply_atmosphere()
	Art.trim(_ids_in_scene())
	hud.set_location(loc.get("name", id))
	if with_fade:
		await fx.fade(0.0, 0.35)
	busy = false
	player.locked = cutscene_running
	if first_visit and loc.has("on_first_visit") and not cutscene_running:
		var ev = loc["on_first_visit"]
		if Game.check(ev.get("if", {})):
			Game.apply(ev.get("do", {}))
			if ev.has("cutscene"):
				await play_cutscene(ev["cutscene"])
	if not cutscene_running and not any_chase():
		Game.player_x = player.position.x
		Game.save_slot(0)


func _ids_in_scene() -> Array:
	var ids := [Game.character]
	for n in npcs_node.get_children():
		ids.append(n.id)
	for c in creatures_node.get_children():
		ids.append(c.id)
	return ids


func _apply_atmosphere() -> void:
	var inside: bool = loc.get("interior", false)
	Sfx.set_context("interior", inside)
	Sfx.set_context("night", Clock.is_night())
	Sfx.set_context("outdoor_city", loc.get("style", "") in ["street", "downtown"])
	var rain := false
	var wchance: float = float(loc.get("rain_chance", 0.35))
	if Game.flags.get("storm", false):
		rain = true
	elif Clock.darkness() > 0.5:
		rain = (int(Clock.day * 7 + Clock.hour()) % 10) < int(wchance * 10.0)
	fx.set_rain(rain and not inside)
	Sfx.set_context("rain", rain)
	var fog: float = float(loc.get("fog", 0.15)) + Clock.darkness() * 0.15
	fx.set_fog(0.0 if inside else fog)
	_update_light()


func _update_light() -> void:
	var dark := Clock.darkness()
	var inside: bool = loc.get("interior", false)
	var day_col := Color(1, 1, 1)
	var dusk_col := Color(0.86, 0.72, 0.68)
	var night_col := Color(0.2, 0.22, 0.34)
	var c: Color
	if dark < 0.5:
		c = day_col.lerp(dusk_col, dark * 2.0)
	else:
		c = dusk_col.lerp(night_col, (dark - 0.5) * 2.0)
	if inside:
		var lightness: float = float(loc.get("lightness", 0.6))
		var power_on: bool = not Game.flags.get(loc.get("power_flag", "__none__"), false)
		c = Color(0.95, 0.9, 0.85).lerp(Color(0.16, 0.16, 0.22), (1.0 - lightness) * 0.8 + dark * 0.35)
		if not power_on:
			c = Color(0.1, 0.1, 0.14)
	canvas_mod.color = c


func _refresh_population() -> void:
	# quem deveria estar aqui agora?
	var want := {}
	for nid in Data.npcs:
		var npc: Dictionary = Data.npcs[nid]
		if not Game.check(npc.get("exists_if", {})):
			continue
		for e in npc.get("schedule", []):
			if e.get("loc", "") != loc_id:
				continue
			if not Clock.hour_in(float(e.get("from", 0)), float(e.get("to", 24))):
				continue
			if not Game.check(e.get("if", {})):
				continue
			want[nid] = e
			break
	var present := {}
	for n in npcs_node.get_children():
		if n.leaving:
			continue
		if not want.has(n.id):
			n.leave_towards(-80.0 if n.position.x < stage_width * 0.5 else stage_width + 80.0)
		else:
			present[n.id] = true
	for nid in want:
		if present.has(nid):
			continue
		var npc_node := NPC.new()
		npc_node.setup(nid, want[nid], self)
		npc_node.position = Vector2(float(want[nid].get("x", 400)), Backdrop.GROUND)
		npc_node.actor.set_reflection(loc.get("reflective", false) and not npc_node.is_spirit())
		npcs_node.add_child(npc_node)
	# criaturas
	for c in creatures_node.get_children():
		c.queue_free()
	for cr in loc.get("creatures", []):
		if not Game.check(cr.get("if", {"night": true})):
			continue
		var node := Creature.new()
		var a := float(cr.get("a", 200))
		var b := float(cr.get("b", stage_width - 200))
		node.setup(cr.get("id", "hollow"), a, b, self)
		node.position = Vector2(float(cr.get("x", (a + b) * 0.5)), Backdrop.GROUND)
		creatures_node.add_child(node)
	player.actor.set_reflection(loc.get("reflective", false))


# ----------------------------------------------------------------- ciclo
func _process(delta: float) -> void:
	if not cutscene_running and cam_follow:
		var look := player.actor.facing * 120.0
		camera.position = Vector2(clampf(player.position.x + look, VIEW_W * 0.5, maxf(VIEW_W * 0.5, stage_width - VIEW_W * 0.5)), 380)
	backdrop.update_parallax(camera.get_screen_center_position().x, VIEW_W)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.33
		backdrop.tick()
		_update_light()
	vision_time = maxf(0.0, vision_time - delta)
	radio_time = maxf(0.0, radio_time - delta)
	if busy or cutscene_running or _dead:
		return
	Game.player_x = player.position.x
	_update_interaction()
	_update_triggers()
	_update_chase_audio(delta)
	_night_events(delta)
	if Input.is_action_just_pressed("interact") and not player.is_hidden:
		_interact()
	if Input.is_action_just_pressed("notebook") or Input.is_action_just_pressed("pause"):
		notebook.open()
	if Input.is_action_just_pressed("photo"):
		take_photo()
	if Input.is_action_just_pressed("ability"):
		use_ability()


func _update_interaction() -> void:
	near_prop = null
	near_npc = null
	var px := player.position.x
	var best := 9999.0
	for n in npcs_node.get_children():
		var d := absf(n.position.x - px)
		if d < 90.0 and d < best and not n.leaving and n.dialogue_id() != "":
			best = d
			near_npc = n
	for p in props_node.get_children():
		if not p.type in ["door", "exit", "clue", "hide", "save", "relay", "use"]:
			continue
		var r := float(p.data.get("r", 70))
		var d := absf(p.position.x - px)
		if d > r or d >= best:
			continue
		if p.type == "clue":
			if not Game.check(p.data.get("req", {})):
				continue
			if p.data.get("vision_only", false) and vision_time <= 0.0:
				continue
			if p.data.has("give") and p.data["give"] in Game.evidence and p.data.get("once", true) and not p.data.has("repeat_text"):
				continue
		if p.type == "relay" and Game.flags.get(p.data.get("flag", ""), false):
			continue
		best = d
		near_prop = p
		near_npc = null
	if near_npc:
		hud.show_prompt("Conversar — " + Data.char_name(near_npc.id))
	elif near_prop:
		var verb := {"door": "Entrar", "exit": "Ir", "clue": "Examinar", "hide": "Esconder-se", "save": "Salvar", "relay": "Ativar", "use": "Usar"}
		hud.show_prompt("%s — %s" % [verb.get(near_prop.type, "Usar"), near_prop.label()])
	else:
		hud.show_prompt("")


func _interact() -> void:
	if near_npc:
		await talk_to(near_npc)
		return
	if near_prop == null:
		return
	var p := near_prop
	var d: Dictionary = p.data
	match p.type:
		"door", "exit":
			if d.has("hours") and not Clock.hour_in(float(d["hours"][0]), float(d["hours"][1])):
				hud.toast(d.get("closed_text", "Fechado agora. Abre às %02d:00." % int(d["hours"][0])))
				Sfx.play("knock", 0.6)
				return
			if d.has("locked_if") and Game.check(d["locked_if"]):
				hud.toast(d.get("locked_text", "Trancado."))
				Sfx.play("knock", 0.6)
				return
			if d.has("req") and not Game.check(d["req"]):
				hud.toast(d.get("req_text", "Ainda não há motivo para ir lá."))
				return
			Game.apply(d.get("do", {}))
			if p.type == "door":
				Sfx.play("door", 0.8)
			await load_location(d.get("to", ""), float(d.get("to_x", 200)))
		"clue":
			player.actor.play("inspect")
			Sfx.play("ui_ok", 0.4)
			if d.has("give") and d["give"] in Game.evidence and d.has("repeat_text"):
				await dialogue.say("player", "neutral", d["repeat_text"])
				return
			var txt = d.get("text", "")
			if d.has("text_by_char") and d["text_by_char"].has(Game.character):
				txt = d["text_by_char"][Game.character]
			if txt is Array:
				for line in txt:
					await dialogue.say(line.get("who", "player"), line.get("expr", "neutral"), line.get("text", ""))
			elif txt != "":
				await dialogue.say("player", d.get("expr", "neutral"), txt)
			if d.has("give"):
				Game.give_evidence(d["give"])
			Game.apply(d.get("do", {}))
			if d.has("cutscene"):
				await play_cutscene(d["cutscene"])
		"hide":
			player.enter_hide(p)
		"save":
			Game.set_health(minf(100.0, Game.health + 25.0))
			notebook.open("Sistema")
		"relay", "use":
			if d.has("req") and not Game.check(d["req"]):
				hud.toast(d.get("req_text", "Não funciona."))
				return
			Game.apply(d.get("do", {}))
			Sfx.play("glitch", 0.7)
			p.queue_redraw()
			if d.has("cutscene"):
				await play_cutscene(d["cutscene"])


func talk_to(n: NPC) -> void:
	var did := n.dialogue_id()
	if did == "":
		return
	player.locked = true
	n.talking = true
	n.actor.set_facing(int(signf(player.position.x - n.position.x)))
	player.actor.set_facing(int(signf(n.position.x - player.position.x)))
	player.actor.play("talk")
	Game.met[n.id] = true
	Clock.freeze("dialogue")
	await dialogue.run(did, n.id)
	Clock.unfreeze("dialogue")
	if is_instance_valid(n):
		n.talking = false
	player.locked = cutscene_running


func _update_triggers() -> void:
	for p in props_node.get_children():
		if p.type != "trigger" or p.used:
			continue
		var once_flag: String = p.data.get("once", "")
		if once_flag != "" and Game.flags.get(once_flag, false):
			continue
		if absf(p.position.x - player.position.x) > float(p.data.get("r", 40)):
			continue
		if not Game.check(p.data.get("if", {})):
			continue
		p.used = true
		if once_flag != "":
			Game.flags[once_flag] = true
		Game.apply(p.data.get("do", {}))
		if p.data.has("cutscene"):
			play_cutscene(p.data["cutscene"])
		if p.data.has("say"):
			dialogue.say("player", "scared", p.data["say"])
		return


# ----------------------------------------------------------------- perseguição / morte
func any_chase() -> bool:
	for c in creatures_node.get_children():
		if c.is_chasing():
			return true
	return false


func on_chase_started(_c: Creature) -> void:
	fx.shake(6.0)
	player.scare(0.5)


func on_chase_ended(_c: Creature) -> void:
	pass


func _update_chase_audio(delta: float) -> void:
	var chase := any_chase()
	Sfx.set_context("chase", 0.85 if chase else 0.0)
	var near_c := 9999.0
	for c in creatures_node.get_children():
		if c.visible:
			near_c = minf(near_c, absf(c.position.x - player.position.x))
	Sfx.set_context("tension", clampf(1.0 - near_c / 900.0, 0.0, 1.0))
	fx.fear_level = lerpf(fx.fear_level, player.fear, delta * 3.0)
	if player.fear > 0.55:
		_hb_t -= delta
		if _hb_t <= 0.0:
			_hb_t = lerpf(0.9, 0.45, player.fear)
			Sfx.play("heartbeat", player.fear * 0.8, 0.0)


func _on_health(v: float) -> void:
	if v <= 0.0 and not _dead:
		_dead = true
		_game_over()


func _game_over() -> void:
	player.locked = true
	Clock.running = false
	fx.flash(Color(0.6, 0.0, 0.0), 1.2)
	Sfx.play("stinger")
	await get_tree().create_timer(1.2).timeout
	await fx.fade(1.0, 1.0)
	await hud.game_over_screen()
	if Game.load_slot(0):
		Game.set_health(70.0)
		_dead = false
		Clock.running = true
		await load_location(Game.location, Game.player_x, false)
		await fx.fade(0.0, 0.8)
		player.locked = false
	else:
		request_title.emit()


func _on_noise(x: float, loud: float) -> void:
	for c in creatures_node.get_children():
		c.notify_noise(x, loud)


# ----------------------------------------------------------------- habilidades
func use_ability() -> void:
	if player.ability_cd > 0.0 or player.locked:
		return
	var ab: String = Data.characters.get(Game.character, {}).get("ability", "")
	match ab:
		"radio":
			# Sintonia: estática revela espíritos próximos e assusta a Estática
			radio_time = 6.0
			player.ability_cd = 12.0
			Sfx.play("radio_on", 0.8)
			for n in npcs_node.get_children():
				if n.is_spirit() and absf(n.position.x - player.position.x) < 520.0:
					n.revealed = 1.0
					_tell(n.id, "radio")
		"camera_flash":
			# Flash: atordoa criaturas próximas
			player.ability_cd = 15.0
			fx.flash(Color(1, 1, 1), 0.5)
			Sfx.play("photo", 1.0)
			for c in creatures_node.get_children():
				if absf(c.position.x - player.position.x) < 420.0 and c.visible:
					c.state = Creature.S.RETREAT
					c._retreat_t = 3.5
					c.aware = 0.0
		"first_aid":
			player.ability_cd = 60.0
			Game.set_health(Game.health + 40.0)
			Game.notify.emit("Primeiros socorros: +40 de saúde", "info")
			Sfx.play("pickup", 0.6)
		"vision":
			# Visão: espíritos brilham e pistas ocultas aparecem
			vision_time = 6.0
			player.ability_cd = 14.0
			fx.flash(Color(0.4, 0.6, 1.0), 0.6)
			Sfx.play("whisper", 0.7)
			for n in npcs_node.get_children():
				if n.is_spirit():
					n.revealed = 1.0
					_tell(n.id, "vision")
			for p in props_node.get_children():
				p.queue_redraw()


func _tell(npc_id: String, how: String) -> void:
	var ev := "tell_%s_%s" % [npc_id, how]
	if Data.evidence.has(ev):
		Game.give_evidence(ev)


## Rádio do Elias: intensidade do sinal (0..1) para o medidor do HUD.
func signal_strength() -> float:
	var best := 0.0
	for n in npcs_node.get_children():
		if n.is_spirit():
			best = maxf(best, 1.0 - absf(n.position.x - player.position.x) / 700.0)
	for c in creatures_node.get_children():
		if c.visible:
			best = maxf(best, 1.0 - absf(c.position.x - player.position.x) / 900.0)
	return clampf(best, 0.0, 1.0)


func take_photo() -> void:
	if player.photo_cd > 0.0 or player.locked or player.is_hidden:
		return
	player.photo_cd = 2.5 if Game.character == "maya" else 5.0
	Sfx.play("photo")
	fx.flash(Color(1, 1, 1), 0.35)
	var subject: NPC = null
	var best := 9999.0
	for n in npcs_node.get_children():
		var dx: float = (n.position.x - player.position.x) * player.actor.facing
		if dx > 0.0 and dx < 520.0 and dx < best:
			best = dx
			subject = n
	var shot := {"npc": subject.id if subject else "", "spirit": subject.is_spirit() if subject else false, "loc": loc_id, "day": Clock.day, "hour": Clock.label()}
	Game.photos.append(shot)
	for p in props_node.get_children():
		if p.type == "photo_spot" and absf(p.position.x - player.position.x) < 300.0 and Game.check(p.data.get("req", {})):
			Game.give_evidence(p.data.get("give", ""))
			Game.apply(p.data.get("do", {}))
	if subject:
		Game.met[subject.id] = true
		if subject.is_spirit():
			subject.revealed = 1.0
			_tell(subject.id, "photo")
			hud.photo_card(subject.id, true)
		else:
			hud.photo_card(subject.id, false)
	else:
		hud.photo_card("", false)


# ----------------------------------------------------------------- eventos
func _night_events(delta: float) -> void:
	if not Clock.is_night():
		return
	_radio_t -= delta
	if _radio_t <= 0.0:
		_radio_t = randf_range(45.0, 90.0)
		var pool: Array = []
		for r in Data.radio:
			if Game.check(r.get("if", {})):
				pool.append(r)
		if not pool.is_empty():
			var r: Dictionary = pool[randi() % pool.size()]
			Sfx.play("radio_on", 0.7)
			Sfx.set_context("static", 0.5)
			hud.radio_line(r.get("text", ""))
			get_tree().create_timer(4.5).timeout.connect(func(): Sfx.set_context("static", 0.0))
			if r.has("do"):
				Game.apply(r["do"])


func flicker_lamps(t: float) -> void:
	for p in props_node.get_children():
		if p.type == "lamp" and absf(p.position.x - player.position.x) < 900.0:
			p.flicker(t)


func _on_hour(_h: int) -> void:
	if busy or loc_id == "":
		return
	_refresh_population()
	for p in props_node.get_children():
		p.queue_redraw()


func _on_phase(ph: String) -> void:
	if loc_id == "":
		return
	backdrop.refresh_time()
	_apply_atmosphere()
	if ph == "night":
		hud.toast("A noite caiu sobre Ravenhill.")
		Sfx.play("far_call", 0.5)
	elif ph == "dawn":
		hud.toast("Amanhece. As ruas voltam a respirar.")


func _on_chapter(n: int) -> void:
	if cutscene_running:
		_pending_card = n   # mostrado quando a cutscene terminar
	else:
		hud.chapter_card(n, Data.chapter_info(n).get("title", ""))
		Game.save_slot(0)


# ----------------------------------------------------------------- cutscenes
func play_cutscene(id: String) -> void:
	if id == "" or not Data.cutscenes.has(id):
		push_warning("Cutscene inexistente: " + id)
		return
	cutscene_running = true
	player.locked = true
	Clock.freeze("cutscene")
	hud.visible = false
	touch.set_visible_controls(false)
	await cutscene.run(id)
	Clock.unfreeze("cutscene")
	hud.visible = true
	touch.set_visible_controls(true)
	cutscene_running = false
	cam_follow = true
	player.locked = false
	if Game.ending_reached != "":
		request_title.emit()
		return
	if _pending_card > 0:
		hud.chapter_card(_pending_card, Data.chapter_info(_pending_card).get("title", ""))
		_pending_card = 0
		Game.player_x = player.position.x
		Game.save_slot(0)


func find_actor(who: String) -> Node2D:
	if who == "player" or who == Game.character:
		return player
	for n in npcs_node.get_children():
		if n.id == who and not n.leaving:
			return n
	for c in creatures_node.get_children():
		if c.id == who or c.name == who:
			return c
	for c in props_node.get_children():
		if c.name == who:
			return c
	return null


func spawn_extra(who: String, x: float, face: int) -> Node2D:
	# personagem extra para cutscene (NPC, outro protagonista ou criatura)
	var existing := find_actor(who)
	if existing:
		existing.position.x = x
		existing.get("actor").set_facing(face)
		return existing
	if Data.creatures.has(who):
		var c := Creature.new()
		c.setup(who, x - 100, x + 100, self)
		c.name = who
		c.position = Vector2(x, Backdrop.GROUND)
		c.state = Creature.S.RETREAT
		c._retreat_t = 0.0
		c.visible = true
		creatures_node.add_child(c)
		c.actor.set_facing(face)
		c.set_process(false)
		return c
	var n := NPC.new()
	var is_char := Data.characters.has(who)
	if is_char:
		# protagonistas não escolhidos aparecem como aliados
		n.id = who
		n.data = {"name": Data.char_name(who)}
		n.world = self
		n.actor = Actor.new()
		n.add_child(n.actor)
		n.actor.setup(who, "char")
		n.pose = "idle"
		n.home_x = x
	else:
		n.setup(who, {"x": x, "pose": "idle"}, self)
	n.position = Vector2(x, Backdrop.GROUND)
	npcs_node.add_child(n)
	n.actor.set_facing(face)
	return n
