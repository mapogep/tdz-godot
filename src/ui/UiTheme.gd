class_name UiTheme
extends RefCounted
## Единая тема интерфейса в постапокалиптическом стиле: тёмные ржавые панели, оранжевые акценты.

const PANEL := Color(0.118, 0.086, 0.059, 0.86)
const LINE := Color(1.0, 0.62, 0.29, 0.30)
const ACCENT := Color("ffa63c")
const GOOD := Color("8fbf4a")
const BAD := Color("ff5a3d")
const TEXT := Color("f4e6d2")
const BTN := Color("45311f")
const BTN_HOVER := Color("5e4229")
const BTN_ACTIVE := Color("5b3d1c")
const PRIMARY := Color("7a4a17")
const DANGER := Color("7d2a1f")

static var _font: SystemFont
static var _theme: Theme


static func font() -> Font:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI Semibold", "Arial Narrow", "Segoe UI"])
		_font.antialiasing = TextServer.FONT_ANTIALIASING_LCD
		_font.hinting = TextServer.HINTING_LIGHT
	return _font


static func box(bg: Color, border: Color = LINE, radius: int = 7, border_w: int = 1, pad: Vector4 = Vector4(10, 8, 10, 8)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	s.anti_aliasing = true
	return s


static func make() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 16
	# панели
	t.set_stylebox("panel", "PanelContainer", box(PANEL))
	t.set_stylebox("panel", "Panel", box(PANEL))
	# подписи
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "Label", 2)
	# кнопки
	for name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var col := BTN
		var border := LINE
		match name:
			"hover": col = BTN_HOVER
			"pressed": col = BTN_ACTIVE; border = ACCENT
			"disabled": col = Color(BTN.r, BTN.g, BTN.b, 0.5)
		if name == "focus":
			t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
		else:
			t.set_stylebox(name, "Button", box(col, border, 6, 1, Vector4(10, 6, 10, 6)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(TEXT.r, TEXT.g, TEXT.b, 0.4))
	t.set_color("icon_normal_color", "Button", Color.WHITE)
	t.set_color("icon_disabled_color", "Button", Color(1, 1, 1, 0.4))
	t.set_constant("h_separation", "Button", 6)
	# поля ввода
	t.set_stylebox("normal", "LineEdit", box(Color(0.06, 0.045, 0.03, 0.9), LINE, 5))
	t.set_stylebox("focus", "LineEdit", box(Color(0.06, 0.045, 0.03, 0.95), ACCENT, 5))
	t.set_color("font_color", "LineEdit", TEXT)
	# ползунки и списки
	var grabber := box(ACCENT, ACCENT, 4, 0, Vector4(0, 0, 0, 0))
	grabber.shadow_size = 0
	var slider_bg := box(Color(0.05, 0.04, 0.03, 0.9), LINE, 4, 1, Vector4(0, 4, 0, 4))
	slider_bg.shadow_size = 0
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", grabber)
	t.set_stylebox("grabber_area_highlight", "HSlider", grabber)
	_theme = t
	return t


## Кнопка стиля «primary» (зелёно-ржавая) или «danger».
static func style_button(b: Button, kind: String) -> void:
	var col := PRIMARY if kind == "primary" else DANGER
	var hover := col.lightened(0.18)
	b.add_theme_stylebox_override("normal", box(col, Color(1.0, 0.75, 0.43, 0.45), 6, 1, Vector4(12, 8, 12, 8)))
	b.add_theme_stylebox_override("hover", box(hover, Color(1.0, 0.75, 0.43, 0.6), 6, 1, Vector4(12, 8, 12, 8)))
	b.add_theme_stylebox_override("pressed", box(col.darkened(0.1), ACCENT, 6, 1, Vector4(12, 8, 12, 8)))
	b.add_theme_stylebox_override("disabled", box(Color(col.r, col.g, col.b, 0.4), LINE, 6, 1, Vector4(12, 8, 12, 8)))
