class_name TurretRig
extends Node3D
## Модель турели: постамент, кольцо цвета уровня, поворотная голова (yaw) и наклоняемое оружие (pitch).
## Базовая турель — Kenney weapon-turret, остальные (пулемёт, ракетомёт, огнемёт) собраны из примитивов
## в той же ржаво-оливковой палитре. Ось ствола +Z, yaw=0 смотрит в +Z (как в симуляции).

const LEVEL_COLORS := [
	Color("8a929c"), Color("7fa3c7"), Color("5fbf9a"), Color("9bd05a"), Color("e0d24a"),
	Color("f0a63a"), Color("f0703a"), Color("e04a4a"), Color("c04ae0"), Color("ffd700"),
]

var weapon := "gun"
var level := 1
var head: Node3D            # вращается по yaw
var pivot: Node3D           # наклон по pitch
var muzzle: Marker3D        # точка дула (в системе pivot)
var spinner: Node3D         # вращающиеся стволы пулемёта
var pitch_scale := 1.0      # доля pitch, показываемая на модели
var cam_back := 0.8         # камера «из башни»: позади оси ствола и выше, м
var cam_up := 0.45
var base_z := 0.05          # положение pivot по оси ствола (для отдачи)
var _recoil := 0.0
var _spin := 0.0
var _mats: Array[StandardMaterial3D] = []


static func create(p_level: int, p_weapon: String) -> TurretRig:
	var r := TurretRig.new()
	r.level = p_level
	r.weapon = p_weapon
	r._build()
	return r


# ───────────── примитивы ─────────────

static func _mat(color: Color, metal: float = 0.5, rough: float = 0.65, emit: Color = Color.BLACK, emit_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	if emit_energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_energy
	return m


func _box(size: Vector3, m: Material, pos: Vector3 = Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


## Цилиндр вдоль оси Z (ствол) при along_z=true, иначе вдоль Y.
func _cyl(r_top: float, r_bot: float, h: float, m: Material, pos: Vector3, along_z: bool = false, parent: Node = null, segs: int = 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	if along_z:
		mi.rotation.x = PI / 2.0
	(parent if parent != null else self).add_child(mi)
	return mi


func _sphere(r: float, m: Material, pos: Vector3, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _build_base() -> Array:
	var accent: Color = LEVEL_COLORS[mini(level, LEVEL_COLORS.size()) - 1]
	var steel := _mat(Color("6b6053"), 0.55, 0.6)
	var dark := _mat(Color("2b2723"), 0.5, 0.7)
	var accent_m := _mat(accent, 0.4, 0.35, accent, 0.6)
	if weapon != "gun":
		_cyl(0.46, 0.5, 0.22, dark, Vector3(0, 0.11, 0), false, null, 20)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.38
	tor.outer_radius = 0.46
	tor.rings = 24
	tor.ring_segments = 8
	ring.mesh = tor
	ring.material_override = accent_m
	ring.position = Vector3(0, 0.24, 0)
	add_child(ring)
	if weapon != "gun":   # у базовой турели собственные ножки — стойка не нужна
		_cyl(0.22, 0.32, 0.7, steel, Vector3(0, 0.58, 0), false, null, 16)
	# точки-индикаторы уровня по кругу основания
	for i in level:
		var a := float(i) / 10.0 * TAU
		_sphere(0.035, accent_m, Vector3(sin(a) * 0.36, 0.26, cos(a) * 0.36))
	return [steel, dark, accent_m]


func _build() -> void:
	var m := _build_base()
	head = Node3D.new()
	add_child(head)
	pivot = Node3D.new()
	head.add_child(pivot)
	muzzle = Marker3D.new()
	pivot.add_child(muzzle)
	match weapon:
		"machinegun": _build_mg(m)
		"rocket": _build_rocket(m)
		"flame": _build_flame(m)
		_: _build_gun(m)
	base_z = pivot.position.z


## Базовая турель — модель turret_tripo.glb (ствол вдоль +X → поворот на -90° вокруг Y, чтобы ствол шёл по +Z).
const TRIPO_HALF := Vector3(0.49, 0.46, 0.40)   # половинные размеры исходной модели


func _build_gun(_m: Array) -> void:
	var s := 1.05 + level * 0.012
	var mi := Assets.tripo("turret_tripo")
	if mi != null:
		mi.rotation.y = -PI / 2.0
		mi.scale = Vector3.ONE * s
		head.position.y = 0.0
		pivot.position.y = TRIPO_HALF.y * s       # центр модели: ножки стоят на нулевом уровне
		pivot.add_child(mi)
		muzzle.position = Vector3(0, 0.27 * s, TRIPO_HALF.x * s + 0.02)
		pitch_scale = 0.0
		cam_back = 1.15
		cam_up = 0.85
	else:   # запасной вариант без модели
		head.position.y = 0.93
		_box(Vector3(0.5, 0.3, 0.6), _m[0], Vector3(0, 0.15, 0), pivot)
		_cyl(0.06, 0.07, 0.8, _m[1], Vector3(0, 0.2, 0.55), true, pivot)
		muzzle.position = Vector3(0, 0.2, 0.95)

func _build_mg(m: Array) -> void:
	var steel: StandardMaterial3D = m[0]
	var dark: StandardMaterial3D = m[1]
	var accent: StandardMaterial3D = m[2]
	var brass := _mat(Color("d9a441"), 0.7, 0.3)
	head.position.y = 1.05
	_box(Vector3(0.5, 0.34, 0.6), steel, Vector3.ZERO, head)
	_box(Vector3(0.4, 0.08, 0.5), accent, Vector3(0, 0.21, 0), head)
	_box(Vector3(0.22, 0.26, 0.3), dark, Vector3(0.34, -0.02, -0.05), head)
	for i in 6:   # лента патронов
		var b := _cyl(0.025, 0.025, 0.08, brass, Vector3(0.26 - i * 0.03, 0.06 + i * 0.012, 0.05 + i * 0.03), false, head, 6)
		b.rotation.z = PI / 2.0
	pivot.position = Vector3(0, 0.35, 0.05)
	spinner = Node3D.new()
	spinner.position.z = 0.42
	pivot.add_child(spinner)
	for i in 3:
		var a := float(i) / 3.0 * TAU
		_cyl(0.035, 0.04, 0.7, dark, Vector3(cos(a) * 0.07, sin(a) * 0.07, 0.1), true, spinner, 8)
	var shroud := _cyl(0.13, 0.13, 0.1, accent, Vector3(0, 0, 0.5), true, pivot)
	shroud.name = "Shroud"
	muzzle.position = Vector3(0, 0, 0.95)
	cam_back = 0.7
	cam_up = 0.42


func _build_rocket(m: Array) -> void:
	var steel: StandardMaterial3D = m[0]
	var dark: StandardMaterial3D = m[1]
	var accent: StandardMaterial3D = m[2]
	var olive := _mat(Color("5b6b3c"), 0.3, 0.7)
	var red := _mat(Color("d8432f"), 0.2, 0.5, Color("551108"), 0.5)
	head.position.y = 1.0
	_box(Vector3(0.7, 0.16, 0.36), steel, Vector3.ZERO, head)
	pivot.position = Vector3(0, 0.32, 0)
	_box(Vector3(0.62, 0.62, 0.9), olive, Vector3(0, 0, 0.15), pivot)
	for xy in [Vector2(-0.15, -0.15), Vector2(0.15, -0.15), Vector2(-0.15, 0.15), Vector2(0.15, 0.15)]:
		_cyl(0.11, 0.11, 0.2, dark, Vector3(xy.x, xy.y, 0.62), true, pivot)
		_cyl(0.0, 0.085, 0.22, red, Vector3(xy.x, xy.y, 0.66), true, pivot, 10)
	_box(Vector3(0.64, 0.06, 0.3), accent, Vector3(0, 0.34, 0.1), pivot)
	muzzle.position = Vector3(0, 0, 0.8)
	cam_back = 0.95
	cam_up = 0.62


func _build_flame(m: Array) -> void:
	var dark: StandardMaterial3D = m[1]
	var accent: StandardMaterial3D = m[2]
	var tank := _mat(Color("b8362a"), 0.4, 0.5)
	var ember := _mat(Color("ff8a2a"), 0.0, 0.5, Color("ff5a10"), 2.5)
	head.position.y = 1.05
	var tk := _cyl(0.2, 0.2, 0.55, tank, Vector3(0, 0.02, -0.2), false, head)
	tk.rotation.z = PI / 2.0
	for x in [0.15, -0.15]:
		var band := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.19
		tor.outer_radius = 0.22
		band.mesh = tor
		band.material_override = accent
		band.rotation.z = PI / 2.0
		band.position = Vector3(x, 0.02, -0.2)
		head.add_child(band)
	_sphere(0.07, dark, Vector3(0, 0.24, -0.2), head)
	pivot.position = Vector3(0, 0.28, 0.05)
	_cyl(0.06, 0.09, 0.62, dark, Vector3(0, 0, 0.35), true, pivot, 10)
	_cyl(0.1, 0.06, 0.12, accent, Vector3(0, 0, 0.7), true, pivot, 10)
	_sphere(0.045, ember, Vector3(0, 0.05, 0.78), pivot)
	# дежурное пламя запальника
	var pilot := OmniLight3D.new()
	pilot.light_color = Color("ff8a2a")
	pilot.light_energy = 0.8
	pilot.omni_range = 2.5
	pilot.position = Vector3(0, 0.05, 0.8)
	pilot.shadow_enabled = false
	pivot.add_child(pilot)
	muzzle.position = Vector3(0, 0, 0.85)
	cam_back = 0.6
	cam_up = 0.36


# ───────────── динамика ─────────────

## Поворачивает модель. Свою турель в FPS ставим точно по прицелу (без сглаживания).
func aim(yaw: float, p: float) -> void:
	head.rotation.y = yaw
	pivot.rotation.x = -p * pitch_scale


func kick() -> void:
	_recoil = 1.0


func spin_up() -> void:
	_spin = 28.0


func _process(delta: float) -> void:
	_recoil = maxf(0.0, _recoil - delta * 8.0)
	pivot.position.z = base_z - _recoil * 0.12
	if spinner != null:
		_spin = maxf(0.0, _spin - delta * 40.0)
		spinner.rotation.z += _spin * delta


## Показать только оружие (для FPS: постамент и корпус не закрывают обзор) или всё.
func show_only_weapon(only: bool) -> void:
	for c in get_children():
		if c != head:
			c.visible = not only
	for c in head.get_children():
		if c != pivot:
			c.visible = not only
