extends CanvasLayer
## Caixa de diálogo cinematográfica: retrato MUGEN com expressão, nome, texto com
## máquina de escrever, escolhas com consequências, variações por personagem/hora.

signal line_done
signal choice_made(i: int)

var panel: PanelContainer
var portrait_frame: Panel
var portrait: TextureRect
var portrait_actor: Actor
var portrait_holder: Control
var name_label: Label
var text: RichTextLabel
var choices_box: VBoxContainer
var hint: Label
var _typing: bool = false
var _active: bool = false
var _choosing: bool = false
var _speed: float = 45.0
var _t: float = 0.0
var _open_frame: int = 0
var auto: bool = false            # testes automatizados: avança falas e escolhe sozinho
var auto_picks: Array = []        # índices de escolha usados em ordem (padrão 0)


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)
	panel = PanelContainer.new()
	panel.anchor_left = 0.04
	panel.anchor_right = 0.96
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -230
	panel.offset_bottom = -22
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.03, 0.035, 0.045, 0.93), UIStyle.LINE, 1, 3, 18))
	root.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	panel.add_child(hb)
	portrait_holder = Control.new()
	portrait_holder.custom_minimum_size = Vector2(170, 180)
	portrait_holder.clip_contents = true
	hb.add_child(portrait_holder)
	portrait_frame = Panel.new()
	portrait_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_frame.add_theme_stylebox_override("panel", UIStyle.box(Color(0.07, 0.07, 0.085), UIStyle.BLOOD, 1, 2, 0))
	portrait_holder.add_child(portrait_frame)
	portrait = TextureRect.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_holder.add_child(portrait)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	hb.add_child(vb)
	name_label = UIStyle.label("", 24, UIStyle.BLOOD_HI)
	vb.add_child(name_label)
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 23)
	text.add_theme_font_size_override("italics_font_size", 23)
	vb.add_child(text)
	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 6)
	vb.add_child(choices_box)
	hint = UIStyle.label("▼", 18, UIStyle.BONE_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(hint)
	panel.visible = false
	panel.gui_input.connect(_on_panel_input)


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	hint.modulate.a = 0.4 + 0.4 * sin(_t * 5.0) if not _typing and not _choosing else 0.0
	if _typing:
		text.visible_characters += maxi(1, int(_speed * float(Game.settings.get("text_speed", 1.0)) * delta * 1.4))
		if text.visible_characters >= text.get_total_character_count():
			text.visible_characters = -1
			_typing = false
	if not _choosing and Input.is_action_just_pressed("advance") and Engine.get_process_frames() > _open_frame:
		_advance()


func _on_panel_input(e: InputEvent) -> void:
	if _choosing:
		return
	if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		_advance()


func _advance() -> void:
	if _typing:
		text.visible_characters = -1
		_typing = false
	else:
		line_done.emit()


func _set_speaker(who: String, expr: String) -> void:
	var id := Game.character if who == "player" else who
	if who == "" or who == "narrator":
		name_label.text = ""
		portrait_holder.visible = false
		return
	if who == "radio":
		name_label.text = "RÁDIO — 7.17"
		portrait_holder.visible = false
		return
	portrait_holder.visible = true
	name_label.text = Data.char_name(id)
	var tex := Art.portrait(id, expr)
	if portrait_actor:
		portrait_actor.queue_free()
		portrait_actor = null
	if tex:
		portrait.texture = tex
	else:
		portrait.texture = null
		# sem retrato pintado: enquadra o próprio sprite (busto)
		var kind := "char" if Data.characters.has(id) else ("creature" if Data.creatures.has(id) else "npc")
		portrait_actor = Actor.new()
		portrait_holder.add_child(portrait_actor)
		portrait_actor.setup(id, kind)
		portrait_actor.expr = expr
		portrait_actor.scale = Vector2(1.9, 1.9)
		portrait_actor.position = Vector2(80, 470)
		portrait_actor.set_facing(1)
		portrait_actor.play("fear" if expr == "scared" else "talk")


## Mostra uma fala e espera o jogador avançar.
func say(who: String, expr: String, line: String) -> void:
	_active = true
	panel.visible = true
	_choosing = false
	_clear_choices()
	_set_speaker(who, expr)
	var style := ""
	if who == "radio":
		style = "[color=#7f97b8][i]%s[/i][/color]"
	elif who == "narrator" or who == "":
		style = "[i][color=#a59e8f]%s[/color][/i]"
	else:
		style = "%s"
	text.text = style % _fmt(line)
	text.visible_characters = 0
	_typing = true
	_t = 0.0
	_open_frame = Engine.get_process_frames()
	if who == "radio":
		Sfx.play("radio_on", 0.5)
	if auto:
		await get_tree().process_frame
		return
	await line_done
	Sfx.play("ui_move", 0.3)


func ask(prompt_who: String, prompt: String, options: Array) -> int:
	if prompt != "":
		_set_speaker(prompt_who, "neutral")
		text.text = _fmt(prompt)
		text.visible_characters = -1
	_active = true
	panel.visible = true
	_choosing = true
	_clear_choices()
	var first: Button = null
	for i in options.size():
		var b := Button.new()
		b.text = "  ›  " + _fmt(str(options[i]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 46)
		var idx := i
		b.pressed.connect(func():
			Sfx.play("ui_ok", 0.6)
			choice_made.emit(idx)
		)
		choices_box.add_child(b)
		if first == null:
			first = b
	if first:
		first.grab_focus()
	if auto:
		await get_tree().process_frame
		var pick: int = int(auto_picks.pop_front()) if not auto_picks.is_empty() else 0
		_choosing = false
		_clear_choices()
		return clampi(pick, 0, options.size() - 1)
	var r: int = await choice_made
	_choosing = false
	_clear_choices()
	return r


func close() -> void:
	panel.visible = false
	_active = false
	if portrait_actor:
		portrait_actor.queue_free()
		portrait_actor = null


func _clear_choices() -> void:
	for c in choices_box.get_children():
		c.queue_free()


func _fmt(s: String) -> String:
	var c: Dictionary = Data.characters.get(Game.character, {})
	return s.replace("{nome}", c.get("short", "")).replace("{hora}", Clock.label())


## Executa uma árvore de diálogo de data/dialogues.json.
func run(id: String, npc_id: String = "") -> void:
	var tree: Dictionary = Data.dialogues.get(id, {})
	if tree.is_empty():
		push_warning("Diálogo inexistente: " + id)
		return
	var node_id: String = "start"
	var guard := 0
	while node_id != "" and node_id != "end" and guard < 200:
		guard += 1
		var node: Dictionary = tree.get(node_id, {})
		if node.is_empty():
			push_warning("Nó inexistente %s em %s" % [node_id, id])
			break
		# desvios condicionais
		if node.has("branch"):
			var nxt := ""
			for br in node["branch"]:
				if Game.check(br.get("if", {})):
					nxt = br.get("go", "")
					break
			node_id = nxt
			continue
		Game.apply(node.get("do", {}))
		var who: String = node.get("who", npc_id)
		if who == "npc":
			who = npc_id
		var line = node.get("text", "")
		var by_char: Dictionary = node.get("by_char", {})
		if by_char.has(Game.character):
			line = by_char[Game.character]
		if line is Array:
			for l in line:
				await say(l.get("who", who) if l.get("who", who) != "npc" else npc_id, l.get("expr", "neutral"), l.get("text", ""))
		elif line != "":
			await say(who, node.get("expr", "neutral"), line)
		if node.has("choices"):
			var shown: Array = []
			var labels: Array = []
			for ch in node["choices"]:
				if Game.check(ch.get("if", {})):
					shown.append(ch)
					labels.append(ch.get("text", "..."))
			if shown.is_empty():
				node_id = node.get("next", "end")
				continue
			var pick := await ask(who, "", labels)
			var chosen: Dictionary = shown[pick]
			Game.apply(chosen.get("do", {}))
			node_id = chosen.get("next", "end")
		else:
			node_id = node.get("next", "end")
	close()
