class_name PlayerRig
extends Node3D
## Солдат другого игрока в «Свободном FPS»: модель soldier (скелет + анимации walk/idle/swing, tools/bake_all.gd),
## АК-47 у груди (следует за наклоном прицела), холодное оружие в правой руке на время удара, имя над головой.
## Лицом к +Z при yaw = 0 (как в симуляции).

const HEIGHT := 1.8

var muzzle: Marker3D
var top_y := 2.05
var _root: Node3D
var _skel: Skeleton3D
var _anim: AnimationPlayer
var _bone_spine := -1
var _rifle: Node3D
var _melee: Node3D
var _label: Label3D
var _flash: MeshInstance3D
var _flash_t := 0.0
var _swing_t := -1.0
var _phase := 0.0
var _mode := ""
var _melee_kind := "machete"


static func create(p_name: String, p_melee: String) -> PlayerRig:
	var r := PlayerRig.new()
	r._melee_kind = p_melee
	r._build(p_name)
	return r


## Меш оружия (assets/models/baked/<n>.res) с текстурой, масштаб — по длине.
static func weapon_mesh(n: String, length: float) -> MeshInstance3D:
	var mesh: Mesh = Assets.baked_mesh(n)
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Assets.model_material(n, true, Color(0.62, 0.61, 0.62) if n == "ak47" else Color(0.85, 0.83, 0.8))
	var bb: AABB = mesh.get_meta("aabb", mesh.get_aabb())
	mi.scale = Vector3.ONE * (length / maxf(bb.size.z if n == "ak47" else bb.size.y, 0.001))
	return mi


func _build(p_name: String) -> void:
	var path := "res://assets/models/baked/soldier.scn"
	if ResourceLoader.exists(path):
		_root = (load(path) as PackedScene).instantiate()
		var rh: float = float(_root.get_meta("rig_height", HEIGHT))
		var k := HEIGHT / rh
		_root.scale = Vector3.ONE * k
		_root.rotation.y = PI                 # модель смотрит в -Z, солдат в игре — в +Z
		add_child(_root)
		var body := _root.find_child("Body", true, false) as MeshInstance3D
		body.material_override = Assets.model_material("soldier")
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_skel = _root.get_node("Skeleton3D")
		_anim = _root.get_node("AnimationPlayer")
		_bone_spine = _skel.find_bone("spine")
		# автомат — у груди справа, ствол вперёд (-Z модели)
		var att := BoneAttachment3D.new()
		att.bone_name = "chest"
		_skel.add_child(att)
		var chest_rest: Vector3 = _skel.get_bone_global_rest(_skel.find_bone("chest")).origin
		_rifle = Node3D.new()
		_rifle.position = (_root.get_meta("rifle_pos", chest_rest) as Vector3) - chest_rest
		att.add_child(_rifle)
		var ak := weapon_mesh("ak47", 0.9 / k)
		if ak != null:
			_rifle.add_child(ak)
		muzzle = Marker3D.new()
		muzzle.position = Vector3(0, 0.02 / k, -0.5 / k)
		_rifle.add_child(muzzle)
		# холодное оружие — в правой кисти (конец предплечья), видно только во время удара
		var hand := BoneAttachment3D.new()
		hand.bone_name = "forearm_R"
		_skel.add_child(hand)
		_melee = Node3D.new()
		_melee.visible = false
		var fr: Vector3 = _skel.get_bone_global_rest(_skel.find_bone("forearm_R")).origin
		var ur: Vector3 = _skel.get_bone_global_rest(_skel.find_bone("upperarm_R")).origin
		_melee.position = (fr - ur) * 0.85            # примерно кисть
		hand.add_child(_melee)
		var mm := weapon_mesh(_melee_kind, 0.62 / k)
		if mm != null:
			mm.rotation.x = -PI / 2.0                    # рукоять в кулаке, клинок вперёд
			mm.position.z = -0.12 / k
			_melee.add_child(mm)
		_flash = _make_flash()
		_flash.position = muzzle.position
		_rifle.add_child(_flash)
		_set_mode("idle")
	else:
		muzzle = Marker3D.new()
		muzzle.position = Vector3(0, 1.3, 0.7)
		add_child(muzzle)
	_label = Label3D.new()
	_label.text = p_name
	_label.position = Vector3(0, top_y + 0.05, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 40
	_label.pixel_size = 0.005
	_label.outline_size = 10
	_label.modulate = Color("d9e6b8")
	add_child(_label)


func _make_flash() -> MeshInstance3D:
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.8, 0.35)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.6, 0.2)
	fm.emission_energy_multiplier = 3.0
	var f := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.1
	s.height = 0.2
	s.radial_segments = 8
	s.rings = 4
	f.mesh = s
	f.material_override = fm
	f.visible = false
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return f


func _set_mode(m: String) -> void:
	if _anim == null or m == _mode:
		return
	_mode = m
	_anim.play(m)
	if m == "walk":
		_anim.pause()


func shoot_flash() -> void:
	if _flash != null:
		_flash_t = 0.05
		_flash.visible = true


func swing() -> void:
	if _anim == null:
		return
	_swing_t = 0.0
	_melee.visible = true
	_rifle.visible = false
	_mode = "swing"
	_anim.play("swing")
	_anim.seek(0.0, true)


## yaw/pitch — направление взгляда, speed — горизонтальная скорость, м/с.
func update(delta: float, yaw: float, pitch: float, speed: float) -> void:
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-delta * 16.0))
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.visible = false
	if _anim == null:
		return
	if _swing_t >= 0.0:
		_swing_t += delta
		if _swing_t >= 0.5:
			_swing_t = -1.0
			_melee.visible = false
			_rifle.visible = true
			_mode = ""
	if _swing_t < 0.0:
		if speed > 0.3:
			_set_mode("walk")
			_phase += delta * speed / 1.4
			_anim.seek(fposmod(_phase, 1.0) * _anim.current_animation_length, true)
		else:
			_set_mode("idle")
	# наклон корпуса по прицелу (кость spine в анимациях не задействована)
	if _bone_spine >= 0:
		_skel.set_bone_pose_rotation(_bone_spine, Quaternion(Vector3.RIGHT, clampf(pitch, -0.8, 0.8)))


func die() -> void:
	_label.visible = false
	if _anim != null:
		_anim.pause()
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", -PI / 2.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "position:y", 0.12, 0.5)
