extends Node2D
class_name Prop
## Objeto interativo ou decorativo do cenário: porta, saída, pista, esconderijo,
## poste de luz, espelho, ponto de salvamento, gatilho de evento.

var data: Dictionary = {}
var type: String = ""
var light: PointLight2D
var _t: float = 0.0
var _flicker: float = 0.0
var world: Node
var used: bool = false


func setup(d: Dictionary, w: Node) -> void:
	data = d
	world = w
	type = d.get("type", "")
	position = Vector2(float(d.get("x", 0)), Backdrop.GROUND)
	if type == "lamp":
		light = PointLight2D.new()
		light.texture = Art.glow()
		light.texture_scale = float(d.get("radius", 5.5))
		light.color = Color(d.get("color", "ffcf8a"))
		light.energy = 0.0
		light.position = Vector2(0, -300)
		add_child(light)
	elif type == "light":
		light = PointLight2D.new()
		light.texture = Art.glow()
		light.texture_scale = float(d.get("radius", 7.0))
		light.color = Color(d.get("color", "e8d9b8"))
		light.energy = float(d.get("energy", 0.9))
		light.position = Vector2(0, -float(d.get("h", 380)))
		add_child(light)
	queue_redraw()


func label() -> String:
	return data.get("label", "")


func flicker(t: float) -> void:
	_flicker = maxf(_flicker, t)


func _process(delta: float) -> void:
	_t += delta
	if type == "lamp":
		var on: bool = Clock.darkness() > 0.35 and not data.get("broken", false)
		var e := 1.2 if on else 0.0
		if on and (data.get("flicker", false) or _flicker > 0.0):
			if fmod(_t * 13.0 + position.x, 7.0) < (2.5 if _flicker > 0.0 else 0.6):
				e = 0.15
		light.energy = lerpf(light.energy, e, minf(1.0, delta * 20.0))
		_flicker = maxf(0.0, _flicker - delta)
	if type == "clue" and _near():
		queue_redraw()


func _near() -> bool:
	return world and world.player and absf(world.player.position.x - position.x) < 160.0


func _draw() -> void:
	var night := Clock.darkness()
	match type:
		"lamp":
			var c := Color("23252a").lerp(Color("0b0c0f"), night)
			draw_rect(Rect2(-4, -300, 8, 300), c)
			draw_line(Vector2(0, -300), Vector2(26, -312), c, 5)
			draw_rect(Rect2(18, -316, 26, 10), c)
			if night > 0.35 and not data.get("broken", false):
				draw_circle(Vector2(31, -305), 5, Color(1, 0.9, 0.7))
		"hide":
			_draw_hide(night)
		"clue":
			if Game.check(data.get("req", {})) and not (data.has("give") and data["give"] in Game.evidence and data.get("once", true)):
				if data.get("vision_only", false) and world.vision_time <= 0.0:
					return
				var a := 0.35 + 0.35 * sin(_t * 4.0)
				var y := -float(data.get("y", 60))
				draw_texture_rect(Art.glow(), Rect2(-16, y - 16, 32, 32), false, Color(0.9, 0.85, 0.6, a * (1.0 if _near() else 0.4)))
				draw_circle(Vector2(0, y), 2.5, Color(1, 0.95, 0.8, a + 0.3))
		"save":
			var y := -float(data.get("y", 120))
			draw_texture_rect(Art.glow(), Rect2(-20, y - 20, 40, 40), false, Color(0.5, 0.75, 1.0, 0.25 + 0.15 * sin(_t * 2.0)))
		"car":
			var c := Color(data.get("color", "3a4148")).lerp(Color("0b0c0f"), night * 0.7)
			draw_rect(Rect2(-120, -70, 240, 50), c)
			draw_colored_polygon(PackedVector2Array([Vector2(-70, -70), Vector2(-40, -112), Vector2(50, -112), Vector2(80, -70)]), c.darkened(0.1))
			draw_rect(Rect2(-35, -106, 40, 32), Color(0.2, 0.25, 0.3, 0.8))
			draw_rect(Rect2(12, -106, 34, 32), Color(0.2, 0.25, 0.3, 0.8))
			draw_circle(Vector2(-75, -20), 22, Color(0.05, 0.05, 0.05))
			draw_circle(Vector2(75, -20), 22, Color(0.05, 0.05, 0.05))
		"bench":
			var c := Color("4a3a2c").darkened(night * 0.6)
			draw_rect(Rect2(-70, -46, 140, 10), c)
			draw_rect(Rect2(-70, -80, 140, 8), c)
			draw_rect(Rect2(-62, -36, 8, 36), c.darkened(0.3))
			draw_rect(Rect2(54, -36, 8, 36), c.darkened(0.3))
		"swing":
			var c := Color("3a3d42").darkened(night * 0.6)
			draw_line(Vector2(-90, 0), Vector2(-60, -230), c, 6)
			draw_line(Vector2(90, 0), Vector2(60, -230), c, 6)
			draw_line(Vector2(-64, -230), Vector2(64, -230), c, 6)
			var sw := sin(_t * 1.3) * (14.0 if night > 0.6 else 2.0)
			for k in [-30, 30]:
				draw_line(Vector2(k, -230), Vector2(k + sw, -70), c, 2)
				draw_rect(Rect2(k + sw - 16, -72, 32, 6), Color("5a3a2a").darkened(night * 0.5))
			queue_redraw()
		"phone":
			var c := Color("6d1f1f").darkened(night * 0.5)
			draw_rect(Rect2(-30, -230, 60, 230), c)
			draw_rect(Rect2(-24, -220, 48, 120), Color(0.15, 0.17, 0.2))
			draw_rect(Rect2(-14, -170, 28, 50), Color("2b2b2b"))
		"sign":
			var c := Color("2a2c31").darkened(night * 0.5)
			draw_rect(Rect2(-4, -220, 8, 220), c)
			draw_rect(Rect2(-90, -260, 180, 54), Color("31503a").darkened(night * 0.5))
			draw_string(ThemeDB.fallback_font, Vector2(-86, -226), data.get("text", ""), HORIZONTAL_ALIGNMENT_CENTER, 172, 16, Color(0.9, 0.9, 0.85, 0.9 - night * 0.4))
		"relay":
			var on: bool = Game.flags.get(data.get("flag", ""), false)
			draw_rect(Rect2(-40, -160, 80, 160), Color("2b2d30"))
			draw_rect(Rect2(-30, -150, 60, 40), Color(0.1, 0.12, 0.1))
			draw_circle(Vector2(0, -60), 14, Color(0.2, 1.0, 0.4) if on else Color(0.9, 0.15, 0.1))


func _draw_hide(night: float) -> void:
	var k: String = data.get("look", "locker")
	var c := Color(data.get("color", "3d4148")).lerp(Color("08090b"), night * 0.6)
	match k:
		"bush":
			for i in 5:
				draw_circle(Vector2(-60 + i * 30, -50 - (i % 2) * 20), 46, Color("1f2a1c").lerp(Color("070906"), night).lightened(0.03 * i))
		"dumpster":
			draw_rect(Rect2(-90, -110, 180, 110), Color("2d4a3a").lerp(Color("07100b"), night))
			draw_rect(Rect2(-96, -118, 192, 12), Color("223a2d").lerp(Color("050a07"), night))
		"wardrobe":
			draw_rect(Rect2(-60, -280, 120, 280), Color("4a3224").lerp(Color("100a07"), night * 0.6))
			draw_line(Vector2(0, -270), Vector2(0, -10), Color(0.1, 0.07, 0.05), 3)
			draw_circle(Vector2(-8, -150), 3, Color(0.7, 0.6, 0.4))
			draw_circle(Vector2(8, -150), 3, Color(0.7, 0.6, 0.4))
		"curtain":
			for i in 6:
				draw_rect(Rect2(-75 + i * 25, -300, 24, 300), Color("5a2228").lerp(Color("12070a"), night * 0.6).darkened(0.1 * (i % 2)))
		"desk":
			draw_rect(Rect2(-90, -100, 180, 16), Color("4a3224").darkened(night * 0.5))
			draw_rect(Rect2(-90, -84, 20, 84), Color("3a281c").darkened(night * 0.5))
			draw_rect(Rect2(70, -84, 20, 84), Color("3a281c").darkened(night * 0.5))
			draw_rect(Rect2(-70, -84, 140, 60), Color(0, 0, 0, 0.6))
		_:
			draw_rect(Rect2(-40, -250, 80, 250), c)
			for s in 5:
				draw_line(Vector2(-25, -220 + s * 8), Vector2(25, -220 + s * 8), c.darkened(0.5), 2)
