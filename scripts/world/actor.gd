extends Node2D
class_name Actor
## Representação visual de qualquer personagem (protagonista, NPC, criatura).
## Origem = pés. Usa os sprites MUGEN do pipeline quando existem; senão desenha a
## silhueta provisória animada (marcada como pendente na auditoria de arte).

signal anim_finished(anim: String)

var id: String = ""
var kind: String = "char"           # char | npc | creature
var info: Dictionary = {}
var facing: int = 1
var anim: String = "idle"
var expr: String = "neutral"
var target_height: float = 230.0
var show_reflection: bool = false
var spirit_glow: float = 0.0        # 0..1 revelação (Visão da Naomi / foto)
var ghostly: bool = false           # espíritos revelados ficam translúcidos e trêmulos
var speed_scale: float = 1.0

var _sprite: AnimatedSprite2D
var _reflection: AnimatedSprite2D
var _t: float = 0.0
var _phase: float = 0.0
var _pal: Dictionary = {}
var _build: String = "slim"
var _hair: String = "short"


func setup(actor_id: String, actor_kind: String) -> void:
	id = actor_id
	kind = actor_kind
	if kind == "char":
		info = Data.characters.get(id, {})
	elif kind == "npc":
		info = Data.npcs.get(id, {})
	else:
		info = Data.creatures.get(id, {})
	target_height = 230.0 * float(info.get("height", 1.0))
	_pal = info.get("palette", {})
	_build = info.get("build", "slim")
	_hair = info.get("hair", "short")
	_phase = randf() * 10.0
	var sf := Art.frames_for(id)
	if sf:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = sf
		_sprite.centered = false
		add_child(_sprite)
		_sprite.animation_finished.connect(func(): anim_finished.emit(anim))
		_fit(_sprite)
		_reflection = AnimatedSprite2D.new()
		_reflection.sprite_frames = sf
		_reflection.centered = false
		_reflection.modulate = Color(0.7, 0.75, 0.9, 0.22)
		_reflection.visible = false
		add_child(_reflection)
		_fit(_reflection)
		_reflection.scale.y = -_reflection.scale.y
		_reflection.position.y = 2
	play("idle")


func _fit(s: AnimatedSprite2D) -> void:
	var tex := s.sprite_frames.get_frame_texture("idle", 0)
	if tex == null:
		return
	var sz := tex.get_size()
	var k := target_height / maxf(sz.y - 8.0, 1.0)
	s.scale = Vector2(k, k)
	s.offset = Vector2(-sz.x * 0.5, -sz.y + 4.0)


func play(a: String) -> void:
	anim = a
	if _sprite:
		if _sprite.sprite_frames.has_animation(a):
			_sprite.play(a)
			_sprite.speed_scale = speed_scale
		if _reflection and _reflection.sprite_frames.has_animation(a):
			_reflection.play(a)


func set_facing(dir: int) -> void:
	if dir == 0:
		return
	facing = 1 if dir > 0 else -1
	if _sprite:
		_sprite.flip_h = facing < 0
		_reflection.flip_h = facing < 0


func set_reflection(on: bool) -> void:
	show_reflection = on
	if _reflection:
		_reflection.visible = on
	queue_redraw()


func has_art() -> bool:
	return _sprite != null


func _process(delta: float) -> void:
	_t += delta * speed_scale
	if ghostly:
		position.x += sin(_t * 47.0) * 0.6
		modulate.a = 0.55 + 0.35 * sin(_t * 9.0 + _phase)
	var g := spirit_glow
	if g > 0.0:
		modulate = Color(1.0 - 0.5 * g, 1.0 - 0.2 * g, 1.0 + 0.6 * g, modulate.a)
	elif not ghostly:
		modulate = Color(1, 1, 1, modulate.a)
	if _sprite == null:
		queue_redraw()


# ---------------------------------------------------------------- silhueta provisória
func _c(key: String, def: Color) -> Color:
	if _pal.has(key):
		return Color(_pal[key])
	return def


func _draw() -> void:
	if _sprite != null:
		if spirit_glow > 0.0:
			draw_texture_rect(Art.glow(), Rect2(-target_height * 0.45, -target_height * 1.05, target_height * 0.9, target_height * 1.1), false, Color(0.4, 0.7, 1.0, 0.5 * spirit_glow))
		return
	if kind == "creature":
		_draw_creature()
	else:
		_draw_human(1.0)
		if show_reflection:
			draw_set_transform(Vector2(0, 2), 0.0, Vector2(1, -0.85))
			_draw_human(0.18)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _limb(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	draw_line(a, b, col, w, true)
	draw_circle(a, w * 0.5, col)
	draw_circle(b, w * 0.5, col)


func _draw_human(alpha: float) -> void:
	var h := target_height
	var f := float(facing)
	var moving := anim in ["walk", "run", "chase"]
	var spd := 1.6 if anim == "walk" else 2.6
	var cyc := sin(_t * TAU * spd * 0.5 + _phase) if moving else 0.0
	var breathe := sin(_t * 2.2 + _phase) * 0.006 * h
	var crouch := 0.0
	if anim in ["crouch", "hide"]:
		crouch = 0.22 * h
	var lean := 0.0
	if anim == "run":
		lean = 0.06 * h * f
	elif anim == "fear":
		lean = -0.04 * h * f
	var wide := 1.0
	match _build:
		"wide": wide = 1.25
		"child": wide = 0.85
		"tall": wide = 0.95
		"old": wide = 1.05
	var skin := _c("skin", Color("c89f86"))
	var hair := _c("hair", Color("2b211c"))
	var top := _c("top", Color("3d4237"))
	var bottom := _c("bottom", Color("1d1f24"))
	var shoes := _c("shoes", Color("d8d6d0"))
	var accent := _c("accent", Color("6b1f22"))
	skin.a = alpha; hair.a = alpha; top.a = alpha; bottom.a = alpha; shoes.a = alpha; accent.a = alpha
	var shade := Color(0, 0, 0, 0.28 * alpha)
	# proporções realistas (~7.5 cabeças)
	var head_r := h * 0.066
	var hip := Vector2(lean * 0.3, -h * 0.47 + crouch)
	var neck := Vector2(lean, -h * 0.84 + crouch * 1.1 + breathe)
	var leg_w := h * 0.075 * wide
	var arm_w := h * 0.055 * wide
	# sombra no chão
	if alpha >= 1.0:
		draw_set_transform(Vector2(0, 0), 0.0, Vector2(1, 0.18))
		draw_circle(Vector2.ZERO, h * 0.16, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# pernas (trás, frente)
	for side in [-1, 1]:
		var sw: float = cyc * side
		var knee := hip + Vector2(f * (sw * h * 0.09) + f * crouch * 0.4, h * 0.23 - crouch * 0.35)
		var foot := Vector2(f * sw * h * 0.14, -h * 0.02)
		if crouch > 0:
			foot = Vector2(f * side * h * 0.06, -h * 0.02)
		var col: Color = bottom.darkened(0.25) if side < 0 else bottom
		_limb(hip + Vector2(side * leg_w * 0.15, 0), knee, leg_w, col)
		_limb(knee, foot, leg_w * 0.9, col)
		draw_rect(Rect2(foot + Vector2(-leg_w * 0.4 + (f * leg_w * 0.2), -leg_w * 0.45), Vector2(leg_w * 1.4, leg_w * 0.55)), shoes.darkened(0.2 if side < 0 else 0.0))
	# braço de trás
	var sh := neck + Vector2(0, h * 0.05)
	var arm_sw := -cyc
	var hand_b := sh + Vector2(f * arm_sw * h * 0.12 - f * h * 0.02, h * 0.3)
	if anim == "fear":
		hand_b = sh + Vector2(f * h * 0.08, -h * 0.02)
	_limb(sh, sh.lerp(hand_b, 0.5) + Vector2(-f * h * 0.015, 0), arm_w, top.darkened(0.3))
	_limb(sh.lerp(hand_b, 0.5) + Vector2(-f * h * 0.015, 0), hand_b, arm_w * 0.9, top.darkened(0.3))
	draw_circle(hand_b, arm_w * 0.45, skin.darkened(0.25))
	# tronco
	var tw := h * 0.12 * wide
	var torso := PackedVector2Array([
		neck + Vector2(-tw * 0.55, h * 0.03), neck + Vector2(tw * 0.55, h * 0.03),
		hip + Vector2(tw * 0.48, h * 0.04), hip + Vector2(-tw * 0.48, h * 0.04)])
	draw_colored_polygon(torso, top)
	draw_colored_polygon(PackedVector2Array([torso[0], torso[0] + Vector2(tw * 0.35, 0), torso[3] + Vector2(tw * 0.3, 0), torso[3]]), shade if f > 0 else Color(1, 1, 1, 0.06 * alpha))
	if _pal.has("coat_long"):
		draw_colored_polygon(PackedVector2Array([hip + Vector2(-tw * 0.5, 0), hip + Vector2(tw * 0.5, 0), hip + Vector2(tw * 0.55 + f * cyc * 6, h * 0.2), hip + Vector2(-tw * 0.55 + f * cyc * 6, h * 0.2)]), top.darkened(0.1))
	# detalhe (alça, câmera, cachecol) na cor de destaque
	draw_line(neck + Vector2(-tw * 0.3 * f, h * 0.04), hip + Vector2(tw * 0.35 * f, -h * 0.02), accent, h * 0.012, true)
	# pescoço e cabeça
	var head := neck + Vector2(f * h * 0.01, -head_r * 1.05)
	if anim in ["inspect"]:
		head += Vector2(f * h * 0.02, h * 0.015)
	_limb(neck + Vector2(0, h * 0.02), head, h * 0.035, skin.darkened(0.15))
	draw_circle(head, head_r, skin)
	draw_circle(head + Vector2(-f * head_r * 0.35, 0), head_r * 0.8, Color(0, 0, 0, 0.12 * alpha))
	# cabelo
	match _hair:
		"bald":
			pass
		"long", "bob":
			var ln := head_r * (2.4 if _hair == "long" else 1.5)
			draw_colored_polygon(PackedVector2Array([head + Vector2(-head_r * 1.05, -head_r * 0.2), head + Vector2(head_r * 1.05, -head_r * 0.2), head + Vector2(head_r * 0.9 - f * head_r * 0.3, ln), head + Vector2(-head_r * 1.1 - f * head_r * 0.3, ln)]), hair)
			draw_circle(head + Vector2(-f * head_r * 0.1, -head_r * 0.25), head_r * 1.04, hair)
			draw_circle(head + Vector2(f * head_r * 0.35, head_r * 0.1), head_r * 0.62, skin)
		"puff":
			draw_circle(head + Vector2(-f * head_r * 0.2, -head_r * 1.15), head_r * 0.85, hair)
			draw_circle(head + Vector2(-f * head_r * 0.15, -head_r * 0.3), head_r * 1.0, hair)
			draw_circle(head + Vector2(f * head_r * 0.35, head_r * 0.12), head_r * 0.64, skin)
			draw_line(head + Vector2(-head_r, -head_r * 0.55), head + Vector2(head_r, -head_r * 0.55), accent, head_r * 0.25)
		"cap":
			draw_circle(head + Vector2(0, -head_r * 0.3), head_r * 1.02, hair)
			draw_rect(Rect2(head + Vector2(min(0.0, f) * head_r * 1.6, -head_r * 0.55), Vector2(head_r * 1.6, head_r * 0.22)), hair.darkened(0.3))
			draw_circle(head + Vector2(f * head_r * 0.3, head_r * 0.15), head_r * 0.66, skin)
		_:
			draw_circle(head + Vector2(-f * head_r * 0.15, -head_r * 0.35), head_r * 0.98, hair)
			draw_colored_polygon(PackedVector2Array([head + Vector2(-head_r, -head_r * 0.6), head + Vector2(f * head_r * 1.15, -head_r * 0.9), head + Vector2(f * head_r * 0.7, -head_r * 0.1)]), hair)
			draw_circle(head + Vector2(f * head_r * 0.38, head_r * 0.18), head_r * 0.6, skin)
	# olho (indica direção e emoção)
	var eye := head + Vector2(f * head_r * 0.55, -head_r * 0.05)
	var eye_col := Color(0.08, 0.08, 0.1, alpha)
	if anim == "fear" or expr == "scared":
		draw_circle(eye, head_r * 0.16, Color(0.95, 0.95, 0.95, alpha))
	draw_circle(eye, head_r * 0.09, eye_col)
	# braço da frente
	var hand_f := sh + Vector2(f * -arm_sw * h * 0.12 + f * h * 0.02, h * 0.3)
	if anim in ["inspect", "flashlight", "talk"]:
		hand_f = sh + Vector2(f * h * 0.17, h * 0.12)
	if anim == "fear":
		hand_f = head + Vector2(f * head_r * 0.8, head_r * 0.6)
	var elbow := sh.lerp(hand_f, 0.5) + Vector2(-f * h * 0.03, h * 0.03)
	_limb(sh + Vector2(f * tw * 0.1, 0), elbow, arm_w, top)
	_limb(elbow, hand_f, arm_w * 0.9, top)
	draw_circle(hand_f, arm_w * 0.45, skin)
	# contorno de luz (rim light) para leitura no escuro
	if alpha >= 1.0:
		draw_arc(head, head_r * 1.02, -PI * 0.5 - f * 0.9, -PI * 0.5 + f * 0.2, 10, Color(0.75, 0.8, 0.95, 0.35), 1.5)
	if spirit_glow > 0.0:
		draw_texture_rect(Art.glow(), Rect2(-h * 0.45, -h * 1.05, h * 0.9, h * 1.1), false, Color(0.4, 0.7, 1.0, 0.5 * spirit_glow))


func _draw_creature() -> void:
	var h := target_height
	var f := float(facing)
	var form: String = info.get("form", "hollow")
	var body := _c("body", Color("17161a"))
	var eyes := _c("eyes", Color("c8d6ff"))
	var jit := sin(_t * 31.0 + _phase) * 2.0
	var stride := sin(_t * (6.0 if anim in ["chase", "run"] else 2.5)) * h * 0.07
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1, 0.15))
	draw_circle(Vector2.ZERO, h * 0.2, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match form:
		"listener":
			# alto, curvado, espinha de antenas
			var hip := Vector2(-f * h * 0.05, -h * 0.5)
			var top := Vector2(f * h * 0.2 + jit, -h * 0.95)
			for side in [-1, 1]:
				_limb(hip, Vector2(stride * side * f, 0), h * 0.04, body)
			_limb(hip, top, h * 0.09, body)
			for i in 6:
				var p := hip.lerp(top, float(i) / 6.0)
				draw_line(p, p + Vector2(-f * h * 0.08, -h * 0.07 - i * 3), body, 2.0)
			draw_circle(top + Vector2(f * h * 0.06, h * 0.02), h * 0.06, body)
			_limb(top, top + Vector2(f * h * 0.15, h * 0.35 + stride * 0.3), h * 0.03, body)
			_limb(top, top + Vector2(f * h * 0.25, h * 0.3 - stride * 0.3), h * 0.03, body)
		"static":
			var col := body
			col.a = 0.65 + 0.35 * sin(_t * 40.0)
			for i in 9:
				var y := -h * float(i) / 9.0
				var off := sin(_t * 23.0 + i * 1.7) * h * 0.04
				draw_rect(Rect2(Vector2(-h * 0.09 + off, y - h * 0.11), Vector2(h * 0.18 + absf(off), h * 0.105)), col)
			draw_circle(Vector2(f * h * 0.03 + jit, -h * 0.9), h * 0.07, col)
		_:
			# Oco: humanoide magro, rosto apagado, membros longos demais
			var hip := Vector2(0, -h * 0.5)
			var neck := Vector2(f * h * 0.04 + jit * 0.5, -h * 0.86)
			for side in [-1, 1]:
				var knee := hip + Vector2(f * stride * side * 0.8, h * 0.25)
				_limb(hip, knee, h * 0.045, body.lightened(0.04 * side))
				_limb(knee, Vector2(f * stride * side * 1.4, 0), h * 0.04, body)
			_limb(hip, neck, h * 0.1, body)
			for side in [-1, 1]:
				var hand := neck + Vector2(f * (h * 0.06 + stride * side * 0.6), h * 0.55)
				if anim in ["chase", "attack"]:
					hand = neck + Vector2(f * h * 0.38, h * 0.08 * side)
				_limb(neck, neck.lerp(hand, 0.5) + Vector2(0, -h * 0.03), h * 0.03, body)
				_limb(neck.lerp(hand, 0.5) + Vector2(0, -h * 0.03), hand, h * 0.025, body)
				for k in 3:
					draw_line(hand, hand + Vector2(f * (h * 0.04 + k * 2), h * 0.03 * (k - 1)), body, 2.0)
			var head := neck + Vector2(f * h * 0.02, -h * 0.08)
			draw_circle(head, h * 0.065, body)
			draw_circle(head + Vector2(f * h * 0.02, 0), h * 0.05, body.lightened(0.18))
	# olhos frios
	var eye_pos := Vector2(f * h * 0.06, -h * 0.94)
	if form == "listener":
		eye_pos = Vector2(f * h * 0.32, -h * 0.92)
	if form != "listener":
		draw_texture_rect(Art.glow(), Rect2(eye_pos - Vector2(14, 14), Vector2(28, 28)), false, Color(eyes.r, eyes.g, eyes.b, 0.6))
		draw_circle(eye_pos, 2.5, eyes)
