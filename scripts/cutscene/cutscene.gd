extends Node
## Diretor de cutscenes. Executa linhas do tempo de data/cutscenes.json usando os
## MESMOS atores, cenários e luz do gameplay (consistência visual total):
## movimentos de personagens, animações, expressões, câmera (pan/zoom/tremor),
## barras de cinema, chuva/névoa/relâmpagos, flashes, rádio, cartões de título,
## escolhas com consequência, desvios por condição e finais com créditos.
##
## Pular: segurar ESC/Start (ou tocar 2x no canto) avança para o fim preservando
## todos os efeitos de estado (flags/evidências) da cena.

var world: Node
var _skip: bool = false
var force_skip: bool = false     # testes: executa a cena inteira instantaneamente
var _skip_hold: float = 0.0
var _card: Control
var _card_layer: CanvasLayer


func _ready() -> void:
	_card_layer = CanvasLayer.new()
	_card_layer.layer = 25
	add_child(_card_layer)


func _process(delta: float) -> void:
	if not world or not world.cutscene_running:
		_skip_hold = 0.0
		return
	if Input.is_action_pressed("skip"):
		_skip_hold += delta
		if _skip_hold > 0.8:
			_skip = true
	else:
		_skip_hold = 0.0


func run(id: String) -> void:
	_skip = force_skip
	var cs: Dictionary = Data.cutscenes.get(id, {})
	world.cam_follow = false
	world.fx.letterbox(cs.get("letterbox", true))
	await _exec(cs.get("steps", []))
	world.dialogue.close()
	world.fx.letterbox(false)
	world.fx.set_glitch(0.0)
	if world.fx.fade_rect.color.a > 0.5 and Game.ending_reached == "":
		await world.fx.fade(0.0, 0.6)
	# devolve a câmera suavemente ao jogador
	var tw := create_tween()
	tw.tween_property(world.camera, "zoom", Vector2.ONE, 0.5)
	await tw.finished


func _actor(who: String) -> Node2D:
	return world.find_actor(who)


func _exec(steps: Array) -> void:
	var i := 0
	while i < steps.size():
		var s: Dictionary = steps[i]
		i += 1
		var c: String = s.get("c", "")
		# ao pular, executa só o que muda estado
		if _skip and not c in ["effects", "if", "choice", "location", "time", "ending", "chapter", "fade_out", "fade_in", "credits", "rain", "spawn", "despawn", "player_visible", "refresh"]:
			continue
		if c != "say" and c != "choice":
			world.dialogue.close()
		match c:
			"wait":
				if not _skip:
					await get_tree().create_timer(float(s.get("t", 1.0))).timeout
			"fade_out":
				await world.fx.fade(1.0, 0.05 if _skip else float(s.get("t", 1.0)))
			"fade_in":
				await world.fx.fade(0.0, 0.05 if _skip else float(s.get("t", 1.0)))
			"letterbox":
				world.fx.letterbox(s.get("on", true))
			"location":
				await world.load_location(s.get("id", ""), float(s.get("x", 300)), false)
				world.cam_follow = false
			"time":
				Clock.set_time(float(s.get("h", 22)))
				world._on_phase(Clock.phase())
			"rain":
				world.fx.set_rain(s.get("on", true))
			"fog":
				world.fx.set_fog(float(s.get("d", 0.3)))
			"spawn":
				var x := float(s.get("x", world.player.position.x + 300))
				if s.has("dx"):
					x = world.player.position.x + float(s["dx"])
				var a: Node2D = world.spawn_extra(s.get("who", ""), x, int(s.get("face", -1)))
				if s.get("ghost", false):
					a.get("actor").ghostly = true
				if s.has("anim"):
					a.get("actor").play(s["anim"])
			"despawn":
				var a := _actor(s.get("who", ""))
				if a and a != world.player:
					if s.get("fade", true) and not _skip:
						var tw := create_tween()
						tw.tween_property(a, "modulate:a", 0.0, float(s.get("t", 0.6)))
						await tw.finished
					a.queue_free()
			"place":
				var a := _actor(s.get("who", ""))
				if a:
					a.position.x = float(s.get("x", a.position.x))
					if s.has("face"):
						a.get("actor").set_facing(int(s["face"]))
			"move":
				var a := _actor(s.get("who", ""))
				if a:
					var to := float(s.get("x", a.position.x))
					if s.has("dx"):
						to = a.position.x + float(s["dx"])
					var spd := float(s.get("speed", 140))
					var anim: String = s.get("anim", "run" if spd > 200.0 else "walk")
					var ac: Actor = a.get("actor")
					ac.set_facing(int(signf(to - a.position.x)))
					ac.play(anim)
					var dur := absf(to - a.position.x) / maxf(spd, 1.0)
					var tw := create_tween()
					tw.tween_property(a, "position:x", to, dur)
					tw.tween_callback(_end_move.bind(ac, s.get("end_anim", "idle")))
					if s.get("wait", true):
						await tw.finished
			"face":
				var a := _actor(s.get("who", ""))
				if a:
					var dir := int(s.get("dir", 1))
					if s.has("to"):
						var b := _actor(s["to"])
						if b:
							dir = int(signf(b.position.x - a.position.x))
					a.get("actor").set_facing(dir)
			"anim":
				var a := _actor(s.get("who", ""))
				if a:
					a.get("actor").play(s.get("name", "idle"))
					if s.has("expr"):
						a.get("actor").expr = s["expr"]
			"ghost":
				var a := _actor(s.get("who", ""))
				if a:
					a.get("actor").ghostly = s.get("on", true)
					a.get("actor").spirit_glow = 1.0 if s.get("on", true) else 0.0
			"say":
				var who: String = s.get("who", "narrator")
				var line: String = s.get("text", "")
				var bc: Dictionary = s.get("by_char", {})
				if bc.has(Game.character):
					line = bc[Game.character]
				if line == "":
					continue
				var a := _actor(who)
				if a and a.get("actor"):
					a.get("actor").play(s.get("anim", "talk"))
					a.get("actor").expr = s.get("expr", "neutral")
				await world.dialogue.say(who, s.get("expr", "neutral"), line)
				if a and is_instance_valid(a) and a.get("actor"):
					a.get("actor").play(s.get("after", "idle"))
			"choice":
				var labels: Array = []
				var opts: Array = []
				for o in s.get("options", []):
					if Game.check(o.get("if", {})):
						opts.append(o)
						labels.append(o.get("text", "..."))
				if opts.is_empty():
					continue
				var pick := 0
				if _skip and not force_skip:
					_skip = false   # escolhas nunca são puladas
				pick = await world.dialogue.ask(s.get("who", "player"), s.get("prompt", ""), labels)
				world.dialogue.close()
				Game.apply(opts[pick].get("do", {}))
				await _exec(opts[pick].get("then", []))
			"if":
				if Game.check(s.get("cond", {})):
					await _exec(s.get("then", []))
				else:
					await _exec(s.get("else", []))
			"effects":
				Game.apply(s.get("do", {}))
			"chapter":
				Game.set_chapter(int(s.get("n", 1)))
			"cam":
				var tx := float(s.get("x", world.camera.position.x))
				if s.has("on"):
					var t := _actor(s["on"])
					if t:
						tx = t.position.x + float(s.get("offset", 0))
				var z := float(s.get("zoom", 1.0))
				var dur := 0.01 if _skip else float(s.get("t", 1.2))
				var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				tw.tween_property(world.camera, "position", Vector2(tx, float(s.get("y", 380))), dur)
				tw.tween_property(world.camera, "zoom", Vector2(z, z), dur)
				if s.get("wait", true):
					await tw.finished
			"shake":
				world.fx.shake(float(s.get("amp", 12)))
			"flash":
				world.fx.flash(Color(s.get("color", "ffffff")), float(s.get("t", 0.5)))
			"lightning":
				world.fx.lightning()
			"glitch":
				world.fx.set_glitch(float(s.get("v", 0.6)))
			"flicker":
				world.flicker_lamps(float(s.get("t", 1.5)))
			"sfx":
				Sfx.play(s.get("name", ""), float(s.get("vol", 1.0)))
			"amb":
				Sfx.set_context(s.get("key", "tension"), s.get("v", 0.0))
			"radio":
				Sfx.play("radio_on", 0.7)
				Sfx.set_context("static", 0.5)
				await world.dialogue.say("radio", "neutral", s.get("text", ""))
				Sfx.set_context("static", 0.0)
			"card":
				await _title_card(s.get("text", ""), s.get("sub", ""), float(s.get("t", 3.0)))
			"ending":
				Game.register_ending(s.get("id", ""))
			"resolve_ending":
				var eid := Game.resolve_ending()
				for e in Data.endings:
					if e.get("id", "") == eid:
						await _exec([{"c": "cutscene", "id": e.get("cutscene", "")}])
						break
			"cutscene":
				var sub: Dictionary = Data.cutscenes.get(s.get("id", ""), {})
				await _exec(sub.get("steps", []))
			"credits":
				if not force_skip:
					_skip = false
					await _credits()
			"player_visible":
				world.player.visible = s.get("on", true)
			"refresh":
				world._refresh_population()
			"player_control":
				world.player.locked = not s.get("on", true)
			_:
				push_warning("Comando de cutscene desconhecido: " + c)


func _end_move(ac: Actor, anim: String) -> void:
	if is_instance_valid(ac):
		ac.play(anim)


func _title_card(t: String, sub: String, dur: float) -> void:
	if _skip:
		return
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.theme = UIStyle.theme()
	_card_layer.add_child(c)
	var a := UIStyle.label(t, 46)
	a.set_anchors_preset(Control.PRESET_CENTER)
	a.offset_left = -560
	a.offset_right = 560
	a.offset_top = -50
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(a)
	var b := UIStyle.label(sub, 21, UIStyle.BONE_DIM)
	b.set_anchors_preset(Control.PRESET_CENTER)
	b.offset_left = -560
	b.offset_right = 560
	b.offset_top = 20
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(b)
	c.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.8)
	tw.tween_interval(dur)
	tw.tween_property(c, "modulate:a", 0.0, 0.8)
	await tw.finished
	c.queue_free()


func _credits() -> void:
	var lines := [
		["THE LAST SIGNAL", 54], ["", 20],
		["Um jogo KAIKODEV", 26], ["", 20],
		["Direção, roteiro e sistemas", 18], ["KAIKODEV", 24], ["", 16],
		["Arte de personagens (estilo MUGEN)", 18], ["Produzida com Canva + pipeline de sprites KAIKODEV", 22], ["", 16],
		["Som e música", 18], ["Síntese procedural original", 22], ["", 16],
		["Motor", 18], ["Godot Engine (MIT)", 22], ["", 30],
		["Em memória dos 41 de Santa Inês.", 22], ["", 30],
		["Obrigado por ouvir o sinal.", 26]
	]
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var v := VBoxContainer.new()
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.offset_left = -500
	v.offset_right = 500
	v.position.y = 760
	layer.add_child(v)
	for l in lines:
		var lab := UIStyle.label(l[0], l[1], UIStyle.BLOOD_HI if l[1] >= 50 else UIStyle.BONE)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lab)
	await get_tree().process_frame
	var tw := create_tween()
	tw.tween_property(v, "position:y", -v.size.y - 40.0, 26.0)
	while tw.is_running():
		await get_tree().process_frame
		if Input.is_action_pressed("skip") or Input.is_action_pressed("advance"):
			tw.kill()
			break
	layer.queue_free()
