extends CanvasLayer
## Controles de toque (Android). TouchScreenButton suporta multitoque real
## (andar + correr + interagir ao mesmo tempo). Aparece só em telas de toque.

var buttons: Array = []
var _visible: bool = true
static var _tex_cache: Dictionary = {}


func _ready() -> void:
	layer = 15
	if not DisplayServer.is_touchscreen_available() and not OS.has_feature("mobile"):
		_visible = false
		return
	var vs := get_viewport().get_visible_rect().size
	var r := 62.0
	var y := vs.y - 120.0
	_add("left", "◀", Vector2(110, y), r)
	_add("right", "▶", Vector2(270, y), r)
	_add("crouch", "▼", Vector2(190, y - 120), r * 0.72)
	var x := vs.x - 110.0
	_add("interact", "E", Vector2(x, y), r)
	_add("run", "»", Vector2(x - 150, y + 10), r * 0.85)
	_add("ability", "Q", Vector2(x - 40, y - 150), r * 0.72)
	_add("photo", "◉", Vector2(x - 170, y - 130), r * 0.72)
	_add("flashlight", "☼", Vector2(x - 290, y - 40), r * 0.66)
	_add("notebook", "≡", Vector2(vs.x - 60, 60), r * 0.6)
	set_visible_controls(true)


func _tex(radius: int, pressed: bool) -> Texture2D:
	var key := "%d_%s" % [radius, pressed]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var s := radius * 2
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(radius, radius)
	for x in s:
		for y in s:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d > radius:
				continue
			var a := 0.0
			var col := Color(0.06, 0.065, 0.08)
			if d > radius - 3.0:
				col = Color(0.72, 0.2, 0.22) if pressed else Color(0.55, 0.53, 0.48)
				a = 0.9
			else:
				a = 0.55 if pressed else 0.38
				if pressed:
					col = Color(0.25, 0.07, 0.08)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	var t := ImageTexture.create_from_image(img)
	_tex_cache[key] = t
	return t


func _add(action: String, glyph: String, center: Vector2, radius: float) -> void:
	var b := TouchScreenButton.new()
	var ri := int(radius)
	b.texture_normal = _tex(ri, false)
	b.texture_pressed = _tex(ri, true)
	b.action = action
	b.position = center - Vector2(radius, radius)
	var sh := CircleShape2D.new()
	sh.radius = radius
	b.shape = sh
	b.shape_centered = true
	b.passby_press = action in ["left", "right", "run"]
	var l := Label.new()
	l.text = glyph
	l.add_theme_font_size_override("font_size", int(radius * 0.7))
	l.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	l.size = Vector2(radius * 2, radius * 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	add_child(b)
	buttons.append(b)


func set_visible_controls(on: bool) -> void:
	var a: float = Game.settings.get("touch_alpha", 0.55)
	for b in buttons:
		b.visible = on and _visible
		b.modulate.a = a
