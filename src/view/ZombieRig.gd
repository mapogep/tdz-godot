class_name ZombieRig
extends Node3D
## Оригинальный зомби-«шаркун»: сутулый, в рваной белой рубашке и тёмных брюках, серо-землистая кожа, раны,
## неровная походка (одна нога подволакивается, голова свесилась). Стилизованный low-poly в общей палитре.
## Три типа различаются размером и окраской (толстый — крупный и тёмный, быстрый — мелкий и желтовато-бледный).

var type := "normal"
var top_y := 1.95            # высота полоски HP над головой
var _mats: Array[StandardMaterial3D] = []
var _leg_l: Node3D
var _knee_l: Node3D
var _leg_r: Node3D
var _knee_r: Node3D
var _torso: Node3D
var _neck: Node3D
var _arm_l: Node3D
var _elbow_l: Node3D
var _arm_r: Node3D
var _elbow_r: Node3D
var _flash := 0.0
var _burning := false
var _body: Node3D
var _skel_root: Node3D          # сцена zombie_rigged.tscn (скелет + AnimationPlayer)
var _anim: AnimationPlayer
var _mode := ""
var _last_phase := 0.0
var _still := 0.0
static var _shirt_tex: ImageTexture


static func create(p_type: String) -> ZombieRig:
	var z := ZombieRig.new()
	z.type = p_type
	z._build()
	return z


static func _mat(color: Color, rough: float = 0.95, tex: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.0
	if tex != null:
		m.albedo_texture = tex
	m.emission_enabled = true
	m.emission = Color(1.0, 0.25, 0.08)
	m.emission_energy_multiplier = 0.0
	return m


## Текстура рубашки: грязно-белая ткань, складки, потёки и брызги крови (рисуется кодом, оригинальная).
static func _shirt_texture() -> ImageTexture:
	if _shirt_tex != null:
		return _shirt_tex
	var S := 128
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color("c9c2b0"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in 30:   # грязь и складки
		var c := Color(0.27, 0.23, 0.18, 0.05 + rng.randf() * 0.12)
		var rect := Rect2i(rng.randi_range(0, S - 1), rng.randi_range(0, S - 1), rng.randi_range(4, 32), rng.randi_range(1, 5))
		_blend_rect(img, rect, c)
	for i in 16:   # кровавые пятна и потёки
		var cx := rng.randi_range(0, S - 1)
		var cy := rng.randi_range(0, S - 1)
		var r := rng.randi_range(3, 11)
		var col := Color(0.38 + rng.randf() * 0.2, 0.04 + rng.randf() * 0.06, 0.03 + rng.randf() * 0.04, 0.55 + rng.randf() * 0.4)
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if x * x + y * y <= r * r:
					_blend_px(img, cx + x, cy + y, col)
		_blend_rect(img, Rect2i(cx - 1, cy, rng.randi_range(2, 4), rng.randi_range(10, 26)), col)
	img.generate_mipmaps()
	_shirt_tex = ImageTexture.create_from_image(img)
	return _shirt_tex


static func _blend_px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var b := img.get_pixel(x, y)
	img.set_pixel(x, y, b.lerp(Color(c.r, c.g, c.b, 1.0), c.a))


static func _blend_rect(img: Image, r: Rect2i, c: Color) -> void:
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			_blend_px(img, x, y, c)


func _part(size: Vector3, m: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build() -> void:
	if _build_rigged():
		return
	var skin := _mat(Color("9a9c86"))
	var flesh := _mat(Color("7a2a26"), 0.8)
	var shirt := _mat(Color.WHITE, 1.0, _shirt_texture())
	var pants := _mat(Color("2c2e27"), 1.0)
	var shoe := _mat(Color("1c1a17"), 0.9)
	var hair := _mat(Color("3d2a20"), 1.0)
	var mouth := _mat(Color("2a0f0d"), 1.0)
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color("e8e6d0")
	eye.emission_enabled = true
	eye.emission = Color("bdb890")
	eye.emission_energy_multiplier = 0.7
	var flash_mats: Array[StandardMaterial3D] = [skin, flesh, shirt, pants, shoe, hair]
	_mats = flash_mats

	_body = Node3D.new()      # общий масштаб: рост ≈ 1,78 м
	_body.scale = Vector3.ONE * 0.88
	add_child(_body)

	# ноги: бедро–голень с шарниром в колене, ботинки; правая подволакивается
	var legs: Array = []
	for x in [-0.13, 0.13]:
		var hip := Node3D.new()
		hip.position = Vector3(x, 0.9, 0)
		_part(Vector3(0.2, 0.46, 0.22), pants, Vector3(0, -0.23, 0), hip)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.46, 0)
		_part(Vector3(0.17, 0.42, 0.19), pants, Vector3(0, -0.21, 0), knee)
		_part(Vector3(0.19, 0.11, 0.32), shoe, Vector3(0, -0.45, 0.06), knee)
		_part(Vector3(0.19, 0.06, 0.2), flesh, Vector3(0.005, -0.28, 0.005), knee)   # прорванная штанина
		hip.add_child(knee)
		_body.add_child(hip)
		legs.append([hip, knee])
	_leg_l = legs[0][0]
	_knee_l = legs[0][1]
	_leg_r = legs[1][0]
	_knee_r = legs[1][1]

	# корпус: таз, рубашка навыпуск, распахнутый ворот, рана на груди
	_torso = Node3D.new()
	_torso.position.y = 0.9
	_body.add_child(_torso)
	_part(Vector3(0.42, 0.18, 0.26), pants, Vector3(0, 0.02, 0), _torso)
	_part(Vector3(0.5, 0.6, 0.29), shirt, Vector3(0, 0.42, 0), _torso)
	var tail := _part(Vector3(0.52, 0.32, 0.31), shirt, Vector3(0, 0.13, 0), _torso)
	for i in 5:   # рваный подол
		_part(Vector3(0.07, 0.1 + (i % 2) * 0.06, 0.32), shirt, Vector3(-0.2 + i * 0.1, -0.2, 0), tail)
	_part(Vector3(0.16, 0.24, 0.02), skin, Vector3(0, 0.62, 0.15), _torso)
	_part(Vector3(0.12, 0.1, 0.02), flesh, Vector3(-0.12, 0.42, 0.155), _torso)

	# шея и голова: свесилась набок, раскрытый рот, молочные глаза, клок волос
	_neck = Node3D.new()
	_neck.position = Vector3(0, 0.74, 0.02)
	_torso.add_child(_neck)
	_part(Vector3(0.11, 0.14, 0.11), skin, Vector3(0, 0.06, 0), _neck)
	_part(Vector3(0.09, 0.07, 0.05), flesh, Vector3(0.05, 0.05, 0.05), _neck)
	var head := Node3D.new()
	head.position = Vector3(0, 0.2, 0.02)
	_neck.add_child(head)
	var skull := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.145
	sm.height = 0.29
	sm.radial_segments = 10
	sm.rings = 6
	skull.mesh = sm
	skull.material_override = skin
	skull.scale = Vector3(0.92, 1.12, 0.98)
	skull.position.y = 0.06
	head.add_child(skull)
	var cap := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.155
	cm.height = 0.155
	cm.is_hemisphere = true
	cm.radial_segments = 10
	cm.rings = 4
	cap.mesh = cm
	cap.material_override = hair
	cap.position = Vector3(0.01, 0.1, -0.015)
	cap.rotation.x = -0.25
	head.add_child(cap)
	_part(Vector3(0.13, 0.05, 0.11), mouth, Vector3(0, -0.06, 0.07), head)
	for x in [-0.055, 0.055]:
		var e := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.03
		em.height = 0.06
		em.radial_segments = 8
		em.rings = 4
		e.mesh = em
		e.material_override = eye
		e.position = Vector3(x, 0.08, 0.125)
		head.add_child(e)
	_part(Vector3(0.05, 0.06, 0.02), flesh, Vector3(0.09, 0.02, 0.11), head)

	# руки: вялые; левая протянута вперёд
	var arms: Array = []
	for side in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(0.33 * side, 0.66, 0)
		_part(Vector3(0.17, 0.34, 0.17), shirt, Vector3(0, -0.17, 0), sh)
		var el := Node3D.new()
		el.position = Vector3(0, -0.34, 0)
		_part(Vector3(0.12, 0.34, 0.12), skin if side < 0.0 else shirt, Vector3(0, -0.17, 0), el)
		_part(Vector3(0.1, 0.12, 0.05), skin, Vector3(0, -0.4, 0), el)
		_part(Vector3(0.13, 0.06, 0.13), flesh, Vector3(0, -0.2, 0), el)
		sh.add_child(el)
		_torso.add_child(sh)
		arms.append([sh, el])
	_arm_l = arms[0][0]
	_elbow_l = arms[0][1]
	_arm_r = arms[1][0]
	_elbow_r = arms[1][1]

	# тип: размер и окраска
	var zc: Dictionary = Cfg.ZOMBIES[type]
	var s: float = zc["scale"]
	if type == "fat":
		scale = Vector3(s * 1.2, s, s * 1.2)
		for m in _mats:
			m.albedo_color = m.albedo_color * Color(0.72, 0.8, 0.55)
	elif type == "fast":
		scale = Vector3.ONE * s
		for m in _mats:
			m.albedo_color = m.albedo_color * Color(1.0, 0.88, 0.5)
	top_y = 1.95 * s
	for n in _find_meshes(self):
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _find_meshes(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			out.append(n)
	return out


## Анимация шага. phase — накопленная фаза шага.
func animate(_dt: float, phase: float) -> void:
	if _skel_root != null:
		_animate_rigged(_dt, phase)
		return
	var s := sin(phase)
	var c := cos(phase)
	_leg_l.rotation.x = s * 0.55
	_knee_l.rotation.x = maxf(0.0, -c) * 0.5
	_leg_r.rotation.x = -s * 0.35
	_knee_r.rotation.x = maxf(0.0, c) * 0.25
	_torso.rotation.x = 0.2 + absf(s) * 0.03
	_torso.rotation.z = s * 0.07
	_torso.position.y = 0.9 + absf(s) * 0.03
	_neck.rotation.z = 0.28 + s * 0.05
	_neck.rotation.x = 0.22 + c * 0.05
	_arm_l.rotation.x = -1.15 + s * 0.12
	_elbow_l.rotation.x = -0.35
	_arm_r.rotation.x = 0.25 - s * 0.3
	_elbow_r.rotation.x = -0.15
	_arm_r.rotation.z = -0.1


## Вспышка при попадании и свечение при горении.
func set_hit_flash(v: float) -> void:
	_flash = v
	_apply_emission()


func set_burning(b: bool) -> void:
	_burning = b
	_apply_emission()


func _apply_emission() -> void:
	var e := 0.0
	if _flash > 0.0:
		e = 0.9
	elif _burning:
		e = 0.5 + 0.2 * sin(Time.get_ticks_msec() / 60.0)
	for m in _mats:
		m.emission_energy_multiplier = e


## Обычный и толстый зомби — zombie_rigged.tscn (модель Tripo), быстрый — одна из пяти «девушек» (girl_rigged.scn + текстура
## girl_A/B/green/blue/red). Скелет из 16 костей, анимации walk/attack/idle (tools/rig_models.gd, tools/bake_models.gd).
## Исходные модели смотрят в -Z, поэтому корень поворачиваем на 180°; ступни на нулевом уровне зашиты в сцену.
func _build_rigged() -> bool:
	var zc: Dictionary = Cfg.ZOMBIES[type]
	var s: float = zc["scale"]
	var girl := type == "fast" and ResourceLoader.exists("res://assets/models/girl_rigged.scn")
	var path := "res://assets/models/girl_rigged.scn" if girl else "res://assets/models/zombie_rigged.tscn"
	if not ResourceLoader.exists(path):
		return false
	_skel_root = (load(path) as PackedScene).instantiate()
	var rig_h: float = float(_skel_root.get_meta("rig_height", 0.946))
	var k: float = (1.72 if girl else float(zc["height"])) / rig_h * 0.98
	_skel_root.rotation.y = PI
	_skel_root.scale = Vector3.ONE * k
	add_child(_skel_root)
	_anim = _skel_root.get_node("AnimationPlayer")
	var body := _skel_root.find_child("Body", true, false) as MeshInstance3D
	var mat: StandardMaterial3D
	if girl:
		mat = Assets.model_material("girl_" + ["A", "B", "green", "blue", "red"][randi() % 5])
	else:
		mat = Assets.tripo_material()
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if girl:
		scale = Vector3.ONE
	elif type == "fat":
		scale = Vector3(s * 1.05, s, s * 1.05)
		mat.albedo_color = mat.albedo_color * Color(0.72, 0.85, 0.6)
	elif type == "fast":
		scale = Vector3.ONE * s
		mat.albedo_color = mat.albedo_color * Color(1.0, 0.9, 0.55)
	else:
		scale = Vector3.ONE
	_mats = [mat]
	top_y = (1.72 if girl else float(zc["height"]) * (s if type != "normal" else 1.0)) + 0.15
	_set_mode("walk")
	return true

func _set_mode(m: String) -> void:
	if m == _mode:
		return
	_mode = m
	_anim.play(m)
	if m == "walk":
		_anim.pause()


## Пока зомби идёт — поза берётся из фазы шага (ноги точно попадают в такт с перемещением);
## остановился (упёрся в турель) — играет анимация атаки.
func _animate_rigged(dt: float, phase: float) -> void:
	if absf(phase - _last_phase) < 0.0005:
		_still += dt
	else:
		_still = 0.0
	_last_phase = phase
	if _still > 0.25:
		_set_mode("attack")
	else:
		_set_mode("walk")
		_anim.seek(fposmod(phase / TAU, 1.0), true)