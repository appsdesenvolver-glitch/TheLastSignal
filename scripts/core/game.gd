extends Node
## Estado global da campanha: personagem, capítulo, flags, evidências, confiança,
## marcações de espíritos, missões, finais. Também: condições/efeitos usados por
## todo o conteúdo em JSON, salvamento seguro e mapa de controles.

signal notify(text: String, kind: String)
signal evidence_added(id: String)
signal mission_updated(id: String)
signal chapter_changed(n: int)
signal health_changed(v: float)
signal state_changed

const SAVE_VERSION := 2
const SLOTS := 4             # 0 = automático, 1..3 = manuais
const META_PATH := "user://meta.json"

var character: String = "elias"
var chapter: int = 1
var flags: Dictionary = {}
var evidence: Array = []
var deductions: Array = []
var trust: Dictionary = {}
var marks: Dictionary = {}       # npc_id -> "spirit" | "human"
var met: Dictionary = {}
var missions: Dictionary = {}    # id -> {"state": "active"/"done"/"failed", "step": int}
var visited: Dictionary = {}
var photos: Array = []           # {"npc": id, "spirit": bool, "loc": id, "day": n}
var health: float = 100.0
var location: String = ""
var player_x: float = 0.0
var playtime: float = 0.0
var ending_reached: String = ""

# meta (persistente entre campanhas)
var settings: Dictionary = {"music": 0.8, "sfx": 0.9, "text_speed": 1.0, "vibration": true,
	"touch_alpha": 0.55, "grain": true, "shake": true, "time_speed": 1.0}
var endings_seen: Dictionary = {}
var chapters_unlocked: Dictionary = {"elias": 1, "maya": 1, "theo": 1, "naomi": 1}

var _mission_timer: float = 0.0
var active: bool = false          # há uma campanha em andamento (não roda missões no menu)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_meta()


func _process(delta: float) -> void:
	if get_tree().paused or not active:
		return
	playtime += delta
	_mission_timer -= delta
	if _mission_timer <= 0.0:
		_mission_timer = 0.4
		update_missions()


# ---------------------------------------------------------------- nova campanha
func new_game(char_id: String, start_chapter: int = 1) -> void:
	active = true
	character = char_id
	chapter = start_chapter
	flags = {}
	evidence = []
	deductions = []
	trust = {}
	marks = {}
	met = {}
	missions = {}
	visited = {}
	photos = []
	health = 100.0
	playtime = 0.0
	ending_reached = ""
	var c: Dictionary = Data.characters.get(char_id, {})
	location = c.get("start_location", "casa_vance")
	player_x = float(c.get("start_x", 300))
	flags["char_" + char_id] = true
	# capítulos posteriores pressupõem descobertas básicas dos anteriores
	var ch := Data.chapter_info(start_chapter)
	apply(ch.get("skip_effects", {}))
	Clock.set_time(float(ch.get("start_hour", 16.5)), 1)
	Clock.speed = float(settings.get("time_speed", 1.0))


# ---------------------------------------------------------------- condições
func check(c) -> bool:
	if c == null:
		return true
	if c is Array:
		for x in c:
			if not check(x):
				return false
		return true
	if not (c is Dictionary):
		return true
	for k in c:
		var v = c[k]
		match k:
			"flag":
				if not flags.get(v, false):
					return false
			"not_flag":
				if flags.get(v, false):
					return false
			"flags":
				for f in v:
					if not flags.get(f, false):
						return false
			"evidence":
				if v is Array:
					for e in v:
						if not e in evidence:
							return false
				elif not v in evidence:
					return false
			"not_evidence":
				if v in evidence:
					return false
			"evidence_count":
				if evidence.size() < int(v):
					return false
			"char":
				if v is Array:
					if not character in v:
						return false
				elif character != v:
					return false
			"not_char":
				if character == v:
					return false
			"night":
				if Clock.is_night() != bool(v):
					return false
			"dark":
				if (Clock.darkness() > 0.5) != bool(v):
					return false
			"hour_between":
				if not Clock.hour_in(float(v[0]), float(v[1])):
					return false
			"chapter":
				if chapter != int(v):
					return false
			"chapter_min":
				if chapter < int(v):
					return false
			"chapter_max":
				if chapter > int(v):
					return false
			"mission_done":
				if missions.get(v, {}).get("state", "") != "done":
					return false
			"mission_active":
				if missions.get(v, {}).get("state", "") != "active":
					return false
			"not_mission":
				if missions.has(v):
					return false
			"trust_min":
				for npc in v:
					if int(trust.get(npc, 0)) < int(v[npc]):
						return false
			"trust_max":
				for npc in v:
					if int(trust.get(npc, 0)) > int(v[npc]):
						return false
			"marked":
				for npc in v:
					if marks.get(npc, "") != v[npc]:
						return false
			"deduction":
				if not v in deductions:
					return false
			"met":
				if not met.has(v):
					return false
			"spirits_correct_min":
				if spirits_correct() < int(v):
					return false
			"wrong_marks_max":
				if wrong_marks() > int(v):
					return false
			"location":
				if location != v:
					return false
			"any":
				var ok := false
				for alt in v:
					if check(alt):
						ok = true
						break
				if not ok:
					return false
			"not":
				if check(v):
					return false
			"health_min":
				if health < float(v):
					return false
	return true


# ---------------------------------------------------------------- efeitos
func apply(e) -> void:
	if e == null:
		return
	if e is Array:
		for x in e:
			apply(x)
		return
	if not (e is Dictionary):
		return
	for k in e:
		var v = e[k]
		match k:
			"set":
				if v is Array:
					for f in v:
						flags[f] = true
				else:
					flags[v] = true
			"unset":
				if v is Array:
					for f in v:
						flags.erase(f)
				else:
					flags.erase(v)
			"give":
				if v is Array:
					for ev in v:
						give_evidence(ev)
				else:
					give_evidence(v)
			"trust":
				for npc in v:
					trust[npc] = int(trust.get(npc, 0)) + int(v[npc])
			"start_mission":
				if v is Array:
					for m in v:
						start_mission(m)
				else:
					start_mission(v)
			"complete_mission":
				complete_mission(v)
			"fail_mission":
				if missions.has(v):
					missions[v]["state"] = "failed"
					mission_updated.emit(v)
			"chapter":
				set_chapter(int(v))
			"heal":
				set_health(health + float(v))
			"damage":
				set_health(health - float(v))
			"time":
				Clock.set_time(float(v))
			"advance_minutes":
				Clock.advance(float(v))
			"mark":
				for npc in v:
					marks[npc] = v[npc]
			"met":
				met[v] = true
			"notify":
				notify.emit(str(v), "info")
	state_changed.emit()


func give_evidence(id: String) -> void:
	if id in evidence:
		return
	evidence.append(id)
	var item: Dictionary = Data.evidence.get(id, {})
	notify.emit("Evidência: " + item.get("name", id), "evidence")
	Sfx.play("pickup")
	evidence_added.emit(id)


func try_deduction(a: String, b: String) -> Dictionary:
	for d in Data.deductions:
		var pair: Array = [d.get("a", ""), d.get("b", "")]
		if a in pair and b in pair and a != b:
			if d.get("id", "") in deductions:
				return {"result": "known", "d": d}
			deductions.append(d.get("id", ""))
			apply(d.get("do", {}))
			notify.emit("Dedução: " + d.get("title", ""), "deduction")
			return {"result": "new", "d": d}
	return {"result": "none"}


func set_chapter(n: int) -> void:
	if n == chapter:
		return
	chapter = n
	var u := int(chapters_unlocked.get(character, 1))
	if n > u:
		chapters_unlocked[character] = n
		save_meta()
	chapter_changed.emit(n)
	var info := Data.chapter_info(n)
	apply(info.get("start_effects", {}))


func set_health(v: float) -> void:
	health = clampf(v, 0.0, 100.0)
	health_changed.emit(health)


# ---------------------------------------------------------------- espíritos
func spirits_correct() -> int:
	var n := 0
	for id in marks:
		var npc: Dictionary = Data.npcs.get(id, {})
		if marks[id] == "spirit" and npc.get("spirit", false):
			n += 1
	return n


func wrong_marks() -> int:
	var n := 0
	for id in marks:
		var npc: Dictionary = Data.npcs.get(id, {})
		var is_spirit: bool = npc.get("spirit", false)
		if (marks[id] == "spirit") != is_spirit:
			n += 1
	return n


func total_spirits() -> int:
	var n := 0
	for id in Data.npcs:
		if Data.npcs[id].get("spirit", false):
			n += 1
	return n


# ---------------------------------------------------------------- missões
func start_mission(id: String) -> void:
	if missions.has(id) or not Data.missions.has(id):
		return
	var m: Dictionary = Data.missions[id]
	if m.has("char") and not check({"char": m["char"]}):
		return
	missions[id] = {"state": "active", "step": 0}
	notify.emit("Nova missão: " + m.get("title", id), "mission")
	Sfx.play("mission")
	mission_updated.emit(id)


func complete_mission(id: String) -> void:
	if not missions.has(id):
		missions[id] = {"state": "active", "step": 0}
	if missions[id]["state"] == "done":
		return
	missions[id]["state"] = "done"
	var m: Dictionary = Data.missions.get(id, {})
	notify.emit("Missão concluída: " + m.get("title", id), "mission")
	apply(m.get("on_complete", {}))
	mission_updated.emit(id)


func update_missions() -> void:
	# auto-início
	for id in Data.missions:
		if missions.has(id):
			continue
		var m: Dictionary = Data.missions[id]
		if m.has("auto_start") and check(m["auto_start"]):
			start_mission(id)
	# avanço de etapas
	for id in missions.keys():
		var st: Dictionary = missions[id]
		if st["state"] != "active":
			continue
		var m: Dictionary = Data.missions.get(id, {})
		var steps: Array = m.get("steps", [])
		var guard := 0
		while int(st["step"]) < steps.size() and guard < 20:
			guard += 1
			var s: Dictionary = steps[int(st["step"])]
			if check(s.get("done_if", {"flag": "__never__"})):
				apply(s.get("on_done", {}))
				st["step"] = int(st["step"]) + 1
				mission_updated.emit(id)
			else:
				break
		if int(st["step"]) >= steps.size() and st["state"] == "active":
			complete_mission(id)
		if m.has("fail_if") and st["state"] == "active" and check(m["fail_if"]):
			st["state"] = "failed"
			notify.emit("Missão perdida: " + m.get("title", id), "fail")
			apply(m.get("on_fail", {}))
			mission_updated.emit(id)


func current_objective() -> String:
	# missão principal ativa de maior prioridade
	var best := ""
	var best_pri := -999
	for id in missions:
		if missions[id]["state"] != "active":
			continue
		var m: Dictionary = Data.missions.get(id, {})
		var pri := int(m.get("priority", 0))
		if m.get("type", "") == "main":
			pri += 100
		if pri > best_pri:
			var steps: Array = m.get("steps", [])
			var i := int(missions[id]["step"])
			if i < steps.size():
				best = steps[i].get("text", m.get("title", ""))
				best_pri = pri
	return best


# ---------------------------------------------------------------- finais
func resolve_ending() -> String:
	for e in Data.endings:
		if check(e.get("cond", {})):
			return e.get("id", "")
	return "end_main"


func register_ending(id: String) -> void:
	ending_reached = id
	endings_seen[id] = true
	save_meta()


# ---------------------------------------------------------------- salvamento
func snapshot() -> Dictionary:
	return {
		"v": SAVE_VERSION, "character": character, "chapter": chapter, "flags": flags,
		"evidence": evidence, "deductions": deductions, "trust": trust, "marks": marks,
		"met": met, "missions": missions, "visited": visited, "photos": photos,
		"health": health, "location": location, "player_x": player_x,
		"minutes": Clock.minutes, "day": Clock.day, "playtime": playtime,
		"stamp": Time.get_datetime_string_from_system(false, true)
	}


func save_slot(slot: int) -> bool:
	var path := "user://save_%d.json" % slot
	var payload := JSON.stringify(snapshot())
	var wrapper := JSON.stringify({"payload": payload, "md5": payload.md5_text()})
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Falha ao salvar: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(wrapper)
	f.close()
	# mantém a versão anterior como backup antes de substituir
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("Falha ao finalizar save: %s" % error_string(err))
		return false
	return true


func read_slot(slot: int) -> Dictionary:
	var path := "user://save_%d.json" % slot
	for p in [path, path + ".bak"]:
		var d := _read_verified(p)
		if not d.is_empty():
			return d
	return {}


func _read_verified(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var w = JSON.parse_string(txt)
	if not (w is Dictionary) or not w.has("payload"):
		return {}
	var payload: String = w["payload"]
	if payload.md5_text() != w.get("md5", ""):
		push_warning("Save corrompido ignorado: " + path)
		return {}
	var d = JSON.parse_string(payload)
	if not (d is Dictionary) or int(d.get("v", 0)) > SAVE_VERSION:
		return {}
	return d


func load_slot(slot: int) -> bool:
	var d := read_slot(slot)
	if d.is_empty():
		return false
	active = true
	character = d.get("character", "elias")
	chapter = int(d.get("chapter", 1))
	flags = d.get("flags", {})
	evidence = d.get("evidence", [])
	deductions = d.get("deductions", [])
	trust = d.get("trust", {})
	marks = d.get("marks", {})
	met = d.get("met", {})
	missions = d.get("missions", {})
	for id in missions:  # JSON devolve números como float
		missions[id]["step"] = int(missions[id].get("step", 0))
	visited = d.get("visited", {})
	photos = d.get("photos", [])
	health = float(d.get("health", 100))
	location = d.get("location", "casa_vance")
	player_x = float(d.get("player_x", 300))
	playtime = float(d.get("playtime", 0))
	ending_reached = ""
	Clock.minutes = float(d.get("minutes", 600))
	Clock.day = int(d.get("day", 1))
	Clock.speed = float(settings.get("time_speed", 1.0))
	return true


func latest_slot() -> int:
	var best := -1
	var best_stamp := ""
	for i in SLOTS:
		var d := read_slot(i)
		if d.is_empty():
			continue
		var s: String = d.get("stamp", "")
		if best == -1 or s > best_stamp:
			best = i
			best_stamp = s
	return best


func save_meta() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"settings": settings, "endings": endings_seen, "chapters": chapters_unlocked}))
		f.close()


func load_meta() -> void:
	if not FileAccess.file_exists(META_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	if d is Dictionary:
		var s: Dictionary = d.get("settings", {})
		for k in s:
			settings[k] = s[k]
		endings_seen = d.get("endings", {})
		var ch: Dictionary = d.get("chapters", {})
		for k in ch:
			chapters_unlocked[k] = int(ch[k])


# ---------------------------------------------------------------- controles
func _setup_input() -> void:
	var keys := {
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP],
		"down": [KEY_S, KEY_DOWN], "run": [KEY_SHIFT], "interact": [KEY_E, KEY_ENTER],
		"crouch": [KEY_C, KEY_CTRL], "flashlight": [KEY_F], "ability": [KEY_Q],
		"photo": [KEY_R], "notebook": [KEY_TAB, KEY_N], "pause": [KEY_ESCAPE],
		"advance": [KEY_SPACE, KEY_ENTER, KEY_E], "skip": [KEY_ESCAPE]
	}
	var pad := {
		"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT], "up": [JOY_BUTTON_DPAD_UP],
		"down": [JOY_BUTTON_DPAD_DOWN], "run": [JOY_BUTTON_RIGHT_SHOULDER], "interact": [JOY_BUTTON_A],
		"crouch": [JOY_BUTTON_B], "flashlight": [JOY_BUTTON_Y], "ability": [JOY_BUTTON_X],
		"photo": [JOY_BUTTON_LEFT_SHOULDER], "notebook": [JOY_BUTTON_BACK], "pause": [JOY_BUTTON_START],
		"advance": [JOY_BUTTON_A], "skip": [JOY_BUTTON_START]
	}
	for a in keys:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a, 0.35)
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
		for b in pad.get(a, []):
			var j := InputEventJoypadButton.new()
			j.button_index = b
			InputMap.action_add_event(a, j)
	for pair in [["left", -1.0], ["right", 1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = JOY_AXIS_LEFT_X
		m.axis_value = pair[1]
		InputMap.action_add_event(pair[0], m)
	var md := InputEventJoypadMotion.new()
	md.axis = JOY_AXIS_LEFT_Y
	md.axis_value = 1.0
	InputMap.action_add_event("crouch", md)
