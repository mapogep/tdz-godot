extends SceneTree
## Подготовка всех моделей игры из исходников assets/source/*.glb (папка с .gdignore — в экспорт не попадает;
## GLB читаются напрямую через GLTFDocument).
##   godot --headless --path . --script res://tools/bake_all.gd [-- --only=name1,name2]
## Результат (assets/models/baked):
##   <prop>.res         — статичный меш (нормали, LOD, низ на нуле, центр по XZ в нуле);
##   <turret>.scn       — турель со скелетом root / turret (yaw) / gun (pitch, отдача);
##   <humanoid>.scn     — персонаж с автоматическим скелетом (16 костей), весами и анимациями;
##   <weapon>.res       — оружие: длинная ось по -Z (ствол/клинок вперёд), метаданные muzzle/grip.
## Текстуры — assets/tex/models/<name>.jpg.

const SRC := "res://assets/source/"
const OUT := "res://assets/models/baked/"
const TEX := "res://assets/tex/models/"

# статичные предметы: [имя, размер текстуры, целевое число треугольников]
const PROPS := [
	["barrel", 512, 240], ["concrete_block", 512, 160], ["fence_concrete", 1024, 500],
	["car_wreck", 512, 700], ["ruined_house", 1024, 1400], ["watchtower", 512, 800],
]

# турели: auto — ось вращения, срез и направление ствола определяются по форме (auto_turret); иначе cut — высота среза
# вращающейся части, fwd — направление ствола в XZ, (cx, cz) — ось вращения (система модели); spin — у пулемёта Гатлинга
# стволы — отдельная кость, вращается при стрельбе
const TURRETS := {
	"turret_pkm": {"out": "pkm", "auto": true, "tris": 1600},
	"turret_gatling2": {"out": "gatling", "auto": true, "tris": 1600, "spin": true},
	"turret_rocket": {"out": "rocket", "auto": true, "tris": 1600},
	"turret_flame": {"out": "flame", "auto": true, "tris": 1600, "fwd": Vector2(-1.0, 0.0)},   # сверху — ручка, сбивает поиск ствола
}

# гуманоиды: авто-скелет; kind — набор анимаций; tris — целевое число треугольников
const HUMANOIDS := {
	"z_walker": {"kind": "zombie", "tris": 1300, "tex": 1024},
	"z_fat": {"kind": "zombie", "tris": 1300, "tex": 1024},
	"z_armored": {"kind": "zombie", "tris": 1300, "tex": 1024},
	"z_boomer": {"kind": "zombie", "tris": 1300, "tex": 1024},
	"z_brute": {"kind": "zombie", "tris": 1600, "tex": 1024},
	"soldier": {"kind": "soldier", "tris": 1600, "tex": 1024},
}

# оружие (auto — ориентация определяется по форме, см. bake_weapon): gun — длинная ось к -Z (ствол вперёд), вторая ось — по высоте, «хвост» (магазин) вниз;
# melee — длинная ось к +Y (клинок/обух вверх, рукоять внизу), вторая ось — вперёд/назад, «хвост» (головка топора,
# лезвие) — вперёд (-Z). flip — развернуть длинную ось, tail — знак «хвоста» по второй оси.
const WEAPONS := {
	"ak47": {"mode": "gun", "auto": true, "tex": 1024, "tris": 1600},
	"machete": {"mode": "melee", "flip": true, "tail": 1.0, "tex": 512, "tris": 600},
	"axe": {"mode": "melee", "auto": true, "tex": 512, "tris": 600},
}

# какой исходник брать для имени ассета (новые версии моделей; облегчённые пересборки с меньшим числом граней)
const SOURCE := {
	"ak47": "ak47_v2", "axe": "axe_v2",
}


static func src_of(n: String) -> String:
	var alt: String = SOURCE.get(n, "")
	if alt != "" and FileAccess.file_exists(ProjectSettings.globalize_path(SRC + alt + ".glb")):
		return alt
	return n


const GIRLS := ["girl_A", "girl_B", "girl_green", "girl_blue", "girl_red"]

var only: Array = []
var rt                                   # tools/retarget.gd: анимации из пака зомби
var _done := false

# походки для каждой модели зомби (клипы пака, tools/retarget.gd WALKS); атаки и покой — у всех
const ZOMBIE_WALKS := {
	"z_walker": ["walk_a", "walk_b"], "z_fat": ["walk_b"], "z_armored": ["walk_a"],
	"z_boomer": ["walk_b"], "z_brute": ["walk_a"], "girl": ["run"],
}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")


## Работа — в первом кадре: GLTF-пак анимаций нужно поставить в дерево сцены, чтобы снять позы.
func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	if rt != null:
		rt.free_pack()
	return true


func _anim_pack():
	if rt == null and FileAccess.file_exists(ProjectSettings.globalize_path("res://assets/source/zombie_pack.glb")):
		rt = load("res://tools/retarget.gd").new()
		if not rt.load_pack(get_root()):
			rt = null
	return rt


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(TEX)
	for p in PROPS:
		if _want(p[0]):
			bake_prop(p[0], p[1], p[2])
	for n in TURRETS.keys():
		if _want(n):
			bake_turret(n, TURRETS[n])
	for n in HUMANOIDS.keys():
		if _want(n):
			bake_humanoid(n, HUMANOIDS[n])
	for n in WEAPONS.keys():
		if _want(n):
			bake_weapon(n, WEAPONS[n])
	if _want("girl"):
		bake_girl()


func _want(n: String) -> bool:
	if not FileAccess.file_exists(ProjectSettings.globalize_path(SRC + src_of("girl_A" if n == "girl" else n) + ".glb")):
		return false
	return only.is_empty() or only.has(n)


# ───────────────────────── загрузка и геометрия ─────────────────────────

static func _rel_xform(node: Node, root: Node) -> Transform3D:
	var x := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			x = (n as Node3D).transform * x
		n = n.get_parent()
	return x


## GLB → все меши, склеенные в один: {verts, uvs, idx, image}.
static func load_glb(name: String) -> Dictionary:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(SRC + src_of(name) + ".glb"), state)
	if err != OK:
		push_error("cannot read %s: %s" % [name, error_string(err)])
		return {}
	var scene := doc.generate_scene(state)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var image: Image = null
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var xf := _rel_xform(mi, scene)
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var base := verts.size()
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in vs:
				verts.append(xf * v)
			if arr[Mesh.ARRAY_TEX_UV] != null:
				uvs.append_array(arr[Mesh.ARRAY_TEX_UV])
			else:
				for i in vs.size():
					uvs.append(Vector2.ZERO)
			if arr[Mesh.ARRAY_INDEX] != null:
				for i in arr[Mesh.ARRAY_INDEX] as PackedInt32Array:
					idx.append(base + i)
			else:
				for i in vs.size():
					idx.append(base + i)
			var mat := mi.mesh.surface_get_material(s)
			if image == null and mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null:
				image = (mat as BaseMaterial3D).albedo_texture.get_image()
	scene.free()
	return {"verts": verts, "uvs": uvs, "idx": idx, "image": image}


static func save_tex(image: Image, name: String, size: int) -> void:
	if image == null:
		print("  (no texture for ", name, ")")
		return
	var img := image.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	if img.get_width() > size:
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	var err := img.save_jpg(ProjectSettings.globalize_path(TEX + name + ".jpg"), 0.9)
	print("  texture ", name, " ", img.get_size(), " -> ", error_string(err))


static func bounds(verts: PackedVector3Array) -> AABB:
	var mn := Vector3(INF, INF, INF)
	var mx := -mn
	for v in verts:
		mn = mn.min(v)
		mx = mx.max(v)
	return AABB(mn, mx - mn)


## Сглаженные нормали по площади граней; знак — чтобы большинство смотрело от центра (у моделей нормалей нет).
static func smooth_normals(verts: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var n := PackedVector3Array()
	n.resize(verts.size())
	for t in range(0, idx.size(), 3):
		var a := verts[idx[t]]
		var fn := (verts[idx[t + 1]] - a).cross(verts[idx[t + 2]] - a)
		n[idx[t]] += fn
		n[idx[t + 1]] += fn
		n[idx[t + 2]] += fn
	var c := bounds(verts).get_center()
	var votes := 0.0
	for i in verts.size():
		votes += n[i].normalized().dot((verts[i] - c).normalized())
	var sgn := 1.0 if votes >= 0.0 else -1.0
	for i in n.size():
		n[i] = n[i].normalized() * sgn
	return n


## Упрощение сетки (meshoptimizer через ImporterMesh.generate_lods) до target треугольников: уровни LOD
## генерируются повторно от уже упрощённой сетки, пока не дойдём до цели; более грубые уровни становятся LOD
## для дальних планов. Возвращает {"idx": базовые индексы, "lods": {расстояние: индексы}}.
static func _lods_of(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(60.0, 25.0, [])
	var out: Array = []
	for i in im.get_surface_lod_count(0):
		out.append([im.get_surface_lod_size(0, i), im.get_surface_lod_indices(0, i)])
	return out


static func simplify(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array, target: int) -> Dictionary:
	var tris := idx.size() / 3
	var base := idx
	var guard := 0
	while base.size() / 3 > int(target * 1.25) and guard < 8:
		guard += 1
		var levels := _lods_of(verts, normals, uvs, base)
		var pick: PackedInt32Array = PackedInt32Array()
		for l in levels:
			var li: PackedInt32Array = l[1]
			if li.size() / 3 >= int(target * 0.8):
				pick = li                       # самый грубый уровень, не ниже цели
		if pick.is_empty() and not levels.is_empty():
			pick = levels[0][1]                 # первый же уровень грубее цели — берём его
		if pick.is_empty() or pick.size() >= base.size():
			break
		base = pick
	var lods := {}
	for l in _lods_of(verts, normals, uvs, base):
		var li: PackedInt32Array = l[1]
		if li.size() / 3 >= 60 and li.size() < base.size():
			lods[l[0]] = li
	print("  tris %d -> %d (lods %d)" % [tris, base.size() / 3, lods.size()])
	return {"idx": base, "lods": lods}

static func build_mesh(arrays: Array, lods: Dictionary) -> ArrayMesh:
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)
	return m


static func base_arrays(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays


static func set_owner_rec(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		set_owner_rec(c, owner_node)


static func save_scene(root: Node, path: String) -> void:
	set_owner_rec(root, root)
	var ps := PackedScene.new()
	ps.pack(root)
	print("  saved ", path, " -> ", error_string(ResourceSaver.save(ps, path)))


# ───────────────────────── статичные предметы ─────────────────────────

func bake_prop(n: String, tex_size: int, target: int) -> void:
	print("prop ", n)
	var d := load_glb(n)
	if d.is_empty():
		return
	var verts: PackedVector3Array = d["verts"]
	var bb := bounds(verts)
	var off := Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	for i in verts.size():
		verts[i] -= off
	var normals := smooth_normals(verts, d["idx"])
	var s := simplify(verts, normals, d["uvs"], d["idx"], target)
	var mesh := build_mesh(base_arrays(verts, normals, d["uvs"], s["idx"]), s["lods"])
	print("  size ", mesh.get_aabb().size, " -> ", error_string(ResourceSaver.save(mesh, OUT + n + ".res")))
	save_tex(d["image"], n, tex_size)


# ───────────────────────── турели ─────────────────────────

static func _with(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	out.merge(b, true)
	return out


## Параметры турели по форме: ось вращения — центр колонны постамента (20–45 % высоты), срез — высота, где сечение
## резко расширяется (начинается само орудие), «вперёд» — направление самых дальних от оси точек выше среза (ствол).
static func auto_turret(verts: PackedVector3Array) -> Dictionary:
	var bb := bounds(verts)
	var H := bb.size.y
	var y0 := bb.position.y
	var col := Vector2.ZERO
	var cnt := 0
	for v in verts:
		var h := (v.y - y0) / H
		if h > 0.2 and h < 0.45:
			col += Vector2(v.x, v.z)
			cnt += 1
	col /= float(maxi(cnt, 1))
	var bins := 40
	var rad := PackedFloat32Array()
	rad.resize(bins)
	for v in verts:
		var k := clampi(int((v.y - y0) / H * bins), 0, bins - 1)
		rad[k] = maxf(rad[k], Vector2(v.x, v.z).distance_to(col))
	var col_r := PackedFloat32Array()
	for k in range(int(bins * 0.2), int(bins * 0.45)):
		col_r.append(rad[k])
	col_r.sort()
	var base_r := col_r[col_r.size() / 2]
	var cut := y0 + H * 0.55
	for k in range(int(bins * 0.3), int(bins * 0.8)):
		if rad[k] > base_r * 1.8:
			cut = y0 + H * (float(k) / bins) - H * 0.02
			break
	var far: Array = []
	for v in verts:
		if v.y > cut:
			far.append([Vector2(v.x, v.z).distance_to(col), Vector2(v.x - col.x, v.z - col.y)])
	far.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	var dir := Vector2.ZERO
	for i in mini(maxi(far.size() / 50, 5), far.size()):
		dir += (far[i][1] as Vector2).normalized()
	dir = dir.normalized()
	print("  auto: pivot (%.2f, %.2f), column r %.2f, cut %.2f of H, fwd %s" % [col.x, col.y, base_r, (cut - y0) / H, dir])
	return {"cx": col.x, "cz": col.y, "cut": cut, "fwd": dir}


func bake_turret(n: String, p: Dictionary) -> void:
	print("turret ", n)
	var d := load_glb(n)
	if d.is_empty():
		return
	var verts: PackedVector3Array = d["verts"]
	var bb := bounds(verts)
	if bool(p.get("auto", false)):
		p = _with(auto_turret(verts), p)          # заданные вручную значения важнее найденных
	var fwd: Vector2 = (p["fwd"] as Vector2).normalized()
	var cx: float = p["cx"]
	var cz: float = p["cz"]
	var cut: float = p["cut"]
	var ymin := bb.position.y
	var best := -INF
	for v in verts:
		best = maxf(best, v.x * fwd.x + v.z * fwd.y)
	var tip := Vector3.ZERO
	var cnt := 0
	for v in verts:
		if v.x * fwd.x + v.z * fwd.y >= best - 0.05:
			tip += v
			cnt += 1
	tip /= float(maxi(cnt, 1))
	var bones := [
		{"name": "root", "parent": "", "pos": Vector3(cx, ymin, cz)},
		{"name": "turret", "parent": "root", "pos": Vector3(cx, cut, cz)},
		{"name": "gun", "parent": "turret", "pos": Vector3(cx, tip.y, cz)},
	]
	# блок стволов Гатлинга: передняя часть орудия (дальше 55 % пути от оси до дула) рядом с линией ствола
	var spin := bool(p.get("spin", false))
	var f3 := Vector3(fwd.x, 0.0, fwd.y)
	var piv := Vector3(cx, 0.0, cz)
	var tip_d := (tip - piv).dot(f3)
	var is_barrel := func(v: Vector3) -> bool:
		if not spin or v.y < cut:
			return false
		var along := (v - piv).dot(f3)
		if along < tip_d * 0.55:
			return false
		var side := (v - piv) - f3 * along
		return Vector2(side.x, side.z).length() < bb.size.y * 0.12 and absf(v.y - tip.y) < bb.size.y * 0.14
	var bc := Vector3.ZERO
	var bn := 0
	if spin:
		for v in verts:
			if is_barrel.call(v):
				bc += v
				bn += 1
		bc /= float(maxi(bn, 1))
		bones.append({"name": "barrels", "parent": "gun", "pos": bc})
		print("  spinning barrels: %d vertices, axis through %s" % [bn, bc])
	var normals := smooth_normals(verts, d["idx"])
	var s := simplify(verts, normals, d["uvs"], d["idx"], int(p.get("tris", 1600)))
	var bi := PackedInt32Array()
	var bw := PackedFloat32Array()
	for v in verts:
		var w_up := smoothstep(cut - 0.03, cut + 0.03, v.y)
		if is_barrel.call(v):
			bi.append_array(PackedInt32Array([3, 0, 0, 0]))
			bw.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
			continue
		bi.append_array(PackedInt32Array([0, 2, 0, 0]))
		bw.append_array(PackedFloat32Array([1.0 - w_up, w_up, 0.0, 0.0]))
	var arrays := base_arrays(verts, normals, d["uvs"], s["idx"])
	arrays[Mesh.ARRAY_BONES] = bi
	arrays[Mesh.ARRAY_WEIGHTS] = bw
	var root := Node3D.new()
	root.name = str(p["out"]).capitalize().replace(" ", "")
	var sk := make_skeleton(bones)
	sk.position = Vector3(-cx, -ymin, -cz)
	root.add_child(sk)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = build_mesh(arrays, s["lods"])
	mi.skin = make_skin(bones)
	mi.custom_aabb = AABB(bb.position - Vector3(0.6, 0.6, 0.6), bb.size + Vector3(1.2, 1.2, 1.2))
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	root.set_meta("fwd_angle", atan2(fwd.x, fwd.y))
	root.set_meta("tip", Vector3(tip.x - cx, tip.y - ymin, tip.z - cz))
	root.set_meta("height", bb.size.y)
	root.set_meta("pivot_y", tip.y - ymin)
	root.set_meta("gun_axis", Vector3(-fwd.y, 0.0, fwd.x))
	root.set_meta("fwd", Vector3(fwd.x, 0.0, fwd.y))
	root.set_meta("tex", n)
	if spin:
		root.set_meta("spin_axis", f3)
	save_scene(root, OUT + str(p["out"]) + ".scn")
	root.free()
	save_tex(d["image"], n, 1024)


# ───────────────────────── скелет ─────────────────────────

static func make_skeleton(bones: Array) -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	var pos := {}
	for b in bones:
		pos[b["name"]] = b["pos"]
	for b in bones:
		var i := sk.add_bone(b["name"])
		var rest: Vector3 = b["pos"]
		if b["parent"] != "":
			sk.set_bone_parent(i, sk.find_bone(b["parent"]))
			rest = (b["pos"] as Vector3) - (pos[b["parent"]] as Vector3)
		sk.set_bone_rest(i, Transform3D(Basis(), rest))
	sk.reset_bone_poses()
	return sk


static func make_skin(bones: Array) -> Skin:
	var skin := Skin.new()
	for b in bones:
		skin.add_named_bind(b["name"], Transform3D(Basis(), -(b["pos"] as Vector3)))
	return skin


static func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 1e-9 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ───────────────────────── авто-скелет гуманоида ─────────────────────────

## Вершины слоя по высоте [y0, y1].
static func _slice(verts: PackedVector3Array, y0: float, y1: float) -> Array:
	var out: Array = []
	for v in verts:
		if v.y >= y0 and v.y <= y1:
			out.append(v)
	return out


static func _mean(pts: Array) -> Vector3:
	var s := Vector3.ZERO
	for v: Vector3 in pts:
		s += v
	return s / float(maxi(pts.size(), 1))


## Силуэт спереди: треугольники растеризуются в сетку по XY (устойчиво к редким вершинам).
class Silhouette:
	var cell := 0.01
	var x0 := 0.0
	var cols := 0
	var rows := 0
	var mask := PackedByteArray()

	func _init(verts: PackedVector3Array, idx: PackedInt32Array, h: float) -> void:
		rows = 260
		cell = h / float(rows)
		var mn := INF
		var mx := -INF
		for v in verts:
			mn = minf(mn, v.x)
			mx = maxf(mx, v.x)
		x0 = mn - cell
		cols = int(ceil((mx - mn) / cell)) + 3
		mask.resize(rows * cols)
		for t in range(0, idx.size(), 3):
			var a := Vector2(verts[idx[t]].x, verts[idx[t]].y)
			var b := Vector2(verts[idx[t + 1]].x, verts[idx[t + 1]].y)
			var c := Vector2(verts[idx[t + 2]].x, verts[idx[t + 2]].y)
			var c0 := clampi(int(floor((minf(a.x, minf(b.x, c.x)) - x0) / cell)), 0, cols - 1)
			var c1 := clampi(int(floor((maxf(a.x, maxf(b.x, c.x)) - x0) / cell)), 0, cols - 1)
			var r0 := clampi(int(floor(minf(a.y, minf(b.y, c.y)) / cell)), 0, rows - 1)
			var r1 := clampi(int(floor(maxf(a.y, maxf(b.y, c.y)) / cell)), 0, rows - 1)
			var area := (b - a).cross(c - a)
			if absf(area) < 1e-12:
				continue
			for r in range(r0, r1 + 1):
				for q in range(c0, c1 + 1):
					var p := Vector2(x0 + (q + 0.5) * cell, (r + 0.5) * cell)
					var w0 := (b - p).cross(c - p) / area
					var w1 := (c - p).cross(a - p) / area
					if w0 >= -0.02 and w1 >= -0.02 and 1.0 - w0 - w1 >= -0.02:
						mask[r * cols + q] = 1

	func col(x: float) -> int:
		return clampi(int(floor((x - x0) / cell)), 0, cols - 1)

	func row(y: float) -> int:
		return clampi(int(floor(y / cell)), 0, rows - 1)

	func filled(r: int, q: int) -> bool:
		return r >= 0 and r < rows and q >= 0 and q < cols and mask[r * cols + q] == 1

	func cx(q: int) -> float:
		return x0 + (q + 0.5) * cell

	## Сплошной отрезок строки r, содержащий столбец q (или пустой Vector2i(-1, -1)).
	func segment(r: int, q: int) -> Vector2i:
		if not filled(r, q):
			return Vector2i(-1, -1)
		var lo := q
		var hi := q
		while filled(r, lo - 1):
			lo -= 1
		while filled(r, hi + 1):
			hi += 1
		return Vector2i(lo, hi)

	## Первый заполненный отрезок шириной не меньше min_w столбцов, если идти от столбца q в сторону side.
	func first_segment(r: int, q: int, side: int, min_w: int = 1) -> Vector2i:
		var k := q
		while k >= 0 and k < cols:
			while k >= 0 and k < cols and not filled(r, k):
				k += side
			if k < 0 or k >= cols:
				return Vector2i(-1, -1)
			var seg := segment(r, k)
			if seg.y - seg.x + 1 >= min_w:
				return seg
			k = (seg.y + 1) if side > 0 else (seg.x - 1)
		return Vector2i(-1, -1)


## Скелет по форме тела (персонаж в A-позе, лицом к -Z, ступни на y=0, центр по XZ в нуле).
## Возвращает {"bones": [...], "segs": [[кость, начало, конец, сторона]], "drop_l", "drop_r", "height"}.
static func auto_skeleton(verts: PackedVector3Array, idx: PackedInt32Array) -> Dictionary:
	var H := bounds(verts).end.y
	var sil := Silhouette.new(verts, idx, H)
	var c0 := sil.col(0.0)
	# промежность: сверху вниз — первая строка, где по центру пусто 3 строки подряд, а по бокам ноги
	var crotch := H * 0.47
	var r := sil.row(H * 0.66)
	while r > sil.row(H * 0.25):
		if not sil.filled(r, c0) and not sil.filled(r - 1, c0) and not sil.filled(r - 2, c0):
			var left := sil.first_segment(r, c0, -1)
			var right := sil.first_segment(r, c0, 1)
			if left.x >= 0 and right.x >= 0 and absf(sil.cx(left.y)) < H * 0.12 and absf(sil.cx(right.x)) < H * 0.12:
				crotch = (r + 1) * sil.cell
				break
		r -= 1
	crotch = maxf(crotch, H * 0.36)      # набедренная повязка/шорты могут скрывать промежность
	# шея: самое узкое место центрального отрезка в верхней части
	var neck := H * 0.86
	var best_w := 1 << 30
	for rr in range(sil.row(H * 0.78), sil.row(H * 0.93)):
		var seg := sil.segment(rr, c0)
		if seg.x >= 0 and seg.y - seg.x < best_w:
			best_w = seg.y - seg.x
			neck = (rr + 0.5) * sil.cell
	var torso_z := func(yy: float) -> float:
		var pts: Array = []
		for v in verts:
			if absf(v.y - yy) < H * 0.03 and absf(v.x) < H * 0.08:
				pts.append(v)
		return _mean(pts).z if not pts.is_empty() else 0.0
	var near_z := func(p: Vector3) -> float:
		var pts: Array = []
		for v in verts:
			if Vector2(v.x - p.x, v.y - p.y).length() < H * 0.05:
				pts.append(v)
		return _mean(pts).z if not pts.is_empty() else p.z
	var sh_y := neck - H * 0.055
	var sh_seg := sil.segment(sil.row(sh_y), c0)
	var hips := Vector3(0, crotch + H * 0.045, torso_z.call(crotch + H * 0.045))
	var spine := Vector3(0, lerpf(hips.y, sh_y, 0.35), torso_z.call(lerpf(hips.y, sh_y, 0.35)))
	var chest := Vector3(0, lerpf(hips.y, sh_y, 0.72), torso_z.call(lerpf(hips.y, sh_y, 0.72)))
	var neck_p := Vector3(0, neck, torso_z.call(neck))
	var head := Vector3(0, neck + H * 0.035, neck_p.z)
	var top := Vector3(0, H, neck_p.z)
	var bones: Array = [
		{"name": "root", "parent": "", "pos": Vector3.ZERO},
		{"name": "hips", "parent": "root", "pos": hips},
		{"name": "spine", "parent": "hips", "pos": spine},
		{"name": "chest", "parent": "spine", "pos": chest},
		{"name": "neck", "parent": "chest", "pos": neck_p},
		{"name": "head", "parent": "neck", "pos": head},
	]
	var segs: Array = [
		["hips", hips, spine, 0], ["spine", spine, chest, 0], ["chest", chest, neck_p, 0],
		["neck", neck_p, head, 0], ["head", head, top, 0],
	]
	# кисти: трассируем руку по силуэту вниз от плеча — внешний отрезок, отделённый от корпуса и непрерывный
	# по строкам; если рука нигде не отделяется от тела — берём самые крайние по X точки
	var find_hand := func(side: int) -> Array:
		var outer := func(rr: int) -> Vector2i:
			var k := 0 if side < 0 else sil.cols - 1
			while k >= 0 and k < sil.cols and not sil.filled(rr, k):
				k -= side
			if k < 0 or k >= sil.cols:
				return Vector2i(-1, -1)
			return sil.segment(rr, k)
		var trace: Array = []
		var prev := Vector2i(-1, -1)
		for rr in range(sil.row(sh_y), sil.row(H * 0.08), -1):
			var seg: Vector2i = outer.call(rr)
			var separate := seg.x >= 0 and not (seg.x <= c0 and seg.y >= c0)
			if prev.x < 0:
				if separate and (rr + 0.5) * sil.cell > crotch + H * 0.04:
					prev = seg
					trace.append([rr, seg])
				continue
			if not separate or seg.y < prev.x - 1 or seg.x > prev.y + 1:
				break
			prev = seg
			trace.append([rr, seg])
		if trace.size() >= 6:
			var tail: Array = trace.slice(maxi(0, trace.size() - 5))
			var hx := 0.0
			for tr in tail:
				var sg: Vector2i = tr[1]
				hx += (sil.cx(sg.x) + sil.cx(sg.y)) * 0.5
			return [Vector3(hx / tail.size(), (int(trace[trace.size() - 1][0]) + 1.5) * sil.cell, 0.0), trace.size(), trace]
		var ext_q := c0
		var ext_rows: Array = []
		for rr in range(sil.row(H * 0.25), sil.row(sh_y)):
			var k := 0 if side < 0 else sil.cols - 1
			while k != c0 and not sil.filled(rr, k):
				k -= side
			if (side < 0 and k < ext_q) or (side > 0 and k > ext_q):
				ext_q = k
				ext_rows = [rr]
			elif k == ext_q:
				ext_rows.append(rr)
		var hand_y := 0.0
		for rr in ext_rows:
			hand_y += (rr + 0.5) * sil.cell
		hand_y /= float(maxi(ext_rows.size(), 1))
		return [Vector3(sil.cx(ext_q) - side * H * 0.02, hand_y, 0.0), 0, []]
	var hands := {-1: find_hand.call(-1), 1: find_hand.call(1)}
	# тела почти симметричны: если одна рука найдена заметно выше другой — зеркалим лучшую
	var hl: Vector3 = hands[-1][0]
	var hr: Vector3 = hands[1][0]
	if absf(hl.y - hr.y) > H * 0.08:
		if hl.y < hr.y:
			hands[1] = [Vector3(-hl.x, hl.y, hl.z), hands[-1][1], []]
		else:
			hands[-1] = [Vector3(-hr.x, hr.y, hr.z), hands[1][1], []]
	var drops := {}
	var hand_zone := {}
	for side: int in [-1, 1]:
		var suffix := "_L" if side < 0 else "_R"
		var edge_q: int = sh_seg.x if side < 0 else sh_seg.y
		var shoulder := Vector3(sil.cx(edge_q) - side * H * 0.05, sh_y, 0.0)
		shoulder.z = near_z.call(shoulder)
		var hand: Vector3 = hands[side][0]
		hand.z = near_z.call(hand)
		var wrist := shoulder.lerp(hand, 0.84)
		var elbow := shoulder.lerp(wrist, 0.5)
		elbow.z = near_z.call(elbow)
		# кончики пальцев: точка кисти по силуэту бывает выше реального конца руки (кисть касается бедра) —
		# продлеваем предплечье вдоль руки до самых дальних вершин в узком цилиндре; иначе пальцы достаются ноге
		# и при взмахе руки тянутся «палками»
		var hdir := (hand - elbow).normalized()
		var reach := PackedFloat32Array()
		for v in verts:
			if side * v.x <= 0.0:
				continue
			var rel := v - hand
			var sp := rel.dot(hdir)
			if sp > 0.0 and sp < H * 0.2 and (rel - hdir * sp).length() < H * 0.05:
				reach.append(sp)
		if reach.size() > 3:
			reach.sort()
			hand += hdir * reach[int(reach.size() * 0.95)]
		hand_zone[side] = [shoulder.lerp(hand, 0.78), hand, hdir]
		# ноги: первый отрезок от центральной щели на высоте бедра, колена и лодыжки
		var leg_at := func(yy: float) -> Vector3:
			var seg := sil.first_segment(sil.row(yy), c0, side, int(H * 0.045 / sil.cell))
			if seg.x >= 0 and seg.x <= c0 and seg.y >= c0:
				seg = Vector2i(c0, seg.y) if side > 0 else Vector2i(seg.x, c0)   # ноги сомкнуты: берём свою половину
			var x := side * H * 0.09 if seg.x < 0 else (sil.cx(seg.x) + sil.cx(seg.y)) * 0.5
			var p := Vector3(x, yy, 0.0)
			p.z = near_z.call(p)
			return p
		var hip_j: Vector3 = leg_at.call(crotch - H * 0.03)
		hip_j.y = crotch
		var knee: Vector3 = leg_at.call(H * 0.28)
		var ankle: Vector3 = leg_at.call(H * 0.06)
		var toe := ankle
		for v in verts:
			if v.y < H * 0.05 and v.x * side > 0.0 and v.z < toe.z and absf(v.x - ankle.x) < H * 0.08:
				toe = v
		toe.y = H * 0.02
		bones.append_array([
			{"name": "upperarm" + suffix, "parent": "chest", "pos": shoulder},
			{"name": "forearm" + suffix, "parent": "upperarm" + suffix, "pos": elbow},
			{"name": "thigh" + suffix, "parent": "hips", "pos": hip_j},
			{"name": "shin" + suffix, "parent": "thigh" + suffix, "pos": knee},
			{"name": "foot" + suffix, "parent": "shin" + suffix, "pos": ankle},
		])
		segs.append_array([
			["upperarm" + suffix, shoulder, elbow, side], ["forearm" + suffix, elbow, hand, side],
			["thigh" + suffix, hip_j, knee, side], ["shin" + suffix, knee, ankle, side], ["foot" + suffix, ankle, toe, side],
		])
		drops[side] = atan2(absf(hand.x - shoulder.x), maxf(shoulder.y - hand.y, 0.01))
	print("  H %.2f crotch %.2f neck %.2f shoulders %.2f drops %.2f %.2f" % [H, crotch / H, neck / H, sh_y / H, drops[-1], drops[1]])
	_debug_image(sil, bones, segs)
	# внешний край тела (корпус выше промежности, нога ниже) по строкам силуэта: всё, что в силуэте торчит дальше, —
	# рука (кисть, пальцы); {сторона: {строка: столбец края}}
	var body_edge := {}
	var leg_w := int(H * 0.045 / sil.cell)
	for side: int in [-1, 1]:
		var edges := {}
		for rr in range(sil.row(H * 0.05), sil.row(sh_y - H * 0.02)):
			var seg: Vector2i
			if (rr + 0.5) * sil.cell >= crotch:
				seg = sil.segment(rr, c0)
			else:
				seg = sil.first_segment(rr, c0, side, leg_w)
			if seg.x >= 0:
				edges[rr] = seg.y if side > 0 else seg.x
		body_edge[side] = edges
	# строки силуэта, где рука отделена от корпуса: {сторона: {строка: [первый, последний столбец]}} — для весов кожи
	var arm_rows := {}
	for side: int in [-1, 1]:
		var rows := {}
		for tr in hands[side][2]:
			rows[int(tr[0])] = tr[1]
		arm_rows[side] = rows
	return {"bones": bones, "segs": segs, "drop_l": drops[-1], "drop_r": drops[1], "height": H,
		"arm_rows": arm_rows, "sil_cell": sil.cell, "sil_x0": sil.x0, "hand_zone": hand_zone, "body_edge": body_edge}

## Веса кожи. Кость — «капсула»: отрезок с радиусом, оценённым по самой модели (75-й перцентиль расстояний
## «своих» вершин; корпус толстый, рука тонкая). Вес 1/d⁴ от поверхности капсулы, а не от оси — иначе бока корпуса
## у подмышек достаются руке и тянутся при взмахе. Вершина не получает кости противоположной стороны; до 4 влияний.
static func auto_weights(verts: PackedVector3Array, rig: Dictionary) -> Array:
	var index := {}
	var bones: Array = rig["bones"]
	for i in bones.size():
		index[bones[i]["name"]] = i
	var H: float = rig["height"]
	var segs: Array = rig["segs"]
	# ниже промежности вершина всегда принадлежит одной ноге (по знаку x) — иначе сомкнутые стопы получают веса
	# обеих ног и при шаге между ними тянется перепонка
	var crotch_y := INF
	for b in rig["bones"]:
		if b["name"] == "thigh_L":
			crotch_y = (b["pos"] as Vector3).y
	var side_of := func(v: Vector3) -> int:
		if v.y < crotch_y - H * 0.03:
			return 1 if v.x >= 0.0 else -1
		return 0 if absf(v.x) < H * 0.02 else (1 if v.x > 0.0 else -1)
	# радиусы капсул: для каждой вершины ближайший по оси отрезок → распределение расстояний по костям
	var dists: Array = []
	for s in segs:
		dists.append(PackedFloat32Array())
	for v in verts:
		var best := -1
		var best_d := INF
		var vs: int = side_of.call(v)
		for i in segs.size():
			var sd: int = segs[i][3]
			if sd != 0 and vs != 0 and sd != vs:
				continue
			var d := seg_dist(v, segs[i][1], segs[i][2])
			if d < best_d:
				best_d = d
				best = i
		if best >= 0:
			dists[best].append(best_d)
	var is_arm := func(name: String) -> bool: return name.begins_with("upperarm") or name.begins_with("forearm")
	var radius := PackedFloat32Array()
	for i in segs.size():
		var arr: PackedFloat32Array = dists[i]
		if arr.is_empty():
			radius.append(0.0)
			continue
		arr.sort()
		# у рук радиус по медиане (в «свои» вершины руки попадают и бока корпуса — 75-й перцентиль их бы захватил)
		var arm_seg: bool = is_arm.call(str(segs[i][0]))
		radius.append(arr[int(arr.size() * (0.5 if arm_seg else 0.75))] * (0.8 if arm_seg else 0.85))
	# руки по силуэту: в строках, где рука отделена от корпуса, вершины внутри отрезка руки — только руке,
	# снаружи — никогда руке (бока корпуса и волосы не тянутся за рукой)
	var arm_rows: Dictionary = rig.get("arm_rows", {})
	var cell: float = rig.get("sil_cell", 1.0)
	var x0: float = rig.get("sil_x0", 0.0)
	var bi := PackedInt32Array()
	var bw := PackedFloat32Array()
	for v in verts:
		var ws: Array = []
		var vs: int = side_of.call(v)
		var arm_mode := 0          # 0 — без ограничений, 1 — только рука своей стороны, -1 — без рук
		var edges_all: Dictionary = rig.get("body_edge", {})
		if vs != 0 and edges_all.has(vs):
			var rr := int(floor(v.y / cell))
			var q := int(floor((v.x - x0) / cell))
			var edges: Dictionary = edges_all[vs]
			var rows: Dictionary = arm_rows.get(vs, {})
			if edges.has(rr):
				var beyond: int = (q - int(edges[rr])) * vs
				if beyond > 1:
					arm_mode = 1                # за краем корпуса или ноги — только рука (кисть, пальцы)
				elif beyond < -1 and rows.has(rr):
					arm_mode = -1               # внутри корпуса в строке, где рука отделена, — руке не достаётся
			elif rows.has(rr):
				var seg: Vector2i = rows[rr]
				arm_mode = 1 if (q >= seg.x - 1 and q <= seg.y + 1) else -1
		for i in segs.size():
			var sd: int = segs[i][3]
			if sd != 0 and vs != 0 and sd != vs:
				continue
			var arm: bool = is_arm.call(str(segs[i][0]))
			if (arm_mode == 1 and not arm) or (arm_mode == -1 and arm):
				continue
			var d := maxf(seg_dist(v, segs[i][1], segs[i][2]) - radius[i], 0.0)
			if arm and arm_mode == 0:
				d = d * 1.4 + H * 0.01          # спорные вершины (бок корпуса у руки) — скорее корпусу
			ws.append([index[segs[i][0]], 1.0 / pow(d + H * 0.012, 4.0)])
		ws.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
		var total := 0.0
		for k in mini(4, ws.size()):
			total += ws[k][1]
		for k in 4:
			if k < ws.size():
				bi.append(ws[k][0])
				bw.append(ws[k][1] / total)
			else:
				bi.append(0)
				bw.append(0.0)
	return [bi, bw]

# ───────────────────────── анимации ─────────────────────────

static func rot_track(a: Animation, bone: String, fn: Callable, steps: int = 16) -> void:
	var t := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(t, "Skeleton3D:" + bone)
	for i in steps + 1:
		var ph := float(i) / float(steps)
		a.rotation_track_insert_key(t, ph * a.length, Quaternion.from_euler(fn.call(ph * TAU)))


static func pos_track(a: Animation, bone: String, rest: Vector3, fn: Callable, steps: int = 16) -> void:
	var t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(t, "Skeleton3D:" + bone)
	for i in steps + 1:
		var ph := float(i) / float(steps)
		a.position_track_insert_key(t, ph * a.length, rest + fn.call(ph * TAU))


## Анимации зомби для A-позы: dl/dr — опускание рук к телу (угол от вертикали), hr — смещение таза в покое.
static func zombie_anims(dl: float, dr: float, hr: Vector3, H: float) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var bob := H * 0.012
	# шаркающая походка: руки вытянуты вперёд, корпус наклонён, голова свесилась, правая нога подволакивается
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	rot_track(a, "thigh_L", func(t: float) -> Vector3: return Vector3(0.5 * sin(t), 0, 0))
	rot_track(a, "thigh_R", func(t: float) -> Vector3: return Vector3(-0.36 * sin(t), 0, 0))
	rot_track(a, "shin_L", func(t: float) -> Vector3: return Vector3(-0.7 * maxf(0.0, cos(t)), 0, 0))
	rot_track(a, "shin_R", func(t: float) -> Vector3: return Vector3(-0.35 * maxf(0.0, -cos(t)), 0, 0))
	rot_track(a, "foot_L", func(t: float) -> Vector3: return Vector3(0.25 * maxf(0.0, -cos(t)), 0, 0))
	rot_track(a, "spine", func(t: float) -> Vector3: return Vector3(-0.12 + 0.02 * absf(sin(t)), 0.1 * sin(t), 0.05 * sin(t)))
	rot_track(a, "chest", func(t: float) -> Vector3: return Vector3(-0.1, -0.08 * sin(t), 0.04 * sin(t)))
	rot_track(a, "neck", func(t: float) -> Vector3: return Vector3(0.1, 0, 0.16 + 0.04 * sin(t * 2.0)))
	rot_track(a, "head", func(t: float) -> Vector3: return Vector3(0.1, 0.06 * sin(t), 0.08 * sin(t + 1.0)))
	rot_track(a, "upperarm_L", func(t: float) -> Vector3: return Vector3(1.2 + 0.1 * sin(t), 0.12, dl * 0.97))
	rot_track(a, "forearm_L", func(t: float) -> Vector3: return Vector3(0.3 + 0.08 * sin(t), 0, 0))
	rot_track(a, "upperarm_R", func(t: float) -> Vector3: return Vector3(1.0 - 0.12 * sin(t), -0.12, -dr * 0.97))
	rot_track(a, "forearm_R", func(t: float) -> Vector3: return Vector3(0.4 - 0.08 * sin(t), 0, 0))
	pos_track(a, "hips", hr, func(t: float) -> Vector3: return Vector3(bob * sin(t), bob * 1.6 * absf(sin(t)), 0))
	lib.add_animation("walk", a)
	# атака: замах обеими руками сверху вниз с выпадом корпуса
	var b := Animation.new()
	b.length = 0.9
	b.loop_mode = Animation.LOOP_LINEAR
	var sw := func(t: float) -> float: return 0.5 - 0.5 * cos(t)
	rot_track(b, "upperarm_L", func(t: float) -> Vector3: return Vector3(2.1 - 1.2 * sw.call(t), 0.2, dl * 0.8))
	rot_track(b, "upperarm_R", func(t: float) -> Vector3: return Vector3(2.1 - 1.2 * sw.call(t), -0.2, -dr * 0.8))
	rot_track(b, "forearm_L", func(t: float) -> Vector3: return Vector3(0.5 - 0.3 * sw.call(t), 0, 0))
	rot_track(b, "forearm_R", func(t: float) -> Vector3: return Vector3(0.5 - 0.3 * sw.call(t), 0, 0))
	rot_track(b, "spine", func(t: float) -> Vector3: return Vector3(0.1 - 0.42 * sw.call(t), 0, 0))
	rot_track(b, "chest", func(t: float) -> Vector3: return Vector3(0.06 - 0.25 * sw.call(t), 0.06 * sin(t), 0))
	rot_track(b, "neck", func(t: float) -> Vector3: return Vector3(0.1 + 0.2 * sw.call(t), 0, 0.14))
	rot_track(b, "thigh_L", func(_t: float) -> Vector3: return Vector3(0.18, 0, 0))
	rot_track(b, "thigh_R", func(_t: float) -> Vector3: return Vector3(-0.1, 0, 0))
	rot_track(b, "shin_L", func(_t: float) -> Vector3: return Vector3(-0.2, 0, 0))
	lib.add_animation("attack", b)
	# покой
	var c := Animation.new()
	c.length = 2.0
	c.loop_mode = Animation.LOOP_LINEAR
	rot_track(c, "spine", func(t: float) -> Vector3: return Vector3(-0.1 + 0.02 * sin(t), 0.05 * sin(t), 0))
	rot_track(c, "neck", func(t: float) -> Vector3: return Vector3(0.15, 0, 0.2 + 0.05 * sin(t)))
	rot_track(c, "upperarm_L", func(t: float) -> Vector3: return Vector3(0.4 + 0.06 * sin(t), 0, dl * 0.9))
	rot_track(c, "upperarm_R", func(t: float) -> Vector3: return Vector3(0.3 - 0.06 * sin(t), 0, -dr * 0.9))
	rot_track(c, "forearm_L", func(_t: float) -> Vector3: return Vector3(0.4, 0, 0))
	rot_track(c, "forearm_R", func(_t: float) -> Vector3: return Vector3(0.3, 0, 0))
	lib.add_animation("idle", c)
	return lib


## Анимации солдата: автомат у груди (руки держат оружие), ходьба, удар холодным оружием, покой.
static func soldier_anims(dl: float, dr: float, hr: Vector3, H: float) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var bob := H * 0.01
	var arms := func(anim: Animation) -> void:
		rot_track(anim, "upperarm_R", func(_t: float) -> Vector3: return Vector3(0.55, 0.35, -dr * 0.95))
		rot_track(anim, "forearm_R", func(_t: float) -> Vector3: return Vector3(1.35, 0.25, 0))
		rot_track(anim, "upperarm_L", func(_t: float) -> Vector3: return Vector3(1.05, -0.55, dl * 0.95))
		rot_track(anim, "forearm_L", func(_t: float) -> Vector3: return Vector3(0.55, -0.2, 0))
	var w := Animation.new()
	w.length = 0.8
	w.loop_mode = Animation.LOOP_LINEAR
	rot_track(w, "thigh_L", func(t: float) -> Vector3: return Vector3(0.55 * sin(t), 0, 0))
	rot_track(w, "thigh_R", func(t: float) -> Vector3: return Vector3(-0.55 * sin(t), 0, 0))
	rot_track(w, "shin_L", func(t: float) -> Vector3: return Vector3(-0.8 * maxf(0.0, cos(t)), 0, 0))
	rot_track(w, "shin_R", func(t: float) -> Vector3: return Vector3(-0.8 * maxf(0.0, -cos(t)), 0, 0))
	pos_track(w, "hips", hr, func(t: float) -> Vector3: return Vector3(0, bob * absf(sin(t)), 0))
	arms.call(w)
	lib.add_animation("walk", w)
	var i := Animation.new()
	i.length = 2.0
	i.loop_mode = Animation.LOOP_LINEAR
	pos_track(i, "hips", hr, func(t: float) -> Vector3: return Vector3(0, bob * 0.3 * sin(t), 0))
	arms.call(i)
	lib.add_animation("idle", i)
	# удар: правая рука сверху вниз наискосок
	var s := Animation.new()
	s.length = 0.5
	var sw := func(t: float) -> float: return 0.5 - 0.5 * cos(t)
	rot_track(s, "upperarm_R", func(t: float) -> Vector3: return Vector3(2.4 - 2.0 * sw.call(t), 0.3, -dr * 0.9 - 0.3 * sw.call(t)))
	rot_track(s, "forearm_R", func(t: float) -> Vector3: return Vector3(0.9 - 0.7 * sw.call(t), 0, 0))
	rot_track(s, "upperarm_L", func(_t: float) -> Vector3: return Vector3(0.4, 0, dl * 0.9))
	rot_track(s, "forearm_L", func(_t: float) -> Vector3: return Vector3(0.6, 0, 0))
	lib.add_animation("swing", s)
	return lib


# ───────────────────────── гуманоиды ─────────────────────────

func bake_humanoid(n: String, p: Dictionary) -> void:
	print("humanoid ", n)
	debug_name = n
	var d := load_glb(n)
	if d.is_empty():
		return
	var verts: PackedVector3Array = d["verts"]
	# лицом к -Z (носки ступней выдаются вперёд): иначе разворачиваем на 180°
	var bb := bounds(verts)
	var low := _slice(verts, bb.position.y, bb.position.y + bb.size.y * 0.05)
	var feet_z := _mean(low).z
	if feet_z > bb.get_center().z:
		for i in verts.size():
			verts[i] = Vector3(-verts[i].x, verts[i].y, -verts[i].z)
		print("  flipped to face -Z")
	bb = bounds(verts)
	var off := Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	for i in verts.size():
		verts[i] -= off
	var rig := auto_skeleton(verts, d["idx"])
	var normals := smooth_normals(verts, d["idx"])
	var s := simplify(verts, normals, d["uvs"], d["idx"], int(p["tris"]))
	var wts := auto_weights(verts, rig)
	if OS.get_environment("RT_DEBUG") != "":
		_debug_weights(verts, rig, wts)
	var arrays := base_arrays(verts, normals, d["uvs"], s["idx"])
	arrays[Mesh.ARRAY_BONES] = wts[0]
	arrays[Mesh.ARRAY_WEIGHTS] = wts[1]
	var root := Node3D.new()
	root.name = n.capitalize().replace(" ", "")
	var sk := make_skeleton(rig["bones"])
	root.add_child(sk)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = build_mesh(arrays, s["lods"])
	mi.skin = make_skin(rig["bones"])
	var H: float = rig["height"]
	mi.custom_aabb = AABB(Vector3(-H * 0.7, -H * 0.2, -H * 0.7), Vector3(H * 1.4, H * 1.4, H * 1.4))
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	root.set_meta("rig_height", H)
	root.set_meta("tex", n)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	var hips: Vector3 = rig["bones"][1]["pos"]
	if p["kind"] == "soldier":
		ap.add_animation_library("", soldier_anims(rig["drop_l"], rig["drop_r"], hips, H))
		# точки крепления оружия (в системе скелета): автомат у груди справа, ствол вперёд (-Z)
		var chest: Vector3 = rig["bones"][3]["pos"]
		root.set_meta("rifle_pos", chest + Vector3(H * 0.07, -H * 0.06, -H * 0.16))
	elif _anim_pack() != null:
		# у громилы огромные руки висят вдоль тела — полный размах рук из пака сетка не выдерживает
		# у моделей с руками вдоль тела (генератор сращивает кисти с бёдрами, плечи с боками) большой размах рук рвёт
		# или растягивает сетку — ослабляем его; у ходока и броненосца руки отставлены (A-поза), им можно полный
		var damp := {}
		match n:
			"z_fat", "z_boomer":
				damp = {"upperarm_L": 0.4, "upperarm_R": 0.4, "forearm_L": 0.55, "forearm_R": 0.55}
			"z_brute":
				damp = {"upperarm_L": 0.25, "upperarm_R": 0.25, "forearm_L": 0.4, "forearm_R": 0.4}
		var res: Array = rt.zombie_library(rig, ZOMBIE_WALKS.get(n, ["walk_a"]), damp)
		ap.add_animation_library("", res[0])
		root.set_meta("anims", res[1])
	else:
		ap.add_animation_library("", zombie_anims(rig["drop_l"], rig["drop_r"], hips, H))
	get_root().add_child(root)
	cut_stretched(root, s)
	get_root().remove_child(root)
	save_scene(root, OUT + n + ".scn")
	root.free()
	save_tex(d["image"], n, int(p["tex"]))


## Быстрые зомби: модели девушек — одна сетка, пять текстур; автоматический скелет, как у остальных.
func bake_girl() -> void:
	print("girl")
	debug_name = "girl"
	var d := load_glb("girl_A")
	var verts: PackedVector3Array = d["verts"]
	for i in verts.size():
		verts[i] = Vector3(-verts[i].x, verts[i].y, -verts[i].z)     # лицом к -Z
	var bb := bounds(verts)
	var off := Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	for i in verts.size():
		verts[i] -= off
	var rig := auto_skeleton(verts, d["idx"])
	var normals := smooth_normals(verts, d["idx"])
	var s := simplify(verts, normals, d["uvs"], d["idx"], 1300)
	var wts := auto_weights(verts, rig)
	if OS.get_environment("RT_DEBUG") != "":
		_debug_weights(verts, rig, wts)
	var arrays := base_arrays(verts, normals, d["uvs"], s["idx"])
	arrays[Mesh.ARRAY_BONES] = wts[0]
	arrays[Mesh.ARRAY_WEIGHTS] = wts[1]
	var root := Node3D.new()
	root.name = "Girl"
	var sk := make_skeleton(rig["bones"])
	root.add_child(sk)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = build_mesh(arrays, s["lods"])
	mi.skin = make_skin(rig["bones"])
	var H: float = rig["height"]
	mi.custom_aabb = AABB(Vector3(-H * 0.7, -H * 0.2, -H * 0.7), Vector3(H * 1.4, H * 1.4, H * 1.4))
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	root.set_meta("rig_height", H)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	if _anim_pack() != null:
		# у девушки руки прижаты к телу и рукава короткие: размах рук при беге уменьшаем
		var res: Array = rt.zombie_library(rig, ZOMBIE_WALKS["girl"], {"upperarm_L": 0.15, "upperarm_R": 0.15, "forearm_L": 0.3, "forearm_R": 0.3})
		ap.add_animation_library("", res[0])
		root.set_meta("anims", res[1])
	else:
		ap.add_animation_library("", zombie_anims(rig["drop_l"], rig["drop_r"], rig["bones"][1]["pos"], H))
	get_root().add_child(root)
	cut_stretched(root, s)
	get_root().remove_child(root)
	save_scene(root, OUT + "girl.scn")
	root.free()
	for g in GIRLS:
		save_tex(load_glb(g)["image"], g, 1024)

# ───────────────────────── оружие ─────────────────────────

## Главная ось облака точек (степенной метод по матрице ковариации).
static func principal_axis(verts: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for v in verts:
		c += v
	c /= float(verts.size())
	var m := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	for v in verts:
		var d := v - c
		var a := [d.x, d.y, d.z]
		for i in 3:
			for j in 3:
				m[i][j] += a[i] * a[j]
	var e := Vector3(1, 0.3, 0.1).normalized()
	for it in 40:
		var n := Vector3(
			m[0][0] * e.x + m[0][1] * e.y + m[0][2] * e.z,
			m[1][0] * e.x + m[1][1] * e.y + m[1][2] * e.z,
			m[2][0] * e.x + m[2][1] * e.y + m[2][2] * e.z)
		e = n.normalized()
	return e


func bake_weapon(n: String, p: Dictionary) -> void:
	print("weapon ", n)
	var d := load_glb(n)
	if d.is_empty():
		return
	var verts: PackedVector3Array = d["verts"]
	var c := bounds(verts).get_center()
	for i in verts.size():
		verts[i] -= c
	var gun: bool = p["mode"] == "gun"
	var ax := principal_axis(verts)
	var e2 := Vector3.ZERO
	if bool(p.get("auto", false)):
		# концы: у автомата дуло тоньше приклада, у топора головка толще рукояти
		var proj := PackedFloat32Array()
		var lo := INF
		var hi := -INF
		for v in verts:
			var t := v.dot(ax)
			proj.append(t)
			lo = minf(lo, t)
			hi = maxf(hi, t)
		var spread := func(from: float, to: float) -> float:
			var sm := 0.0
			var cnt := 0
			for i in verts.size():
				if proj[i] >= from and proj[i] <= to:
					sm += (verts[i] - ax * proj[i]).length()
					cnt += 1
			return sm / maxf(cnt, 1)
		var len := hi - lo
		var s_lo: float = spread.call(lo, lo + len * 0.2)
		var s_hi: float = spread.call(hi - len * 0.2, hi)
		var hi_is_target := (s_hi < s_lo) if gun else (s_hi > s_lo)     # целевой конец: дуло / головка
		if not hi_is_target:
			ax = -ax
		var main_to := Vector3(0, 0, -1) if gun else Vector3(0, 1, 0)
		var q := Basis(Quaternion(ax, main_to))
		for i in verts.size():
			verts[i] = q * verts[i]
		# поворот вокруг оси: у автомата ствол выше центра масс (магазин и рукоять внизу) → «вверх»;
		# у топора лезвие — смещение головки от рукояти → вперёд (+Z)
		var all_c := Vector3.ZERO
		var end_c := Vector3.ZERO
		var cnt2 := 0
		var lo2 := INF
		var hi2 := -INF
		for v in verts:
			var t2 := v.dot(main_to)
			lo2 = minf(lo2, t2)
			hi2 = maxf(hi2, t2)
		for v in verts:
			all_c += v
			if v.dot(main_to) > hi2 - (hi2 - lo2) * (0.3 if gun else 0.22):
				end_c += v
				cnt2 += 1
		all_c /= float(verts.size())
		end_c /= float(maxi(cnt2, 1))
		var off := end_c - all_c
		off -= main_to * off.dot(main_to)
		var target := Vector3(0, 1, 0) if gun else Vector3(0, 0, 1)
		e2 = off.normalized()
		var r0 := Basis(Quaternion(e2, target))
		for i in verts.size():
			verts[i] = r0 * verts[i]
	else:
		if bool(p["flip"]):
			ax = -ax
		var main_to2 := Vector3(0, 0, -1) if gun else Vector3(0, 1, 0)
		var q2 := Basis(Quaternion(ax, main_to2))
		for i in verts.size():
			verts[i] = q2 * verts[i]
		# вторая ось — в плоскости, перпендикулярной главной: 2D-ковариация и «хвост» (третий момент)
		var u := Vector3(1, 0, 0)
		var w := Vector3(0, 1, 0) if gun else Vector3(0, 0, 1)
		var suu := 0.0
		var suw := 0.0
		var sww := 0.0
		for v in verts:
			var a := v.dot(u)
			var b := v.dot(w)
			suu += a * a
			suw += a * b
			sww += b * b
		var ang := 0.5 * atan2(2.0 * suw, suu - sww)
		e2 = u * cos(ang) + w * sin(ang)
		var skew := 0.0
		for v in verts:
			skew += pow(v.dot(e2), 3.0)
		if skew < 0.0:
			e2 = -e2
		var r := Basis(Quaternion(e2, (Vector3(0, 1, 0) if gun else Vector3(0, 0, 1)) * float(p["tail"])))
		for i in verts.size():
			verts[i] = r * verts[i]
	var bb2 := bounds(verts)
	var normals := smooth_normals(verts, d["idx"])
	var s := simplify(verts, normals, d["uvs"], d["idx"], int(p["tris"]))
	var mesh := build_mesh(base_arrays(verts, normals, d["uvs"], s["idx"]), s["lods"])
	mesh.set_meta("aabb", bb2)
	print("  axis ", ax, " tail ", e2, " size ", bb2.size, " -> ", error_string(ResourceSaver.save(mesh, OUT + n + ".res")))
	save_tex(d["image"], n, int(p["tex"]))


## Отладка: силуэт и кости в shots/rig_<n>.png.
static var debug_name := ""


static func _debug_image(sil: Silhouette, bones: Array, segs: Array) -> void:
	if debug_name == "":
		return
	var img := Image.create(sil.cols, sil.rows, false, Image.FORMAT_RGB8)
	for r in sil.rows:
		for q in sil.cols:
			img.set_pixel(q, sil.rows - 1 - r, Color(0.8, 0.8, 0.8) if sil.filled(r, q) else Color(0.15, 0.15, 0.18))
	for s in segs:
		var a: Vector3 = s[1]
		var b: Vector3 = s[2]
		for i in 40:
			var p := a.lerp(b, i / 39.0)
			var q := sil.col(p.x)
			var rr := sil.rows - 1 - sil.row(p.y)
			img.set_pixel(q, rr, Color(1, 0.2, 0.1) if s[3] < 0 else (Color(0.1, 0.5, 1) if s[3] > 0 else Color(0.1, 0.9, 0.2)))
	img.resize(sil.cols * 3, sil.rows * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path("res://shots/rig_%s.png" % debug_name))


## Отладка весов: вершины по доминирующей кости в крайних по X областях (там, где кисти).
static func _debug_weights(verts: PackedVector3Array, rig: Dictionary, wts: Array) -> void:
	var bi: PackedInt32Array = wts[0]
	var bw: PackedFloat32Array = wts[1]
	var names: Array = []
	for b in rig["bones"]:
		names.append(b["name"])
	var bad := {}
	var H: float = rig["height"]
	for i in verts.size():
		var v := verts[i]
		var s := bw[i * 4] + bw[i * 4 + 1] + bw[i * 4 + 2] + bw[i * 4 + 3]
		if s < 0.99 or is_nan(s):
			bad["sum!=1"] = int(bad.get("sum!=1", 0)) + 1
		if absf(v.x) > H * 0.22:
			var nm: String = names[bi[i * 4]]
			bad[nm] = int(bad.get(nm, 0)) + 1
	print("  weights at |x|>0.22H: ", bad, " hand_zone ", rig.get("hand_zone", {}))


## «Склейки»: генератор сращивает касающиеся части тела (кисть с бедром, обувь между собой). Рёбра «кисть/предплечье —
## чужая кость» и «стопа/голень — другая нога», которые в анимациях растягиваются больше чем в stretch раз (и длиннее
## 0,1 высоты), — это «палки» на концах рук. Чиним в два прохода: сначала вершины руки на таких рёбрах отдаём кости
## соседа (место склейки остаётся на теле, тело не рвётся, у кисти пропадает лишь тонкий слой), затем оставшиеся
## растянутые треугольники удаляем. Скиннинг — на CPU по позам скелета (12 кадров каждой анимации). Сцена — в дереве.
func cut_stretched(root: Node3D, s: Dictionary, stretch: float = 4.0) -> void:
	var sk: Skeleton3D = root.get_node("Skeleton3D")
	var mi := root.find_child("Body", true, false) as MeshInstance3D
	var ap: AnimationPlayer = root.get_node("AnimationPlayer")
	var arr := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var H: float = float(root.get_meta("rig_height", 2.0))
	var skin := mi.skin
	var names: Array = []
	var bind_bone: Array = []
	for b in skin.get_bind_count():
		names.append(skin.get_bind_name(b))
		bind_bone.append(sk.find_bone(skin.get_bind_name(b)))
	var dom_of := func(i: int) -> int:
		var best := 0
		for k in range(1, 4):
			if w[i * 4 + k] > w[i * 4 + best]:
				best = k
		return bones[i * 4 + best]
	var arm_of := func(b: int) -> String:
		var nm: String = names[b]
		return nm.right(1) if (nm.begins_with("forearm") or nm.begins_with("upperarm")) else ""
	var fore := func(b: int) -> bool: return str(names[b]).begins_with("forearm")
	var leg_of := func(b: int) -> String:
		var nm: String = names[b]
		return nm.right(1) if (nm.begins_with("shin") or nm.begins_with("foot")) else ""
	# кандидаты: рёбра базовой сетки и LOD между «чужими» частями
	var lists: Array = [s["idx"]]
	for key in (s["lods"] as Dictionary).keys():
		lists.append(s["lods"][key])
	var candidates := func() -> Dictionary:
		var out := {}
		for li: PackedInt32Array in lists:
			for t in range(0, li.size(), 3):
				for e in 3:
					var a := li[t + e]
					var c := li[t + (e + 1) % 3]
					var da: int = dom_of.call(a)
					var dc: int = dom_of.call(c)
					var la: String = leg_of.call(da)
					var lc: String = leg_of.call(dc)
					var legs_web := la != "" and lc != "" and la != lc
					if not legs_web:
						if not (fore.call(da) or fore.call(dc)):
							continue
						if arm_of.call(da) == arm_of.call(dc):
							continue
					out[Vector2i(mini(a, c), maxi(a, c))] = true
		return out
	var find_bad := func(edges: Dictionary) -> Dictionary:
		var bad := {}
		for an in ap.get_animation_list():
			ap.play(an)
			var length := ap.current_animation_length
			for f in 12:
				ap.seek(length * f / 12.0, true)
				var mats: Array = []
				for b in skin.get_bind_count():
					mats.append(sk.get_bone_global_pose(bind_bone[b]) * skin.get_bind_pose(b))
				for e: Vector2i in edges.keys():
					if bad.has(e):
						continue
					var pa := Vector3.ZERO
					var pc := Vector3.ZERO
					for k in 4:
						if w[e.x * 4 + k] > 0.0:
							pa += (mats[bones[e.x * 4 + k]] as Transform3D) * verts[e.x] * w[e.x * 4 + k]
						if w[e.y * 4 + k] > 0.0:
							pc += (mats[bones[e.y * 4 + k]] as Transform3D) * verts[e.y] * w[e.y * 4 + k]
					var q := pa.distance_to(pc)
					if q > H * 0.1 and q > verts[e.x].distance_to(verts[e.y]) * stretch:
						bad[e] = true
		ap.stop()
		return bad
	# проход 1: вершины руки (кисти) на растянутых рёбрах — кости соседа по телу
	var bad1: Dictionary = find_bad.call(candidates.call())
	var moved := 0
	for e: Vector2i in bad1.keys():
		var da: int = dom_of.call(e.x)
		var dc: int = dom_of.call(e.y)
		var src := -1
		var dst := -1
		if fore.call(da) and not fore.call(dc) and arm_of.call(dc) == "":
			src = e.y
			dst = e.x
		elif fore.call(dc) and not fore.call(da) and arm_of.call(da) == "":
			src = e.x
			dst = e.y
		if dst < 0:
			continue
		for k in 4:
			bones[dst * 4 + k] = bones[src * 4 + k]
			w[dst * 4 + k] = w[src * 4 + k]
		moved += 1
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = w
	mi.mesh = build_mesh(arr, s["lods"])
	# проход 2: оставшиеся растянутые треугольники — удаляем
	var bad: Dictionary = find_bad.call(candidates.call())
	var filt := func(li: PackedInt32Array) -> PackedInt32Array:
		var out := PackedInt32Array()
		for t in range(0, li.size(), 3):
			var ok := true
			for e in 3:
				var a := li[t + e]
				var c := li[t + (e + 1) % 3]
				if bad.has(Vector2i(mini(a, c), maxi(a, c))):
					ok = false
					break
			if ok:
				out.append_array(PackedInt32Array([li[t], li[t + 1], li[t + 2]]))
		return out
	var before: int = (s["idx"] as PackedInt32Array).size() / 3
	s["idx"] = filt.call(s["idx"])
	for key in (s["lods"] as Dictionary).keys():
		s["lods"][key] = filt.call(s["lods"][key])
	arr[Mesh.ARRAY_INDEX] = s["idx"]
	mi.mesh = build_mesh(arr, s["lods"])
	print("  webs: %d hand vertices moved to body, %d triangles cut" % [moved, before - (s["idx"] as PackedInt32Array).size() / 3])
