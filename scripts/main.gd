extends Node
## Raiz do jogo: alterna entre menu principal, seleção de personagem e o mundo.

var current: Node


func _ready() -> void:
	get_tree().set_auto_accept_quit(true)
	RenderingServer.set_default_clear_color(Color(0.02, 0.02, 0.03))
	if not Data.errors.is_empty():
		push_error("Erros de dados: %s" % str(Data.errors))
	show_title()


func _swap(n: Node) -> void:
	if current:
		current.queue_free()
		await get_tree().process_frame
	get_tree().paused = false
	current = n
	add_child(n)


func show_title() -> void:
	Clock.running = false
	Game.active = false
	Sfx.set_context("interior", false)
	Sfx.set_context("night", true)
	Sfx.set_context("chase", 0.0)
	Sfx.set_context("tension", 0.2)
	Sfx.set_context("static", 0.12)
	Sfx.set_context("rain", true)
	Sfx.set_context("outdoor_city", false)
	var t := preload("res://scripts/ui/title.gd").new()
	t.new_game.connect(show_select)
	t.continue_game.connect(_continue)
	t.chapter_selected.connect(_start_chapter)
	await _swap(t)


func show_select() -> void:
	var s := preload("res://scripts/ui/char_select.gd").new()
	s.chosen.connect(func(id): _start(id, 1))
	s.back.connect(show_title)
	await _swap(s)


func _start_chapter(char_id: String, n: int) -> void:
	_start(char_id, n)


func _start(char_id: String, chapter: int) -> void:
	Game.new_game(char_id, chapter)
	var w := World.new()
	w.request_title.connect(show_title)
	await _swap(w)
	Sfx.set_context("static", 0.0)
	await w.start(true)


func _continue() -> void:
	var slot := Game.latest_slot()
	if slot < 0 or not Game.load_slot(slot):
		return
	var w := World.new()
	w.request_title.connect(show_title)
	await _swap(w)
	Sfx.set_context("static", 0.0)
	await w.start(false)
