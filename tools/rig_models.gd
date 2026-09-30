extends SceneTree
## Инструмент: делает из статичных моделей Tripo скелетные сцены с автоматическими весами кожи и анимациями.
##   godot --headless --path . --script res://tools/rig_models.gd
## Результат: assets/models/zombie_rigged.tscn (кости + walk/attack/idle) и turret_rigged.tscn (кости yaw/pitch + fire).
## Система координат — исходная модель: зомби смотрит в -Z, ствол турели вдоль +X; игра поворачивает корень сцены.

# ───────────── общие функции ─────────────

## bones: [{name, parent (имя или ""), pos (глобальная поза покоя в системе модели)}]
static func make_skeleton(bones: Array) -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	var idx := {}
	for b in bones:
		var i := sk.add_bone(b["name"])
		idx[b["name"]] = i
		var pos: Vector3 = b["pos"]
		var rest_pos := pos
		if b["parent"] != "":
			var pi: int = idx[b["parent"]]
			sk.set_bone_parent(i, pi)
			rest_pos = pos - _bone_pos(bones, b["parent"])
		sk.set_bone_rest(i, Transform3D(Basis(), rest_pos))
	sk.reset_bone_poses()
	return sk


static func _bone_pos(bones: Array, name: String) -> Vector3:
	for b in bones:
		if b["name"] == name:
			return b["pos"]
	return Vector3.ZERO


static func point_segment_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 1e-9 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Строит ArrayMesh с костями/весами; weight_fn(vertex) -> {bone_index: weight}
static func skin_mesh(src: Mesh, bones: Array, weight_fn: Callable) -> ArrayMesh:
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n := verts.size()
	var bi := PackedInt32Array()
	var bw := PackedFloat32Array()
	bi.resize(n * 4)
	bw.resize(n * 4)
	for v in n:
		var ws: Dictionary = weight_fn.call(verts[v])
		var keys := ws.keys()
		keys.sort_custom(func(a, b) -> bool: return ws[a] > ws[b])
		var total := 0.0
		for k in mini(4, keys.size()):
			total += ws[keys[k]]
		for k in 4:
			if k < keys.size() and total > 0.0:
				bi[v * 4 + k] = keys[k]
				bw[v * 4 + k] = ws[keys[k]] / total
			else:
				bi[v * 4 + k] = 0
				bw[v * 4 + k] = 0.0
	# у моделей Tripo нормалей нет — считаем сглаженные (без них освещение не работает)
	arrays[Mesh.ARRAY_NORMAL] = smooth_normals(verts, arrays[Mesh.ARRAY_INDEX])
	arrays[Mesh.ARRAY_BONES] = bi
	arrays[Mesh.ARRAY_WEIGHTS] = bw
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## Сглаженные нормали по площади граней; знак выбирается так, чтобы большинство смотрело от центра модели.
static func smooth_normals(verts: PackedVector3Array, idx) -> PackedVector3Array:
	var n := PackedVector3Array()
	n.resize(verts.size())
	var tri: PackedInt32Array = idx if idx != null else PackedInt32Array(range(verts.size()))
	for t in range(0, tri.size(), 3):
		var a := verts[tri[t]]
		var b := verts[tri[t + 1]]
		var c := verts[tri[t + 2]]
		var fn := (b - a).cross(c - a)
		n[tri[t]] += fn
		n[tri[t + 1]] += fn
		n[tri[t + 2]] += fn
	var center := Vector3.ZERO
	for v in verts:
		center += v
	center /= float(verts.size())
	var votes := 0.0
	for i in verts.size():
		votes += n[i].normalized().dot((verts[i] - center).normalized())
	var sgn := 1.0 if votes >= 0.0 else -1.0
	print("normals: verts=", verts.size(), " tris=", tri.size() / 3, " sign=", sgn, " votes=", votes)
	for i in n.size():
		n[i] = n[i].normalized() * sgn
	return n

static func make_skin(bones: Array) -> Skin:
	var skin := Skin.new()
	for i in bones.size():
		skin.add_named_bind(bones[i]["name"], Transform3D(Basis(), -(bones[i]["pos"] as Vector3)))
	return skin


static func vertex_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.82
	return m


static func load_mesh(path: String) -> Mesh:
	var s: Node = (load(path) as PackedScene).instantiate()
	var mi := s.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var m := mi.mesh
	s.free()
	return m


static func set_owner_rec(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		set_owner_rec(c, owner_node)


static func save_scene(root: Node, path: String) -> void:
	set_owner_rec(root, root)
	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, path)
	print("saved ", path, " -> ", error_string(err))


## То же, что save_scene, но в компактном бинарном .scn.
static func save_scene_bin(root: Node, path: String) -> void:
	set_owner_rec(root, root)
	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, path)
	print("saved ", path, " -> ", error_string(err))


static func rot_track(anim: Animation, bone: String, fn: Callable, steps: int) -> void:
	var t := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t, "Skeleton3D:" + bone)
	for i in steps + 1:
		var ph := float(i) / float(steps)
		var e: Vector3 = fn.call(ph * TAU)
		anim.rotation_track_insert_key(t, ph * anim.length, Quaternion.from_euler(e))


static func pos_track(anim: Animation, bone: String, rest: Vector3, fn: Callable, steps: int) -> void:
	var t := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(t, "Skeleton3D:" + bone)
	for i in steps + 1:
		var ph := float(i) / float(steps)
		var o: Vector3 = fn.call(ph * TAU)
		anim.position_track_insert_key(t, ph * anim.length, rest + o)


# ───────────── зомби ─────────────

const Z_BONES := [
	{"name": "root", "parent": "", "pos": Vector3(0, -0.455, 0)},
	{"name": "hips", "parent": "root", "pos": Vector3(0, -0.03, 0.0)},
	{"name": "spine", "parent": "hips", "pos": Vector3(0, 0.08, 0.02)},
	{"name": "chest", "parent": "spine", "pos": Vector3(0, 0.2, 0.05)},
	{"name": "neck", "parent": "chest", "pos": Vector3(0, 0.29, 0.04)},
	{"name": "head", "parent": "neck", "pos": Vector3(0, 0.35, 0.0)},
	{"name": "upperarm_L", "parent": "chest", "pos": Vector3(-0.15, 0.23, 0.075)},
	{"name": "forearm_L", "parent": "upperarm_L", "pos": Vector3(-0.16, 0.08, 0.09)},
	{"name": "upperarm_R", "parent": "chest", "pos": Vector3(0.15, 0.23, 0.075)},
	{"name": "forearm_R", "parent": "upperarm_R", "pos": Vector3(0.16, 0.08, 0.09)},
	{"name": "thigh_L", "parent": "hips", "pos": Vector3(-0.09, -0.03, -0.02)},
	{"name": "shin_L", "parent": "thigh_L", "pos": Vector3(-0.09, -0.2, -0.07)},
	{"name": "foot_L", "parent": "shin_L", "pos": Vector3(-0.09, -0.4, -0.05)},
	{"name": "thigh_R", "parent": "hips", "pos": Vector3(0.09, -0.03, -0.02)},
	{"name": "shin_R", "parent": "thigh_R", "pos": Vector3(0.09, -0.2, -0.07)},
	{"name": "foot_R", "parent": "shin_R", "pos": Vector3(0.09, -0.4, -0.05)},
]

# сегменты кости: [кость, начало, конец]
const Z_SEGS := [
	["hips", Vector3(0, -0.03, 0.0), Vector3(0, 0.08, 0.02)],
	["spine", Vector3(0, 0.08, 0.02), Vector3(0, 0.2, 0.05)],
	["chest", Vector3(0, 0.2, 0.05), Vector3(0, 0.29, 0.04)],
	["neck", Vector3(0, 0.29, 0.04), Vector3(0, 0.35, 0.0)],
	["head", Vector3(0, 0.35, 0.0), Vector3(0, 0.49, -0.02)],
	["upperarm_L", Vector3(-0.15, 0.23, 0.075), Vector3(-0.16, 0.08, 0.09)],
	["forearm_L", Vector3(-0.16, 0.08, 0.09), Vector3(-0.16, -0.05, 0.04)],
	["upperarm_R", Vector3(0.15, 0.23, 0.075), Vector3(0.16, 0.08, 0.09)],
	["forearm_R", Vector3(0.16, 0.08, 0.09), Vector3(0.16, -0.05, 0.04)],
	["thigh_L", Vector3(-0.09, -0.03, -0.02), Vector3(-0.09, -0.2, -0.07)],
	["shin_L", Vector3(-0.09, -0.2, -0.07), Vector3(-0.09, -0.4, -0.05)],
	["foot_L", Vector3(-0.09, -0.4, -0.05), Vector3(-0.09, -0.44, -0.2)],
	["thigh_R", Vector3(0.09, -0.03, -0.02), Vector3(0.09, -0.2, -0.07)],
	["shin_R", Vector3(0.09, -0.2, -0.07), Vector3(0.09, -0.4, -0.05)],
	["foot_R", Vector3(0.09, -0.4, -0.05), Vector3(0.09, -0.44, -0.2)],
]


static func zombie_weights(v: Vector3) -> Dictionary:
	var index := {}
	for i in Z_BONES.size():
		index[Z_BONES[i]["name"]] = i
	var per := {}
	for s in Z_SEGS:
		var d := point_segment_dist(v, s[1], s[2])
		var w := 1.0 / pow(d + 0.012, 3.0)
		var bi: int = index[s[0]]
		per[bi] = maxf(per.get(bi, 0.0), w)
	return per


static func build_zombie() -> void:
	var src := load_mesh("res://assets/models/zombie_tripo.glb")
	var root := Node3D.new()
	root.name = "ZombieRigged"
	var sk := make_skeleton(Z_BONES)
	root.add_child(sk)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = skin_mesh(src, Z_BONES, zombie_weights)
	mi.skin = make_skin(Z_BONES)
	mi.material_override = vertex_material()
	mi.custom_aabb = AABB(Vector3(-0.6, -0.6, -0.6), Vector3(1.2, 1.2, 1.2))
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	sk.position.y = 0.455        # ступни на нулевом уровне
	root.set_meta("rig_height", 0.946)

	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	var lib := AnimationLibrary.new()
	lib.add_animation("walk", _zombie_walk())
	lib.add_animation("attack", _zombie_attack())
	lib.add_animation("idle", _zombie_idle())
	ap.add_animation_library("", lib)
	save_scene(root, "res://assets/models/zombie_rigged.tscn")
	root.free()


## Шаркающая походка: ноги (правая подволакивается), руки вытянуты вперёд, корпус наклонён, голова свесилась.
static func _zombie_walk(hips_rest: Vector3 = Vector3.ZERO, bob_scale: float = 1.0) -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	var N := 16
	rot_track(a, "thigh_L", func(t: float) -> Vector3: return Vector3(0.55 * sin(t), 0, 0), N)
	rot_track(a, "thigh_R", func(t: float) -> Vector3: return Vector3(-0.38 * sin(t), 0, 0), N)
	rot_track(a, "shin_L", func(t: float) -> Vector3: return Vector3(-0.7 * maxf(0.0, cos(t)), 0, 0), N)
	rot_track(a, "shin_R", func(t: float) -> Vector3: return Vector3(-0.35 * maxf(0.0, -cos(t)), 0, 0), N)
	rot_track(a, "foot_L", func(t: float) -> Vector3: return Vector3(0.25 * maxf(0.0, -cos(t)), 0, 0), N)
	rot_track(a, "spine", func(t: float) -> Vector3: return Vector3(-0.14 + 0.02 * absf(sin(t)), 0.12 * sin(t), 0.05 * sin(t)), N)
	rot_track(a, "chest", func(t: float) -> Vector3: return Vector3(-0.1, -0.1 * sin(t), 0.04 * sin(t)), N)
	rot_track(a, "neck", func(t: float) -> Vector3: return Vector3(0.12, 0, 0.16 + 0.04 * sin(t * 2.0)), N)
	rot_track(a, "head", func(t: float) -> Vector3: return Vector3(0.1, 0.06 * sin(t), 0.08 * sin(t + 1.0)), N)
	rot_track(a, "upperarm_L", func(t: float) -> Vector3: return Vector3(1.25 + 0.1 * sin(t), 0, -0.05), N)
	rot_track(a, "forearm_L", func(t: float) -> Vector3: return Vector3(0.3 + 0.08 * sin(t), 0, 0), N)
	rot_track(a, "upperarm_R", func(t: float) -> Vector3: return Vector3(1.05 - 0.12 * sin(t), 0, 0.06), N)
	rot_track(a, "forearm_R", func(t: float) -> Vector3: return Vector3(0.4 - 0.08 * sin(t), 0, 0), N)
	if hips_rest == Vector3.ZERO:
		hips_rest = Z_BONES[1]["pos"] - Z_BONES[0]["pos"]
	pos_track(a, "hips", hips_rest, func(t: float) -> Vector3: return Vector3(0.012 * sin(t), 0.02 * absf(sin(t)), 0) * bob_scale, N)
	return a


## Атака: замах обеими руками сверху вниз с выпадом корпуса.
static func _zombie_attack() -> Animation:
	var a := Animation.new()
	a.length = 0.9
	a.loop_mode = Animation.LOOP_LINEAR
	var N := 16
	rot_track(a, "upperarm_L", func(t: float) -> Vector3: return Vector3(2.0 - 1.1 * (0.5 - 0.5 * cos(t)) , 0, -0.1), N)
	rot_track(a, "upperarm_R", func(t: float) -> Vector3: return Vector3(2.0 - 1.1 * (0.5 - 0.5 * cos(t)) , 0, 0.1), N)
	rot_track(a, "forearm_L", func(t: float) -> Vector3: return Vector3(0.5 - 0.3 * (0.5 - 0.5 * cos(t)), 0, 0), N)
	rot_track(a, "forearm_R", func(t: float) -> Vector3: return Vector3(0.5 - 0.3 * (0.5 - 0.5 * cos(t)), 0, 0), N)
	rot_track(a, "spine", func(t: float) -> Vector3: return Vector3(0.1 - 0.42 * (0.5 - 0.5 * cos(t)), 0, 0), N)
	rot_track(a, "chest", func(t: float) -> Vector3: return Vector3(0.06 - 0.25 * (0.5 - 0.5 * cos(t)), 0.06 * sin(t), 0), N)
	rot_track(a, "neck", func(t: float) -> Vector3: return Vector3(0.1 + 0.2 * (0.5 - 0.5 * cos(t)), 0, 0.14), N)
	rot_track(a, "thigh_L", func(_t: float) -> Vector3: return Vector3(0.18, 0, 0), N)
	rot_track(a, "thigh_R", func(_t: float) -> Vector3: return Vector3(-0.1, 0, 0), N)
	rot_track(a, "shin_L", func(_t: float) -> Vector3: return Vector3(-0.2, 0, 0), N)
	return a


static func _zombie_idle() -> Animation:
	var a := Animation.new()
	a.length = 2.0
	a.loop_mode = Animation.LOOP_LINEAR
	var N := 16
	rot_track(a, "spine", func(t: float) -> Vector3: return Vector3(-0.1 + 0.02 * sin(t), 0.05 * sin(t), 0), N)
	rot_track(a, "neck", func(t: float) -> Vector3: return Vector3(0.15, 0, 0.2 + 0.05 * sin(t)), N)
	rot_track(a, "upperarm_L", func(t: float) -> Vector3: return Vector3(0.5 + 0.06 * sin(t), 0, -0.05), N)
	rot_track(a, "upperarm_R", func(t: float) -> Vector3: return Vector3(0.35 - 0.06 * sin(t), 0, 0.05), N)
	rot_track(a, "forearm_L", func(_t: float) -> Vector3: return Vector3(0.4, 0, 0), N)
	rot_track(a, "forearm_R", func(_t: float) -> Vector3: return Vector3(0.3, 0, 0), N)
	return a


# ───────────── турель ─────────────

const T_BONES := [
	{"name": "root", "parent": "", "pos": Vector3(0, -0.455, 0)},
	{"name": "turret", "parent": "root", "pos": Vector3(0, 0.1, 0)},
	{"name": "gun", "parent": "turret", "pos": Vector3(0.0, 0.37, -0.25)},
]


static func turret_weights(v: Vector3) -> Dictionary:
	# ножки — root; плита и купол — turret (вращается по yaw); орудие сверху — gun (pitch и отдача)
	var w_turret := smoothstep(0.06, 0.1, v.y)
	var w_gun := 0.0
	if v.z < -0.08 and v.z > -0.42:
		w_gun = smoothstep(0.31, 0.34, v.y)
	var ws := {}
	var w_root := 1.0 - w_turret
	var w_t := w_turret * (1.0 - w_gun)
	if w_root > 0.0:
		ws[0] = w_root
	if w_t > 0.0:
		ws[1] = w_t
	if w_turret * w_gun > 0.0:
		ws[2] = w_turret * w_gun
	return ws


static func build_turret() -> void:
	var src := load_mesh("res://assets/models/turret_tripo.glb")
	var root := Node3D.new()
	root.name = "TurretRigged"
	var sk := make_skeleton(T_BONES)
	root.add_child(sk)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = skin_mesh(src, T_BONES, turret_weights)
	mi.skin = make_skin(T_BONES)
	mi.material_override = vertex_material()
	mi.custom_aabb = AABB(Vector3(-0.8, -0.6, -0.8), Vector3(1.6, 1.4, 1.6))
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	# анимация выстрела: откат орудия назад и возврат
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	var lib := AnimationLibrary.new()
	var a := Animation.new()
	a.length = 0.18
	var t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(t, "Skeleton3D:gun")
	var rest: Vector3 = T_BONES[2]["pos"] - T_BONES[1]["pos"]
	a.position_track_insert_key(t, 0.0, rest)
	a.position_track_insert_key(t, 0.03, rest + Vector3(-0.07, 0, 0))
	a.position_track_insert_key(t, 0.18, rest)
	lib.add_animation("fire", a)
	ap.add_animation_library("", lib)
	save_scene(root, "res://assets/models/turret_rigged.tscn")
	root.free()


func _init() -> void:
	build_zombie()
	build_turret()
	quit()
