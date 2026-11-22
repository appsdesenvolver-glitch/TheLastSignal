extends Node
## Testes automatizados (rodam no CI com Godot headless):
##   godot --headless --path . res://tests/Tests.tscn
## Cobrem dados, condições/efeitos, salvamento (incl. corrupção), resolução de todos
## os finais e uma JOGATINA COMPLETA por protagonista: abertura, visita a todos os
## locais, todos os capítulos via cutscenes reais, cena final e créditos.

var passed: int = 0
var failures: Array = []


func ok(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(msg)
		printerr("FALHOU: " + msg)


func _ready() -> void:
	await get_tree().process_frame
	_test_data()
	_test_conditions()
	_test_saves()
	_test_endings()
	for c in Data.characters:
		await _test_playthrough(c)
	await _test_all_cutscenes()
	print("\n==== %d verificações OK, %d falhas ====" % [passed, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


func _test_data() -> void:
	ok(Data.errors.is_empty(), "dados carregam sem erro: %s" % str(Data.errors))
	ok(Data.characters.size() == 4, "4 protagonistas")
	ok(Data.locations.size() >= 20, "20+ locais")
	ok(Data.endings.size() >= 7, "7+ finais")
	for id in Data.characters:
		ok(Data.cutscenes.has(Data.characters[id].get("opening", "")), "abertura de " + id)


func _test_conditions() -> void:
	Game.new_game("maya", 1)
	ok(Game.check({"char": "maya"}), "cond char")
	ok(not Game.check({"char": "elias"}), "cond char negativa")
	Game.apply({"set": ["a", "b"], "trust": {"edith": 2}})
	ok(Game.check({"flags": ["a", "b"], "trust_min": {"edith": 2}}), "efeito set+trust")
	ok(Game.check({"any": [{"flag": "zzz"}, {"flag": "a"}]}), "cond any")
	ok(Game.check({"not": {"flag": "zzz"}}), "cond not")
	Game.give_evidence("foto_1979")
	Game.give_evidence("livro_obitos")
	var r := Game.try_deduction("livro_obitos", "foto_1979")
	ok(r["result"] == "new" and Game.check({"deduction": "ded_edith"}), "dedução edith")
	ok(Game.try_deduction("foto_1979", "livro_obitos")["result"] == "known", "dedução repetida")
	ok(Game.try_deduction("foto_1979", "cartazes")["result"] == "none", "dedução inválida")
	Game.marks = {"edith": "spirit", "jonah": "spirit"}
	ok(Game.spirits_correct() == 1 and Game.wrong_marks() == 1, "contagem de marcações")
	Clock.set_time(23.0)
	ok(Game.check({"night": true}) and Game.check({"hour_between": [22, 2]}), "cond noite / intervalo que cruza meia-noite")
	Clock.set_time(12.0)
	ok(Game.check({"night": false}), "cond dia")
	# missão avança sozinha
	Game.missions = {}
	Game.start_mission("m2_main")
	Game.give_evidence("foto_1979")
	Game.update_missions()
	ok(int(Game.missions["m2_main"]["step"]) >= 3, "missão m2 avança com evidências/dedução (passo %d)" % int(Game.missions["m2_main"]["step"]))


func _test_saves() -> void:
	Game.new_game("theo", 2)
	Game.flags["teste_save"] = true
	Game.trust["clara"] = 3
	Game.location = "hospital_lobby"
	Game.player_x = 777.0
	Clock.set_time(21.5, 4)
	ok(Game.save_slot(3), "salvar espaço 3")
	Game.new_game("elias", 1)
	ok(Game.load_slot(3), "carregar espaço 3")
	ok(Game.character == "theo" and Game.chapter == 2 and Game.flags.get("teste_save", false), "estado restaurado")
	ok(int(Game.trust.get("clara", 0)) == 3 and absf(Game.player_x - 777.0) < 0.1, "confiança/posição restauradas")
	ok(Clock.day == 4 and absf(Clock.hour() - 21.5) < 0.01, "relógio restaurado")
	# salva de novo (gera backup) e corrompe o principal: deve cair no backup
	ok(Game.save_slot(3), "salvar de novo (backup)")
	var f := FileAccess.open("user://save_3.json", FileAccess.WRITE)
	f.store_string("{corrompido")
	f.close()
	ok(not Game.read_slot(3).is_empty(), "save corrompido recupera pelo backup")
	DirAccess.remove_absolute("user://save_3.json")
	DirAccess.remove_absolute("user://save_3.json.bak")
	ok(Game.read_slot(3).is_empty(), "espaço vazio retorna vazio")


func _ending_with(state: Dictionary, char_id: String) -> String:
	Game.new_game(char_id, 5)
	Game.flags = {}
	Game.marks = {}
	Game.trust = {}
	Game.deductions = []
	for k in state.get("flags", []):
		Game.flags[k] = true
	Game.marks = state.get("marks", {})
	Game.trust = state.get("trust", {})
	Game.deductions = state.get("deductions", [])
	return Game.resolve_ending()


func _test_endings() -> void:
	var all_spirits := {}
	for id in Data.npcs:
		if Data.npcs[id].get("spirit", false):
			all_spirits[id] = "spirit"
	ok(_ending_with({"flags": ["final_iris", "jonah_saved"], "marks": all_spirits}, "elias") == "end_true", "final verdadeiro")
	ok(_ending_with({"flags": ["final_iris"]}, "maya") == "end_hidden", "final oculto")
	ok(_ending_with({"flags": ["final_join"]}, "theo") == "end_bad", "final ruim (aceitar)")
	ok(_ending_with({"flags": ["final_destroy"], "marks": {"jonah": "spirit", "greer": "spirit", "tomas": "spirit"}}, "theo") == "end_bad", "final ruim (acusações erradas)")
	ok(_ending_with({"flags": ["final_keep"], "trust": {"edith": 3}}, "naomi") == "end_secret", "final secreto")
	ok(_ending_with({"flags": ["final_destroy"], "deductions": ["ded_daniel"]}, "elias") == "end_elias", "final Elias")
	ok(_ending_with({"flags": ["final_destroy"], "deductions": ["ded_lucia"]}, "maya") == "end_maya", "final Maya")
	ok(_ending_with({"flags": ["final_destroy"], "deductions": ["ded_sam"]}, "theo") == "end_theo", "final Theo")
	ok(_ending_with({"flags": ["final_destroy"], "deductions": ["ded_iris2"]}, "naomi") == "end_naomi", "final Naomi")
	ok(_ending_with({"flags": ["final_flee"]}, "naomi") == "end_survival", "final sobrevivência")
	ok(_ending_with({"flags": ["final_destroy"]}, "maya") == "end_main", "final principal")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _play(w: World, id: String) -> void:
	Game.ending_reached = ""
	await w.play_cutscene(id)
	await _frames(2)


func _test_playthrough(char_id: String) -> void:
	print("-- jogatina completa: ", char_id)
	Game.new_game(char_id, 1)
	var w := World.new()
	add_child(w)
	w.cutscene.force_skip = true
	w.dialogue.auto = true
	await _frames(2)
	w.player.invuln = 99999.0
	await w.start(true)
	var start: String = Data.characters[char_id]["start_location"]
	ok(Game.location == start, "%s: abertura termina em %s (está em %s)" % [char_id, start, Game.location])
	await _frames(3)
	ok(Game.missions.has("m1_main"), "%s: missão principal 1 iniciada" % char_id)
	# visita todos os locais, de dia e de noite
	for h in [12.0, 23.0]:
		Clock.set_time(h)
		for lid in Data.locations:
			await w.load_location(lid, 300.0, false)
			await _frames(2)
			ok(w.loc_id == lid and is_instance_valid(w.backdrop), "%s: carregou %s às %dh" % [char_id, lid, int(h)])
	# capítulo 1
	Game.flags["talked_greer"] = true
	await w.load_location("praca", 900.0, false)
	Clock.set_time(23.0)
	await _play(w, "ch1_swing")
	ok(Game.flags.get("heard_717", false), "%s: ouviu 7.17" % char_id)
	await w.load_location("diner", 900.0, false)
	await _play(w, "ch1_end")
	ok(Game.chapter == 2, "%s: chegou ao capítulo 2" % char_id)
	# capítulo 2
	Game.give_evidence("foto_1979")
	Game.give_evidence("livro_obitos")
	Game.try_deduction("foto_1979", "livro_obitos")
	Clock.set_time(3.0)
	await _play(w, "ch2_edith")
	ok(Game.chapter == 3 and Game.flags.get("edith_confronted", false), "%s: capítulo 3" % char_id)
	# capítulo 3
	Game.flags["subsolo_key"] = true
	await w.load_location("hospital_subsolo", 2400.0, false)
	Game.flags["got_notas"] = true
	Game.give_evidence("notas_lamparina")
	await _play(w, "ch3_listener")
	var has_listener := false
	for c in w.creatures_node.get_children():
		if c.id == "listener":
			has_listener = true
	ok(has_listener, "%s: Ouvinte surge no subsolo" % char_id)
	await w.load_location("hospital_lobby", 2100.0, false)
	await _play(w, "ch3_end")
	ok(Game.chapter == 4, "%s: capítulo 4" % char_id)
	# capítulo 4
	Game.apply({"give": ["foto_1979"]})
	Game.try_deduction("notas_lamparina", "foto_1979")
	ok(Game.flags.get("halvorsen_open", false), "%s: Casa Halvorsen destrancada pela dedução" % char_id)
	await w.load_location("lab_lamparina", 1400.0, false)
	Game.give_evidence("diario_halvorsen")
	w.dialogue.auto_picks = [0]
	await _play(w, "ch4_jonah")
	ok(Game.chapter == 5 and Game.flags.get("jonah_saved", false), "%s: capítulo 5, Jonah salvo" % char_id)
	# capítulo 5
	await w.load_location("torre", 400.0, false)
	await _play(w, "ch5_maestro")
	ok(Game.flags.get("maestro_awake", false), "%s: Maestro desperto" % char_id)
	var has_boss := false
	for c in w.creatures_node.get_children():
		if c.id == "maestro":
			has_boss = true
	ok(has_boss, "%s: chefe presente na torre" % char_id)
	Game.apply({"set": ["relay1", "relay2", "relay3"]})
	w.dialogue.auto_picks = [0]
	await _play(w, "ch5_final")
	ok(Game.ending_reached != "", "%s: chegou a um final (%s)" % [char_id, Game.ending_reached])
	ok(Game.endings_seen.has(Game.ending_reached), "%s: final registrado na galeria" % char_id)
	w.queue_free()
	await _frames(2)


func _test_all_cutscenes() -> void:
	print("-- todas as cutscenes isoladamente")
	Game.new_game("naomi", 5)
	var w := World.new()
	add_child(w)
	w.cutscene.force_skip = true
	w.dialogue.auto = true
	await _frames(2)
	w.player.invuln = 99999.0
	await w.load_location("torre", 400.0, false)
	for id in Data.cutscenes:
		w.dialogue.auto_picks = []
		await _play(w, id)
		ok(not w.cutscene_running and w.player != null, "cutscene %s executa e devolve o controle" % id)
	w.queue_free()
	await _frames(2)
