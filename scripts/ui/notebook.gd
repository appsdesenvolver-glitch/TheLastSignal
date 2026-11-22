extends CanvasLayer
## Caderno de investigação (pausa o jogo): missões, evidências, quadro de deduções,
## pessoas (marcar humano/espírito — pode estar errado!), mapa e sistema.

var world: Node
var root: Control
var tabs: TabContainer
var _sel_a: String = ""
var _board_list: ItemList
var _board_result: RichTextLabel


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.theme()
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var head := UIStyle.label("CADERNO DE INVESTIGAÇÃO", 26, UIStyle.BONE)
	head.position = Vector2(64, 26)
	root.add_child(head)
	var close := UIStyle.button("Voltar  ✕", close_book, 160)
	close.anchor_left = 1.0
	close.anchor_right = 1.0
	close.offset_left = -220
	close.offset_right = -60
	close.offset_top = 20
	close.offset_bottom = 70
	root.add_child(close)
	tabs = TabContainer.new()
	tabs.anchor_right = 1.0
	tabs.anchor_bottom = 1.0
	tabs.offset_left = 60
	tabs.offset_right = -60
	tabs.offset_top = 84
	tabs.offset_bottom = -40
	root.add_child(tabs)


func _unhandled_input(e: InputEvent) -> void:
	if root.visible and (e.is_action_pressed("pause") or e.is_action_pressed("notebook")):
		get_viewport().set_input_as_handled()
		close_book()


func open(tab: String = "") -> void:
	if root.visible:
		return
	get_tree().paused = true
	_rebuild()
	root.visible = true
	Sfx.play("ui_ok", 0.5)
	if tab != "":
		for i in tabs.get_tab_count():
			if tabs.get_tab_title(i) == tab:
				tabs.current_tab = i


func close_book() -> void:
	root.visible = false
	get_tree().paused = false
	Sfx.play("ui_back", 0.5)


func _rebuild() -> void:
	for c in tabs.get_children():
		c.queue_free()
	_tab_missions()
	_tab_evidence()
	_tab_board()
	_tab_people()
	_tab_map()
	_tab_system()


func _scroll(title: String) -> VBoxContainer:
	var s := ScrollContainer.new()
	s.name = title
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(s)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	s.add_child(v)
	return v


func _rich(t: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.text = t
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", 19)
	r.add_theme_font_size_override("bold_font_size", 21)
	return r


func _tab_missions() -> void:
	var v := _scroll("Missões")
	var order := {"main": 0, "char": 1, "side": 2, "night": 3, "secret": 4}
	var ids: Array = Game.missions.keys()
	ids.sort_custom(func(a, b):
		var ma: Dictionary = Data.missions.get(a, {})
		var mb: Dictionary = Data.missions.get(b, {})
		var sa := 0 if Game.missions[a]["state"] == "active" else 1
		var sb := 0 if Game.missions[b]["state"] == "active" else 1
		if sa != sb:
			return sa < sb
		return order.get(ma.get("type", "side"), 9) < order.get(mb.get("type", "side"), 9)
	)
	if ids.is_empty():
		v.add_child(_rich("[i]Nenhuma missão ainda.[/i]"))
	var tnames := {"main": "PRINCIPAL", "char": "PESSOAL", "side": "SECUNDÁRIA", "night": "NOTURNA", "secret": "SECRETA"}
	for id in ids:
		var m: Dictionary = Data.missions.get(id, {})
		var st: Dictionary = Game.missions[id]
		var state: String = st["state"]
		var col := "#d6cfbf" if state == "active" else ("#6f6b62" if state == "done" else "#5a3a3a")
		var t := "[color=#b8323a]%s[/color]  [b][color=%s]%s[/color][/b]" % [tnames.get(m.get("type", "side"), ""), col, m.get("title", id)]
		if state == "done":
			t += "  [color=#6f6b62](concluída)[/color]"
		elif state == "failed":
			t += "  [color=#7a4a4a](perdida)[/color]"
		t += "\n[color=#8d8778]%s[/color]" % m.get("desc", "")
		var steps: Array = m.get("steps", [])
		for i in steps.size():
			if i > int(st["step"]):
				break
			var done := i < int(st["step"]) or state == "done"
			t += "\n   %s %s" % ["☑" if done else "☐", steps[i].get("text", "")]
		v.add_child(_rich(t))
		v.add_child(HSeparator.new())


func _tab_evidence() -> void:
	var v := _scroll("Evidências")
	if Game.evidence.is_empty():
		v.add_child(_rich("[i]Nenhuma evidência. Examine objetos, fotografe, converse.[/i]"))
	var kinds := {"doc": "DOCUMENTO", "photo": "FOTO", "audio": "GRAVAÇÃO", "object": "OBJETO", "testimony": "DEPOIMENTO", "tell": "SINAL"}
	for id in Game.evidence:
		var e: Dictionary = Data.evidence.get(id, {})
		v.add_child(_rich("[color=#c9b27c]%s[/color]  [b]%s[/b]\n[color=#a59e8f]%s[/color]" % [kinds.get(e.get("kind", "object"), "PISTA"), e.get("name", id), e.get("desc", "")]))
	var ph: Array = Game.photos
	if not ph.is_empty():
		v.add_child(HSeparator.new())
		v.add_child(_rich("[b]Fotografias tiradas: %d[/b]" % ph.size()))


func _tab_board() -> void:
	var h := HBoxContainer.new()
	h.name = "Quadro"
	h.add_theme_constant_override("separation", 18)
	tabs.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	left.add_child(UIStyle.label("Ligue duas evidências para tentar uma dedução:", 18, UIStyle.BONE_DIM))
	_board_list = ItemList.new()
	_board_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for id in Game.evidence:
		_board_list.add_item(Data.evidence.get(id, {}).get("name", id))
		_board_list.set_item_metadata(_board_list.item_count - 1, id)
	_board_list.item_selected.connect(_on_board_pick)
	left.add_child(_board_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	_board_result = _rich("")
	right.add_child(_board_result)
	var known := "[b]Deduções[/b]\n"
	for d in Data.deductions:
		if d.get("id", "") in Game.deductions:
			known += "• [color=#7f97b8]%s[/color] — %s\n" % [d.get("title", ""), d.get("text", "")]
	right.add_child(_rich(known))
	_sel_a = ""


func _on_board_pick(i: int) -> void:
	var id: String = _board_list.get_item_metadata(i)
	if _sel_a == "":
		_sel_a = id
		_board_result.text = "[color=#c9b27c]Primeira:[/color] %s\nEscolha a segunda." % Data.evidence.get(id, {}).get("name", id)
		Sfx.play("ui_move", 0.5)
		return
	var r := Game.try_deduction(_sel_a, id)
	match r["result"]:
		"new":
			_board_result.text = "[color=#7f97b8][b]%s[/b][/color]\n%s" % [r["d"].get("title", ""), r["d"].get("text", "")]
			Sfx.play("mission", 0.7)
		"known":
			_board_result.text = "Você já chegou a essa conclusão."
		_:
			_board_result.text = "[color=#8d8778]Essas duas coisas não se conectam... ainda.[/color]"
			Sfx.play("ui_back", 0.5)
	_sel_a = ""
	_board_list.deselect_all()


func _tab_people() -> void:
	var v := _scroll("Pessoas")
	v.add_child(_rich("[color=#8d8778]Marque quem você acredita ser um espírito disfarçado. As marcações influenciam os finais — e acusar errado tem preço.[/color]"))
	var ids: Array = Game.met.keys()
	ids.sort()
	for id in ids:
		if not Data.npcs.has(id):
			continue
		var n: Dictionary = Data.npcs[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := _rich("[b]%s[/b]  [color=#8d8778]%s[/color]\n%s" % [n.get("name", id), n.get("role", ""), _tells_for(id)])
		info.custom_minimum_size = Vector2(560, 0)
		row.add_child(info)
		var cur: String = Game.marks.get(id, "")
		for opt in [["Humano", "human"], ["Espírito", "spirit"], ["?", ""]]:
			var b := Button.new()
			b.text = opt[0]
			b.toggle_mode = true
			b.button_pressed = cur == opt[1]
			b.custom_minimum_size = Vector2(120, 44)
			var val: String = opt[1]
			b.pressed.connect(func():
				if val == "":
					Game.marks.erase(id)
				else:
					Game.marks[id] = val
				Sfx.play("ui_ok", 0.5)
				_rebuild_keep("Pessoas")
			)
			row.add_child(b)
		v.add_child(row)
		v.add_child(HSeparator.new())
	var tr := Game.trust
	if not tr.is_empty():
		var t := "[b]Confiança[/b]\n"
		for k in tr:
			t += "%s: %+d   " % [Data.char_name(k), int(tr[k])]
		v.add_child(_rich(t))


func _tells_for(id: String) -> String:
	var found: Array = []
	for e in Game.evidence:
		var ev: Dictionary = Data.evidence.get(e, {})
		if ev.get("about", "") == id:
			found.append(ev.get("name", e))
	if found.is_empty():
		return "[color=#5f5b53]Sem sinais anotados.[/color]"
	return "[color=#c9b27c]Sinais:[/color] " + ", ".join(found)


func _rebuild_keep(tab: String) -> void:
	await get_tree().process_frame
	_rebuild()
	await get_tree().process_frame
	for i in tabs.get_tab_count():
		if tabs.get_tab_title(i) == tab:
			tabs.current_tab = i


func _tab_map() -> void:
	var v := _scroll("Mapa")
	v.add_child(_rich("[b]RAVENHILL[/b]  —  você está em: [color=#b8323a]%s[/color]" % Data.locations.get(Game.location, {}).get("name", "")))
	var districts := {}
	for id in Data.locations:
		var l: Dictionary = Data.locations[id]
		var d: String = l.get("district", "Outros")
		if not districts.has(d):
			districts[d] = []
		districts[d].append(id)
	for d in districts:
		var t := "[color=#c9b27c]%s[/color]\n" % d
		for id in districts[d]:
			var l: Dictionary = Data.locations[id]
			var seen: bool = Game.visited.has(id)
			var here: bool = id == Game.location
			t += "   %s %s\n" % ["●" if here else ("○" if seen else "·"), l.get("name", id) if seen else "???"]
		v.add_child(_rich(t))


func _tab_system() -> void:
	var v := _scroll("Sistema")
	v.add_child(UIStyle.label("Salvar", 22))
	for i in range(1, Game.SLOTS):
		var d := Game.read_slot(i)
		var desc := "Vazio"
		if not d.is_empty():
			desc = "%s — Cap. %d — %s" % [Data.char_name(d.get("character", "")), int(d.get("chapter", 1)), d.get("stamp", "")]
		var slot := i
		var on_save := func():
			if world and (world.any_chase() or world.cutscene_running):
				Game.notify.emit("Não é seguro salvar agora.", "fail")
				return
			if Game.save_slot(slot):
				Game.notify.emit("Jogo salvo no espaço %d." % slot, "info")
			_rebuild_keep("Sistema")
		var b := UIStyle.button("Espaço %d:  %s" % [i, desc], on_save, 640)
		v.add_child(b)
	v.add_child(HSeparator.new())
	v.add_child(UIStyle.label("Configurações", 22))
	v.add_child(_slider("Música", "music"))
	v.add_child(_slider("Efeitos", "sfx"))
	v.add_child(_slider("Velocidade do texto", "text_speed", 0.4, 2.5))
	v.add_child(_slider("Opacidade dos controles", "touch_alpha", 0.15, 1.0))
	v.add_child(_slider("Ritmo do relógio", "time_speed", 0.5, 2.0))
	v.add_child(_toggle("Vibração", "vibration"))
	v.add_child(_toggle("Granulação de filme", "grain"))
	v.add_child(_toggle("Tremor de câmera", "shake"))
	v.add_child(HSeparator.new())
	var on_quit := func():
		close_book()
		if world:
			world.request_title.emit()
	v.add_child(UIStyle.button("Sair para o menu", on_quit, 640))


func _slider(title: String, key: String, mn: float = 0.0, mx: float = 1.0) -> Control:
	var h := HBoxContainer.new()
	var l := UIStyle.label(title, 18)
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.05
	s.value = float(Game.settings.get(key, 1.0))
	s.custom_minimum_size = Vector2(320, 36)
	s.value_changed.connect(func(val):
		Game.settings[key] = val
		if key == "time_speed":
			Clock.speed = val
		Game.save_meta()
	)
	h.add_child(s)
	return h


func _toggle(title: String, key: String) -> Control:
	var c := CheckButton.new()
	c.text = title
	c.button_pressed = bool(Game.settings.get(key, true))
	c.toggled.connect(func(on):
		Game.settings[key] = on
		Game.save_meta()
	)
	return c
