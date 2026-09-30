extends Node
## Настройки игрока (язык, качество графики, громкость) — хранятся в user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"
const QUALITIES := ["low", "medium", "high", "ultra"]

var quality := "high"
var volume := 0.8
var fullscreen := false
var mouse_sens := 0.0022


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	quality = str(cf.get_value("game", "quality", quality))
	volume = float(cf.get_value("game", "volume", volume))
	fullscreen = bool(cf.get_value("game", "fullscreen", fullscreen))
	mouse_sens = float(cf.get_value("game", "mouse_sens", mouse_sens))
	I18n.lang = str(cf.get_value("game", "lang", I18n.lang))
	if not QUALITIES.has(quality):
		quality = "high"


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "quality", quality)
	cf.set_value("game", "volume", volume)
	cf.set_value("game", "fullscreen", fullscreen)
	cf.set_value("game", "mouse_sens", mouse_sens)
	cf.set_value("game", "lang", I18n.lang)
	cf.save(PATH)


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(volume, 0.0, 1.0)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	changed.emit()


func set_quality(q: String) -> void:
	quality = q
	save_settings()
	apply()


func set_volume(v: float) -> void:
	volume = v
	save_settings()
	apply()


func set_fullscreen(v: bool) -> void:
	fullscreen = v
	save_settings()
	apply()


## Индекс качества 0..3.
func q_index() -> int:
	return QUALITIES.find(quality)
