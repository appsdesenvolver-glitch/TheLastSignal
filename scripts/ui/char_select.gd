extends Control
## Seleção de personagem: quatro protagonistas em palco, cada um com animação
## própria, ficha (idade, papel, habilidade, história) e confirmação.

signal chosen(id: String)
signal back

var ids: Array = []
var idx: int = 0
var actors: Array = []
var stage: Node2D
var info_name: Label
var info_role: Label
var info_ability: RichTextLabel
var info_bio: RichTextLabel
var _t: float = 0.0
var _fx: ScreenFX
var _confirming: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	ids = Data.characters.keys()
	var bg := ColorRect.new()
	bg.color = UIStyle.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	stage = Node2D.new()
	add_child(stage)
	var spacing := 210.0
	for i in ids.size():
		var a := Actor.new()
		stage.add_child(a)
		a.setup(ids[i], "char")
		a.position = Vector2(150 + i * spacing, 560)
		a.set_facing(1)
		actors.append(a)
	var head := UIStyle.label("ESCOLHA QUEM VAI OUVIR O SINAL", 30, UIStyle.BONE)
	head.position = Vector2(70, 34)
	add_child(head)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.66
	panel.anchor_right = 0.97
	panel.anchor_top = 0.12
	panel.anchor_bottom = 0.88
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	info_name = UIStyle.label("", 34, UIStyle.BONE)
	v.add_child(info_name)
	info_role = UIStyle.label("", 18, UIStyle.BLOOD_HI)
	info_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info_role)
	info_ability = RichTextLabel.new()
	info_ability.bbcode_enabled = true
	info_ability.fit_content = true
	info_ability.add_theme_font_size_override("normal_font_size", 18)
	v.add_child(info_ability)
	info_bio = RichTextLabel.new()
	info_bio.bbcode_enabled = true
	info_bio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_bio.add_theme_font_size_override("normal_font_size", 18)
	v.add_child(info_bio)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(UIStyle.button("◀", _prev, 70))
	row.add_child(UIStyle.button("▶", _next, 70))
	var go := UIStyle.button("Confirmar", _confirm, 180)
	row.add_child(go)
	var bk := UIStyle.button("Voltar", _back, 140)
	bk.position = Vector2(70, 650)
	bk.anchor_top = 1.0
	bk.anchor_bottom = 1.0
	bk.offset_top = -80
	bk.offset_bottom = -28
	add_child(bk)
	_fx = ScreenFX.new()
	add_child(_fx)
	_fx.set_fog(0.25)
	_fx.fade(0.0, 0.8)
	go.grab_focus()
	_select(0)


func _prev() -> void:
	_select(idx - 1)


func _next() -> void:
	_select(idx + 1)


func _back() -> void:
	back.emit()


func _select(i: int) -> void:
	idx = posmod(i, ids.size())
	var c: Dictionary = Data.characters[ids[idx]]
	info_name.text = c.get("name", "")
	info_role.text = "%s anos  ·  %s" % [str(c.get("age", "")), c.get("role", "")]
	info_ability.text = "[color=#7f97b8]Habilidade — %s[/color]\n%s" % [c.get("ability_name", ""), c.get("ability_desc", "")]
	info_bio.text = "[color=#a59e8f]%s[/color]\n\n[i]\"%s\"[/i]" % [c.get("bio", ""), c.get("quote", "")]
	Sfx.play("ui_move", 0.5)
	for k in actors.size():
		var a: Actor = actors[k]
		var sel := k == idx
		a.play("walk" if sel else "idle")
		a.modulate = Color(1, 1, 1, 1) if sel else Color(0.35, 0.35, 0.42, 1)
	if Art.frames_for(ids[idx]) == null:
		info_bio.text += "\n\n[color=#5f5b53][font_size=14]Sprite MUGEN final pendente — usando silhueta provisória.[/font_size][/color]"


func _process(delta: float) -> void:
	_t += delta
	for k in actors.size():
		var a: Actor = actors[k]
		var sel := k == idx
		a.scale = a.scale.lerp(Vector2.ONE * (1.25 if sel else 0.92), delta * 6.0)
		a.position.y = 560.0 + (0.0 if sel else 10.0)
	queue_redraw()
	if _confirming:
		return
	if Input.is_action_just_pressed("left"):
		_select(idx - 1)
	elif Input.is_action_just_pressed("right"):
		_select(idx + 1)


func _draw() -> void:
	# holofote no escolhido + chão molhado
	var a: Actor = actors[idx] if not actors.is_empty() else null
	draw_rect(Rect2(0, 560, 1600, 200), Color("0e0f14"))
	if a:
		var x := a.position.x
		draw_colored_polygon(PackedVector2Array([Vector2(x - 30, 0), Vector2(x + 30, 0), Vector2(x + 150, 570), Vector2(x - 150, 570)]), Color(0.85, 0.8, 0.7, 0.06 + 0.02 * sin(_t * 3.0)))
		draw_texture_rect(Art.glow(), Rect2(x - 170, 520, 340, 90), false, Color(0.9, 0.85, 0.75, 0.25))
	for k in actors.size():
		var b: Actor = actors[k]
		draw_string(ThemeDB.fallback_font, Vector2(b.position.x - 90, 640), Data.char_name(ids[k]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 180, 18, UIStyle.BLOOD_HI if k == idx else UIStyle.BONE_DIM)


func _confirm() -> void:
	if _confirming:
		return
	_confirming = true
	var a: Actor = actors[idx]
	a.play("run")
	Sfx.play("stinger", 0.7)
	_fx.flash(Color(0.6, 0.1, 0.1), 0.6)
	await _fx.fade(1.0, 1.0)
	chosen.emit(ids[idx])
