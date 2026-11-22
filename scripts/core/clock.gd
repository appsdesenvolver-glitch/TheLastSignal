extends Node
## Relógio de Ravenhill: ciclo dia/noite contínuo.
## 1 segundo real = `speed` minutos de jogo (padrão 1.0 → um dia dura 24 min).

signal hour_changed(hour: int)
signal phase_changed(phase: String)
signal day_changed(day: int)

var minutes: float = 8.0 * 60.0
var day: int = 1
var speed: float = 1.0
var running: bool = false
var frozen_by: Dictionary = {}   # cutscenes/diálogos congelam o tempo
var _last_hour: int = -1
var _last_phase: String = ""


func _process(delta: float) -> void:
	if not running or not frozen_by.is_empty() or get_tree().paused:
		return
	advance(delta * speed)


func advance(mins: float) -> void:
	minutes += mins
	while minutes >= 1440.0:
		minutes -= 1440.0
		day += 1
		day_changed.emit(day)
	_emit_changes()


func set_time(h: float, d: int = -1) -> void:
	minutes = fposmod(h, 24.0) * 60.0
	if d > 0:
		day = d
	_emit_changes()


func _emit_changes() -> void:
	var h := int(minutes / 60.0)
	if h != _last_hour:
		_last_hour = h
		hour_changed.emit(h)
	var p := phase()
	if p != _last_phase:
		_last_phase = p
		phase_changed.emit(p)


func hour() -> float:
	return minutes / 60.0


func phase() -> String:
	var h := hour()
	if h >= 6.0 and h < 18.0:
		return "day"
	if h >= 18.0 and h < 20.5:
		return "dusk"
	if h >= 5.0 and h < 6.0:
		return "dawn"
	return "night"


func is_night() -> bool:
	return phase() == "night"


## 0 = meio-dia claro, 1 = madrugada total. Contínuo para transições suaves.
func darkness() -> float:
	var h := hour()
	if h >= 7.0 and h < 17.0:
		return 0.0
	if h >= 17.0 and h < 21.0:
		return smoothstep(17.0, 21.0, h)
	if h >= 4.5 and h < 7.0:
		return 1.0 - smoothstep(4.5, 7.0, h)
	return 1.0


func hour_in(a: float, b: float) -> bool:
	var h := hour()
	if a <= b:
		return h >= a and h < b
	return h >= a or h < b   # intervalo que atravessa a meia-noite


func label() -> String:
	return "%02d:%02d" % [int(minutes / 60.0), int(fmod(minutes, 60.0))]


func freeze(who: String) -> void:
	frozen_by[who] = true


func unfreeze(who: String) -> void:
	frozen_by.erase(who)
