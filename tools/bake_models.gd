extends SceneTree
## Инструмент: готовит игровые ресурсы из новых моделей (assets/models/*.glb):
##  • текстуры извлекаются в assets/tex/models/*.jpg (материал собирается в игре — так файлы остаются компактными);
##  • статичные предметы (бочки, бетонные блоки, заборы) → assets/models/baked/*.res: один меш с нормалями
##    (в моделях нормалей нет, без них освещение не работает), низ на нуле, центр по XZ в нуле;
##  • турели (пулемёт, артиллерия, огнемёт) → assets/models/*_rigged.scn: кости root / turret (yaw) / gun (pitch, отдача);
##  • девушки-зомби girl_* → girl_rigged.scn (скелет + анимации walk/attack/idle, веса кожи считаются автоматически),
##    текстуры пяти вариантов — assets/tex/models/girl_*.jpg.
## Запуск: godot --headless --path . --script res://tools/bake_models.gd
const R := preload("res://tools/rig_models.gd")

const STATIC := ["barrel", "concrete_block", "fence_barrels", "fence_concrete"]
const GIRLS := ["girl_A", "girl_B", "girl_green", "girl_blue", "girl_red"]

# параметры турелей (в системе координат исходной модели): cut — высота, выше которой всё вращается,
# fwd — направление ствола в XZ, (cx, cz) — ось вращения
const TURRETS := {
	"turret_machinegun": {"cut": -0.55, "fwd": Vector2(-0.98, -0.19), "cx": 0.0, "cz": 0.0},
	"turret_flamethrower": {"cut": 0.0, "fwd": Vector2(-1.0, 0.0), "cx": 0.36, "cz": 0.0},
	"turret_artillery": {"cut": -0.05, "fwd": Vector2(-0.55, 0.83), "cx": 0.04, "cz": -0.4},
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/models/baked")
	DirAccess.make_dir_recursive_absolute("res://assets/tex/models")
	for n in STATIC:
		bake_static(n)
	for n in TURRETS.keys():
		bake_turret(n, TURRETS[n])
	bake_girl()
	quit()


# ───────────── загрузка модели ─────────────

static func rel_xform(node: Node3D, root: Node3D) -> Transform3D:
	var x := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			x = (n as Node3D).transform * x
		n = n.get_parent()
	return x


## Все меши glb, склеенные в один (позиции — в системе корня сцены). Возвращает {mesh, tex}.
static func load_merged(path: String) -> Dictionary:
	var scene := (load(path) as PackedScene).instantiate() as Node3D
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var tex: Texture2D = null
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var xf := rel_xform(mi, scene)
			var base := verts.size()
			for v in arr[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				verts.append(xf * v)
			if arr[Mesh.ARRAY_TEX_UV] != null:
				uvs.append_array(arr[Mesh.ARRAY_TEX_UV])
			else:
				for i in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
					uvs.append(Vector2.ZERO)
			var ind = arr[Mesh.ARRAY_INDEX]
			if ind == null:
				for i in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
					idx.append(base + i)
			else:
				for i in ind as PackedInt32Array:
					idx.append(base + i)
			var mat := mi.mesh.surface_get_material(s)
			if tex == null and mat is BaseMaterial3D:
				tex = (mat as BaseMaterial3D).albedo_texture
	scene.free()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {"mesh": m, "tex": tex}


static func save_tex(tex: Texture2D, out: String) -> void:
	if tex == null:
		print("  (нет текстуры для ", out, ")")
		return
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	var err := img.save_jpg(ProjectSettings.globalize_path(out), 0.92)
	print("  texture ", out, " ", img.get_size(), " -> ", error_string(err))


static func bounds(mesh: Mesh) -> AABB:
	return mesh.get_aabb()


# ───────────── статичные предметы ─────────────

func bake_static(n: String) -> void:
	print("static ", n)
	var d := load_merged("res://assets/models/%s.glb" % n)
	var src: ArrayMesh = d["mesh"]
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bb := src.get_aabb()
	var off := Vector3(bb.position.x + bb.size.x * 0.5, bb.position.y, bb.position.z + bb.size.z * 0.5)
	for i in verts.size():
		verts[i] -= off
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = R.smooth_normals(verts, arrays[Mesh.ARRAY_INDEX])
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	print("  size ", out.get_aabb().size)
	ResourceSaver.save(out, "res://assets/models/baked/%s.res" % n)
	save_tex(d["tex"], "res://assets/tex/models/%s.jpg" % n)


# ───────────── турели ─────────────

func bake_turret(n: String, p: Dictionary) -> void:
	print("turret ", n)
	var d := load_merged("res://assets/models/%s.glb" % n)
	var src: ArrayMesh = d["mesh"]
	var bb := src.get_aabb()
	var verts: PackedVector3Array = src.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var fwd: Vector2 = (p["fwd"] as Vector2).normalized()
	var cx: float = p["cx"]
	var cz: float = p["cz"]
	var cut: float = p["cut"]
	var ymin := bb.position.y
	# кончик ствола: самые дальние вдоль fwd вершины
	var best := -1e9
	for v in verts:
		best = maxf(best, v.x * fwd.x + v.z * fwd.y)
	var tip := Vector3.ZERO
	var cnt := 0
	for v in verts:
		if v.x * fwd.x + v.z * fwd.y >= best - 0.05:
			tip += v
			cnt += 1
	tip /= float(maxi(cnt, 1))
	print("  tip ", tip, " (cnt ", cnt, ") bbox ", bb)
	var bones := [
		{"name": "root", "parent": "", "pos": Vector3(cx, ymin, cz)},
		{"name": "turret", "parent": "root", "pos": Vector3(cx, cut, cz)},
		{"name": "gun", "parent": "turret", "pos": Vector3(cx, tip.y, cz)},
	]
	var wf := func(v: Vector3) -> Dictionary:
		var w_up := smoothstep(cut - 0.03, cut + 0.03, v.y)
		var ws := {}
		if 1.0 - w_up > 0.0:
			ws[0] = 1.0 - w_up
		if w_up > 0.0:
			ws[2] = w_up
		return ws
	var root := Node3D.new()
	root.name = n.capitalize().replace(" ", "")
	var sk := R.make_skeleton(bones)
	sk.position = Vector3(-cx, -ymin, -cz)      # ось вращения — в нуле, основание — на нулевом уровне
	root.add_child(sk)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = R.skin_mesh(src, bones, wf)
	mi.skin = R.make_skin(bones)
	mi.custom_aabb = AABB(bb.position - Vector3(0.6, 0.6, 0.6), bb.size + Vector3(1.2, 1.2, 1.2))
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	var a := atan2(fwd.x, fwd.y)                 # угол ствола от +Z; корень сцены разворачивается на -a
	root.set_meta("fwd_angle", a)
	root.set_meta("tip", Vector3(tip.x - cx, tip.y - ymin, tip.z - cz))
	root.set_meta("height", bb.size.y)
	root.set_meta("pivot_y", tip.y - ymin)
	root.set_meta("gun_axis", Vector3(-fwd.y, 0.0, fwd.x))
	root.set_meta("fwd", Vector3(fwd.x, 0.0, fwd.y))
	root.set_meta("gun_rest", bones[2]["pos"] - bones[1]["pos"])
	R.save_scene_bin(root, "res://assets/models/%s_rigged.scn" % n.trim_prefix("turret_"))
	root.free()
	save_tex(d["tex"], "res://assets/tex/models/%s.jpg" % n)


# ───────────── девушки-зомби ─────────────

# кости в системе модели ПОСЛЕ разворота на 180° (как у зомби: лицом к -Z; исходные девушки смотрят в +Z)
const G_BONES := [
	{"name": "root", "parent": "", "pos": Vector3(0, -1.0, 0)},
	{"name": "hips", "parent": "root", "pos": Vector3(0, 0.03, 0.0)},
	{"name": "spine", "parent": "hips", "pos": Vector3(0, 0.2, 0.0)},
	{"name": "chest", "parent": "spine", "pos": Vector3(0, 0.38, 0.0)},
	{"name": "neck", "parent": "chest", "pos": Vector3(0, 0.6, 0.0)},
	{"name": "head", "parent": "neck", "pos": Vector3(0, 0.68, 0.0)},
	{"name": "upperarm_L", "parent": "chest", "pos": Vector3(-0.17, 0.5, 0.0)},
	{"name": "forearm_L", "parent": "upperarm_L", "pos": Vector3(-0.27, 0.2, 0.0)},
	{"name": "upperarm_R", "parent": "chest", "pos": Vector3(0.17, 0.5, 0.0)},
	{"name": "forearm_R", "parent": "upperarm_R", "pos": Vector3(0.27, 0.2, 0.0)},
	{"name": "thigh_L", "parent": "hips", "pos": Vector3(-0.09, 0.02, 0.0)},
	{"name": "shin_L", "parent": "thigh_L", "pos": Vector3(-0.1, -0.42, -0.02)},
	{"name": "foot_L", "parent": "shin_L", "pos": Vector3(-0.1, -0.8, 0.0)},
	{"name": "thigh_R", "parent": "hips", "pos": Vector3(0.09, 0.02, 0.0)},
	{"name": "shin_R", "parent": "thigh_R", "pos": Vector3(0.1, -0.42, -0.02)},
	{"name": "foot_R", "parent": "shin_R", "pos": Vector3(0.1, -0.8, 0.0)},
]

const G_SEGS := [
	["hips", Vector3(0, 0.03, 0), Vector3(0, 0.2, 0)],
	["spine", Vector3(0, 0.2, 0), Vector3(0, 0.38, 0)],
	["chest", Vector3(0, 0.38, 0), Vector3(0, 0.6, 0)],
	["neck", Vector3(0, 0.6, 0), Vector3(0, 0.69, 0.0)],
	["head", Vector3(0, 0.69, 0), Vector3(0, 0.98, 0)],
	["upperarm_L", Vector3(-0.17, 0.5, 0), Vector3(-0.27, 0.2, 0)],
	["forearm_L", Vector3(-0.27, 0.2, 0), Vector3(-0.31, -0.2, 0)],
	["upperarm_R", Vector3(0.17, 0.5, 0), Vector3(0.27, 0.2, 0)],
	["forearm_R", Vector3(0.27, 0.2, 0), Vector3(0.31, -0.2, 0)],
	["thigh_L", Vector3(-0.09, 0.02, 0), Vector3(-0.1, -0.42, -0.02)],
	["shin_L", Vector3(-0.1, -0.42, -0.02), Vector3(-0.1, -0.8, 0)],
	["foot_L", Vector3(-0.1, -0.8, 0), Vector3(-0.1, -0.98, -0.2)],
	["thigh_R", Vector3(0.09, 0.02, 0), Vector3(0.1, -0.42, -0.02)],
	["shin_R", Vector3(0.1, -0.42, -0.02), Vector3(0.1, -0.8, 0)],
	["foot_R", Vector3(0.1, -0.8, 0), Vector3(0.1, -0.98, -0.2)],
]


static func girl_weights(v: Vector3) -> Dictionary:
	var index := {}
	for i in G_BONES.size():
		index[G_BONES[i]["name"]] = i
	var per := {}
	for s in G_SEGS:
		var d := R.point_segment_dist(v, s[1], s[2])
		var w := 1.0 / pow(d + 0.02, 3.0)
		var bi: int = index[s[0]]
		per[bi] = maxf(per.get(bi, 0.0), w)
	return per


func bake_girl() -> void:
	print("girl")
	var d := load_merged("res://assets/models/girl_A.glb")
	var src: ArrayMesh = d["mesh"]
	# разворот на 180° вокруг Y: (x, z) → (-x, -z)
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] = Vector3(-verts[i].x, verts[i].y, -verts[i].z)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var flipped := ArrayMesh.new()
	flipped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var bb := flipped.get_aabb()
	print("  bbox ", bb)
	var root := Node3D.new()
	root.name = "GirlRigged"
	var sk := R.make_skeleton(G_BONES)
	sk.position.y = -bb.position.y
	root.add_child(sk)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = R.skin_mesh(flipped, G_BONES, girl_weights)
	mi.skin = R.make_skin(G_BONES)
	mi.custom_aabb = AABB(bb.position - Vector3(0.6, 0.6, 0.6), bb.size + Vector3(1.2, 1.2, 1.2))
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	root.set_meta("rig_height", bb.size.y)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	var lib := AnimationLibrary.new()
	var hips_rest: Vector3 = G_BONES[1]["pos"] - G_BONES[0]["pos"]
	lib.add_animation("walk", R._zombie_walk(hips_rest, 2.1))
	lib.add_animation("attack", R._zombie_attack())
	lib.add_animation("idle", R._zombie_idle())
	ap.add_animation_library("", lib)
	R.save_scene_bin(root, "res://assets/models/girl_rigged.scn")
	root.free()
	for g in GIRLS:
		var dd := load_merged("res://assets/models/%s.glb" % g)
		save_tex(dd["tex"], "res://assets/tex/models/%s.jpg" % g)
