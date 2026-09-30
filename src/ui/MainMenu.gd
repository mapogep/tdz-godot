class_name MainMenu
extends CanvasLayer
## Главное меню: заставка, одиночная игра, создание игры (Host), подключение по адресу, настройки.

signal start_requested(mode: String, address: String, port: int, use_save: bool)
signal quit_requested()

var _root: Control
var _bg: TextureRect
var _title: Label
var _main_box: VBoxContainer
var _join_box: VBoxContainer
var _opt_box: VBoxContainer
var _btn_continue: Button
var _btn_single: Button
var _btn_host: Button
var _btn_join: Button
var _btn_opt: Button
var _btn_quit: Button
var _btn_lang: Button
var _ip: LineEdit
var _port: LineEdit
var _lbl_ip: Label
var _lbl_port: Label
var _btn_join_go: Button
var _btn_back_join: Button
var _btn_back_opt: Button
var _status: Label
var _tip: Label
var _options: OptionsPanel
var has_save := false


func _init() -> void:
	layer = 20


func build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.make()
	add_child(_root)
	_bg = TextureRect.new()
	_bg.texture = load("res://assets/tex/splash.jpg")
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.pivot_offset = Vector2(800, 450)
	_root.add_child(_bg)
	# медленный «кинематографический» наезд фона
	var tw := create_tween().set_loops()
	tw.tween_property(_bg, "scale", Vector2(1.06, 1.06), 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_bg, "scale", Vector2(1.0, 1.0), 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.01, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var vign := ColorRect.new()
	vign.set_anchors_preset(Control.PRESET_FULL_RECT)
	vign.color = Color(0, 0, 0, 0.0)
	_root.add_child(vign)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 72)
	_title.add_theme_color_override("font_color", Color("fff1dc"))
	_title.add_theme_color_override("font_shadow_color", Color(1.0, 0.45, 0.15, 0.55))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 0)
	_title.add_theme_constant_override("shadow_outline_size", 22)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_title.add_theme_constant_override("outline_size", 8)
	v.add_child(_title)
	_tip = Label.new()
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.add_theme_color_override("font_color", Color(UiTheme.TEXT, 0.8))
	v.add_child(_tip)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	v.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 10)
	stack.add_child(_main_box)
	_btn_continue = _mk("", func() -> void: start_requested.emit("single", "", 0, true), "primary")
	_btn_single = _mk("", func() -> void: start_requested.emit("single", "", 0, false), "primary")
	_btn_host = _mk("", func() -> void: start_requested.emit("host", "", NetHub.DEFAULT_PORT, false))
	_btn_join = _mk("", func() -> void: _show("join"))
	_btn_opt = _mk("", func() -> void: _show("opt"))
	_btn_quit = _mk("", func() -> void: quit_requested.emit(), "danger")
	for b in [_btn_continue, _btn_single, _btn_host, _btn_join, _btn_opt, _btn_quit]:
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 19)
		_main_box.add_child(b)

	_join_box = VBoxContainer.new()
	_join_box.add_theme_constant_override("separation", 10)
	_join_box.visible = false
	stack.add_child(_join_box)
	_lbl_ip = Label.new()
	_join_box.add_child(_lbl_ip)
	_ip = LineEdit.new()
	_ip.text = "127.0.0.1"
	_join_box.add_child(_ip)
	_lbl_port = Label.new()
	_join_box.add_child(_lbl_port)
	_port = LineEdit.new()
	_port.text = str(NetHub.DEFAULT_PORT)
	_join_box.add_child(_port)
	_btn_join_go = _mk("", func() -> void:
		start_requested.emit("join", _ip.text.strip_edges(), int(_port.text), false), "primary")
	_join_box.add_child(_btn_join_go)
	_btn_back_join = _mk("", func() -> void: _show("main"))
	_join_box.add_child(_btn_back_join)

	_opt_box = VBoxContainer.new()
	_opt_box.add_theme_constant_override("separation", 10)
	_opt_box.visible = false
	stack.add_child(_opt_box)
	_options = OptionsPanel.new()
	_opt_box.add_child(_options)
	_btn_back_opt = _mk("", func() -> void: _show("main"))
	_opt_box.add_child(_btn_back_opt)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", UiTheme.ACCENT)
	v.add_child(_status)

	_btn_lang = _mk("", func() -> void: I18n.toggle(); Settings.save_settings())
	_btn_lang.custom_minimum_size = Vector2(56, 40)
	_root.add_child(_btn_lang)
	_btn_lang.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	I18n.language_changed.connect(_texts)
	_texts()


func _mk(text: String, cb: Callable, kind: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		cb.call())
	if kind != "":
		UiTheme.style_button(b, kind)
	return b


func _show(which: String) -> void:
	_main_box.visible = which == "main"
	_join_box.visible = which == "join"
	_opt_box.visible = which == "opt"
	_status.text = ""


func set_status(text: String) -> void:
	_status.text = text


func _texts() -> void:
	_title.text = I18n.t("menu_title")
	_tip.text = I18n.t("tip_gate")
	_btn_continue.text = I18n.t("menu_continue")
	_btn_continue.visible = has_save
	_btn_single.text = I18n.t("menu_single")
	_btn_host.text = I18n.t("menu_host")
	_btn_join.text = I18n.t("menu_join")
	_btn_opt.text = I18n.t("menu_options")
	_btn_quit.text = I18n.t("menu_quit")
	_btn_lang.text = I18n.t("toggle_lang")
	_lbl_ip.text = I18n.t("menu_ip")
	_lbl_port.text = I18n.t("menu_port")
	_btn_join_go.text = I18n.t("menu_join")
	_btn_back_join.text = I18n.t("menu_back")
	_btn_back_opt.text = I18n.t("menu_back")


func refresh_save(p_has_save: bool) -> void:
	has_save = p_has_save
	_btn_continue.visible = has_save
