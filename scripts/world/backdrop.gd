extends Node2D
class_name Backdrop
## Cenário em camadas com paralaxe. Se houver arte pintada em res://art/stages/<loc>/
## (far.png, mid.png, main.png, ground.png, front.png) ela é usada; caso contrário o
## cenário é pintado proceduralmente a partir do estilo do local (determinístico por seed).

const GROUND := 600.0

class Layer extends Node2D:
	var factor: float = 1.0
	var painter: Callable
	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)

var loc_id: String = ""
var loc: Dictionary = {}
var width: float = 2400.0
var style: String = "street"
var interior: bool = false
var rng := RandomNumberGenerator.new()
var layers: Array = []
var sky_rect: ColorRect
var sky_mat: ShaderMaterial
var _night: float = 0.0
var _blink: float = 0.0
var tower_light: Node2D

const SKY_SHADER := """
shader_type canvas_item;
uniform vec4 top_col : source_color = vec4(0.1, 0.12, 0.2, 1.0);
uniform vec4 bottom_col : source_color = vec4(0.3, 0.3, 0.35, 1.0);
uniform float night = 0.0;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec3 c = mix(top_col.rgb, bottom_col.rgb, pow(UV.y, 1.3));
	vec2 g = floor(UV * vec2(220.0, 120.0));
	float s = step(0.996, h(g)) * night * (1.0 - UV.y) * (0.6 + 0.4 * sin(TIME * 2.0 + h(g) * 40.0));
	vec2 m = vec2(0.8, 0.2);
	float d = distance(UV * vec2(1.78, 1.0), m * vec2(1.78, 1.0));
	c += night * (smoothstep(0.045, 0.04, d) * vec3(0.55, 0.55, 0.5) + smoothstep(0.35, 0.0, d) * vec3(0.05, 0.06, 0.09));
	c += vec3(s);
	COLOR = vec4(c, 1.0);
}
"""


func build(id: String, data: Dictionary, sky_layer: CanvasLayer) -> void:
	loc_id = id
	loc = data
	width = float(data.get("width", 2400))
	style = data.get("style", "street")
	interior = data.get("interior", false)
	rng.seed = hash(id)
	if not interior:
		sky_rect = ColorRect.new()
		sky_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		sky_mat = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = SKY_SHADER
		sky_mat.shader = sh
		sky_rect.material = sky_mat
		sky_layer.add_child(sky_rect)
	if interior:
		_add_layer(1.0, _paint_interior, "main")
	else:
		_add_layer(0.12, _paint_far, "far")
		_add_layer(0.45, _paint_mid, "mid")
		_add_layer(1.0, _paint_main, "main")
	_add_layer(1.0, _paint_ground, "ground")
	refresh_time()


func _add_layer(factor: float, painter: Callable, art_name: String) -> void:
	var l := Layer.new()
	l.factor = factor
	var tex := Art.stage_layer(loc_id, art_name)
	if tex:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.position = Vector2(0, GROUND - tex.get_height() + (140 if art_name == "ground" else 0))
		l.add_child(s)
	else:
		l.painter = painter
	add_child(l)
	layers.append(l)


func update_parallax(cam_x: float, view_w: float) -> void:
	for l in layers:
		var f: float = l.factor
		l.position.x = (cam_x - view_w * 0.5) * (1.0 - f)


## Redesenho periódico (luz da torre, letreiros, monitores) — chamado ~3x por segundo.
func tick() -> void:
	for l in layers:
		if l.painter.is_valid():
			l.queue_redraw()


func refresh_time() -> void:
	_night = Clock.darkness()
	if sky_mat:
		var day_top := Color("5d6f86")
		var day_bot := Color("b9b4a6")
		var dusk_top := Color("2a2440")
		var dusk_bot := Color("8a4b3c")
		var night_top := Color("05060b")
		var night_bot := Color("1a1d2b")
		var top: Color
		var bot: Color
		if _night < 0.5:
			top = day_top.lerp(dusk_top, _night * 2.0)
			bot = day_bot.lerp(dusk_bot, _night * 2.0)
		else:
			top = dusk_top.lerp(night_top, (_night - 0.5) * 2.0)
			bot = dusk_bot.lerp(night_bot, (_night - 0.5) * 2.0)
		if loc.get("fog", 0.0) > 0.3:
			bot = bot.lerp(Color("6c7078"), 0.3 * (1.0 - _night))
		sky_mat.set_shader_parameter("top_col", top)
		sky_mat.set_shader_parameter("bottom_col", bot)
		sky_mat.set_shader_parameter("night", _night)
	for l in layers:
		l.queue_redraw()


# --------------------------------------------------------------- utilidades
func _r(a: float, b: float) -> float:
	return rng.randf_range(a, b)


func _win_lit(seed_v: int) -> bool:
	# janelas acesas mudam de noite e são estáveis por cena
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r.randf() < (0.15 + 0.35 * _night)


func _window(c: CanvasItem, rect: Rect2, seed_v: int, frame: Color) -> void:
	c.draw_rect(rect.grow(3), frame)
	var lit := _win_lit(seed_v) and _night > 0.25
	var glass := Color("1a2230").lerp(Color("6f7f92"), (1.0 - _night) * 0.6)
	if lit:
		glass = Color("d9a75a").lerp(Color("e8d3a0"), 0.3)
	c.draw_rect(rect, glass)
	if lit:
		c.draw_texture_rect(Art.glow(), rect.grow(rect.size.x * 0.8), false, Color(1.0, 0.75, 0.4, 0.25))
		# silhueta na janela, às vezes
		if seed_v % 7 == 0:
			c.draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.35, rect.size.y * 0.3), Vector2(rect.size.x * 0.3, rect.size.y * 0.7)), Color(0.08, 0.06, 0.05, 0.85))
	c.draw_line(rect.position + Vector2(rect.size.x * 0.5, 0), rect.position + Vector2(rect.size.x * 0.5, rect.size.y), frame, 2)
	c.draw_line(rect.position + Vector2(0, rect.size.y * 0.5), rect.position + Vector2(rect.size.x, rect.size.y * 0.5), frame, 2)


# --------------------------------------------------------------- camadas externas
func _paint_far(c: Layer) -> void:
	rng.seed = hash(loc_id + "far")
	var w := width * 0.12 + 1600.0
	var base := Color("1b1f29").lerp(Color("596170"), (1.0 - _night) * 0.55)
	var y0 := GROUND - 140.0
	match style:
		"forest", "hill":
			var x := -200.0
			while x < w:
				var th := _r(160, 320)
				c.draw_colored_polygon(PackedVector2Array([Vector2(x, y0 + 40), Vector2(x + 40, y0 - th), Vector2(x + 80, y0 + 40)]), base)
				x += _r(30, 70)
		_:
			var x := -200.0
			while x < w:
				var bw := _r(60, 160)
				var bh := _r(80, 260)
				c.draw_rect(Rect2(x, y0 - bh, bw, bh + 60), base)
				if _night > 0.3:
					var wy := y0 - bh + 14
					while wy < y0 - 10:
						var wx := x + 8
						while wx < x + bw - 10:
							if _win_lit(int(wx * 7 + wy)):
								c.draw_rect(Rect2(wx, wy, 6, 8), Color(0.85, 0.65, 0.35, 0.7))
							wx += 16
						wy += 22
				x += bw + _r(4, 30)
	# a torre de rádio no horizonte — sempre visível: o sinal
	var tx := 900.0 + float(hash(loc_id) % 500)
	var tcol := base.darkened(0.25)
	c.draw_line(Vector2(tx, y0 - 330), Vector2(tx - 34, y0 + 20), tcol, 3)
	c.draw_line(Vector2(tx, y0 - 330), Vector2(tx + 34, y0 + 20), tcol, 3)
	for i in 9:
		var yy := y0 - 330 + i * 38.0
		var hw := 34.0 * (i * 38.0) / 350.0
		c.draw_line(Vector2(tx - hw, yy), Vector2(tx + hw, yy + 38), tcol, 1.5)
		c.draw_line(Vector2(tx + hw, yy), Vector2(tx - hw, yy + 38), tcol, 1.5)
	var on := fmod(Time.get_ticks_msec() / 1000.0, 1.6) < 0.8
	if on:
		c.draw_texture_rect(Art.glow(), Rect2(tx - 22, y0 - 352, 44, 44), false, Color(1, 0.15, 0.1, 0.9))
	c.draw_circle(Vector2(tx, y0 - 330), 3.5, Color(1, 0.2, 0.15) if on else Color(0.3, 0.05, 0.05))
	# névoa no horizonte
	c.draw_rect(Rect2(-200, y0 - 30, w + 400, 200), Color(0.5, 0.52, 0.58, 0.10 + 0.08 * loc.get("fog", 0.0)))


func _paint_mid(c: Layer) -> void:
	rng.seed = hash(loc_id + "mid")
	var w := width * 0.45 + 1600.0
	var col := Color("12151c").lerp(Color("3d434e"), (1.0 - _night) * 0.6)
	var y0 := GROUND - 60.0
	var x := -100.0
	match style:
		"forest", "hill", "park":
			while x < w:
				var tw := _r(50, 110)
				var th := _r(200, 360)
				c.draw_rect(Rect2(x + tw * 0.45, y0 - th * 0.4, tw * 0.1, th * 0.4 + 60), col.darkened(0.2))
				for k in 4:
					var ky := y0 - th * (0.3 + k * 0.17)
					var kw := tw * (1.0 - k * 0.2)
					c.draw_colored_polygon(PackedVector2Array([Vector2(x + tw * 0.5 - kw * 0.6, ky + 40), Vector2(x + tw * 0.5, ky - 50), Vector2(x + tw * 0.5 + kw * 0.6, ky + 40)]), col)
				x += _r(40, 120)
		_:
			while x < w:
				var bw := _r(140, 260)
				var bh := _r(160, 300)
				c.draw_rect(Rect2(x, y0 - bh, bw, bh + 60), col)
				# telhado inclinado ou platibanda
				if rng.randf() < 0.5:
					c.draw_colored_polygon(PackedVector2Array([Vector2(x - 10, y0 - bh), Vector2(x + bw * 0.5, y0 - bh - 60), Vector2(x + bw + 10, y0 - bh)]), col.darkened(0.15))
				var wy := y0 - bh + 30
				while wy < y0 - 40:
					var wx := x + 22
					while wx < x + bw - 40:
						_window(c, Rect2(wx, wy, 26, 34), int(wx * 3 + wy * 11), col.darkened(0.3))
						wx += 56
					wy += 70
				# poste telefônico
				if rng.randf() < 0.4:
					c.draw_line(Vector2(x + bw + 20, y0 + 40), Vector2(x + bw + 20, y0 - bh - 40), col.darkened(0.4), 4)
				x += bw + _r(30, 90)


func _paint_main(c: Layer) -> void:
	rng.seed = hash(loc_id + "main")
	var night := _night
	var y0 := GROUND
	var wall_day: Color = Color(loc.get("wall", "6d675d"))
	var wall := wall_day.lerp(wall_day.darkened(0.75), night)
	# fachadas nas portas (cada porta ganha um prédio próprio)
	var doors: Array = []
	for p in loc.get("props", []):
		if p.get("type", "") == "door":
			doors.append(p)
	var covered: Array = []
	for d in doors:
		var dx := float(d.get("x", 0))
		var bw := float(d.get("bw", 360))
		var bh := float(d.get("bh", 300))
		var kind: String = d.get("facade", "house")
		var bx := dx - bw * 0.5
		covered.append([bx, bx + bw])
		var bcol: Color = Color(d.get("color", wall_day.to_html())).lerp(Color("0c0d12"), night * 0.75)
		match kind:
			"store", "diner", "police", "shop":
				c.draw_rect(Rect2(bx, y0 - bh, bw, bh), bcol)
				c.draw_rect(Rect2(bx - 6, y0 - bh - 14, bw + 12, 18), bcol.darkened(0.3))
				# vitrine
				_window(c, Rect2(bx + 20, y0 - 150, dx - bx - 70, 110), int(dx), bcol.darkened(0.4))
				_window(c, Rect2(dx + 50, y0 - 150, bw * 0.5 - 70, 110), int(dx) + 3, bcol.darkened(0.4))
				# letreiro
				var sign_col := Color(d.get("sign_color", "b8453a"))
				var lit: bool = night > 0.3 and not d.get("closed_sign", false)
				if lit and d.get("sign_flicker", false) and fmod(Time.get_ticks_msec() / 130.0, 9.0) < 1.0:
					lit = false
				var sr := Rect2(bx + bw * 0.15, y0 - bh + 22, bw * 0.7, 44)
				c.draw_rect(sr, Color(0.07, 0.07, 0.08))
				c.draw_rect(sr, sign_col if lit else sign_col.darkened(0.55), false, 3)
				if lit:
					c.draw_texture_rect(Art.glow(), sr.grow(50), false, Color(sign_col.r, sign_col.g, sign_col.b, 0.35))
				var font := ThemeDB.fallback_font
				var label: String = d.get("sign", d.get("label", ""))
				c.draw_string(font, sr.position + Vector2(10, 31), label.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 20, 22, (sign_col.lightened(0.4) if lit else Color(0.55, 0.5, 0.45)))
				# toldo
				c.draw_colored_polygon(PackedVector2Array([Vector2(bx + 10, y0 - 170), Vector2(bx + bw - 10, y0 - 170), Vector2(bx + bw + 6, y0 - 145), Vector2(bx - 6, y0 - 145)]), sign_col.darkened(0.5 + night * 0.3))
			"school", "hospital", "church", "station":
				c.draw_rect(Rect2(bx, y0 - bh, bw, bh), bcol)
				if kind == "church":
					c.draw_colored_polygon(PackedVector2Array([Vector2(dx - 70, y0 - bh), Vector2(dx, y0 - bh - 150), Vector2(dx + 70, y0 - bh)]), bcol.darkened(0.2))
					c.draw_line(Vector2(dx, y0 - bh - 150), Vector2(dx, y0 - bh - 200), bcol.darkened(0.3), 4)
					c.draw_line(Vector2(dx - 14, y0 - bh - 185), Vector2(dx + 14, y0 - bh - 185), bcol.darkened(0.3), 4)
				var cols := int(bw / 80.0)
				for row in int((bh - 140) / 90.0):
					for k in cols:
						var wx := bx + 25 + k * 80.0
						if absf(wx + 15 - dx) < 60:
							continue
						_window(c, Rect2(wx, y0 - bh + 30 + row * 90.0, 34, 52), int(wx * 13 + row), bcol.darkened(0.35))
				var font := ThemeDB.fallback_font
				c.draw_string(font, Vector2(bx, y0 - bh + 22), d.get("sign", "").to_upper(), HORIZONTAL_ALIGNMENT_CENTER, bw, 18, Color(0.8, 0.78, 0.7, 0.8 - night * 0.4))
			"gas":
				c.draw_rect(Rect2(bx, y0 - 200, bw * 0.55, 200), bcol)
				_window(c, Rect2(bx + 20, y0 - 150, bw * 0.3, 90), int(dx), bcol.darkened(0.4))
				c.draw_rect(Rect2(bx + bw * 0.55, y0 - 280, bw * 0.45 + 120, 22), Color("2a2c31"))
				for k in 2:
					c.draw_rect(Rect2(bx + bw * 0.62 + k * 110, y0 - 258, 10, 258), Color("2a2c31"))
					c.draw_rect(Rect2(bx + bw * 0.62 + k * 110 + 30, y0 - 90, 34, 90), Color("7a2a26").darkened(night * 0.6))
				if night > 0.3:
					c.draw_texture_rect(Art.glow(), Rect2(bx + bw * 0.5, y0 - 300, 340, 300), false, Color(0.9, 0.95, 1.0, 0.18))
			"haunted":
				var hc := Color("2a2622").lerp(Color("0a0909"), night * 0.6)
				c.draw_rect(Rect2(bx, y0 - bh, bw, bh), hc)
				c.draw_colored_polygon(PackedVector2Array([Vector2(bx - 20, y0 - bh), Vector2(bx + bw * 0.35, y0 - bh - 130), Vector2(bx + bw * 0.6, y0 - bh - 60), Vector2(bx + bw + 20, y0 - bh)]), hc.darkened(0.3))
				c.draw_rect(Rect2(bx + bw * 0.7, y0 - bh - 160, 40, 120), hc.darkened(0.2))
				for k in 3:
					var wr := Rect2(bx + 30 + k * (bw - 90) / 2.0, y0 - bh + 40, 40, 60)
					c.draw_rect(wr.grow(3), hc.darkened(0.4))
					c.draw_rect(wr, Color(0.05, 0.05, 0.06))
					c.draw_line(wr.position, wr.end, Color(0.35, 0.3, 0.25), 3)
					c.draw_line(wr.position + Vector2(wr.size.x, 0), wr.position + Vector2(0, wr.size.y), Color(0.35, 0.3, 0.25), 3)
				if night > 0.5 and fmod(Time.get_ticks_msec() / 1000.0, 11.0) < 0.4:
					c.draw_rect(Rect2(bx + 30 + (bw - 90) / 2.0, y0 - bh + 40, 40, 60), Color(0.6, 0.75, 1.0, 0.5))
			_:
				# casa com varanda
				c.draw_rect(Rect2(bx, y0 - bh, bw, bh), bcol)
				c.draw_colored_polygon(PackedVector2Array([Vector2(bx - 24, y0 - bh), Vector2(dx, y0 - bh - 110), Vector2(bx + bw + 24, y0 - bh)]), bcol.darkened(0.35))
				for k in [-1, 1]:
					_window(c, Rect2(dx + k * bw * 0.28 - 22, y0 - bh + 50, 44, 60), int(dx) + k, bcol.darkened(0.45))
				c.draw_rect(Rect2(bx - 10, y0 - 40, bw + 20, 12), bcol.darkened(0.45))
				for k in 5:
					c.draw_rect(Rect2(bx + k * (bw / 4.0) - 3, y0 - 40, 6, 40), bcol.darkened(0.5))
		# porta
		var door_col: Color = Color(d.get("door_color", "3a2a22")).lerp(Color("080808"), night * 0.6)
		c.draw_rect(Rect2(dx - 34, y0 - 128, 68, 128), door_col.darkened(0.4))
		c.draw_rect(Rect2(dx - 30, y0 - 124, 60, 124), door_col)
		c.draw_circle(Vector2(dx + 20, y0 - 60), 3.5, Color(0.75, 0.65, 0.4))
	# muros/cercas entre prédios
	var fence := Color("2a2a2d").lerp(Color("0c0c0e"), night)
	var x := 0.0
	while x < width:
		var free := true
		for cv in covered:
			if x > cv[0] - 10 and x < cv[1] + 10:
				free = false
				break
		if free:
			match style:
				"forest", "hill", "park":
					if rng.randf() < 0.18:
						var th := _r(260, 420)
						c.draw_rect(Rect2(x, y0 - th * 0.35, 16, th * 0.35), Color("1a1512").lerp(Color("070606"), night))
						c.draw_circle(Vector2(x + 8, y0 - th * 0.5), _r(60, 110), Color("1d261c").lerp(Color("060807"), night))
				_:
					c.draw_rect(Rect2(x, y0 - 70, 22, 70), fence)
					c.draw_line(Vector2(x, y0 - 50), Vector2(x + 22, y0 - 50), fence.lightened(0.1), 3)
		x += 22.0


func _paint_ground(c: Layer) -> void:
	var night := _night
	var y0 := GROUND
	var top_col := Color(loc.get("ground", "4a4844"))
	if interior:
		top_col = Color(loc.get("floor", "3b2c22"))
	top_col = top_col.lerp(top_col.darkened(0.7), night)
	c.draw_rect(Rect2(-400, y0, width + 800, 220), top_col)
	if interior:
		# assoalho em tábuas
		var x := -400.0
		while x < width + 400:
			c.draw_line(Vector2(x, y0), Vector2(x - 30, y0 + 220), top_col.darkened(0.25), 2)
			x += 64.0
		c.draw_rect(Rect2(-400, y0, width + 800, 6), top_col.darkened(0.5))
		return
	match style:
		"forest", "hill":
			c.draw_rect(Rect2(-400, y0, width + 800, 10), top_col.lightened(0.08))
			rng.seed = hash(loc_id + "g")
			for i in int(width / 18.0):
				var gx := _r(-200, width + 200)
				c.draw_line(Vector2(gx, y0 + 2), Vector2(gx + _r(-4, 4), y0 - _r(6, 18)), Color("26301f").lerp(Color("0a0d08"), night), 2)
		_:
			# calçada, meio-fio e rua com reflexos
			c.draw_rect(Rect2(-400, y0, width + 800, 42), top_col.lightened(0.12))
			var x := -400.0
			while x < width + 400:
				c.draw_line(Vector2(x, y0), Vector2(x, y0 + 42), top_col.darkened(0.2), 1.5)
				x += 90.0
			c.draw_rect(Rect2(-400, y0 + 42, width + 800, 8), top_col.darkened(0.35))
			var road := Color("26272b").lerp(Color("0b0c0f"), night)
			c.draw_rect(Rect2(-400, y0 + 50, width + 800, 180), road)
			x = -400.0
			while x < width + 400:
				c.draw_rect(Rect2(x, y0 + 128, 70, 6), Color(0.75, 0.7, 0.55, 0.35))
				x += 160.0
			if loc.get("wet", false) or Sfx.context.get("rain", false):
				c.draw_rect(Rect2(-400, y0 + 50, width + 800, 180), Color(0.5, 0.6, 0.8, 0.06))


# --------------------------------------------------------------- interiores
func _paint_interior(c: Layer) -> void:
	var night := _night
	var y0 := GROUND
	var wall := Color(loc.get("wall", "4b4038"))
	var lightness: float = loc.get("lightness", 0.6)
	wall = wall.lerp(Color("070707"), (1.0 - lightness) * 0.6 + night * 0.25)
	c.draw_rect(Rect2(-400, 0, width + 800, y0), wall)
	# papel de parede listrado / azulejo conforme o tema
	var theme: String = loc.get("theme", "home")
	var x := -400.0
	match theme:
		"hospital", "lab", "basement":
			while x < width + 400:
				c.draw_line(Vector2(x, 120), Vector2(x, y0), wall.darkened(0.12), 1)
				x += 48.0
			var yy := 120.0
			while yy < y0:
				c.draw_line(Vector2(-400, yy), Vector2(width + 400, yy), wall.darkened(0.12), 1)
				yy += 48.0
		_:
			while x < width + 400:
				c.draw_rect(Rect2(x, 0, 18, y0), wall.darkened(0.07))
				x += 54.0
	# rodapé / lambri
	c.draw_rect(Rect2(-400, y0 - 150, width + 800, 150), wall.darkened(0.35))
	c.draw_rect(Rect2(-400, y0 - 154, width + 800, 6), wall.darkened(0.55))
	# teto
	c.draw_rect(Rect2(-400, 0, width + 800, 70), wall.darkened(0.6))
	# janelas para fora
	for wx in loc.get("windows", []):
		var r := Rect2(float(wx) - 50, y0 - 380, 100, 150)
		c.draw_rect(r.grow(8), wall.darkened(0.5))
		var outside := Color("7c8796").lerp(Color("0b0e18"), night)
		c.draw_rect(r, outside)
		if night > 0.6 and int(wx) % 3 == 0:
			c.draw_circle(r.position + Vector2(70, 30), 8, Color(0.8, 0.8, 0.75, 0.6))
		c.draw_line(r.position + Vector2(50, 0), r.position + Vector2(50, 150), wall.darkened(0.5), 4)
		# cortinas
		c.draw_rect(Rect2(r.position + Vector2(-16, -10), Vector2(22, 170)), Color(loc.get("curtain", "5a2a28")).darkened(0.3 + night * 0.3))
		c.draw_rect(Rect2(r.position + Vector2(94, -10), Vector2(22, 170)), Color(loc.get("curtain", "5a2a28")).darkened(0.3 + night * 0.3))
	# mobília
	for d in loc.get("deco", []):
		_deco(c, d.get("k", ""), float(d.get("x", 0)), wall)
	# portas internas
	for p in loc.get("props", []):
		if p.get("type", "") in ["door", "exit"] and p.has("x"):
			var dx := float(p["x"])
			c.draw_rect(Rect2(dx - 40, y0 - 210, 80, 210), wall.darkened(0.6))
			c.draw_rect(Rect2(dx - 34, y0 - 204, 68, 204), Color(p.get("door_color", "3a2a22")).darkened(0.2 + night * 0.4))
			c.draw_circle(Vector2(dx + 22, y0 - 100), 4, Color(0.7, 0.6, 0.35))


func _deco(c: CanvasItem, k: String, x: float, wall: Color) -> void:
	var y0 := GROUND
	var wood := Color("4a3224").darkened(_night * 0.5)
	var metal := Color("5b6068").darkened(_night * 0.5)
	var dark := Color(0.06, 0.06, 0.07)
	match k:
		"bed":
			c.draw_rect(Rect2(x - 110, y0 - 70, 220, 50), Color("6a6f78").darkened(_night * 0.5))
			c.draw_rect(Rect2(x - 120, y0 - 130, 18, 130), wood)
			c.draw_rect(Rect2(x - 104, y0 - 86, 60, 22), Color("c9c4b8").darkened(_night * 0.5))
		"shelf":
			c.draw_rect(Rect2(x - 70, y0 - 300, 140, 300), wood)
			for i in 4:
				c.draw_rect(Rect2(x - 64, y0 - 290 + i * 72, 128, 60), dark)
				for b in 6:
					c.draw_rect(Rect2(x - 60 + b * 20, y0 - 280 + i * 72, 14, 50), Color.from_hsv(fmod(b * 0.17 + i * 0.3, 1.0), 0.35, 0.35 - _night * 0.15))
		"table":
			c.draw_rect(Rect2(x - 90, y0 - 100, 180, 14), wood)
			c.draw_rect(Rect2(x - 80, y0 - 86, 10, 86), wood.darkened(0.3))
			c.draw_rect(Rect2(x + 70, y0 - 86, 10, 86), wood.darkened(0.3))
		"counter":
			c.draw_rect(Rect2(x - 220, y0 - 120, 440, 120), Color("7a2f2a").darkened(0.2 + _night * 0.4))
			c.draw_rect(Rect2(x - 228, y0 - 128, 456, 14), Color("b9b2a3").darkened(_night * 0.5))
			for i in 5:
				c.draw_rect(Rect2(x - 200 + i * 95, y0 - 60, 30, 60), metal)
				c.draw_circle(Vector2(x - 185 + i * 95, y0 - 64), 22, Color("8a2b2b").darkened(_night * 0.4))
		"booth":
			c.draw_rect(Rect2(x - 100, y0 - 140, 30, 140), Color("8a2b2b").darkened(_night * 0.4))
			c.draw_rect(Rect2(x + 70, y0 - 140, 30, 140), Color("8a2b2b").darkened(_night * 0.4))
			c.draw_rect(Rect2(x - 60, y0 - 96, 120, 12), Color("b9b2a3").darkened(_night * 0.5))
		"locker":
			for i in 4:
				c.draw_rect(Rect2(x - 100 + i * 50, y0 - 230, 46, 230), metal.darkened(0.1 * (i % 2)))
				for s in 4:
					c.draw_line(Vector2(x - 92 + i * 50, y0 - 210 + s * 7), Vector2(x - 66 + i * 50, y0 - 210 + s * 7), dark, 2)
		"hospital_bed":
			c.draw_rect(Rect2(x - 100, y0 - 80, 200, 26), Color("c9ccd1").darkened(_night * 0.5))
			c.draw_rect(Rect2(x - 100, y0 - 54, 200, 8), metal)
			c.draw_line(Vector2(x - 95, y0 - 46), Vector2(x - 95, y0), metal, 4)
			c.draw_line(Vector2(x + 95, y0 - 46), Vector2(x + 95, y0), metal, 4)
			c.draw_line(Vector2(x + 120, y0), Vector2(x + 120, y0 - 190), metal, 3)
			c.draw_rect(Rect2(x + 108, y0 - 190, 24, 34), Color(0.7, 0.8, 0.85, 0.5))
		"radio_rack":
			c.draw_rect(Rect2(x - 80, y0 - 260, 160, 260), Color("2b2d30"))
			for i in 6:
				c.draw_rect(Rect2(x - 70, y0 - 250 + i * 42, 140, 34), Color("3a3d42"))
				for j in 4:
					var on := fmod(Time.get_ticks_msec() / 500.0 + i + j, 3.0) < 1.5
					c.draw_circle(Vector2(x - 55 + j * 18, y0 - 232 + i * 42), 3, Color(0.9, 0.3, 0.2) if on else Color(0.25, 0.1, 0.08))
				c.draw_rect(Rect2(x + 10, y0 - 244 + i * 42, 50, 20), Color(0.15, 0.25, 0.2))
		"pews":
			for i in 3:
				c.draw_rect(Rect2(x - 160 + i * 120, y0 - 90, 100, 18), wood)
				c.draw_rect(Rect2(x - 160 + i * 120, y0 - 150, 12, 150), wood.darkened(0.2))
		"altar":
			c.draw_rect(Rect2(x - 90, y0 - 110, 180, 110), Color("d8d1c2").darkened(0.3 + _night * 0.4))
			for cx in [-60, 60]:
				c.draw_rect(Rect2(x + cx - 4, y0 - 150, 8, 40), Color(0.9, 0.88, 0.8))
				if _night > 0.2:
					c.draw_texture_rect(Art.glow(), Rect2(x + cx - 30, y0 - 180, 60, 60), false, Color(1, 0.7, 0.3, 0.6))
		"machine":
			c.draw_rect(Rect2(x - 120, y0 - 260, 240, 260), Color("34373a"))
			c.draw_circle(Vector2(x - 50, y0 - 170), 40, Color("1f2124"))
			c.draw_circle(Vector2(x - 50, y0 - 170), 30, Color("4a4d52"))
			c.draw_rect(Rect2(x + 10, y0 - 220, 90, 60), Color(0.1, 0.25, 0.18))
			c.draw_line(Vector2(x + 20, y0 - 190), Vector2(x + 90, y0 - 190 + sin(Time.get_ticks_msec() / 200.0) * 15), Color(0.4, 1.0, 0.6), 2)
		"tv":
			c.draw_rect(Rect2(x - 60, y0 - 160, 120, 90), Color("1c1c1e"))
			var flick := 0.3 + 0.3 * sin(Time.get_ticks_msec() / 37.0)
			c.draw_rect(Rect2(x - 50, y0 - 152, 100, 74), Color(0.5, 0.55, 0.6, flick))
			c.draw_rect(Rect2(x - 40, y0 - 70, 80, 70), wood)
		"mirror":
			c.draw_rect(Rect2(x - 46, y0 - 330, 92, 200), Color("8a7a5a").darkened(_night * 0.5))
			c.draw_rect(Rect2(x - 40, y0 - 324, 80, 188), Color(0.55, 0.62, 0.7, 0.8).darkened(_night * 0.6))
		"frame":
			c.draw_rect(Rect2(x - 36, y0 - 360, 72, 90), Color("6b5636"))
			c.draw_rect(Rect2(x - 30, y0 - 354, 60, 78), Color("2a2420"))
			c.draw_circle(Vector2(x, y0 - 326), 14, Color("7d6c5e").darkened(0.3))
		"boxes":
			for i in 3:
				c.draw_rect(Rect2(x - 70 + i * 46, y0 - 50 - (i % 2) * 44, 44, 44), Color("6b5236").darkened(0.2 * i + _night * 0.4))
		"stairs":
			for i in 8:
				c.draw_rect(Rect2(x - 120 + i * 30, y0 - 20 - i * 30, 260 - i * 30, 20), wood.darkened(0.1 * (i % 2)))
		"plant":
			c.draw_rect(Rect2(x - 18, y0 - 46, 36, 46), Color("6b3b2a"))
			for i in 7:
				c.draw_line(Vector2(x, y0 - 46), Vector2(x + (i - 3) * 14, y0 - 110 - (i % 3) * 18), Color("2f4a2a").darkened(_night * 0.5), 5)
		"fridge":
			c.draw_rect(Rect2(x - 45, y0 - 230, 90, 230), Color("c9c5bb").darkened(_night * 0.5))
			c.draw_line(Vector2(x - 45, y0 - 150), Vector2(x + 45, y0 - 150), dark, 2)
		"desk":
			c.draw_rect(Rect2(x - 100, y0 - 110, 200, 16), wood)
			c.draw_rect(Rect2(x - 100, y0 - 94, 70, 94), wood.darkened(0.3))
			c.draw_rect(Rect2(x + 20, y0 - 170, 70, 56), Color("2a2c30"))
			c.draw_rect(Rect2(x + 26, y0 - 164, 58, 42), Color(0.3, 0.5, 0.45, 0.7) if _night < 0.9 else Color(0.2, 0.35, 0.3))
		"cell":
			for i in 10:
				c.draw_line(Vector2(x - 120 + i * 26, y0 - 260), Vector2(x - 120 + i * 26, y0), metal, 5)
			c.draw_line(Vector2(x - 125, y0 - 260), Vector2(x + 125, y0 - 260), metal, 8)
		"board":
			c.draw_rect(Rect2(x - 110, y0 - 360, 220, 140), Color("7a5a3a"))
			for i in 7:
				c.draw_rect(Rect2(x - 100 + (i % 4) * 52, y0 - 350 + (i / 4) * 64, 40, 50), Color(0.85, 0.82, 0.7).darkened(0.1 * (i % 3)))
			c.draw_line(Vector2(x - 80, y0 - 330), Vector2(x + 60, y0 - 270), Color(0.7, 0.1, 0.1), 2)
