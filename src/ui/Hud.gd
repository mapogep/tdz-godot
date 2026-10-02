class_name Hud
extends CanvasLayer
## Интерфейс игры: панель волны и денег, инструменты и оружие, панель турели, список игроков и турелей,
## прицел и боезапас в режиме «из башни», пауза, экран поражения. Рисуется кодом в единой теме.

signal action(name: String, arg: Variant)

const ICON := {
	"select": "res://assets/ui/select.svg", "wall": "res://assets/tex/icon-wall.png", "remove": "res://assets/ui/remove.svg",
	"gun": "res://assets/tex/icon-turret.png", "machinegun": "res://assets/tex/icon-machinegun.png",
	"rocket": "res://assets/tex/icon-rocket.png", "flame": "res://assets/tex/icon-flame.png",
}
const ZOMBIE_COLOR := {"normal": "#6fae4f", "fat": "#a8863a", "fast": "#e8d040", "armored": "#8fa3b8", "boomer": "#a6e03a", "brute": "#e0503a"}

var st: ClientState
var root: Control

var _lbl_wave: Label
var _lbl_timer: Label
var _incoming: RichTextLabel
var _lbl_money: Label
var _lbl_walls: Label
var _lbl_turrets: Label
var _btn_start: Button
var _top_left: PanelContainer
var _right_box: VBoxContainer
var _btn_lang: Button
var _btn_menu: Button
var _players: VBoxContainer
var _players_panel: PanelContainer
var _tlist_panel: PanelContainer
var _tlist_title: Label
var _tlist_flow: HFlowContainer
var _tools_panel: PanelContainer
var _tools_row: HBoxContainer
var _tool_buttons: Dictionary = {}
var _tp: PanelContainer                # панель турели
var _tp_title: Label
var _tp_rows: Dictionary = {}
var _tp_btn_up: Button
var _tp_btn_sell: Button
var _tp_btn_move: Button
var _tp_btn_fps: Button
var _tp_hint: Label
var _hint: Label
var _conn: Label
var _toast: PanelContainer
var _toast_lbl: Label
var _banner: Label
var _fps_root: Control
var _cross: Crosshair
var _ammo_lbl: Label
var _fps_hint: Label
var _fps_wave: Label
var _reload: ProgressBar
var _free_root: Control
var _free_cross: Crosshair
var _free_hp: ProgressBar
var _free_hp_lbl: Label
var _free_ammo: Label
var _free_sub: Label
var _free_top: Label
var _free_reload: ProgressBar
var _free_hint: Label
var _hotkeys: PanelContainer
var _hotkeys_lbl: Label
const TOP_BAR := 30.0              # высота полосы горячих клавиш сверху
var _vignette: TextureRect
var _vig_t := 0.0
var _dead_panel: PanelContainer
var _dead_lbl: Label
var _pause: Control
var _pause_title: Label
var _pause_sub: Label
var _pause_leave: Button
var _over: Control
var _over_title: Label
var _over_lines: Label
var _over_restart: Button
var _over_wait: Label
var _over_menu: Button
var _menu_overlay: Control
var _menu_resume: Button
var _menu_exit: Button
var _menu_title: Label
var _options: OptionsPanel
var _sig_tools := ""
var _sig_tlist := ""
var _sig_players := ""
var _sig_incoming := ""
var _reload_start := 0.0
var _toast_tw: Tween
var _announce: Label
var _announce_tw: Tween
var _report: PanelContainer
var _report_title: Label
var _report_grid: GridContainer
var _report_auto: Label
var _report_tw: Tween
var _board: PanelContainer
var _board_grid: GridContainer
var _board_sig := ""
var _over_grid: GridContainer
var _banner_tw: Tween


# ───────────────────────── сборка ─────────────────────────

func _init() -> void:
	layer = 10


func build(p_st: ClientState) -> void:
	st = p_st
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)
	_build_top_left()
	_build_top_right()
	_build_tools()
	_build_turret_panel()
	_build_footer()
	_build_toast_banner()
	_build_fps()
	_build_free_fps()
	_build_pause()
	_build_game_over()
	_build_scores()
	_build_hotkeys()
	_build_menu_overlay()
	I18n.language_changed.connect(func() -> void:
		_sig_tools = ""
		_sig_tlist = ""
		_sig_players = ""
		_sig_incoming = ""
		_static_texts()
		refresh())
	_static_texts()
	refresh()


func _label(text: String = "", size: int = 16, color: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, cb: Callable, kind: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		cb.call())
	if kind != "":
		UiTheme.style_button(b, kind)
	return b


func _build_top_left() -> void:
	_top_left = PanelContainer.new()
	root.add_child(_top_left)
	_top_left.position = Vector2(12, 12 + TOP_BAR)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_top_left.add_child(v)
	_lbl_wave = _label("", 26)
	v.add_child(_lbl_wave)
	_lbl_timer = _label("", 17)
	v.add_child(_lbl_timer)
	_incoming = RichTextLabel.new()
	_incoming.bbcode_enabled = true
	_incoming.fit_content = true
	_incoming.scroll_active = false
	_incoming.autowrap_mode = TextServer.AUTOWRAP_OFF
	_incoming.custom_minimum_size = Vector2(330, 24)
	_incoming.add_theme_font_size_override("normal_font_size", 14)
	_incoming.add_theme_font_size_override("bold_font_size", 14)
	v.add_child(_incoming)
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 6)
	v.add_child(money_row)
	var coin := TextureRect.new()
	coin.texture = load("res://assets/tex/icon-coin.png")
	coin.custom_minimum_size = Vector2(26, 26)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	money_row.add_child(coin)
	_lbl_money = _label("", 22, UiTheme.ACCENT)
	money_row.add_child(_lbl_money)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	_lbl_walls = _label("", 17)
	_lbl_turrets = _label("", 17)
	row.add_child(_lbl_walls)
	row.add_child(_lbl_turrets)
	_btn_start = _button("", func() -> void: action.emit("startWave", null), "primary")
	_btn_start.custom_minimum_size = Vector2(0, 38)
	v.add_child(_btn_start)


func _build_top_right() -> void:
	_right_box = VBoxContainer.new()
	_right_box.add_theme_constant_override("separation", 8)
	root.add_child(_right_box)
	_right_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_right_box.offset_top += TOP_BAR
	_right_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.alignment = BoxContainer.ALIGNMENT_END
	_right_box.add_child(top)
	_btn_lang = _button("", func() -> void: I18n.toggle(); Settings.save_settings())
	_btn_lang.custom_minimum_size = Vector2(48, 36)
	top.add_child(_btn_lang)
	_btn_menu = _button("", func() -> void: action.emit("menu", null))
	_btn_menu.icon = load(ICON.get("menu", "res://assets/ui/menu.svg"))
	_btn_menu.custom_minimum_size = Vector2(48, 36)
	_btn_menu.add_theme_constant_override("icon_max_width", 22)
	top.add_child(_btn_menu)
	_players_panel = PanelContainer.new()
	_right_box.add_child(_players_panel)
	_players = VBoxContainer.new()
	_players.add_theme_constant_override("separation", 3)
	_players_panel.add_child(_players)
	_tlist_panel = PanelContainer.new()
	_right_box.add_child(_tlist_panel)
	var tv := VBoxContainer.new()
	_tlist_panel.add_child(tv)
	_tlist_title = _label("", 12, Color(UiTheme.TEXT, 0.7))
	tv.add_child(_tlist_title)
	_tlist_flow = HFlowContainer.new()
	_tlist_flow.custom_minimum_size = Vector2(210, 0)
	_tlist_flow.add_theme_constant_override("h_separation", 4)
	_tlist_flow.add_theme_constant_override("v_separation", 4)
	tv.add_child(_tlist_flow)


func _build_tools() -> void:
	_tools_panel = PanelContainer.new()
	root.add_child(_tools_panel)
	_tools_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	_tools_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tools_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tools_row = HBoxContainer.new()
	_tools_row.add_theme_constant_override("separation", 6)
	_tools_panel.add_child(_tools_row)


func _build_turret_panel() -> void:
	_tp = PanelContainer.new()
	root.add_child(_tp)
	_tp.custom_minimum_size = Vector2(280, 0)
	_tp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
	# правый нижний угол: панель растёт влево и вверх, поэтому всегда остаётся на экране
	_tp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tp.offset_right = -14.0
	_tp.offset_bottom = -60.0
	_tp.offset_left = -294.0
	_tp.offset_top = -60.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_tp.add_child(v)
	_tp_title = _label("", 19, UiTheme.ACCENT)
	v.add_child(_tp_title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	v.add_child(grid)
	for key in ["level", "damage", "dps", "range", "fire_rate", "splash", "hp", "ammo"]:
		var k := _label("", 15, Color(UiTheme.TEXT, 0.82))
		k.custom_minimum_size = Vector2(120, 0)
		var val := RichTextLabel.new()
		val.bbcode_enabled = true
		val.fit_content = true
		val.scroll_active = false
		val.autowrap_mode = TextServer.AUTOWRAP_OFF
		val.custom_minimum_size = Vector2(140, 22)
		val.add_theme_font_size_override("normal_font_size", 15)
		val.add_theme_font_size_override("bold_font_size", 15)
		grid.add_child(k)
		grid.add_child(val)
		_tp_rows[key] = {"k": k, "v": val}
	var btns := GridContainer.new()
	btns.columns = 2
	btns.add_theme_constant_override("h_separation", 6)
	btns.add_theme_constant_override("v_separation", 6)
	v.add_child(btns)
	_tp_btn_up = _button("", func() -> void: action.emit("upgrade", st.selected_turret), "primary")
	_tp_btn_sell = _button("", func() -> void: action.emit("sell", st.selected_turret), "danger")
	_tp_btn_move = _button("", func() -> void: action.emit("move", null))
	_tp_btn_fps = _button("FPS", func() -> void: action.emit("enterFps", st.selected_turret))
	for b in [_tp_btn_up, _tp_btn_sell, _tp_btn_move, _tp_btn_fps]:
		b.custom_minimum_size = Vector2(130, 36)
		btns.add_child(b)
	_tp_hint = _label("", 12, UiTheme.ACCENT)
	_tp_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tp_hint.custom_minimum_size = Vector2(250, 0)
	v.add_child(_tp_hint)


func _build_footer() -> void:
	_hint = _label("", 13, Color(UiTheme.TEXT, 0.72))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 10)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_conn = _label("", 12, Color(UiTheme.TEXT, 0.6))
	root.add_child(_conn)
	_conn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)


func _build_toast_banner() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", UiTheme.box(Color(0.59, 0.12, 0.1, 0.94), Color(1, 0.4, 0.3, 0.5), 8, 1, Vector4(20, 10, 20, 10)))
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast)
	_toast_lbl = _label("", 19, Color.WHITE)
	_toast.add_child(_toast_lbl)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 150)
	_banner = _label("", 44, Color.WHITE)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 110)


class Crosshair extends Control:
	var weapon := "gun"
	var hit_t := 0.0

	func _process(delta: float) -> void:
		hit_t = maxf(0.0, hit_t - delta)
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var col := Color(1, 1, 1, 0.95)
		if weapon == "flame":
			col = Color("ffb347")
		var gap := 8.0
		var len := 10.0
		if weapon == "machinegun":
			gap = 12.0
			len = 9.0
		if weapon == "rocket":
			draw_arc(c, 17.0, 0, TAU, 40, Color(1, 1, 1, 0.85), 2.0, true)
			gap = 5.0
			len = 6.0
		if weapon == "ak":
			gap = 7.0
			len = 8.0
		if weapon == "melee":
			draw_circle(c, 2.4, Color(0, 0, 0, 0.7))
			draw_circle(c, 1.7, col)
			return
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * gap + Vector2(1, 1), c + d * (gap + len) + Vector2(1, 1), Color(0, 0, 0, 0.7), 3.0)
			draw_line(c + d * gap, c + d * (gap + len), col, 2.0)
		draw_circle(c, 1.6, col)
		if hit_t > 0.0:
			var a := hit_t / 0.12
			var r := Color(1.0, 0.25, 0.2, a)
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * 8.0, c + d * 16.0, r, 3.0)


func _build_fps() -> void:
	_fps_root = Control.new()
	_fps_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fps_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_root.visible = false
	root.add_child(_fps_root)
	_cross = Crosshair.new()
	_cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_root.add_child(_cross)
	_fps_wave = _label("", 20)
	_fps_root.add_child(_fps_wave)
	_fps_wave.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 14 + TOP_BAR)
	var br := VBoxContainer.new()
	br.alignment = BoxContainer.ALIGNMENT_END
	_fps_root.add_child(br)
	br.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 26)
	_ammo_lbl = _label("", 34)
	_ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_ammo_lbl)
	_fps_hint = _label("", 13, Color(UiTheme.TEXT, 0.85))
	_fps_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_fps_hint)
	_reload = ProgressBar.new()
	_reload.custom_minimum_size = Vector2(190, 8)
	_reload.show_percentage = false
	_reload.max_value = 1.0
	_reload.add_theme_stylebox_override("background", UiTheme.box(Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 4, 0, Vector4(0, 0, 0, 0)))
	_reload.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.ACCENT, Color(0, 0, 0, 0), 4, 0, Vector4(0, 0, 0, 0)))
	br.add_child(_reload)


## HUD «Свободного FPS»: прицел, здоровье, патроны и запасные магазины, подсказки, красная виньетка урона.
func _build_free_fps() -> void:
	_free_root = Control.new()
	_free_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_free_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_free_root.visible = false
	root.add_child(_free_root)
	# виньетка урона: радиальный градиент, прозрачный в центре
	var grad := Gradient.new()
	grad.set_color(0, Color(0.8, 0.0, 0.0, 0.0))
	grad.set_color(1, Color(0.8, 0.0, 0.0, 0.85))
	grad.set_offset(0, 0.45)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = gt
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_free_root.add_child(_vignette)
	_free_cross = Crosshair.new()
	_free_cross.weapon = "ak"
	_free_cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	_free_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_free_root.add_child(_free_cross)
	# верх: режим, волна и деньги
	var top := VBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	_free_root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12 + TOP_BAR)
	_free_top = _label("", 20)
	_free_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_free_top)
	# низ слева: здоровье
	var bl := VBoxContainer.new()
	_free_root.add_child(bl)
	bl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 26)
	bl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_free_hp_lbl = _label("", 22, Color("ff8a7a"))
	bl.add_child(_free_hp_lbl)
	_free_hp = ProgressBar.new()
	_free_hp.custom_minimum_size = Vector2(260, 14)
	_free_hp.show_percentage = false
	_free_hp.max_value = 100.0
	_free_hp.add_theme_stylebox_override("background", UiTheme.box(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.25), 4, 1, Vector4(0, 0, 0, 0)))
	_free_hp.add_theme_stylebox_override("fill", UiTheme.box(Color("c8402f"), Color(0, 0, 0, 0), 4, 0, Vector4(0, 0, 0, 0)))
	bl.add_child(_free_hp)
	# низ справа: оружие и патроны
	var br := VBoxContainer.new()
	_free_root.add_child(br)
	br.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 26)
	br.grow_vertical = Control.GROW_DIRECTION_BEGIN
	br.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_free_ammo = _label("", 40)
	_free_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_free_ammo)
	_free_sub = _label("", 15, Color(UiTheme.TEXT, 0.85))
	_free_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_free_sub)
	_free_reload = ProgressBar.new()
	_free_reload.custom_minimum_size = Vector2(200, 8)
	_free_reload.show_percentage = false
	_free_reload.max_value = 1.0
	_free_reload.add_theme_stylebox_override("background", UiTheme.box(Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 4, 0, Vector4(0, 0, 0, 0)))
	_free_reload.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.ACCENT, Color(0, 0, 0, 0), 4, 0, Vector4(0, 0, 0, 0)))
	br.add_child(_free_reload)
	_free_hint = _label("", 13, Color(UiTheme.TEXT, 0.7))
	_free_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_free_root.add_child(_free_hint)
	_free_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 8)
	_free_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_free_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# плашка «вы погибли» (режим стратегии, только просмотр)
	_dead_panel = PanelContainer.new()
	_dead_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.35, 0.07, 0.06, 0.92), Color(1, 0.4, 0.3, 0.55), 8, 1, Vector4(22, 10, 22, 10)))
	_dead_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dead_panel.visible = false
	root.add_child(_dead_panel)
	_dead_lbl = _label("", 20, Color.WHITE)
	_dead_panel.add_child(_dead_lbl)
	_dead_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 60)


## Красная вспышка по краям экрана при уроне.
func damage_flash(amount: float) -> void:
	_vig_t = clampf(_vig_t + 0.35 + amount * 0.02, 0.0, 1.0)


func _process(delta: float) -> void:
	_fit_panels()
	_update_hotkeys()
	_update_board()
	if _vignette != null:
		_vig_t = maxf(0.0, _vig_t - delta * 1.2)
		var low := 0.0
		if st != null and st.in_free_fps():
			var f := st.my_fps()
			low = clampf(1.0 - float(f["hp"]) / float(f["max_hp"]) - 0.6, 0.0, 0.4)   # у самого края здоровья экран краснеет постоянно
		_vignette.modulate.a = clampf(_vig_t + low, 0.0, 1.0)


## Панели, не помещающиеся в окно, уменьшаются (от угла привязки), чтобы всё было видно при любом размере окна.
func _fit_panels() -> void:
	var vp := root.get_viewport_rect().size
	_hint.custom_minimum_size.x = minf(vp.x - 40.0, 1100.0)
	if _tp != null and _tp.visible:
		var sz := _tp.get_combined_minimum_size()
		var k := minf(1.0, minf((vp.y - 120.0) / maxf(sz.y, 1.0), (vp.x - 30.0) / maxf(sz.x, 1.0)))
		k = clampf(k, 0.45, 1.0)
		_tp.pivot_offset = Vector2(_tp.size.x, _tp.size.y)
		_tp.scale = Vector2(k, k)
	if _tools_panel != null and _tools_panel.visible:
		var sz2 := _tools_panel.get_combined_minimum_size()
		var k2 := clampf((vp.x - 20.0) / maxf(sz2.x, 1.0), 0.5, 1.0)
		_tools_panel.pivot_offset = Vector2(_tools_panel.size.x * 0.5, _tools_panel.size.y)
		_tools_panel.scale = Vector2(k2, k2)


func _refresh_free(s: Dictionary) -> void:
	var f := st.my_fps()
	var w := str(f["weapon"])
	_free_cross.weapon = "ak" if w == "ak" else "melee"
	_free_top.text = "%s  ·  %s: %d  ·  $%d" % [I18n.t("free_title"), I18n.t("wave"), int(s["wave"]), int(s["money"])]
	_free_hp.value = float(f["hp"])
	_free_hp_lbl.text = "♥ %d" % int(ceil(float(f["hp"])))
	if w == "ak":
		var mag := int(Cfg.PWEAPONS["ak"]["mag"])
		if float(f["reload"]) > 0.0:
			_free_ammo.text = I18n.t("reloading")
		else:
			_free_ammo.text = "%d / %d" % [int(f["ammo"]), int(f["mags"]) * mag]
		_free_sub.text = "%s · %d %s" % [I18n.t("w_ak"), int(f["mags"]), I18n.t("free_mags")]
		if int(f["ammo"]) == 0 and int(f["mags"]) == 0:
			_free_sub.text = I18n.t("free_no_ammo")
		_free_reload.value = float(f["reload"])
	else:
		_free_ammo.text = I18n.t("w_" + str(f["melee"]))
		_free_sub.text = "%s: %d" % [I18n.t("damage"), int(Cfg.PWEAPONS[str(f["melee"])]["damage"])]
		_free_reload.value = 0.0
	_free_hint.text = ""


func _build_pause() -> void:
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0, 0, 0, 0.5)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause.visible = false
	root.add_child(_pause)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(c)
	var p := PanelContainer.new()
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	_pause_title = _label("", 26)
	_pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_pause_title)
	_pause_sub = _label("", 16, Color(UiTheme.TEXT, 0.85))
	_pause_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_pause_sub)
	_pause_leave = _button("", func() -> void: action.emit("leaveFps", null), "danger")
	v.add_child(_pause_leave)
	# клик по фону паузы возвращает управление
	_pause.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			action.emit("resumeFps", null))


func _build_game_over() -> void:
	_over = Control.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_STOP
	_over.visible = false
	root.add_child(_over)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/tex/splash.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_over.add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(v)
	var ic := TextureRect.new()
	ic.texture = load("res://assets/tex/icon-zombie.png")
	ic.custom_minimum_size = Vector2(110, 110)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(ic)
	_over_title = _label("", 62, UiTheme.BAD)
	_over_title.add_theme_constant_override("outline_size", 10)
	_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_over_title)
	_over_lines = _label("", 22)
	_over_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_over_lines)
	_over_grid = GridContainer.new()
	_over_grid.columns = 5
	_over_grid.add_theme_constant_override("h_separation", 22)
	var og := CenterContainer.new()
	og.add_child(_over_grid)
	v.add_child(og)
	_over_restart = _button("", func() -> void: action.emit("restart", null), "primary")
	_over_restart.custom_minimum_size = Vector2(240, 46)
	v.add_child(_over_restart)
	_over_wait = _label("", 17, Color(UiTheme.TEXT, 0.85))
	_over_wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_over_wait)
	_over_menu = _button("", func() -> void: action.emit("toMenu", null))
	_over_menu.custom_minimum_size = Vector2(240, 40)
	v.add_child(_over_menu)


func _build_menu_overlay() -> void:
	_menu_overlay = ColorRect.new()
	(_menu_overlay as ColorRect).color = Color(0, 0, 0, 0.6)
	_menu_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_overlay.visible = false
	root.add_child(_menu_overlay)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_overlay.add_child(c)
	var p := PanelContainer.new()
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	_menu_title = _label("", 30)
	_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_menu_title)
	_options = OptionsPanel.new()
	v.add_child(_options)
	_menu_resume = _button("", func() -> void: action.emit("closeMenu", null), "primary")
	v.add_child(_menu_resume)
	_menu_exit = _button("", func() -> void: action.emit("toMenu", null), "danger")
	v.add_child(_menu_exit)


func _static_texts() -> void:
	_btn_lang.text = I18n.t("toggle_lang")
	_tlist_title.text = "%s (T)" % I18n.t("turrets")
	_tp_btn_up.text = I18n.t("upgrade")
	_tp_btn_sell.text = I18n.t("sell")
	_tp_btn_move.text = I18n.t("move")
	_btn_start.text = I18n.t("start_wave")
	_pause_title.text = I18n.t("pause_title")
	_pause_sub.text = I18n.t("pause_resume")
	_pause_leave.text = I18n.t("pause_leave")
	_over_title.text = I18n.t("city_destroyed")
	_over_restart.text = I18n.t("restart")
	_over_menu.text = I18n.t("to_menu")
	_over_wait.text = I18n.t("wait_host")
	_menu_title.text = I18n.t("paused")
	_menu_resume.text = I18n.t("resume")
	_menu_exit.text = I18n.t("to_menu")
	for k in _tp_rows.keys():
		_tp_rows[k]["k"].text = I18n.t(k) if k != "ammo" else I18n.t("ammo")


# ───────────────────────── публичное ─────────────────────────

func toast(text: String) -> void:
	_toast_lbl.text = text
	if _toast_tw != null:
		_toast_tw.kill()
	_toast.modulate.a = 1.0
	_toast_tw = create_tween()
	_toast_tw.tween_interval(1.5)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.3)


func banner(text: String) -> void:
	_banner.text = text
	if _banner_tw != null:
		_banner_tw.kill()
	_banner.modulate.a = 1.0
	_banner_tw = create_tween()
	_banner_tw.tween_interval(1.4)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.4)


func hit_marker() -> void:
	_cross.hit_t = 0.12


func set_conn(text: String) -> void:
	_conn.text = text


func set_pause(on: bool) -> void:
	_pause.visible = on


func show_menu(on: bool) -> void:
	_menu_overlay.visible = on


func menu_open() -> bool:
	return _menu_overlay.visible


## Прогресс перезарядки в FPS — вызывать каждый кадр.
func update_reload(reloading: bool, reload_time: float) -> void:
	if not reloading:
		_reload_start = 0.0
		_reload.value = 0.0
		return
	if _reload_start == 0.0:
		_reload_start = Time.get_ticks_msec() / 1000.0
	_reload.value = clampf((Time.get_ticks_msec() / 1000.0 - _reload_start) / maxf(reload_time, 0.1), 0.0, 1.0)


# ───────────────────────── обновление ─────────────────────────

func refresh() -> void:
	if st == null or not st.has_snap():
		return
	var s := st.snap
	var mine := st.my_turret()
	var in_fps := not mine.is_empty()
	var in_free := st.in_free_fps()
	var hide_ui := in_fps or in_free
	_top_left.visible = not hide_ui
	_right_box.visible = not hide_ui
	_hint.visible = not hide_ui
	_fps_root.visible = in_fps
	_free_root.visible = in_free
	_dead_panel.visible = st.is_dead() and not in_fps
	_dead_lbl.text = I18n.t("dead_banner")

	_lbl_wave.text = "%s: %d" % [I18n.t("wave"), int(s["wave"])]
	match str(s["state"]):
		"Preparation": _lbl_timer.text = "%s: %d" % [I18n.t("next_wave_in"), int(s["prep_left"])]
		"WaveRunning": _lbl_timer.text = I18n.t("wave_running")
		_: _lbl_timer.text = ""
	_lbl_money.text = "%s: $%d" % [I18n.t("money"), int(s["money"])]
	_lbl_walls.text = "%s: %d" % [I18n.t("walls"), int(s["walls_left"])]
	_lbl_turrets.text = "%s: %d" % [I18n.t("turrets"), int(s["turrets_left"])]
	_btn_start.visible = st.is_host() and str(s["state"]) == "Preparation" and not st.is_dead()
	_hint.text = I18n.t("hint_build") if st.is_host() else I18n.t("hint_guest")

	_refresh_incoming(s)
	_refresh_players(s)
	_refresh_turret_list(s)
	_refresh_tools(s)
	_refresh_turret_panel(s)
	_refresh_fps(s, mine)
	if in_free:
		_refresh_free(s)
	_refresh_game_over(s)


func _refresh_incoming(s: Dictionary) -> void:
	if str(s["state"]) != "Preparation":
		_incoming.visible = false
		return
	_incoming.visible = true
	var counts := {}
	for zt in Cfg.ZOMBIE_TYPES:
		counts[zt] = 0
	for z in Cfg.wave_composition(int(s["wave"])):
		counts[z] += 1
	var bb := "[color=#b9a58c]%s:[/color] " % I18n.t("incoming")
	for z in Cfg.ZOMBIE_TYPES:
		if counts[z] > 0:
			bb += "[color=%s]●[/color] %s ×%d   " % [ZOMBIE_COLOR[z], I18n.t("z_" + z), counts[z]]
	if bb != _sig_incoming:
		_sig_incoming = bb
		_incoming.text = bb


func _refresh_players(s: Dictionary) -> void:
	var sig := ""
	for p in s["players"]:
		sig += "%s|%s|%s|%s|%s;" % [p["id"], p["name"], p["is_host"], p["turret_id"], p.get("score", 0)]
	sig += I18n.lang
	if sig == _sig_players:
		return
	_sig_players = sig
	for c in _players.get_children():
		c.queue_free()
	for p in s["players"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var you := int(p["id"]) == st.my_id
		row.add_child(_label("%s%s" % [p["name"], " (%s)" % I18n.t("you") if you else ""], 14))
		row.add_child(_label("%d" % int(p.get("score", 0)), 13, UiTheme.ACCENT))
		if p["is_host"]:
			row.add_child(_label(I18n.t("host"), 11, UiTheme.ACCENT))
		if int(p["turret_id"]) != 0:
			row.add_child(_label(I18n.t("in_turret"), 11, Color(UiTheme.TEXT, 0.7)))
		_players.add_child(row)


func _refresh_turret_list(s: Dictionary) -> void:
	var turrets: Array = s["turrets"]
	var mine := st.my_turret()
	_tlist_panel.visible = not turrets.is_empty() and mine.is_empty() and not st.in_free_fps()
	var sig := "%d|" % st.selected_turret
	for t in turrets:
		sig += "%s:%s:%s;" % [t["id"], t["weapon"], t["level"]]
	if sig == _sig_tlist:
		return
	_sig_tlist = sig
	for c in _tlist_flow.get_children():
		c.queue_free()
	for t in turrets:
		var b := Button.new()
		b.icon = load(ICON[t["weapon"]])
		b.text = "L%d" % int(t["level"])
		b.toggle_mode = true
		b.button_pressed = int(t["id"]) == st.selected_turret
		b.custom_minimum_size = Vector2(56, 44)
		b.add_theme_constant_override("icon_max_width", 24)
		b.add_theme_font_size_override("font_size", 11)
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.tooltip_text = "%s #%d" % [I18n.t("w_" + str(t["weapon"])), int(t["id"])]
		var id := int(t["id"])
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			action.emit("selectTurret", id))
		_tlist_flow.add_child(b)


func _refresh_tools(s: Dictionary) -> void:
	var show := st.can_build() and st.my_turret().is_empty()
	_tools_panel.visible = show
	if not show:
		return
	var wall_info := "×%d" % int(s["walls_left"]) if int(s["walls_left"]) > 0 else "$%d" % Cfg.WALL_COST
	var items: Array = [
		{"key": "tool:select", "label": "1 · " + I18n.t("tool_select"), "sub": "", "icon": ICON["select"], "active": st.tool == "select", "tip": ""},
		{"key": "tool:wall", "label": "2 · " + I18n.t("tool_wall"), "sub": wall_info, "icon": ICON["wall"], "active": st.tool == "wall", "tip": ""},
		{"key": "tool:remove", "label": "3 · " + I18n.t("tool_remove"), "sub": "", "icon": ICON["remove"], "active": st.tool == "remove", "tip": ""},
	]
	for i in Cfg.WEAPON_TYPES.size():
		var w: String = Cfg.WEAPON_TYPES[i]
		var free := w == "gun" and int(s["turrets_left"]) > 0
		var stats := Cfg.turret_stats(1, w)
		items.append({
			"key": "weapon:" + w, "label": "%d · %s" % [4 + i, I18n.t("w_" + w)],
			"sub": "×%d" % int(s["turrets_left"]) if free else "$%d" % Cfg.turret_cost(w),
			"icon": ICON[w], "active": st.tool == "turret" and st.weapon == w,
			"tip": "%s: %s %s, %s %s m" % [I18n.t("w_" + w), I18n.t("damage"), str(snappedf(stats["damage"], 0.1)), I18n.t("range"), str(stats["range"])]})
	var sig := ""
	for it in items:
		sig += "%s|%s|%s|%s#" % [it["key"], it["label"], it["sub"], it["active"]]
	if sig == _sig_tools:
		return
	_sig_tools = sig
	for c in _tools_row.get_children():
		c.queue_free()
	for it in items:
		var b := Button.new()
		b.icon = load(it["icon"])
		b.text = it["label"] + ("\n" + it["sub"] if it["sub"] != "" else "\n ")
		b.toggle_mode = true
		b.button_pressed = it["active"]
		b.tooltip_text = it["tip"]
		b.custom_minimum_size = Vector2(104, 94)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 42)
		b.add_theme_constant_override("h_separation", 0)
		b.add_theme_font_size_override("font_size", 13)
		var key: String = it["key"]
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			var parts := key.split(":")
			action.emit("weapon" if parts[0] == "weapon" else "tool", parts[1]))
		_tools_row.add_child(b)


func _refresh_turret_panel(s: Dictionary) -> void:
	var t := st.turret_by_id(st.selected_turret)
	if t.is_empty() or not st.my_turret().is_empty() or st.in_free_fps():
		_tp.visible = false
		return
	_tp.visible = true
	var w := str(t["weapon"])
	var lvl := int(t["level"])
	var stats := Cfg.turret_stats(lvl, w)
	var can_next := lvl < int(Cfg.TURRET["max_level"])
	var nxt := Cfg.turret_stats(lvl + 1, w) if can_next else {}
	var cfg: Dictionary = Cfg.WEAPONS[w]
	_tp_title.text = "%s #%d" % [I18n.t("w_" + w), int(t["id"])]
	_row("level", "%s / %d" % [I18n.t("max") if not can_next else str(lvl), int(Cfg.TURRET["max_level"])])
	var dmg_suffix := " " + I18n.t("per_tick") if w == "flame" else ""
	_row("damage", "%s%s%s" % [_num(stats["damage"]), dmg_suffix, _up(stats["damage"], nxt.get("damage", stats["damage"]))])
	var dps: float = float(stats["damage"]) * float(stats["rate"])
	var dps_n: float = float(nxt.get("damage", stats["damage"])) * float(nxt.get("rate", stats["rate"]))
	_row("dps", "%d%s" % [int(round(dps)), _up(round(dps), round(dps_n), 0)])
	_row("range", "%.1f m%s" % [stats["range"], _up(stats["range"], nxt.get("range", stats["range"]), 1)])
	_row("fire_rate", "%.1f/s%s" % [stats["rate"], _up(stats["rate"], nxt.get("rate", stats["rate"]), 1)])
	var has_splash := float(cfg["splash"]) > 0.0
	_tp_rows["splash"]["k"].visible = has_splash
	_tp_rows["splash"]["v"].visible = has_splash
	if has_splash:
		_row("splash", "%s m" % str(cfg["splash"]))
	_row("hp", "%d / %d" % [int(t["hp"]), int(t["max_hp"])])
	_tp_rows["ammo"]["k"].text = I18n.t("fuel") if w == "flame" else I18n.t("ammo")
	_row("ammo", I18n.t("reloading") if bool(t["reloading"]) else "%d/%d" % [int(t["ammo"]), int(stats["mag"])])
	var build := st.can_build()
	var cost := Cfg.upgrade_cost(lvl, w)
	_tp_btn_up.text = "%s%s" % [I18n.t("upgrade"), " $%d" % cost if can_next else ""]
	_tp_btn_up.disabled = not build or not can_next or int(s["money"]) < cost
	_tp_btn_sell.text = "%s $%d" % [I18n.t("sell"), Cfg.sell_value(int(t["invested"]))]
	_tp_btn_sell.disabled = not build
	_tp_btn_move.disabled = not build
	_tp_btn_move.button_pressed = st.moving
	var busy := int(t["controlled_by"]) != 0 and int(t["controlled_by"]) != st.my_id
	_tp_btn_fps.disabled = busy or str(s["state"]) == "GameOver"
	_tp_hint.text = I18n.t("move_hint") if st.moving else ""


func _row(key: String, value: String) -> void:
	_tp_rows[key]["k"].text = I18n.t(key) if key != "ammo" else _tp_rows[key]["k"].text
	var v: RichTextLabel = _tp_rows[key]["v"]
	if v.text != value:
		v.text = value


static func _num(x: float) -> String:
	return str(snappedf(x, 0.1))


## Превью улучшения: зелёная стрелка со следующим значением.
static func _up(a: float, b: float, digits: int = 1) -> String:
	if is_equal_approx(a, b):
		return ""
	return "  [color=#8fbf4a]→ %s[/color]" % (str(snappedf(b, 0.1)) if digits > 0 else str(int(b)))


func _refresh_fps(s: Dictionary, mine: Dictionary) -> void:
	if mine.is_empty():
		return
	var w := str(mine["weapon"])
	var stats := Cfg.turret_stats(int(mine["level"]), w)
	_cross.weapon = w
	_fps_wave.text = "%s: %d  ·  $%d" % [I18n.t("wave"), int(s["wave"]), int(s["money"])]
	if bool(mine["reloading"]):
		_ammo_lbl.text = I18n.t("reloading")
	elif w == "flame":
		_ammo_lbl.text = "%s %d%%" % [I18n.t("fuel"), int(round(float(mine["ammo"]) / float(stats["mag"]) * 100.0))]
	else:
		_ammo_lbl.text = "%d / %d" % [int(mine["ammo"]), int(stats["mag"])]
	var dmg := snappedf(float(stats["damage"]) * float(Cfg.TURRET["fps_mul"]), 0.1)
	_fps_hint.text = "%s · %s %d · %s %s%s" % [I18n.t("w_" + w), I18n.t("level"), int(mine["level"]), I18n.t("damage"), str(dmg),
		" " + I18n.t("per_tick") if w == "flame" else ""]
	update_reload(bool(mine["reloading"]), float(stats["reload"]))


func _refresh_game_over(s: Dictionary) -> void:
	var over := str(s["state"]) == "GameOver"
	_over.visible = over
	if not over:
		return
	_over_lines.text = "%s: %d\n%s: %d\n%s: $%d" % [I18n.t("wave"), int(s["wave"]), I18n.t("zombies_killed"), int(s["killed"]),
		I18n.t("money_earned"), int(s["earned"])]
	_over_restart.visible = st.is_host()
	var rows: Array = []
	for p in _players_by_score(s):
		rows.append([str(rows.size() + 1), _pname(p), str(int(p.get("score", 0))), str(int(p.get("kills", 0))), str(int(p.get("deaths", 0))), int(p["id"]) == st.my_id])
	_fill_grid(_over_grid, [I18n.t("rank"), I18n.t("player"), I18n.t("score"), I18n.t("kills"), I18n.t("deaths")], rows)
	_over_wait.visible = not st.is_host()


# ───────────────────────── очки и рейтинг ─────────────────────────

func _build_scores() -> void:
	# рейтинг по итогам волны
	_report = PanelContainer.new()
	_report.mouse_filter = Control.MOUSE_FILTER_STOP
	_report.visible = false
	root.add_child(_report)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_report.add_child(v)
	_report_title = _label("", 24, UiTheme.ACCENT)
	_report_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_report_title)
	_report_grid = GridContainer.new()
	_report_grid.columns = 5
	_report_grid.add_theme_constant_override("h_separation", 22)
	_report_grid.add_theme_constant_override("v_separation", 4)
	v.add_child(_report_grid)
	_report_auto = _label("", 13, Color(UiTheme.TEXT, 0.7))
	_report_auto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_report_auto)
	var hint := _label("", 11, Color(UiTheme.TEXT, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_meta("i18n", "close_hint")
	v.add_child(hint)
	_report.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 170)
	_report.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_report.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_report.visible = false)
	# таблица счёта (удерживать Tab)
	_board = PanelContainer.new()
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.visible = false
	root.add_child(_board)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 8)
	_board.add_child(bv)
	var bt := _label("", 22, UiTheme.ACCENT)
	bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bt.set_meta("i18n", "scoreboard")
	bv.add_child(bt)
	_board_grid = GridContainer.new()
	_board_grid.columns = 5
	_board_grid.add_theme_constant_override("h_separation", 26)
	_board_grid.add_theme_constant_override("v_separation", 4)
	bv.add_child(_board_grid)
	_board.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_board.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_board.grow_vertical = Control.GROW_DIRECTION_BOTH
	# крупное сообщение на несколько секунд (новый тип врага)
	_announce = _label("", 21, Color("ffd9a0"))
	_announce.add_theme_constant_override("outline_size", 6)
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_announce.custom_minimum_size = Vector2(760, 0)
	_announce.modulate.a = 0.0
	_announce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_announce)
	_announce.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 172)
	_announce.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _pname(p: Dictionary) -> String:
	return "%s%s" % [p["name"], " (%s)" % I18n.t("you") if int(p["id"]) == st.my_id else ""]


func _players_by_score(s: Dictionary) -> Array:
	var list: Array = (s.get("players", []) as Array).duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("score", 0)) > int(b.get("score", 0)))
	return list


## Таблица: заголовки + строки [ячейки…, своя_строка: bool].
func _fill_grid(grid: GridContainer, headers: Array, rows: Array) -> void:
	for c in grid.get_children():
		c.queue_free()
	for h in headers:
		grid.add_child(_label(str(h), 13, Color(UiTheme.TEXT, 0.6)))
	for r in rows:
		var mine: bool = r[r.size() - 1]
		for i in r.size() - 1:
			var l := _label(str(r[i]), 17, UiTheme.ACCENT if mine else UiTheme.TEXT)
			if i >= 2:
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(l)


## Рейтинг по итогам волны: показывается 10 секунд (клик — закрыть).
func show_report(rep: Dictionary) -> void:
	_report_title.text = I18n.t("wave_rating") % int(rep["wave"])
	var rows: Array = []
	var rank := 0
	for r in rep["rows"]:
		rank += 1
		var name := "%s%s" % [r["name"], " (%s)" % I18n.t("you") if int(r["id"]) == st.my_id else ""]
		rows.append([str(rank), name, "+%d" % int(r["wave_score"]), str(int(r["wave_kills"])), str(int(r["score"])), int(r["id"]) == st.my_id])
	_fill_grid(_report_grid, [I18n.t("rank"), I18n.t("player"), I18n.t("wave_pts"), I18n.t("kills"), I18n.t("score")], rows)
	_report_auto.text = I18n.t("auto_kills") % int(rep["auto_kills"])
	for n in _report.find_children("*", "Label", true, false):
		if n.has_meta("i18n"):
			n.text = I18n.t(n.get_meta("i18n"))
	_report.visible = true
	_report.modulate.a = 1.0
	if _report_tw != null:
		_report_tw.kill()
	_report_tw = create_tween()
	_report_tw.tween_interval(10.0)
	_report_tw.tween_property(_report, "modulate:a", 0.0, 0.6)
	_report_tw.tween_callback(func() -> void: _report.visible = false)


func announce(text: String, secs: float = 6.0) -> void:
	_announce.text = text
	_announce.modulate.a = 1.0
	if _announce_tw != null:
		_announce_tw.kill()
	_announce_tw = create_tween()
	_announce_tw.tween_interval(secs)
	_announce_tw.tween_property(_announce, "modulate:a", 0.0, 0.6)


func _update_board() -> void:
	if _board == null or st == null or not st.has_snap():
		return
	var show := Input.is_key_pressed(KEY_TAB) and not menu_open()
	_board.visible = show
	if not show:
		return
	var rows: Array = []
	var sig := I18n.lang
	for p in _players_by_score(st.snap):
		rows.append([str(rows.size() + 1), _pname(p), str(int(p.get("score", 0))), str(int(p.get("kills", 0))), str(int(p.get("deaths", 0))), int(p["id"]) == st.my_id])
		sig += str(rows[rows.size() - 1])
	if sig == _board_sig:
		return
	_board_sig = sig
	for n in _board.find_children("*", "Label", true, false):
		if n.has_meta("i18n"):
			n.text = I18n.t(n.get_meta("i18n"))
	_fill_grid(_board_grid, [I18n.t("rank"), I18n.t("player"), I18n.t("score"), I18n.t("kills"), I18n.t("deaths")], rows)


# ───────────────────────── горячие клавиши (полоса сверху) ─────────────────────────

func _build_hotkeys() -> void:
	_hotkeys = PanelContainer.new()
	_hotkeys.add_theme_stylebox_override("panel", UiTheme.box(Color(0.06, 0.05, 0.04, 0.78), Color(1, 0.75, 0.4, 0.18), 0, 1, Vector4(12, 4, 12, 4)))
	_hotkeys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hotkeys)
	_hotkeys.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE)
	_hotkeys_lbl = _label("", 13, Color("e8d6b8"))
	_hotkeys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hotkeys_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hotkeys_lbl.clip_text = true
	_hotkeys.add_child(_hotkeys_lbl)


## Набор клавиш зависит от режима: стратегия, турель (FPS из башни), свободный FPS.
func _update_hotkeys() -> void:
	if _hotkeys_lbl == null or st == null or not st.has_snap():
		return
	var key := "hk_strategy"
	if st.in_free_fps():
		key = "hk_free"
	elif not st.my_turret().is_empty():
		key = "hk_turret"
	var txt := I18n.t(key)
	if _hotkeys_lbl.text != txt:
		_hotkeys_lbl.text = txt
	_hotkeys.visible = not menu_open()