extends Node2D
class_name Player
## Protagonista controlado. Movimento lateral responsivo (aceleração curta),
## corrida com fôlego, agachar, esconder, lanterna, câmera, habilidade própria.

signal noise_made(x: float, loudness: float)

var actor: Actor
var char_id: String = "elias"
var info: Dictionary = {}
var world: Node
var velocity_x: float = 0.0
var stamina: float = 100.0
var max_stamina: float = 100.0
var crouching: bool = false
var is_hidden: bool = false
var hide_spot: Node = null
var flashlight_on: bool = false
var flashlight: PointLight2D
var halo: PointLight2D
var locked: bool = false          # cutscene / diálogo / menu
var invuln: float = 0.0
var fear: float = 0.0
var noise: float = 0.0
var bounds := Vector2(40, 2000)
var ability_cd: float = 0.0
var photo_cd: float = 0.0
var _step_t: float = 0.0
var _hurt_t: float = 0.0

const WALK := 150.0
const RUN := 285.0
const CROUCH := 70.0


func setup(id: String, w: Node) -> void:
	char_id = id
	world = w
	info = Data.characters.get(id, {})
	var st: Dictionary = info.get("stats", {})
	max_stamina = float(st.get("stamina", 100))
	stamina = max_stamina
	actor = Actor.new()
	add_child(actor)
	actor.setup(id, "char")
	# lanterna: cone de luz real (afeta sprites via CanvasModulate)
	flashlight = PointLight2D.new()
	flashlight.texture = _cone_texture()
	flashlight.texture_scale = 1.0
	flashlight.energy = 1.15
	flashlight.color = Color(1.0, 0.95, 0.82)
	flashlight.position = Vector2(30, -150)
	flashlight.offset = Vector2(260, 0)
	flashlight.enabled = false
	add_child(flashlight)
	# leve halo ao redor do personagem para nunca sumir totalmente no escuro
	halo = PointLight2D.new()
	halo.texture = Art.glow()
	halo.texture_scale = 3.2
	halo.energy = 0.35
	halo.color = Color(0.6, 0.65, 0.85)
	halo.position = Vector2(0, -110)
	add_child(halo)


static var _cone_cache: Texture2D

func _cone_texture() -> Texture2D:
	if _cone_cache:
		return _cone_cache
	var w := 520
	var h := 300
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in w:
		var t := float(x) / w
		var half := lerpf(10.0, h * 0.5, t)
		for y in h:
			var dy := absf(y - h * 0.5)
			if dy <= half:
				var edge := 1.0 - smoothstep(half * 0.65, half, dy)
				var a := (1.0 - t) * edge
				img.set_pixel(x, y, Color(a, a, a, a))
	_cone_cache = ImageTexture.create_from_image(img)
	return _cone_cache


func _process(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	ability_cd = maxf(0.0, ability_cd - delta)
	photo_cd = maxf(0.0, photo_cd - delta)
	fear = maxf(0.0, fear - delta * 0.15)
	if _hurt_t > 0.0:
		_hurt_t -= delta
		if _hurt_t <= 0.0:
			actor.play("idle")
		return
	if locked:
		velocity_x = move_toward(velocity_x, 0.0, 1400.0 * delta)
		noise = 0.0
		return
	if is_hidden:
		noise = 0.0
		stamina = minf(max_stamina, stamina + 25.0 * delta)
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("left") or Input.is_action_just_pressed("right"):
			leave_hide()
		return
	var axis := Input.get_axis("left", "right")
	crouching = Input.is_action_pressed("crouch")
	var running := Input.is_action_pressed("run") and not crouching and absf(axis) > 0.1 and stamina > 1.0
	var mult: float = float(info.get("stats", {}).get("speed", 1.0))
	var target := axis * (RUN if running else (CROUCH if crouching else WALK)) * mult
	velocity_x = move_toward(velocity_x, target, 2200.0 * delta)
	position.x = clampf(position.x + velocity_x * delta, bounds.x, bounds.y)
	if running:
		stamina = maxf(0.0, stamina - 24.0 * delta)
	else:
		stamina = minf(max_stamina, stamina + (16.0 if absf(axis) < 0.1 else 9.0) * delta)
	if axis != 0.0:
		actor.set_facing(int(signf(axis)))
	var moving := absf(velocity_x) > 8.0
	noise = 0.0
	if crouching:
		actor.play("crouch")
		noise = 0.05 if moving else 0.0
	elif moving:
		actor.play("run" if running else "walk")
		noise = 1.0 if running else 0.35
	elif fear > 0.6:
		actor.play("fear")
	elif flashlight_on:
		actor.play("flashlight")
	else:
		actor.play("idle")
	actor.speed_scale = clampf(absf(velocity_x) / (RUN if running else WALK), 0.6, 1.3) if moving else 1.0
	if moving:
		_step_t -= delta * (1.7 if running else 1.0)
		if _step_t <= 0.0:
			_step_t = 0.36 if not crouching else 0.6
			Sfx.play("step", 0.25 if crouching else (0.7 if running else 0.45), 0.15)
			if noise > 0.0:
				noise_made.emit(position.x, noise)
	flashlight.position.x = 30.0 * actor.facing
	flashlight.rotation = 0.0 if actor.facing > 0 else PI
	if Input.is_action_just_pressed("flashlight"):
		toggle_flashlight()


func toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
	flashlight.enabled = flashlight_on
	Sfx.play("flashlight", 0.6)


func enter_hide(spot: Node) -> void:
	is_hidden = true
	hide_spot = spot
	velocity_x = 0.0
	position.x = spot.position.x
	actor.play("hide")
	actor.modulate.a = 0.35
	flashlight.enabled = false
	Sfx.play("hide", 0.6)


func leave_hide() -> void:
	is_hidden = false
	hide_spot = null
	actor.modulate.a = 1.0
	flashlight.enabled = flashlight_on
	actor.play("idle")
	Sfx.play("hide", 0.5)


func hurt(amount: float, from_x: float) -> void:
	if invuln > 0.0:
		return
	invuln = 1.6
	Game.set_health(Game.health - amount)
	fear = 1.0
	_hurt_t = 0.5
	actor.play("hurt")
	velocity_x = 0.0
	position.x = clampf(position.x + signf(position.x - from_x) * 60.0, bounds.x, bounds.y)
	Sfx.play("hurt")
	if Game.settings.get("vibration", true):
		Input.vibrate_handheld(220)


func scare(amount: float) -> void:
	fear = clampf(fear + amount, 0.0, 1.0)
