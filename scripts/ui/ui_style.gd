extends RefCounted
class_name UIStyle
## Identidade visual da interface: carvão profundo, osso envelhecido e um vermelho
## sangue contido. Sem cores saturadas. Tudo construído em código (sem assets externos).

const BG := Color("0b0c10")
const PANEL := Color(0.055, 0.06, 0.075, 0.94)
const PANEL_LIGHT := Color(0.09, 0.095, 0.115, 0.96)
const LINE := Color("2c2f38")
const BONE := Color("d6cfbf")
const BONE_DIM := Color("8d8778")
const BLOOD := Color("8e1e24")
const BLOOD_HI := Color("b8323a")
const COLD := Color("7f97b8")

static var _theme: Theme


static func box(bg: Color, border: Color = LINE, bw: int = 1, radius: int = 2, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 20
	t.set_color("font_color", "Label", BONE)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", "Label", 4)
	t.set_stylebox("panel", "Panel", box(PANEL))
	t.set_stylebox("panel", "PanelContainer", box(PANEL))
	# botões: texto osso, borda fina, realce em vermelho sangue sem saturar
	t.set_stylebox("normal", "Button", box(Color(0.07, 0.075, 0.09, 0.92), LINE, 1, 2, 16))
	t.set_stylebox("hover", "Button", box(Color(0.12, 0.08, 0.09, 0.95), BLOOD, 1, 2, 16))
	t.set_stylebox("pressed", "Button", box(Color(0.2, 0.07, 0.08, 0.95), BLOOD_HI, 2, 2, 16))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), BLOOD_HI, 2, 2, 16))
	t.set_stylebox("disabled", "Button", box(Color(0.05, 0.05, 0.06, 0.8), Color("1d1f25"), 1, 2, 16))
	t.set_color("font_color", "Button", BONE)
	t.set_color("font_hover_color", "Button", Color("f1e9d8"))
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("4c4a45"))
	t.set_color("font_focus_color", "Button", Color("f1e9d8"))
	t.set_font_size("font_size", "Button", 20)
	t.set_stylebox("panel", "TabContainer", box(PANEL, LINE, 1, 2, 14))
	t.set_stylebox("tab_selected", "TabBar", box(Color(0.14, 0.06, 0.07, 1), BLOOD, 1, 2, 14))
	t.set_stylebox("tab_unselected", "TabBar", box(Color(0.06, 0.065, 0.08, 1), LINE, 1, 2, 14))
	t.set_stylebox("tab_hovered", "TabBar", box(Color(0.1, 0.07, 0.08, 1), BLOOD, 1, 2, 14))
	t.set_color("font_selected_color", "TabBar", BONE)
	t.set_color("font_unselected_color", "TabBar", BONE_DIM)
	t.set_color("font_hovered_color", "TabBar", BONE)
	t.set_color("default_color", "RichTextLabel", BONE)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("slider", "HSlider", box(Color(0.1, 0.1, 0.12), LINE, 1, 4, 2))
	t.set_stylebox("grabber_area", "HSlider", box(BLOOD, BLOOD, 0, 4, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(BLOOD_HI, BLOOD_HI, 0, 4, 2))
	t.set_stylebox("panel", "ItemList", box(Color(0.05, 0.055, 0.07, 0.9)))
	t.set_color("font_color", "ItemList", BONE)
	t.set_stylebox("selected", "ItemList", box(Color(0.18, 0.07, 0.08), BLOOD))
	t.set_stylebox("selected_focus", "ItemList", box(Color(0.18, 0.07, 0.08), BLOOD_HI))
	t.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("normal", "LineEdit", box(Color(0.05, 0.05, 0.06), LINE))
	t.set_stylebox("background", "ProgressBar", box(Color(0.05, 0.05, 0.06, 0.8), LINE, 1, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(BLOOD, BLOOD, 0, 1, 0))
	t.set_stylebox("panel", "PopupPanel", box(PANEL_LIGHT, BLOOD))
	_theme = t
	return t


static func label(text: String, size: int = 20, col: Color = BONE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


static func button(text: String, cb: Callable, min_w: float = 280.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 52)
	b.pressed.connect(func():
		Sfx.play("ui_ok", 0.6)
		cb.call()
	)
	b.mouse_entered.connect(func(): Sfx.play("ui_move", 0.35))
	b.focus_entered.connect(func(): Sfx.play("ui_move", 0.25))
	return b
