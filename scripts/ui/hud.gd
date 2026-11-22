extends CanvasLayer
## HUD discreto: hora/fase, local, objetivo atual, saúde e fôlego, medidor de sinal
## (Elias), recarga da habilidade, prompt de interação, notificações, transmissões
## de rádio, cartões de capítulo, revelação de fotos e tela de "levado".

var world: Node
var root: Control
var clock_label: Label
var loc_label: Label
var objective: Label
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var signal_bar: ProgressBar
var signal_box: Control
var ability_label: Label
var prompt: Label
var toast_box: VBoxContainer
var radio_label: Label
var phase_icon: Control
var _phase_draw_t: float = 0.0


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)
	# canto superior esquerdo: hora e local
	var tl := VBoxContainer.new()
	tl.position = Vector2(28, 18)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)
	var row := HBoxContainer.new()
	tl.add_child(row)
	phase_icon = Control.new()
	phase_icon.custom_minimum_size = Vector2(30, 30)
	phase_icon.draw.connect(_draw_phase)
	row.add_child(phase_icon)
	clock_label = UIStyle.label("", 26)
	row.add_child(clock_label)
	loc_label = UIStyle.label("", 17, UIStyle.BONE_DIM)
	tl.add_child(loc_label)
	# objetivo (topo centro)
	objective = UIStyle.label("", 19, UIStyle.BONE)
	objective.anchor_left = 0.25
	objective.anchor_right = 0.75
	objective.offset_top = 20
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(objective)
	# barras (canto superior direito)
	var tr := VBoxContainer.new()
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_left = -250
	tr.offset_right = -28
	tr.offset_top = 22
	tr.add_theme_constant_override("separation", 6)
	root.add_child(tr)
	health_bar = _bar(tr, UIStyle.BLOOD)
	stamina_bar = _bar(tr, Color("7d7766"))
	signal_box = VBoxContainer.new()
	tr.add_child(signal_box)
	signal_box.add_child(UIStyle.label("SINAL", 13, UIStyle.COLD))
	signal_bar = _bar(signal_box, UIStyle.COLD)
	ability_label = UIStyle.label("", 15, UIStyle.BONE_DIM)
	ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(ability_label)
	# prompt de interação
	prompt = UIStyle.label("", 22)
	prompt.anchor_left = 0.2
	prompt.anchor_right = 0.8
	prompt.anchor_top = 1.0
	prompt.anchor_bottom = 1.0
	prompt.offset_top = -270
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt)
	toast_box = VBoxContainer.new()
	toast_box.anchor_left = 1.0
	toast_box.anchor_right = 1.0
	toast_box.offset_left = -470
	toast_box.offset_right = -28
	toast_box.offset_top = 150
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
	radio_label = UIStyle.label("", 22, UIStyle.COLD)
	radio_label.anchor_left = 0.15
	radio_label.anchor_right = 0.85
	radio_label.anchor_top = 0.62
	radio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio_label.modulate.a = 0.0
	root.add_child(radio_label)
	Game.notify.connect(_on_notify)
	signal_box.visible = Game.character == "elias"


func _bar(parent: Node, col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(222, 9)
	b.show_percentage = false
	b.max_value = 100
	b.add_theme_stylebox_override("fill", UIStyle.box(col, col, 0, 1, 0))
	parent.add_child(b)
	return b


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	clock_label.text = "  %s   Dia %d" % [Clock.label(), Clock.day]
	objective.text = Game.current_objective()
	health_bar.value = Game.health
	var p: Player = world.player
	stamina_bar.value = p.stamina / p.max_stamina * 100.0
	stamina_bar.modulate.a = 1.0 if p.stamina < p.max_stamina - 1.0 else 0.35
	if signal_box.visible:
		var s: float = world.signal_strength()
		signal_bar.value = s * 100.0 + randf_range(-4.0, 4.0) * s
		Sfx.set_context("static", maxf(Sfx.context.get("static", 0.0) * 0.98, s * (0.5 if world.radio_time > 0.0 else 0.12)))
	var ab: Dictionary = Data.characters.get(Game.character, {})
	ability_label.text = ("[Q] %s" % ab.get("ability_name", "")) if p.ability_cd <= 0.0 else ("%s  %ds" % [ab.get("ability_name", ""), ceili(p.ability_cd)])
	_phase_draw_t += delta
	if _phase_draw_t > 1.0:
		_phase_draw_t = 0.0
		phase_icon.queue_redraw()


func _draw_phase() -> void:
	var d := Clock.darkness()
	var c := Vector2(15, 15)
	if d < 0.5:
		phase_icon.draw_circle(c, 9, Color("c9b27c").lerp(Color("a3543c"), d * 2.0))
	else:
		phase_icon.draw_circle(c, 9, Color("c8c8c0"))
		phase_icon.draw_circle(c + Vector2(4, -3), 8, Color("0b0c10"))


func set_location(n: String) -> void:
	loc_label.text = n.to_upper()


func show_prompt(t: String) -> void:
	prompt.text = ("[E]  " + t) if t != "" and not DisplayServer.is_touchscreen_available() else t


func toast(t: String, col: Color = UIStyle.BONE) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.box(Color(0.04, 0.045, 0.055, 0.9), UIStyle.LINE, 1, 2, 12))
	var l := UIStyle.label(t, 18, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(400, 0)
	p.add_child(l)
	p.modulate.a = 0.0
	toast_box.add_child(p)
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(3.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _on_notify(t: String, kind: String) -> void:
	var col := UIStyle.BONE
	match kind:
		"evidence": col = Color("c9b27c")
		"mission": col = UIStyle.BLOOD_HI
		"deduction": col = UIStyle.COLD
		"fail": col = Color("8a8a8a")
	toast(t, col)


func radio_line(t: String) -> void:
	radio_label.text = "« " + t + " »"
	var tw := create_tween()
	tw.tween_property(radio_label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(3.8)
	tw.tween_property(radio_label, "modulate:a", 0.0, 1.0)


func chapter_card(n: int, title: String) -> void:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	var a := UIStyle.label("CAPÍTULO %d" % n, 22, UIStyle.BLOOD_HI)
	a.set_anchors_preset(Control.PRESET_CENTER)
	a.offset_top = -60
	a.offset_left = -300
	a.offset_right = 300
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(a)
	var b := UIStyle.label(title.to_upper(), 44)
	b.set_anchors_preset(Control.PRESET_CENTER)
	b.offset_top = -20
	b.offset_left = -500
	b.offset_right = 500
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(b)
	c.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 1.0)
	tw.tween_interval(2.8)
	tw.tween_property(c, "modulate:a", 0.0, 1.2)
	tw.tween_callback(c.queue_free)
	Sfx.play("mission", 0.7)


## Foto revelada: espíritos aparecem queimados/borrados — a "prova" da câmera.
func photo_card(npc_id: String, spirit: bool) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.box(Color("e6e0d0"), Color("cfc8b6"), 1, 1, 10))
	p.position = Vector2(60, 150)
	p.rotation = -0.05
	var v := VBoxContainer.new()
	p.add_child(v)
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(220, 190)
	pic.clip_contents = true
	v.add_child(pic)
	var bg := ColorRect.new()
	bg.color = Color("1b1d22") if Clock.darkness() > 0.5 else Color("6c6a64")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.add_child(bg)
	if npc_id != "":
		var a := Actor.new()
		pic.add_child(a)
		a.setup(npc_id, "npc")
		a.position = Vector2(110, 300)
		a.scale = Vector2(1.2, 1.2)
		if spirit:
			a.modulate = Color(0.55, 0.32, 0.25, 0.85)
			a.ghostly = true
			var burn := ColorRect.new()
			burn.color = Color(0.25, 0.05, 0.02, 0.45)
			burn.set_anchors_preset(Control.PRESET_FULL_RECT)
			pic.add_child(burn)
	var cap := Label.new()
	cap.text = (Data.char_name(npc_id) if npc_id != "" else "Nada... só o escuro.") + ("  — ??" if spirit else "")
	cap.add_theme_color_override("font_color", Color("2a2620"))
	cap.add_theme_font_size_override("font_size", 16)
	v.add_child(cap)
	root.add_child(p)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.6)
	tw.tween_interval(3.0 if not spirit else 4.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)
	if spirit:
		Sfx.play("whisper", 0.6)


func game_over_screen() -> void:
	var c := ColorRect.new()
	c.color = Color(0, 0, 0, 1)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	var l := UIStyle.label("VOCÊ FOI LEVADO", 48, UIStyle.BLOOD_HI)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.offset_left = -400
	l.offset_right = 400
	l.offset_top = -40
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(l)
	var s := UIStyle.label("O sinal guarda o que encontra no escuro.", 20, UIStyle.BONE_DIM)
	s.set_anchors_preset(Control.PRESET_CENTER)
	s.offset_left = -400
	s.offset_right = 400
	s.offset_top = 20
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(s)
	c.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.6)
	await tw.finished
	c.queue_free()
