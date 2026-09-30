class_name ViewModel
extends Node3D
## Оружие «от первого лица» (свободный FPS): АК-47 и холодное оружие (мачете или топор), собранные из примитивов
## в ржаво-оливковой палитре игры. Крепится к камере. Анимации: покачивание при ходьбе, инерция от поворота мыши,
## отдача и вспышка выстрела, перезарядка (магазин отсоединяется и вставляется), замах/удар, смена оружия, спринт.

var weapon := "ak"           # ak | machete | axe (то, что сейчас в руках)
var _shown := "ak"
var _pending := ""
var _swap := 0.0             # 0 — оружие поднято, 1 — опущено
var _swap_dir := 0.0         # +1 опускаем, -1 поднимаем, 0 — покой
var _holder: Node3D
var _nodes: Dictionary = {}  # имя -> Node3D
var _mag: Node3D
var _flash: Node3D
var _flash_t := 0.0
var _recoil := 0.0
var _swing_t := -1.0
var _swing_len := 0.55
var _reload_t := -1.0
var _reload_len := 2.3
var _phase := 0.0
var _sway := Vector2.ZERO
var _sprint_k := 0.0
var _mats: Dictionary = {}

const BASE := {
	"ak": {"pos": Vector3(0.14, -0.175, -0.47), "rot": Vector3(0.02, 0.05, 0.0), "scale": 0.7},
	"machete": {"pos": Vector3(0.22, -0.2, -0.55), "rot": Vector3(-0.35, 0.2, -0.5), "scale": 0.75},
	"axe": {"pos": Vector3(0.22, -0.17, -0.58), "rot": Vector3(-0.25, 0.1, -0.3), "scale": 0.62},
}


func _init() -> void:
	_mats = {
		"steel": _mat(Color("2a2c2b"), 0.75, 0.42),
		"steel_l": _mat(Color("8d9091"), 0.9, 0.28),
		"wood": _mat(Color("6b3a17"), 0.0, 0.6),
		"wood_d": _mat(Color("3d2410"), 0.0, 0.7),
		"glove": _mat(Color("2b2620"), 0.0, 0.9),
		"sleeve": _mat(Color("3a3e2b"), 0.0, 0.95),
		"skin": _mat(Color("a57c62"), 0.0, 0.85),
		"rag": _mat(Color("6d6a5a"), 0.0, 1.0),
	}
	_holder = Node3D.new()
	_holder.scale = Vector3.ONE * 0.7
	add_child(_holder)
	_build_ak()
	_build_machete()
	_build_axe()
	set_weapon_now("ak")


static func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mats[mat]
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 1
	mi.mesh = c
	mi.material_override = _mats[mat]
	mi.position = pos
	mi.rotation.x = PI / 2.0        # вдоль оси Z
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _hands_ak(n: Node3D) -> void:
	_box(n, Vector3(0.062, 0.07, 0.095), Vector3(0.004, -0.085, 0.078), "glove")          # правая рука на рукоятке
	_box(n, Vector3(0.06, 0.07, 0.22), Vector3(0.03, -0.13, 0.22), "sleeve", Vector3(0.25, -0.1, 0.0))
	_box(n, Vector3(0.07, 0.06, 0.12), Vector3(0.0, -0.055, -0.3), "glove")               # левая — на цевье
	_box(n, Vector3(0.065, 0.06, 0.26), Vector3(-0.09, -0.11, -0.12), "sleeve", Vector3(0.1, 0.55, 0.0))


func _build_ak() -> void:
	var n := Node3D.new()
	n.name = "ak"
	_box(n, Vector3(0.046, 0.062, 0.3), Vector3(0, 0, -0.05), "steel")                      # ствольная коробка
	_box(n, Vector3(0.04, 0.02, 0.29), Vector3(0, 0.04, -0.05), "steel")                    # крышка ствольной коробки
	_box(n, Vector3(0.032, 0.022, 0.035), Vector3(0, 0.058, 0.07), "steel")                 # целик
	_box(n, Vector3(0.052, 0.05, 0.2), Vector3(0, -0.012, -0.31), "wood")                   # цевьё
	_box(n, Vector3(0.046, 0.02, 0.17), Vector3(0, 0.032, -0.32), "wood_d")                 # верхняя накладка
	_cyl(n, 0.0095, 0.42, Vector3(0, 0.01, -0.5), "steel")                                  # ствол
	_cyl(n, 0.0075, 0.26, Vector3(0, 0.05, -0.37), "steel")                                 # газовая трубка
	_box(n, Vector3(0.008, 0.038, 0.012), Vector3(0, 0.046, -0.66), "steel")                # мушка
	_cyl(n, 0.0135, 0.05, Vector3(0, 0.01, -0.72), "steel")                                 # дульный тормоз
	_mag = Node3D.new()
	n.add_child(_mag)
	_box(_mag, Vector3(0.032, 0.14, 0.055), Vector3(0, -0.105, -0.07), "steel", Vector3(-0.16, 0, 0))
	_box(_mag, Vector3(0.032, 0.1, 0.055), Vector3(0, -0.205, -0.115), "steel", Vector3(-0.5, 0, 0))
	_box(n, Vector3(0.032, 0.1, 0.042), Vector3(0, -0.078, 0.078), "wood_d", Vector3(0.35, 0, 0))   # рукоятка
	_box(n, Vector3(0.012, 0.006, 0.07), Vector3(0, -0.038, 0.03), "steel")                 # спусковая скоба
	_box(n, Vector3(0.042, 0.078, 0.21), Vector3(0, -0.02, 0.245), "wood", Vector3(-0.1, 0, 0))     # приклад
	_box(n, Vector3(0.046, 0.09, 0.015), Vector3(0, -0.028, 0.35), "steel", Vector3(-0.1, 0, 0))    # затыльник
	_hands_ak(n)
	# вспышка выстрела
	_flash = Node3D.new()
	_flash.position = Vector3(0, 0.01, -0.77)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.82, 0.4, 0.95)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.6, 0.2)
	fm.emission_energy_multiplier = 3.5
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for a in [0.0, PI / 2.0, PI / 4.0]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.2, 0.2)
		q.mesh = qm
		q.material_override = fm
		q.rotation.z = a
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flash.add_child(q)
	var side := MeshInstance3D.new()
	var sm := QuadMesh.new()
	sm.size = Vector2(0.3, 0.08)
	side.mesh = sm
	side.material_override = fm
	side.rotation.y = PI / 2.0
	side.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.add_child(side)
	_flash.visible = false
	n.add_child(_flash)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 2.2
	light.omni_range = 5.0
	light.shadow_enabled = false
	_flash.add_child(light)
	_holder.add_child(n)
	_nodes["ak"] = n


func _hand_melee(n: Node3D, at: Vector3) -> void:
	_box(n, Vector3(0.07, 0.07, 0.1), at, "glove")
	_box(n, Vector3(0.08, 0.08, 0.36), at + Vector3(0.02, -0.05, 0.25), "sleeve", Vector3(0.25, -0.08, 0.0))


func _build_machete() -> void:
	var n := Node3D.new()
	n.name = "machete"
	_box(n, Vector3(0.03, 0.036, 0.14), Vector3(0, 0, 0), "wood_d")                          # рукоять
	_box(n, Vector3(0.05, 0.016, 0.02), Vector3(0, 0, -0.078), "steel")                       # гарда
	_box(n, Vector3(0.006, 0.048, 0.24), Vector3(0, 0.004, -0.2), "steel_l")                  # клинок, основание
	_box(n, Vector3(0.006, 0.062, 0.2), Vector3(0, 0.014, -0.41), "steel_l", Vector3(0.0, 0.0, 0.0))   # расширение к острию
	_box(n, Vector3(0.006, 0.05, 0.07), Vector3(0, 0.008, -0.55), "steel_l", Vector3(-0.28, 0, 0))     # острие
	_box(n, Vector3(0.008, 0.006, 0.44), Vector3(0, 0.042, -0.3), "steel")                    # обух
	_hand_melee(n, Vector3(0, 0, 0.01))
	n.visible = false
	_holder.add_child(n)
	_nodes["machete"] = n


func _build_axe() -> void:
	var n := Node3D.new()
	n.name = "axe"
	_box(n, Vector3(0.032, 0.034, 0.6), Vector3(0, 0, -0.2), "wood")                          # топорище
	_box(n, Vector3(0.036, 0.04, 0.05), Vector3(0, 0, 0.12), "wood_d")                        # навершие
	_box(n, Vector3(0.034, 0.1, 0.09), Vector3(0, 0.03, -0.46), "steel")                      # обух
	_box(n, Vector3(0.012, 0.19, 0.05), Vector3(0, 0.04, -0.525), "steel_l", Vector3(0.0, 0.0, 0.0))   # лезвие
	_box(n, Vector3(0.036, 0.04, 0.07), Vector3(0, -0.05, -0.44), "steel")                    # крепление
	_hand_melee(n, Vector3(0, 0, 0.02))
	_hand_melee(n, Vector3(0.005, 0.0, -0.12))
	n.visible = false
	_holder.add_child(n)
	_nodes["axe"] = n


# ───────────── управление ─────────────

func set_weapon_now(w: String) -> void:
	weapon = w
	_shown = w
	_pending = ""
	_swap = 0.0
	_swap_dir = 0.0
	for k in _nodes.keys():
		(_nodes[k] as Node3D).visible = k == w


## Плавная смена оружия (текущее опускается, новое поднимается).
func switch_to(w: String) -> void:
	if w == weapon and _pending == "":
		return
	if w == _shown and _swap_dir == 0.0:
		return
	_pending = w
	weapon = w
	_swap_dir = 1.0
	_swing_t = -1.0
	_reload_t = -1.0


func fire() -> void:
	_recoil = minf(1.0, _recoil + 0.6)
	_flash_t = 0.045
	_flash.visible = true
	_flash.rotation.z = randf() * TAU
	_flash.scale = Vector3.ONE * randf_range(0.8, 1.25)


func swing(duration: float) -> void:
	_swing_t = 0.0
	_swing_len = maxf(duration, 0.2)


func reload(duration: float) -> void:
	_reload_t = 0.0
	_reload_len = maxf(duration, 0.5)


func is_busy() -> bool:
	return _swap_dir != 0.0 or _reload_t >= 0.0


## Вызывать каждый кадр. move — скорость (0..1), look — поворот мыши за кадр (рад), sprint — бег.
func update(delta: float, move: float, look: Vector2, sprint: bool) -> void:
	# смена оружия
	if _swap_dir != 0.0:
		_swap += _swap_dir * delta * 5.5
		if _swap_dir > 0.0 and _swap >= 1.0:
			_swap = 1.0
			_shown = _pending if _pending != "" else weapon
			for k in _nodes.keys():
				(_nodes[k] as Node3D).visible = k == _shown
			_swap_dir = -1.0
			_pending = ""
		elif _swap_dir < 0.0 and _swap <= 0.0:
			_swap = 0.0
			_swap_dir = 0.0
	_recoil = maxf(0.0, _recoil - delta * 9.0)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.visible = false
	_phase += delta * (5.5 + 3.5 * float(sprint)) * clampf(move, 0.0, 1.0)
	_sprint_k = lerpf(_sprint_k, 1.0 if (sprint and move > 0.1) else 0.0, 1.0 - exp(-delta * 8.0))
	# инерция от поворота: оружие чуть запаздывает за мышью
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-delta * 9.0))
	_sway += Vector2(clampf(look.x, -0.05, 0.05), clampf(look.y, -0.05, 0.05)) * 1.6
	_sway = _sway.limit_length(0.09)

	var base: Dictionary = BASE[_shown]
	var pos: Vector3 = base["pos"]
	var rot: Vector3 = base["rot"]
	var bob := clampf(move, 0.0, 1.0)
	pos += Vector3(sin(_phase) * 0.008, absf(cos(_phase)) * -0.008 - 0.003 * sin(_phase * 2.0), 0.0) * bob
	pos += Vector3(_sway.x * 0.35, -_sway.y * 0.25, 0.0)
	rot += Vector3(_sway.y * 0.45, _sway.x * 0.55, 0.0)
	# бег: оружие опускается и заваливается
	pos += Vector3(0.03, -0.05, 0.03) * _sprint_k
	rot += Vector3(0.28, 0.35, 0.08) * _sprint_k
	# отдача
	pos.z += _recoil * 0.05
	pos.y += _recoil * 0.008
	rot.x += _recoil * 0.06
	# смена оружия
	pos.y -= _swap * 0.38
	rot.x -= _swap * 0.5

	if _reload_t >= 0.0 and _shown == "ak":
		_reload_t += delta / _reload_len
		var t := _reload_t
		var tilt := sin(clampf(t, 0.0, 1.0) * PI)
		pos += Vector3(-0.03, -0.06, 0.02) * tilt
		rot += Vector3(0.35, -0.25, 0.4) * tilt
		# магазин: вниз и в сторону, затем обратно
		var out := smoothstep(0.18, 0.36, t) - smoothstep(0.58, 0.76, t)
		_mag.position = Vector3(-0.02, -0.16, -0.02) * out
		_mag.rotation.z = 0.3 * out
		if _reload_t >= 1.0:
			_reload_t = -1.0
			_mag.position = Vector3.ZERO
			_mag.rotation = Vector3.ZERO
	elif _shown != "ak":
		_mag.position = Vector3.ZERO

	if _swing_t >= 0.0 and _shown != "ak":
		_swing_t += delta / _swing_len
		var t := _swing_t
		var wind := smoothstep(0.0, 0.22, t)
		var strike := smoothstep(0.22, 0.42, t)
		var recover := smoothstep(0.55, 1.0, t)
		var a := (wind * 0.25 + strike * 0.75) * (1.0 - recover)
		pos += Vector3(-0.28, 0.04, -0.12) * a + Vector3(0.05, 0.05, 0.05) * wind * (1.0 - strike)
		rot += Vector3(-0.55, 0.5, 1.5) * a + Vector3(0.5, 0.0, -0.4) * wind * (1.0 - strike)
		if _swing_t >= 1.0:
			_swing_t = -1.0

	_holder.position = pos
	_holder.rotation = rot
	_holder.scale = Vector3.ONE * float(base["scale"])
	_holder.scale = Vector3.ONE * float(base["scale"])
