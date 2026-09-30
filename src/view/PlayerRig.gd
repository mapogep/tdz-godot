class_name PlayerRig
extends Node3D
## Солдат другого игрока (свободный FPS): каска, разгрузка, АК-47 в руках. Лицом к +Z при yaw=0 (как в симуляции).
## Ходьба — по перемещению, взгляд — по pitch, вспышка выстрела, взмах холодным оружием, падение при смерти.

var muzzle: Marker3D
var top_y := 2.05
var _body: Node3D
var _torso: Node3D
var _legs: Array[Node3D] = []
var _arm_l: Node3D
var _arm_r: Node3D
var _rifle: Node3D
var _melee: Node3D
var _label: Label3D
var _flash: MeshInstance3D
var _flash_t := 0.0
var _phase := 0.0
var _swing_t := -1.0
var _melee_kind := "machete"
var _use_melee := false


static func _mat(c: Color, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func create(p_name: String, p_melee: String) -> PlayerRig:
	var r := PlayerRig.new()
	r._melee_kind = p_melee
	r._build(p_name)
	return r


func _build(p_name: String) -> void:
	var cloth := _mat(Color("4d5236"))
	var pants := _mat(Color("42432f"))
	var vest := _mat(Color("2f3128"))
	var skin := _mat(Color("a57c62"))
	var boot := _mat(Color("1d1a17"))
	var steel := _mat(Color("2a2c2b"), 0.45, 0.7)
	var wood := _mat(Color("6b3a17"), 0.6)
	var helmet := _mat(Color("3f4530"), 0.7)
	_body = Node3D.new()
	add_child(_body)
	# ноги
	for x in [-0.11, 0.11]:
		var hip := Node3D.new()
		hip.position = Vector3(x, 0.92, 0)
		_box(hip, Vector3(0.16, 0.9, 0.18), Vector3(0, -0.45, 0), pants)
		_box(hip, Vector3(0.17, 0.12, 0.26), Vector3(0, -0.88, 0.04), boot)
		_body.add_child(hip)
		_legs.append(hip)
	# корпус
	_torso = Node3D.new()
	_torso.position = Vector3(0, 0.92, 0)
	_body.add_child(_torso)
	_box(_torso, Vector3(0.44, 0.54, 0.26), Vector3(0, 0.3, 0), cloth)
	_box(_torso, Vector3(0.47, 0.34, 0.3), Vector3(0, 0.34, 0), vest)
	for x in [-0.13, 0.0, 0.13]:
		_box(_torso, Vector3(0.1, 0.12, 0.06), Vector3(x, 0.24, 0.17), vest)
	# голова, каска, очки
	var head := Node3D.new()
	head.position = Vector3(0, 0.7, 0)
	_torso.add_child(head)
	var sk := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sk.mesh = sm
	sk.material_override = skin
	head.add_child(sk)
	var cap := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.15
	cm.height = 0.15
	cm.is_hemisphere = true
	cap.mesh = cm
	cap.material_override = helmet
	cap.position = Vector3(0, 0.03, -0.005)
	head.add_child(cap)
	_box(head, Vector3(0.24, 0.05, 0.05), Vector3(0, 0.03, 0.115), steel)
	# руки держат винтовку
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.27, 0.52, 0)
	_torso.add_child(_arm_r)
	_box(_arm_r, Vector3(0.11, 0.42, 0.11), Vector3(0, -0.2, 0), cloth)
	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.27, 0.52, 0)
	_torso.add_child(_arm_l)
	_box(_arm_l, Vector3(0.11, 0.42, 0.11), Vector3(0, -0.2, 0), cloth)
	_arm_r.rotation.x = -1.15
	_arm_l.rotation.x = -1.4
	_arm_l.rotation.z = -0.35
	# АК-47
	_rifle = Node3D.new()
	_rifle.position = Vector3(0.09, 0.4, 0.3)
	_torso.add_child(_rifle)
	_box(_rifle, Vector3(0.05, 0.08, 0.6), Vector3(0, 0, 0), steel)
	_box(_rifle, Vector3(0.055, 0.06, 0.3), Vector3(0, -0.01, 0.42), wood)
	_box(_rifle, Vector3(0.04, 0.09, 0.22), Vector3(0, -0.02, -0.38), wood)
	_box(_rifle, Vector3(0.035, 0.2, 0.06), Vector3(0, -0.14, 0.02), steel, Vector3(-0.3, 0, 0))
	var mz := Marker3D.new()
	mz.position = Vector3(0, 0.01, 0.68)
	_rifle.add_child(mz)
	muzzle = mz
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.8, 0.35)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.6, 0.2)
	fm.emission_energy_multiplier = 3.0
	_flash = MeshInstance3D.new()
	var fq := SphereMesh.new()
	fq.radius = 0.1
	fq.height = 0.2
	_flash.mesh = fq
	_flash.material_override = fm
	_flash.position = Vector3(0, 0, 0.74)
	_flash.visible = false
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rifle.add_child(_flash)
	# холодное оружие (виден при взмахе)
	_melee = Node3D.new()
	_melee.position = Vector3(0.3, 0.1, 0.1)
	_melee.visible = false
	_torso.add_child(_melee)
	if _melee_kind == "axe":
		_box(_melee, Vector3(0.04, 0.04, 0.7), Vector3(0, 0, 0.3), wood)
		_box(_melee, Vector3(0.05, 0.22, 0.14), Vector3(0, 0.06, 0.6), steel)
	else:
		_box(_melee, Vector3(0.04, 0.04, 0.16), Vector3(0, 0, 0), _mat(Color("2f2a24")))
		_box(_melee, Vector3(0.012, 0.08, 0.55), Vector3(0, 0.02, 0.36), _mat(Color("9aa0a2"), 0.3, 0.9))
	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# имя над головой
	_label = Label3D.new()
	_label.text = p_name
	_label.position = Vector3(0, top_y + 0.05, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 40
	_label.pixel_size = 0.005
	_label.outline_size = 10
	_label.modulate = Color("d9e6b8")
	_label.fixed_size = false
	add_child(_label)


func shoot_flash() -> void:
	_flash_t = 0.05
	_flash.visible = true
	_use_melee = false


func swing() -> void:
	_swing_t = 0.0
	_use_melee = true
	_melee.visible = true
	_rifle.visible = false


## pos — положение ног, yaw/pitch — направление взгляда, speed — горизонтальная скорость м/с.
func update(delta: float, yaw: float, pitch: float, speed: float) -> void:
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-delta * 16.0))
	_phase += delta * speed * 1.9
	var s := sin(_phase)
	var amp := clampf(speed / 3.0, 0.0, 1.0)
	_legs[0].rotation.x = s * 0.7 * amp
	_legs[1].rotation.x = -s * 0.7 * amp
	_torso.position.y = 0.92 + absf(s) * 0.02 * amp
	_torso.rotation.x = 0.04
	var aim := clampf(pitch, -0.9, 0.9)
	if not _use_melee:
		_arm_r.rotation.x = -1.15 - aim
		_arm_l.rotation.x = -1.4 - aim
		_rifle.rotation.x = -aim
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.visible = false
	if _swing_t >= 0.0:
		_swing_t += delta / 0.5
		var t := _swing_t
		var a := sin(clampf(t, 0.0, 1.0) * PI)
		_arm_r.rotation.x = -1.9 + 1.5 * a
		_melee.rotation.x = -1.2 + 2.0 * a
		if _swing_t >= 1.0:
			_swing_t = -1.0
			_use_melee = false
			_melee.visible = false
			_rifle.visible = true


func die() -> void:
	_label.visible = false
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", -PI / 2.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "position:y", 0.12, 0.5)
