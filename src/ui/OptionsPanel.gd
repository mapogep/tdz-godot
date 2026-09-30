class_name OptionsPanel
extends VBoxContainer
## Настройки: качество графики, громкость, полный экран, язык. Используется в главном меню и в паузе.

signal quality_changed(q: String)

var _q: OptionButton
var _vol: HSlider
var _full: CheckButton
var _lang_btn: Button
var _lbl_q: Label
var _lbl_v: Label


func _init() -> void:
	add_theme_constant_override("separation", 10)
	_lbl_q = Label.new()
	add_child(_lbl_q)
	_q = OptionButton.new()
	for i in Settings.QUALITIES.size():
		_q.add_item("", i)
	_q.selected = Settings.q_index()
	_q.item_selected.connect(func(i: int) -> void:
		Settings.set_quality(Settings.QUALITIES[i])
		quality_changed.emit(Settings.QUALITIES[i])
		Sfx.play("click"))
	add_child(_q)
	_lbl_v = Label.new()
	add_child(_lbl_v)
	_vol = HSlider.new()
	_vol.min_value = 0.0
	_vol.max_value = 1.0
	_vol.step = 0.05
	_vol.value = Settings.volume
	_vol.custom_minimum_size = Vector2(260, 22)
	_vol.value_changed.connect(func(v: float) -> void: Settings.set_volume(v))
	add_child(_vol)
	_full = CheckButton.new()
	_full.button_pressed = Settings.fullscreen
	_full.toggled.connect(func(v: bool) -> void: Settings.set_fullscreen(v))
	add_child(_full)
	_lang_btn = Button.new()
	_lang_btn.pressed.connect(func() -> void:
		I18n.toggle()
		Settings.save_settings())
	add_child(_lang_btn)
	I18n.language_changed.connect(_texts)
	_texts()


func _texts() -> void:
	_lbl_q.text = I18n.t("opt_quality")
	for i in Settings.QUALITIES.size():
		_q.set_item_text(i, I18n.t("q_" + Settings.QUALITIES[i]))
	_lbl_v.text = I18n.t("opt_volume")
	_full.text = I18n.t("opt_fullscreen")
	_lang_btn.text = "%s: %s" % [I18n.t("opt_language"), I18n.t("toggle_lang")]
