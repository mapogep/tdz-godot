class_name ViewModel
extends Node3D
## Оружие «от первого лица» (свободный FPS): АК-47 и холодное оружие (мачете или топор) — сгенерированные модели
## (assets/models/baked, tools/bake_all.gd). Крепится к камере. Анимации: покачивание при ходьбе, инерция от поворота
## мыши, отдача и вспышка выстрела, перезарядка (оружие уходит вниз и поворачивается), замах/удар, смена оружия, бег.

var weapon := "ak"           # ak | machete | axe (то, что сейчас в руках)
var _shown := "ak"
var _pending := ""
var _swap := 0.0             # 0 — оружие поднято, 1 — опущено
var _swap_dir := 0.0         # +1 опускаем, -1 поднимаем, 0 — покой
var _holder: Node3D
var _nodes: Dictionary = {}  # имя -> Node3D
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

# положение в кадре (система камеры: -Z вперёд), поворот и длина модели
const BASE := {
	"ak": {"pos": Vector3(0.25, -0.21, -0.5), "rot": Vector3(0.05, 0.26, -0.2), "len": 0.72},
	"machete": {"pos": Vector3(0.24, -0.3, -0.5), "rot": Vector3(-0.75, 0.25, -0.35), "len": 0.62},
	"axe": {"pos": Vector3(0.25, -0.34, -0.52), "rot": Vector3(-0.6, 0.2, -0.25), "len": 0.7},
}


func _init() -> void:
	_holder = Node3D.new()
	add_child(_holder)
	for n in ["ak", "machete", "axe"]:
		var node := Node3D.new()
		node.name = n
		_holder.add_child(node)
		_nodes[n] = node
		var mi := PlayerRig.weapon_mesh("ak47" if n == "ak" else n, float(BASE[n]["len"]))
		if mi != null:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# своё оружие не должно «проваливаться» в стены — рисуем поверх (без теста глубины сцены не обойтись,
			# поэтому просто держим его близко к камере)
			node.add_child(mi)
			if n == "ak":
				var bb: AABB = mi.mesh.get_meta("aabb", mi.mesh.get_aabb())
				_flash = _make_flash()
				_flash.position = Vector3(0, (bb.position.y + bb.size.y * 0.72) * mi.scale.y, bb.position.z * mi.scale.z - 0.03)
				node.add_child(_flash)
	if _flash == null:
		_flash = _make_flash()
		(_nodes["ak"] as Node3D).add_child(_flash)
	set_weapon_now("ak")


func _make_flash() -> Node3D:
	var f := Node3D.new()
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
		qm.size = Vector2(0.16, 0.16)
		q.mesh = qm
		q.material_override = fm
		q.rotation.z = a
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.add_child(q)
	var side := MeshInstance3D.new()
	var sm := QuadMesh.new()
	sm.size = Vector2(0.26, 0.07)
	side.mesh = sm
	side.material_override = fm
	side.rotation.y = PI / 2.0
	side.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(side)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.position = Vector3(0, 0, -0.3)
	f.add_child(light)
	f.visible = false
	return f


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


## Точка дула в мировых координатах (для искр и гильз).
func muzzle_global() -> Vector3:
	return _flash.global_position


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
	pos += Vector3(0.03, -0.06, 0.03) * _sprint_k
	rot += Vector3(0.3, 0.4, 0.1) * _sprint_k
	# отдача
	pos.z += _recoil * 0.05
	pos.y += _recoil * 0.008
	rot.x += _recoil * 0.07
	# смена оружия
	pos.y -= _swap * 0.4
	rot.x -= _swap * 0.5

	if _reload_t >= 0.0 and _shown == "ak":
		# перезарядка: автомат уходит вниз и заваливается на бок, «рывок» при смене магазина, возврат
		_reload_t += delta / _reload_len
		var t := _reload_t
		var tilt := sin(clampf(t, 0.0, 1.0) * PI)
		var jerk := smoothstep(0.45, 0.5, t) - smoothstep(0.5, 0.6, t)
		pos += Vector3(-0.04, -0.09, 0.03) * tilt + Vector3(0, 0.025, 0) * jerk
		rot += Vector3(0.45, -0.3, 0.7) * tilt
		if _reload_t >= 1.0:
			_reload_t = -1.0

	if _swing_t >= 0.0 and _shown != "ak":
		_swing_t += delta / _swing_len
		var t := _swing_t
		var wind := smoothstep(0.0, 0.22, t)
		var strike := smoothstep(0.22, 0.42, t)
		var recover := smoothstep(0.55, 1.0, t)
		var a := (wind * 0.25 + strike * 0.75) * (1.0 - recover)
		# замах назад-вверх, удар наискосок вниз влево
		pos += Vector3(-0.3, 0.02, -0.14) * a + Vector3(0.05, 0.1, 0.06) * wind * (1.0 - strike)
		rot += Vector3(-1.1, 0.4, 1.2) * a + Vector3(0.9, 0.0, -0.3) * wind * (1.0 - strike)
		if _swing_t >= 1.0:
			_swing_t = -1.0

	_holder.position = pos
	_holder.rotation = rot
