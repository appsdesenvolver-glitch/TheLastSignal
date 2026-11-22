extends Node
## Carrega todo o conteúdo do jogo a partir de res://data/*.json.
## Conteúdo (história, NPCs, mapa, missões, cutscenes) fica em dados para que
## os sistemas sejam genéricos e testáveis.

var characters: Dictionary = {}
var npcs: Dictionary = {}
var locations: Dictionary = {}
var missions: Dictionary = {}
var dialogues: Dictionary = {}
var cutscenes: Dictionary = {}
var evidence: Dictionary = {}
var deductions: Array = []
var endings: Array = []
var chapters: Array = []
var creatures: Dictionary = {}
var radio: Array = []
var errors: Array = []


func _ready() -> void:
	reload()


func reload() -> void:
	errors.clear()
	characters = _load("characters")
	npcs = _load("npcs")
	locations = _load("locations")
	missions = _load("missions")
	dialogues = _load("dialogues")
	cutscenes = _load("cutscenes")
	creatures = _load("creatures")
	var ev := _load("evidence")
	evidence = ev.get("items", {})
	deductions = ev.get("deductions", [])
	var st := _load("story")
	endings = st.get("endings", [])
	chapters = st.get("chapters", [])
	radio = st.get("radio", [])
	for e in errors:
		push_error(e)


func _load(name: String) -> Dictionary:
	var path := "res://data/%s.json" % name
	if not FileAccess.file_exists(path):
		errors.append("Arquivo de dados ausente: " + path)
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(txt) != OK:
		errors.append("JSON inválido em %s linha %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not (json.data is Dictionary):
		errors.append("Raiz de %s precisa ser um objeto" % path)
		return {}
	return json.data


func char_name(id: String) -> String:
	if id == "player":
		id = Game.character
	if characters.has(id):
		return characters[id].get("short", characters[id].get("name", id))
	if npcs.has(id):
		return npcs[id].get("name", id)
	if creatures.has(id):
		return creatures[id].get("name", id)
	return id


func chapter_info(n: int) -> Dictionary:
	for c in chapters:
		if int(c.get("n", 0)) == n:
			return c
	return {}
