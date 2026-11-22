extends Node
## Carregamento de arte com cache. Sprites MUGEN processados pelo pipeline ficam em
## res://art/characters/<id>/<anim>/<n>.png + manifest.json. Cenários pintados em
## res://art/stages/<location>/<layer>.png. Quando a arte de um personagem ainda não
## foi produzida, o jogo usa a silhueta provisória do Actor e registra no relatório
## de auditoria (Art.missing_report()).

var _frames_cache: Dictionary = {}
var _tex_cache: Dictionary = {}
var _missing: Dictionary = {}

const ANIM_FALLBACK := {
	"run": ["walk"], "crouch": ["idle"], "hide": ["crouch", "idle"], "inspect": ["idle"],
	"fear": ["idle"], "hurt": ["fear", "idle"], "talk": ["idle"], "flashlight": ["idle"],
	"turn": ["idle"], "chase": ["run", "walk"], "attack": ["chase", "run", "walk"], "walk": ["idle"]
}


func manifest(id: String) -> Dictionary:
	var path := "res://art/characters/%s/manifest.json" % id
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


## SpriteFrames prontos para AnimatedSprite2D, ou null se não houver arte.
func frames_for(id: String) -> SpriteFrames:
	if _frames_cache.has(id):
		return _frames_cache[id]
	var m := manifest(id)
	var anims: Dictionary = m.get("anims", {})
	if anims.is_empty():
		_missing[id] = true
		_frames_cache[id] = null
		return null
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in anims:
		var info: Dictionary = anims[a]
		sf.add_animation(a)
		sf.set_animation_speed(a, float(info.get("fps", 10)))
		sf.set_animation_loop(a, bool(info.get("loop", true)))
		for i in int(info.get("frames", 0)):
			var p := "res://art/characters/%s/%s/%d.png" % [id, a, i]
			if ResourceLoader.exists(p):
				sf.add_frame(a, load(p))
	# garante que toda animação usada pelo jogo exista (aponta para a mais próxima)
	for want in ["idle", "walk", "run", "crouch", "hide", "inspect", "fear", "hurt", "talk", "flashlight", "turn", "chase", "attack"]:
		if sf.has_animation(want):
			continue
		var src := ""
		for alt in ANIM_FALLBACK.get(want, []):
			if sf.has_animation(alt):
				src = alt
				break
		if src == "":
			src = sf.get_animation_names()[0]
		sf.add_animation(want)
		sf.set_animation_speed(want, sf.get_animation_speed(src))
		sf.set_animation_loop(want, sf.get_animation_loop(src))
		for i in sf.get_frame_count(src):
			sf.add_frame(want, sf.get_frame_texture(src, i))
	_frames_cache[id] = sf
	return sf


func portrait(id: String, expr: String = "neutral") -> Texture2D:
	for e in [expr, "neutral"]:
		var p := "res://art/characters/%s/portrait_%s.png" % [id, e]
		if ResourceLoader.exists(p):
			return _tex(p)
	return null


func stage_layer(loc: String, layer: String) -> Texture2D:
	var p := "res://art/stages/%s/%s.png" % [loc, layer]
	if ResourceLoader.exists(p):
		return _tex(p)
	return null


func _tex(p: String) -> Texture2D:
	if not _tex_cache.has(p):
		_tex_cache[p] = load(p)
	return _tex_cache[p]


## Libera texturas que não estão em uso ao trocar de local (controle de memória).
func trim(keep_ids: Array) -> void:
	for id in _frames_cache.keys():
		if not id in keep_ids:
			_frames_cache.erase(id)
	_tex_cache.clear()


func missing_report() -> Array:
	return _missing.keys()


## Textura de brilho radial reutilizável (lâmpadas, lanterna, olhos).
var _glow: Texture2D
func glow() -> Texture2D:
	if _glow == null:
		var g := GradientTexture2D.new()
		g.width = 128
		g.height = 128
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(0, 0, 0, 0))
		gr.add_point(0.35, Color(0.5, 0.5, 0.5, 0.5))
		g.gradient = gr
		_glow = g
	return _glow
