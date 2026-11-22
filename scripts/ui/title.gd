extends Control
## Menu principal animado: Ravenhill sob chuva, a torre piscando no horizonte,
## título com interferência de rádio, névoa e granulação. Sem cores berrantes.

signal new_game
signal continue_game
signal chapter_selected(char_id: String, n: int)

var _t: float = 0.0
var _title: Label
var _title_ghost: Label
var _menu: VBoxContainer
var _panel: PanelContainer
var _drops: Array = []
var _fx: ScreenFX


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	for i in 140:
		_drops.append(Vector3(randf() * 1400.0, randf() * 760.0, randf_range(0.6, 1.0)))
	_title_ghost = UIStyle.label("THE LAST SIGNAL", 76, Color(0.5, 0.1, 0.12, 0.5))
	_title_ghost.position = Vector2(92, 92)
	add_child(_title_ghost)
	_title = UIStyle.label("THE LAST SIGNAL", 76, UIStyle.BONE)
	_title.position = Vector2(90, 88)
	add_child(_title)
	var sub := UIStyle.label("RAVENHILL  ·  OUTUBRO DE 2004", 20, UIStyle.BONE_DIM)
	sub.position = Vector2(96, 186)
	add_child(sub)
	_menu = VBoxContainer.new()
	_menu.position = Vector2(96, 270)
	_menu.add_theme_constant_override("separation", 10)
	add_child(_menu)
	var cont := UIStyle.button("Continuar", func(): continue_game.emit())
	cont.disabled = Game.latest_slot() < 0
	_menu.add_child(cont)
	_menu.add_child(UIStyle.button("Novo jogo", func(): new_game.emit()))
	_menu.add_child(UIStyle.button("Capítulos", _show_chapters))
	_menu.add_child(UIStyle.button("Galeria de finais", _show_endings))
	_menu.add_child(UIStyle.button("Configurações", _show_settings))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		_menu.add_child(UIStyle.button("Sair", func(): get_tree().quit()))
	var credit := UIStyle.label("KAIKODEV", 16, UIStyle.BONE_DIM)
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.offset_top = -44
	credit.offset_left = 96
	add_child(credit)
	_fx = ScreenFX.new()
	add_child(_fx)
	_fx.set_fog(0.35)
	_fx.set_rain(true)
	_fx.fade(0.0, 1.6)
	if cont.disabled:
		(_menu.get_child(1) as Button).grab_focus()
	else:
		cont.grab_focus()


func _process(delta: float) -> void:
	_t += delta
	# interferência no título
	var glitch := fmod(_t, 5.3) < 0.18 or (fmod(_t, 13.1) > 12.9)
	_title.position.x = 90.0 + (randf_range(-6, 6) if glitch else 0.0)
	_title_ghost.visible = glitch or fmod(_t, 2.0) < 0.05
	_title.modulate.a = 0.75 if glitch else 1.0
	for i in _drops.size():
		var d: Vector3 = _drops[i]
		d.y += delta * 900.0 * d.z
		d.x -= delta * 160.0 * d.z
		if d.y > 760.0:
			d.y = -20.0
			d.x = randf() * 1500.0
		_drops[i] = d
	queue_redraw()


func _draw() -> void:
	var sz := get_viewport_rect().size
	var w := sz.x
	var h := sz.y
	# céu
	for i in 24:
		var t := float(i) / 24.0
		draw_rect(Rect2(0, h * t, w, h / 24.0 + 1), Color("05060b").lerp(Color("1b1e2b"), t))
	# lua atrás das nuvens
	draw_texture_rect(Art.glow(), Rect2(w * 0.7, 40, 260, 260), false, Color(0.6, 0.65, 0.75, 0.35))
	draw_circle(Vector2(w * 0.7 + 130, 170), 34, Color(0.75, 0.75, 0.7, 0.85))
	# colina e torre
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.45, h), Vector2(w * 0.75, h * 0.56), Vector2(w * 1.05, h)]), Color("0a0b10"))
	var tx := w * 0.75
	var ty := h * 0.56
	var tc := Color("07080c")
	draw_line(Vector2(tx, ty - 300), Vector2(tx - 40, ty + 10), tc, 4)
	draw_line(Vector2(tx, ty - 300), Vector2(tx + 40, ty + 10), tc, 4)
	for i in 8:
		var yy := ty - 300 + i * 38.0
		var hw := 40.0 * (i * 38.0) / 310.0
		draw_line(Vector2(tx - hw, yy), Vector2(tx + hw, yy + 38), tc, 2)
		draw_line(Vector2(tx + hw, yy), Vector2(tx - hw, yy + 38), tc, 2)
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	draw_texture_rect(Art.glow(), Rect2(tx - 60, ty - 360, 120, 120), false, Color(1, 0.12, 0.1, 0.6 * pulse))
	draw_circle(Vector2(tx, ty - 300), 4, Color(1, 0.2, 0.15, 0.4 + 0.6 * pulse))
	# ondas do sinal
	for k in 3:
		var r := fmod(_t * 60.0 + k * 70.0, 210.0)
		draw_arc(Vector2(tx, ty - 300), r, -PI * 0.95, -PI * 0.05, 32, Color(0.7, 0.15, 0.15, 0.25 * (1.0 - r / 210.0)), 2)
	# cidade
	var x := -20.0
	var seed_i := 3
	while x < w * 0.62:
		seed_i = (seed_i * 1103515245 + 12345) % 2147483647
		var bw := 60.0 + float(seed_i % 120)
		var bh := 90.0 + float((seed_i / 7) % 220)
		draw_rect(Rect2(x, h - bh - 80, bw, bh + 80), Color("0d0f15"))
		var wy := h - bh - 64
		while wy < h - 90:
			var wx := x + 10
			while wx < x + bw - 12:
				var hsh := int(wx * 13.0 + wy * 7.0) % 17
				if hsh == 0 or (hsh == 5 and fmod(_t + wx, 9.0) > 1.0):
					draw_rect(Rect2(wx, wy, 7, 9), Color(0.85, 0.62, 0.3, 0.75))
				wx += 18
			wy += 24
		x += bw + 6
	# chuva
	for d in _drops:
		draw_line(Vector2(d.x, d.y), Vector2(d.x - 4 * d.z, d.y + 18 * d.z), Color(0.7, 0.75, 0.85, 0.25 * d.z), 1.0)
	# poste piscando à esquerda
	var on := fmod(_t * 7.0, 11.0) > 1.2
	draw_rect(Rect2(w * 0.56, h - 330, 6, 330), Color("0c0d11"))
	if on:
		draw_texture_rect(Art.glow(), Rect2(w * 0.56 - 160, h - 480, 340, 340), false, Color(1.0, 0.8, 0.5, 0.25))
	draw_circle(Vector2(w * 0.56 + 18, h - 336), 5, Color(1, 0.85, 0.6) if on else Color(0.2, 0.18, 0.15))


# ---------------------------------------------------------------- painéis
func _open_panel(title: String) -> VBoxContainer:
	if _panel:
		_panel.queue_free()
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.42
	_panel.anchor_right = 0.96
	_panel.anchor_top = 0.08
	_panel.anchor_bottom = 0.92
	add_child(_panel)
	var s := ScrollContainer.new()
	_panel.add_child(s)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	s.add_child(v)
	v.add_child(UIStyle.label(title, 28, UIStyle.BLOOD_HI))
	return v


func _show_chapters() -> void:
	var v := _open_panel("CAPÍTULOS")
	v.add_child(UIStyle.label("Capítulos já alcançados podem ser rejogados.", 17, UIStyle.BONE_DIM))
	for cid in Data.characters:
		var unlocked := int(Game.chapters_unlocked.get(cid, 1))
		v.add_child(UIStyle.label(Data.char_name(cid).to_upper(), 20, UIStyle.BONE))
		for ch in Data.chapters:
			var n := int(ch.get("n", 1))
			var b := Button.new()
			b.text = "  %d. %s" % [n, ch.get("title", "")] if n <= unlocked else "  %d. ———" % n
			b.disabled = n > unlocked
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(0, 44)
			var c_id: String = cid
			b.pressed.connect(func(): chapter_selected.emit(c_id, n))
			v.add_child(b)


func _show_endings() -> void:
	var v := _open_panel("GALERIA DE FINAIS")
	var seen := 0
	for e in Data.endings:
		var got: bool = Game.endings_seen.has(e.get("id", ""))
		if got:
			seen += 1
		var t := RichTextLabel.new()
		t.bbcode_enabled = true
		t.fit_content = true
		t.add_theme_font_size_override("normal_font_size", 19)
		if got:
			t.text = "[color=#b8323a]%s[/color]  [b]%s[/b]\n[color=#8d8778]%s[/color]" % [e.get("kind", "").to_upper(), e.get("title", ""), e.get("summary", "")]
		else:
			t.text = "[color=#4c4a45]%s  ———  %s[/color]" % [e.get("kind", "").to_upper(), e.get("hint", "Ainda não descoberto.")]
		v.add_child(t)
	v.add_child(UIStyle.label("%d / %d finais" % [seen, Data.endings.size()], 18, UIStyle.BONE_DIM))


func _show_settings() -> void:
	var v := _open_panel("CONFIGURAÇÕES")
	for pair in [["Música", "music"], ["Efeitos", "sfx"], ["Velocidade do texto", "text_speed"]]:
		var h := HBoxContainer.new()
		var l := UIStyle.label(pair[0], 18)
		l.custom_minimum_size = Vector2(240, 0)
		h.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0 if pair[1] != "text_speed" else 0.4
		s.max_value = 1.0 if pair[1] != "text_speed" else 2.5
		s.step = 0.05
		s.value = float(Game.settings.get(pair[1], 1.0))
		s.custom_minimum_size = Vector2(300, 36)
		var key: String = pair[1]
		s.value_changed.connect(func(val):
			Game.settings[key] = val
			Game.save_meta()
		)
		h.add_child(s)
		v.add_child(h)
	for pair in [["Vibração", "vibration"], ["Granulação de filme", "grain"], ["Tremor de câmera", "shake"]]:
		var c := CheckButton.new()
		c.text = pair[0]
		c.button_pressed = bool(Game.settings.get(pair[1], true))
		var key: String = pair[1]
		c.toggled.connect(func(on):
			Game.settings[key] = on
			Game.save_meta()
		)
		v.add_child(c)
