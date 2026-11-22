extends CanvasLayer
class_name ScreenFX
## Atmosfera em tela: chuva, névoa, granulação de filme, vinheta de medo,
## relâmpagos, flashes, tremor, barras de cinema e transições em fade.

const OVERLAY_SHADER := """
shader_type canvas_item;
uniform float grain = 0.06;
uniform float vignette = 0.45;
uniform float fear = 0.0;
uniform float glitch = 0.0;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float d = distance(uv, vec2(0.5));
	float v = smoothstep(0.35, 0.95, d) * (vignette + fear * 0.45);
	float n = (h(uv * 731.0 + fract(TIME * 7.13)) - 0.5) * grain;
	float line = glitch * step(0.985, h(vec2(floor(uv.y * 90.0), floor(TIME * 18.0)))) * 0.35;
	vec3 red = vec3(0.25, 0.0, 0.02) * fear * smoothstep(0.3, 0.9, d) * (0.7 + 0.3 * sin(TIME * 7.0));
	COLOR = vec4(red + vec3(n + line), clamp(v + abs(n) + line + length(red), 0.0, 1.0));
}
"""

const FOG_SHADER := """
shader_type canvas_item;
uniform float density = 0.3;
uniform vec4 tint : source_color = vec4(0.55, 0.6, 0.68, 1.0);
uniform float offset = 0.0;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1.0,0.0)), f.x), mix(h(i+vec2(0.0,1.0)), h(i+vec2(1.0,1.0)), f.x), f.y); }
void fragment() {
	vec2 uv = UV * vec2(3.0, 1.2) + vec2(TIME * 0.015 + offset, 0.0);
	float n = noise(uv) * 0.6 + noise(uv * 2.7 + vec2(TIME * 0.03, 3.1)) * 0.4;
	float band = smoothstep(0.35, 0.95, UV.y);
	COLOR = vec4(tint.rgb, n * density * band);
}
"""

var fade_rect: ColorRect
var flash_rect: ColorRect
var overlay: ColorRect
var overlay_mat: ShaderMaterial
var fog_rect: ColorRect
var fog_mat: ShaderMaterial
var rain: CPUParticles2D
var bar_top: ColorRect
var bar_bot: ColorRect
var fear_level: float = 0.0
var _lightning_t: float = 8.0
var raining: bool = false
var camera: Camera2D
var _shake: float = 0.0


func _ready() -> void:
	layer = 20
	var fog_layer := CanvasLayer.new()
	fog_layer.layer = 5
	add_child(fog_layer)
	fog_rect = ColorRect.new()
	fog_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_mat = _mat(FOG_SHADER)
	fog_rect.material = fog_mat
	fog_layer.add_child(fog_rect)
	rain = CPUParticles2D.new()
	rain.amount = 260
	rain.lifetime = 0.9
	rain.preprocess = 1.0
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(900, 10)
	rain.position = Vector2(640, -40)
	rain.direction = Vector2(-0.18, 1)
	rain.spread = 2.0
	rain.gravity = Vector2(0, 0)
	rain.initial_velocity_min = 900
	rain.initial_velocity_max = 1150
	rain.scale_amount_min = 1.0
	rain.scale_amount_max = 1.0
	var img := Image.create(2, 22, false, Image.FORMAT_RGBA8)
	for y in 22:
		img.set_pixel(0, y, Color(0.75, 0.8, 0.9, float(y) / 22.0 * 0.5))
		img.set_pixel(1, y, Color(0.75, 0.8, 0.9, float(y) / 22.0 * 0.3))
	rain.texture = ImageTexture.create_from_image(img)
	rain.emitting = false
	fog_layer.add_child(rain)
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_mat = _mat(OVERLAY_SHADER)
	overlay.material = overlay_mat
	add_child(overlay)
	bar_top = _bar(true)
	bar_bot = _bar(false)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	set_fog(0.2)
	overlay_mat.set_shader_parameter("grain", 0.06 if Game.settings.get("grain", true) else 0.0)


func _mat(code: String) -> ShaderMaterial:
	var s := Shader.new()
	s.code = code
	var m := ShaderMaterial.new()
	m.shader = s
	return m


func _bar(top: bool) -> ColorRect:
	var b := ColorRect.new()
	b.color = Color(0, 0, 0, 1)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.anchor_right = 1.0
	if top:
		b.anchor_bottom = 0.0
		b.offset_bottom = 0.0
	else:
		b.anchor_top = 1.0
		b.anchor_bottom = 1.0
		b.offset_top = 0.0
	add_child(b)
	return b


func _process(delta: float) -> void:
	overlay_mat.set_shader_parameter("fear", fear_level)
	if raining and Clock.darkness() > 0.5:
		_lightning_t -= delta
		if _lightning_t <= 0.0:
			_lightning_t = randf_range(9.0, 24.0)
			lightning()
	if camera and _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 18.0)
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	elif camera:
		camera.offset = Vector2.ZERO


func set_rain(on: bool) -> void:
	raining = on
	rain.emitting = on
	Sfx.set_context("rain", on)


func set_fog(d: float) -> void:
	fog_mat.set_shader_parameter("density", d)


func set_glitch(v: float) -> void:
	overlay_mat.set_shader_parameter("glitch", v)


func lightning() -> void:
	var tw := create_tween()
	flash_rect.color = Color(0.85, 0.9, 1.0, 0.0)
	tw.tween_property(flash_rect, "color:a", 0.55, 0.05)
	tw.tween_property(flash_rect, "color:a", 0.0, 0.08)
	tw.tween_property(flash_rect, "color:a", 0.35, 0.05)
	tw.tween_property(flash_rect, "color:a", 0.0, 0.4)
	get_tree().create_timer(randf_range(0.6, 1.8)).timeout.connect(func(): Sfx.play("thunder", 0.8))


func flash(col: Color, t: float) -> void:
	flash_rect.color = Color(col.r, col.g, col.b, 0.9)
	create_tween().tween_property(flash_rect, "color:a", 0.0, t)


func shake(amount: float) -> void:
	if Game.settings.get("shake", true):
		_shake = maxf(_shake, amount)


func fade(to_alpha: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", to_alpha, t)
	await tw.finished


func letterbox(on: bool, t: float = 0.6) -> void:
	var h := 82.0 if on else 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(bar_top, "offset_bottom", h, t).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bar_bot, "offset_top", -h, t).set_trans(Tween.TRANS_SINE)
