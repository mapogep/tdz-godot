class_name Assets
extends RefCounted
## Загрузка и кэш моделей Kenney (CC0), текстур и шейдеров. Единый постапокалиптический вид:
## материалы моделей заменяются на wasteland.gdshader (приглушённые цвета, тёплый оттенок, копоть).

static var _scenes: Dictionary = {}
static var _parts: Dictionary = {}
static var _mats: Dictionary = {}
static var _shaders: Dictionary = {}
static var _white: Texture2D

## Имя модели → как сильно приглушать цвета (sat) и затемнять (dark), сила копоти (grime).
const GRADES := [
	["character-zombie", 0.85, 1.0, 0.1],
	["weapon-", 0.6, 0.95, 0.1],
	["pine", 0.2, 0.52, 0.3],
	["trunk", 0.2, 0.52, 0.3],
	["stump", 0.2, 0.52, 0.3],
	["log", 0.2, 0.52, 0.3],
	["plant", 0.3, 0.6, 0.3],
	["building", 0.38, 0.7, 0.4],
	["low-detail", 0.38, 0.7, 0.4],
	["sedan", 0.5, 0.78, 0.35], ["suv", 0.5, 0.78, 0.35], ["van", 0.5, 0.78, 0.35], ["truck", 0.5, 0.78, 0.35],
	["ambulance", 0.5, 0.78, 0.35], ["police", 0.5, 0.78, 0.35], ["taxi", 0.5, 0.78, 0.35], ["firetruck", 0.5, 0.78, 0.35],
	["garbage", 0.5, 0.78, 0.35], ["delivery", 0.5, 0.78, 0.35], ["tractor", 0.5, 0.78, 0.35],
	["debris", 0.5, 0.78, 0.35], ["wheel", 0.5, 0.78, 0.35],
	["rock", 0.3, 0.7, 0.3], ["crate", 0.3, 0.7, 0.25], ["pipe", 0.3, 0.7, 0.25], ["wall", 0.3, 0.7, 0.25],
	["fence", 0.3, 0.7, 0.25], ["iron", 0.3, 0.7, 0.25],
	["tent", 0.7, 0.95, 0.15], ["campfire", 0.7, 0.95, 0.1], ["sign", 0.7, 0.95, 0.1],
	["lightpost", 0.7, 0.95, 0.1], ["fire-basket", 0.7, 0.95, 0.0],
]


static func path(model: String) -> String:
	return "res://assets/models/%s.glb" % model


static func has(model: String) -> bool:
	return ResourceLoader.exists(path(model))


static func scene(model: String) -> PackedScene:
	if _scenes.has(model):
		return _scenes[model]
	var ps: PackedScene = null
	if has(model):
		ps = load(path(model)) as PackedScene
	_scenes[model] = ps
	return ps


static func instance(model: String) -> Node3D:
	var ps := scene(model)
	if ps == null:
		return null
	return ps.instantiate() as Node3D


static func shader(p: String) -> Shader:
	if not _shaders.has(p):
		_shaders[p] = load(p)
	return _shaders[p]


static func tex(p: String) -> Texture2D:
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	return null


static func white() -> Texture2D:
	if _white == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white


static func grade_for(model: String) -> Vector3:
	for g in GRADES:
		if model.begins_with(g[0]):
			return Vector3(g[1], g[2], g[3])
	return Vector3(0.55, 0.9, 0.25)


## Материал Kenney → wasteland.gdshader (текстура-атлас сохраняется).
static func waste_material(src: Material, sat: float, dark: float, grime: float = 0.25) -> ShaderMaterial:
	var key := "%s|%.2f|%.2f|%.2f" % [src.get_instance_id() if src != null else 0, sat, dark, grime]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = shader("res://assets/shaders/wasteland.gdshader")
	var t: Texture2D = null
	var col := Color.WHITE
	var metal := 0.0
	var rough := 0.88
	if src is BaseMaterial3D:
		t = src.albedo_texture
		col = src.albedo_color
		metal = src.metallic
		rough = clampf(src.roughness, 0.4, 1.0)
	m.set_shader_parameter("albedo_tex", t if t != null else white())
	m.set_shader_parameter("albedo_color", col)
	m.set_shader_parameter("sat", sat)
	m.set_shader_parameter("dark", dark)
	m.set_shader_parameter("grime", grime)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("metallic", metal * 0.5)
	_mats[key] = m
	return m


static func _rel_xform(node: Node3D, root: Node3D) -> Transform3D:
	var x := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			x = (n as Node3D).transform * x
		n = n.get_parent()
	return x


## Части модели (меш + локальная трансформа + материалы) — для MultiMesh-расстановки.
static func parts(model: String) -> Array:
	if _parts.has(model):
		return _parts[model]
	var out: Array = []
	var root := instance(model)
	if root != null:
		var g := grade_for(model)
		var stack: Array = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.append(c)
			if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
				var mi := n as MeshInstance3D
				var mat: Material = mi.get_active_material(0)
				out.append({
					"mesh": mi.mesh,
					"xform": _rel_xform(mi, root),
					"mat": waste_material(mat, g.x, g.y, g.z) if mat != null else null,
				})
		root.free()
	_parts[model] = out
	return out


## Заменяет материалы всех мешей узла на цветокорректированные (для отдельных экземпляров: зомби, оружие).
static func grade_node(root: Node, sat: float, dark: float, grime: float = 0.15) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var mat: Material = mi.get_active_material(i)
				if mat != null and not (mat is ShaderMaterial):
					mi.set_surface_override_material(i, waste_material(mat, sat, dark, grime))


## Трипланарная поверхность (стены, баррикады).
static func surface_material(tex_path: String, tile: float, sat: float, dark: float, rough: float = 0.85,
		bump: float = 1.4, metal: float = 0.0, grime: float = 0.35) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("res://assets/shaders/surface.gdshader")
	m.set_shader_parameter("tex", tex(tex_path))
	m.set_shader_parameter("tile", tile)
	m.set_shader_parameter("sat", sat)
	m.set_shader_parameter("dark", dark)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("bump", bump)
	m.set_shader_parameter("metallic", metal)
	m.set_shader_parameter("grime", grime)
	return m


static func ground_material(field_size: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("res://assets/shaders/ground.gdshader")
	m.set_shader_parameter("albedo_tex", tex("res://assets/tex/ground.jpg"))
	m.set_shader_parameter("field_size", field_size)
	return m


static var _tripo_mat: StandardMaterial3D


## Модели Tripo: одна сетка с вершинными цветами, без текстур. Возвращает MeshInstance3D
## (own_material — своя копия материала для вспышек), либо null, если файла нет.
static func tripo(model: String, own_material: bool = false) -> MeshInstance3D:
	var path := "res://assets/models/%s.glb" % model
	if not ResourceLoader.exists(path):
		return null
	var scene: Node = (load(path) as PackedScene).instantiate()
	var src := scene.find_children("*", "MeshInstance3D", true, false)
	if src.is_empty():
		scene.free()
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = (src[0] as MeshInstance3D).mesh
	scene.free()
	if _tripo_mat == null:
		_tripo_mat = StandardMaterial3D.new()
		_tripo_mat.vertex_color_use_as_albedo = true
		_tripo_mat.albedo_color = Color(0.66, 0.64, 0.6)
		_tripo_mat.roughness = 0.82
		_tripo_mat.emission_enabled = true
		_tripo_mat.emission = Color(1.0, 0.25, 0.08)
		_tripo_mat.emission_energy_multiplier = 0.0
	mi.material_override = _tripo_mat.duplicate() if own_material else _tripo_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi