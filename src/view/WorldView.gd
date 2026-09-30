class_name WorldView
extends Node3D
## 3D-мир: окружение (небо, свет, туман), земля, стены, турели, зомби, ракеты и все эффекты.
## Получает снапшоты симуляции (apply_snapshot) — одинаково на Host и на клиенте — и ничего не решает сам.

signal shake_requested(amount: float, pos: Vector3)
signal hit_confirmed()                       # своя ручная очередь попала (для маркера в прицеле)
signal own_shot(weapon: String)              # свой выстрел из FPS (отдача камеры)

const WALL_CAP := 640
const HP_BAR_SIZE := Vector2(0.9, 0.14)

var nav: NavSim
var fx: Fx
var scenery: Scenery
var sun: DirectionalLight3D
var env: Environment
var world_env: WorldEnvironment
var quality := 2
var my_id := 1

var turret_views: Dictionary = {}     # id -> Dictionary
var zombie_views: Dictionary = {}     # id -> Dictionary
var rocket_views: Dictionary = {}     # id -> Node3D
var corpses: Array = []

var fps_turret_id := 0                # какая турель занята локальным игроком (0 — никакая)
var fps_yaw := 0.0
var fps_pitch := 0.0

var _walls_mm: MultiMeshInstance3D
var _wall_keys: Array = []
var _wall_sig := ""
var _time := 0.0
var _smoke_clock := 0.0
var _hp_mat_template: ShaderMaterial

# подсказки строительства (управляются InputCtl)
var ghost: MeshInstance3D
var range_ring: MeshInstance3D
var select_ring: MeshInstance3D
var _ghost_mat: StandardMaterial3D


func setup(p_nav: NavSim, p_quality: int) -> void:
	nav = p_nav
	quality = p_quality
	_build_environment()
	fx = Fx.new()
	fx.set_quality(quality)
	fx.shake_requested.connect(func(a: float, p: Vector3) -> void: shake_requested.emit(a, p))
	add_child(fx)
	_build_ground()
	_build_walls()
	scenery = Scenery.new()
	add_child(scenery)
	scenery.build(nav, quality, fx._soft)
	_build_ash()
	_build_helpers()
	_hp_mat_template = ShaderMaterial.new()
	_hp_mat_template.shader = Assets.shader("res://assets/shaders/hpbar.gdshader")
	apply_quality(quality)


# ───────────────────────── окружение ─────────────────────────

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = Assets.tex("res://assets/tex/sky.jpg")
	pano.filter = true
	sky.sky_material = pano
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.sky_rotation = Vector3(0, deg_to_rad(-40), 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.92
	env.fog_enabled = true
	env.fog_light_color = Color("6a5a4c")
	env.fog_density = 0.011
	env.fog_sky_affect = 0.55
	env.fog_aerial_perspective = 0.35
	env.fog_height = 6.0
	env.fog_height_density = 0.02
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.light_color = Color("ffc48f")
	sun.light_energy = 1.55
	sun.rotation_degrees = Vector3(-24, 118, 0)      # низкое закатное солнце
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.4
	sun.shadow_blur = 1.4
	sun.light_angular_distance = 0.5
	sun.directional_shadow_max_distance = 95.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)
	var fill := DirectionalLight3D.new()                # холодная подсветка теней (teal & orange)
	fill.light_color = Color("7a8fb0")
	fill.light_energy = 0.22
	fill.rotation_degrees = Vector3(-40, -60, 0)
	fill.shadow_enabled = false
	add_child(fill)


## Пресеты качества: 0 низкое … 3 ультра.
func apply_quality(q: int) -> void:
	quality = q
	fx.set_quality(q)
	env.glow_enabled = q >= 1
	env.glow_intensity = 0.55
	env.glow_strength = 1.05
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = q >= 2
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssil_enabled = q >= 3
	env.ssil_intensity = 1.0
	env.volumetric_fog_enabled = q >= 2
	env.volumetric_fog_density = 0.012 if q == 2 else 0.02
	env.volumetric_fog_albedo = Color("b59a80")
	env.volumetric_fog_emission = Color("2a1a10")
	env.volumetric_fog_emission_energy = 0.5
	env.volumetric_fog_gi_inject = 0.5
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 90.0 if q == 2 else 140.0
	env.volumetric_fog_detail_spread = 2.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q <= 1 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 0.6 if q <= 1 else 1.4
	sun.directional_shadow_max_distance = 60.0 if q == 0 else 95.0
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096, 4096][q], true)
	var vp := get_viewport()
	if vp != null:
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q <= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
		vp.use_taa = q >= 3


# ───────────────────────── статический мир ─────────────────────────

func _build_ground() -> void:
	var fs := nav.field_size
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(420, 420)
	pm.subdivide_width = 1
	pm.subdivide_depth = 1
	plane.mesh = pm
	plane.material_override = Assets.ground_material(float(fs))
	plane.position = Vector3(fs / 2.0, 0, fs / 2.0)
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)

	# внешняя стена — кольцо бетонных блоков (MultiMesh)
	var cells: Array = []
	for y in nav.size:
		for x in nav.size:
			if nav.is_blocked(x, y):
				cells.append(Vector2i(x, y))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(1, 2, 1)
	mm.mesh = box
	mm.instance_count = cells.size()
	for i in cells.size():
		var w := NavSim.cell_to_world(cells[i])
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(w.x, 1.0, w.y)))
	var ring := MultiMeshInstance3D.new()
	ring.multimesh = mm
	ring.material_override = Assets.surface_material("res://assets/tex/concrete.jpg", 2.4, 0.8, 0.9, 0.9, 1.6, 0.0, 0.45)
	ring.custom_aabb = AABB(Vector3(-2, 0, -2), Vector3(fs + 4, 3, fs + 4))
	add_child(ring)


func _build_walls() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(0.96, Cfg.WALL_HEIGHT, 0.96)
	mm.mesh = box
	mm.instance_count = WALL_CAP
	mm.visible_instance_count = 0
	_walls_mm = MultiMeshInstance3D.new()
	_walls_mm.multimesh = mm
	_walls_mm.material_override = Assets.surface_material("res://assets/tex/scrap.jpg", 1.6, 0.9, 0.95, 0.75, 1.5, 0.2, 0.4)
	_walls_mm.custom_aabb = AABB(Vector3(-2, 0, -2), Vector3(nav.field_size + 4, 3, nav.field_size + 4))
	add_child(_walls_mm)


## Пепел и пыль в воздухе над полем: медленно дрейфующие частицы.
func _build_ash() -> void:
	var p := GPUParticles3D.new()
	p.amount = [120, 260, 420, 600][clampi(quality, 0, 3)]
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -2, -40), Vector3(90, 20, 90))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(34, 6, 34)
	pm.direction = Vector3(1, -0.15, 0.3)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0.15, -0.12, 0.05)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 2.5
	pm.scale_min = 0.03
	pm.scale_max = 0.09
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.7, 0.4, 0.0))
	ramp.set_color(1, Color(0.6, 0.5, 0.45, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.72, 0.45, 0.55))
	ramp.add_point(0.8, Color(0.75, 0.6, 0.5, 0.4))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.albedo_texture = fx._soft
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(nav.field_size / 2.0, 3.0, nav.field_size / 2.0)
	add_child(p)


func _build_helpers() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.albedo_color = Color(0.24, 0.86, 0.5, 0.45)
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost = MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(0.96, Cfg.WALL_HEIGHT, 0.96)
	ghost.mesh = gb
	ghost.material_override = _ghost_mat
	ghost.visible = false
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ghost)

	range_ring = _make_ring(0.965, 1.0, Color(0.4, 0.8, 1.0, 0.7))
	select_ring = _make_ring(0.55, 0.68, Color(1.0, 0.75, 0.25, 0.95))


func _make_ring(inner: float, outer: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = inner
	tor.outer_radius = outer
	tor.rings = 64
	tor.ring_segments = 3
	mi.mesh = tor
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = 0.8
	mi.material_override = m
	mi.scale = Vector3(1, 0.02, 1)
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Подсветка строительства: cell — клетка, ok — можно ли, tall — высота призрака, range_m — радиус дальности, lift — высота.
func set_ghost(cell: Variant, ok: bool, tall: bool, range_m: float, lift: float) -> void:
	if cell == null:
		ghost.visible = false
		range_ring.visible = false
		return
	var w := NavSim.cell_to_world(cell)
	ghost.visible = true
	ghost.position = Vector3(w.x, lift + (Cfg.WALL_HEIGHT if tall else 0.4) / 2.0 * 1.0, w.y)
	ghost.scale = Vector3(1, 1.0 if tall else 0.33, 1)
	_ghost_mat.albedo_color = Color(0.24, 0.86, 0.5, 0.45) if ok else Color(1.0, 0.3, 0.3, 0.45)
	if range_m > 0.0:
		range_ring.visible = true
		range_ring.position = Vector3(w.x, 0.05 + lift, w.y)
		range_ring.scale = Vector3(range_m, 0.02, range_m)
	else:
		range_ring.visible = false


func set_selection(turret_id: int) -> void:
	var v: Dictionary = turret_views.get(turret_id, {})
	if v.is_empty() or fps_turret_id != 0:
		select_ring.visible = false
		return
	var rig: TurretRig = v["rig"]
	select_ring.visible = true
	select_ring.position = Vector3(rig.position.x, 0.05 + rig.position.y, rig.position.z)
	if not ghost.visible:
		var st := Cfg.turret_stats(int(v["level"]), str(v["weapon"]))
		range_ring.visible = true
		range_ring.position = Vector3(rig.position.x, 0.04 + rig.position.y, rig.position.z)
		range_ring.scale = Vector3(st["range"], 0.02, st["range"])


func clear_selection_visuals() -> void:
	select_ring.visible = false
	if not ghost.visible:
		range_ring.visible = false


# ───────────────────────── синхронизация снапшотов ─────────────────────────

func set_walls(cells: Array) -> void:
	var sig := str(cells.size()) + ":" + str(cells.hash())
	if sig == _wall_sig:
		return
	_wall_sig = sig
	_wall_keys = cells.duplicate()
	var mm := _walls_mm.multimesh
	var n := nav.size
	var count := mini(cells.size(), WALL_CAP)
	for i in count:
		var k: int = cells[i]
		var w := NavSim.cell_to_world(Vector2i(k % n, k / n))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(w.x, Cfg.WALL_HEIGHT / 2.0, w.y)))
	mm.visible_instance_count = count


func wall_at(cell: Vector2i) -> bool:
	return _wall_keys.has(cell.y * nav.size + cell.x)


func apply_snapshot(s: Dictionary) -> void:
	_sync_turrets(s["turrets"])
	_sync_zombies(s["zombies"], s["deaths"])
	_sync_rockets(s["rockets"])
	_play_events(s)


func _lift(elevated: bool) -> float:
	return Cfg.WALL_HEIGHT if elevated else 0.0


func _sync_turrets(list: Array) -> void:
	var seen := {}
	for t in list:
		var id: int = t["id"]
		seen[id] = true
		var v: Dictionary = turret_views.get(id, {})
		if not v.is_empty() and (v["level"] != t["level"]):
			_remove_turret_view(id)
			v = {}
		if v.is_empty():
			var rig := TurretRig.create(t["level"], t["weapon"])
			add_child(rig)
			var bar := _make_hp_bar()
			bar.visible = false
			add_child(bar)
			v = {"rig": rig, "bar": bar, "level": t["level"], "weapon": t["weapon"],
				"yaw": t["yaw"], "pitch": t["pitch"], "ty": t["yaw"], "tp": t["pitch"], "hp_frac": 1.0,
				"elevated": t["elevated"], "cx": t["cx"], "cy": t["cy"]}
			turret_views[id] = v
			if fps_turret_id == id:
				(rig as TurretRig).show_only_weapon(true)
		var w := NavSim.cell_to_world(Vector2i(t["cx"], t["cy"]))
		var lift := _lift(t["elevated"])
		var rig2: TurretRig = v["rig"]
		rig2.position = Vector3(w.x, lift, w.y)
		v["elevated"] = t["elevated"]
		v["cx"] = t["cx"]
		v["cy"] = t["cy"]
		v["ty"] = t["yaw"]
		v["tp"] = t["pitch"]
		v["hp_frac"] = clampf(float(t["hp"]) / maxf(1.0, float(t["max_hp"])), 0.0, 1.0)
	for id in turret_views.keys():
		if not seen.has(id):
			_remove_turret_view(id)


func _remove_turret_view(id: int) -> void:
	var v: Dictionary = turret_views.get(id, {})
	if v.is_empty():
		return
	if is_instance_valid(v["rig"]):
		v["rig"].queue_free()
	if is_instance_valid(v["bar"]):
		v["bar"].queue_free()
	turret_views.erase(id)


func _make_hp_bar() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = HP_BAR_SIZE
	mi.mesh = q
	mi.material_override = _hp_mat_template.duplicate()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _set_bar(bar: MeshInstance3D, frac: float, color: Color) -> void:
	var m := bar.material_override as ShaderMaterial
	m.set_shader_parameter("frac", frac)
	m.set_shader_parameter("fill_color", color)


func _sync_zombies(list: Array, deaths: Array) -> void:
	var seen := {}
	for z in list:
		var id: int = z["id"]
		seen[id] = true
		var v: Dictionary = zombie_views.get(id, {})
		if v.is_empty():
			var rig := ZombieRig.create(z["type"])
			rig.position = Vector3(z["x"], 0, z["z"])
			add_child(rig)
			var bar := _make_hp_bar()
			add_child(bar)
			v = {"rig": rig, "bar": bar, "x": z["x"], "z": z["z"], "tx": z["x"], "tz": z["z"], "heading": 0.0,
				"phase": randf() * 6.0, "flash": 0.0, "hp_frac": 1.0, "type": z["type"], "burning": false}
			zombie_views[id] = v
		v["tx"] = z["x"]
		v["tz"] = z["z"]
		v["hp_frac"] = clampf(float(z["hp"]) / maxf(1.0, float(z["max_hp"])), 0.0, 1.0)
		v["burning"] = z["burning"]
	var dead := {}
	for d in deaths:
		dead[int(d["id"])] = d
	for id in zombie_views.keys():
		if seen.has(id):
			continue
		var v2: Dictionary = zombie_views[id]
		zombie_views.erase(id)
		if is_instance_valid(v2["bar"]):
			v2["bar"].queue_free()
		if dead.has(id):
			_make_corpse(v2)
		else:
			v2["rig"].queue_free()


## Падающий труп: заваливается назад, оседает и исчезает.
func _make_corpse(v: Dictionary) -> void:
	var rig: ZombieRig = v["rig"]
	rig.set_burning(false)
	rig.set_hit_flash(0.0)
	corpses.append(rig)
	var tw := create_tween()
	tw.tween_property(rig, "rotation:x", -PI / 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(rig, "position:y", -0.05, 0.45)
	tw.tween_interval(1.4)
	tw.tween_property(rig, "position:y", -0.9, 1.2)
	tw.tween_callback(func() -> void:
		corpses.erase(rig)
		rig.queue_free())


func _sync_rockets(list: Array) -> void:
	var seen := {}
	for r in list:
		var id: int = r["id"]
		seen[id] = true
		var node: Node3D = rocket_views.get(id)
		if node == null:
			node = _make_rocket()
			node.position = r["p"]
			add_child(node)
			rocket_views[id] = node
		node.set_meta("target", r["p"])
		var d: Vector3 = r["d"]
		if d.length() > 0.01:
			node.look_at(node.global_position + d, Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT)
	for id in rocket_views.keys():
		if not seen.has(id):
			rocket_views[id].queue_free()
			rocket_views.erase(id)


func _make_rocket() -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.06
	cm.height = 0.42
	body.mesh = cm
	body.rotation.x = PI / 2.0
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("cfcfcf")
	bm.metallic = 0.5
	bm.roughness = 0.4
	body.material_override = bm
	n.add_child(body)
	var nose := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.0
	nm.bottom_radius = 0.06
	nm.height = 0.16
	nose.mesh = nm
	nose.rotation.x = PI / 2.0
	nose.position.z = 0.29
	var nmat := StandardMaterial3D.new()
	nmat.albedo_color = Color("d8432f")
	nose.material_override = nmat
	n.add_child(nose)
	var flame := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.0
	fm.bottom_radius = 0.05
	fm.height = 0.3
	flame.mesh = fm
	flame.rotation.x = -PI / 2.0
	flame.position.z = -0.33
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color("ffa02a")
	fmat.emission_enabled = true
	fmat.emission = Color("ff7a1a")
	fmat.emission_energy_multiplier = 3.0
	flame.material_override = fmat
	n.add_child(flame)
	var l := OmniLight3D.new()
	l.light_color = Color("ff9a3a")
	l.light_energy = 1.6
	l.omni_range = 4.0
	l.position.z = -0.4
	n.add_child(l)
	return n


# ───────────────────────── события боя ─────────────────────────

func _muzzle_pos(turret_id: int, fallback: Vector3) -> Vector3:
	var v: Dictionary = turret_views.get(turret_id, {})
	if v.is_empty():
		return fallback
	var rig: TurretRig = v["rig"]
	if rig.is_inside_tree():
		return rig.muzzle.global_position
	return fallback


func _play_events(s: Dictionary) -> void:
	for sh in s["shots"]:
		var tid: int = sh["turret"]
		var weapon: String = sh["weapon"]
		var from := _muzzle_pos(tid, sh["from"])
		var to: Vector3 = sh["to"]
		var own := tid == fps_turret_id and fps_turret_id != 0
		var v: Dictionary = turret_views.get(tid, {})
		if not v.is_empty():
			var rig: TurretRig = v["rig"]
			if weapon != "flame":
				rig.kick()
		match weapon:
			"machinegun":
				fx.tracer(from, to, Color("fff0b0"), 0.012)
				fx.muzzle_flash(from, 0.12 if own else 0.5)
				if not v.is_empty():
					(v["rig"] as TurretRig).spin_up()
				Sfx.play("mg", from)
			"rocket":
				fx.muzzle_flash(from, 0.2 if own else 1.4)
				if not own:
					fx.smoke_puff(from, 6)
				Sfx.play("rocket", from)
			"flame":
				fx.flame_stream(from, to, own)
				Sfx.play("flame", from, -4.0)
			_:
				fx.tracer(from, to, Color.WHITE if sh["manual"] else Color("ffd27a"))
				fx.muzzle_flash(from, 0.25 if own else 1.0)
				Sfx.play("shot_manual" if sh["manual"] else "shot", from)
		if own:
			own_shot.emit(weapon)
		if weapon == "rocket" or weapon == "flame":
			if own and int(sh["hit"]) != 0 and weapon == "flame":
				hit_confirmed.emit()
			continue
		var hit := int(sh["hit"])
		if hit != 0:
			fx.sparks(to, Color("ff5a4a"), 3 if weapon == "machinegun" else 5)
			var zv: Dictionary = zombie_views.get(hit, {})
			if not zv.is_empty():
				zv["flash"] = 0.12
				Sfx.play("hurt", to)
			if own:
				hit_confirmed.emit()
				Sfx.play("hit")
		else:
			fx.sparks(to, Color("cccccc"), 2)
	for e in s["explosions"]:
		var p := Vector3(e["x"], e["y"], e["z"])
		fx.blast(p, float(e["radius"]))
		Sfx.play("boom", p)
	for d in s["destroyed"]:
		var y := _lift(d["elevated"]) + 0.8
		var p2 := Vector3(d["x"], y, d["z"])
		fx.turret_explosion(p2)
		fx.float_text("BOOM", p2 + Vector3(0, 1.2, 0), Color("ff8a4d"), 60)
		Sfx.play("boom", p2)
	for d in s["deaths"]:
		var pos := Vector3(d["x"], 0, d["z"])
		fx.death_burst(pos, d["type"] == "fat")
		fx.float_text("+$%d" % int(d["reward"]), Vector3(d["x"], 1.8, d["z"]))
		Sfx.play("kill", pos)
		Sfx.play("coin", null, -6.0)


# ───────────────────────── кадр ─────────────────────────

func _process(delta: float) -> void:
	_time += delta
	scenery.animate_lights(_time)

	# турели: плавный поворот; своя турель в FPS — точно по прицелу
	var ta := 1.0 - exp(-delta * 18.0)
	for id in turret_views.keys():
		var v: Dictionary = turret_views[id]
		var rig: TurretRig = v["rig"]
		if id == fps_turret_id:
			v["yaw"] = fps_yaw
			v["pitch"] = fps_pitch
			rig.pitch_scale = 1.0
			rig.aim(fps_yaw, fps_pitch)
		else:
			v["yaw"] = float(v["yaw"]) + wrapf(float(v["ty"]) - float(v["yaw"]), -PI, PI) * ta
			v["pitch"] = float(v["pitch"]) + (float(v["tp"]) - float(v["pitch"])) * ta
			rig.pitch_scale = 0.5 if (v["weapon"] == "gun") else 1.0
			rig.aim(v["yaw"], v["pitch"])
		# полоска прочности — только у повреждённых турелей
		var bar: MeshInstance3D = v["bar"]
		var show_bar: bool = float(v["hp_frac"]) < 1.0 and id != fps_turret_id
		bar.visible = show_bar
		if show_bar:
			bar.position = rig.position + Vector3(0, 2.0, 0)
			var f: float = v["hp_frac"]
			_set_bar(bar, f, Color("59a8d6") if f > 0.5 else (Color("e0c040") if f > 0.25 else Color("e04a3a")))

	# зомби: сглаживание между тиками симуляции, поворот по ходу, ходьба, полоска HP, горение
	var za := 1.0 - exp(-delta * 20.0)
	for id in zombie_views.keys():
		var v: Dictionary = zombie_views[id]
		var rig: ZombieRig = v["rig"]
		var px: float = v["x"]
		var pz: float = v["z"]
		v["x"] = px + (float(v["tx"]) - px) * za
		v["z"] = pz + (float(v["tz"]) - pz) * za
		var dx: float = v["x"] - px
		var dz: float = v["z"] - pz
		var moved := sqrt(dx * dx + dz * dz)
		if moved > 0.0001:
			var target := atan2(dx, dz)
			v["heading"] = float(v["heading"]) + wrapf(target - float(v["heading"]), -PI, PI) * minf(1.0, delta * 10.0)
		v["phase"] = float(v["phase"]) + moved * 7.0
		rig.position.x = v["x"]
		rig.position.z = v["z"]
		rig.rotation.y = v["heading"]
		rig.animate(delta, v["phase"])
		v["flash"] = maxf(0.0, float(v["flash"]) - delta)
		rig.set_hit_flash(v["flash"])
		rig.set_burning(v["burning"])
		if v["burning"] and randf() < delta * 26.0:
			fx.burn_puff(Vector3(v["x"] + randf_range(-0.2, 0.2), 0.4 + randf() * 1.2, v["z"] + randf_range(-0.2, 0.2)))
		var bar: MeshInstance3D = v["bar"]
		bar.position = Vector3(v["x"], rig.top_y + 0.1, v["z"])
		var f2: float = v["hp_frac"]
		_set_bar(bar, f2, Color("59d64a") if f2 > 0.5 else (Color("e0c040") if f2 > 0.25 else Color("e04a3a")))

	# ракеты: плавный полёт и дымный след
	var ra := 1.0 - exp(-delta * 25.0)
	for id in rocket_views.keys():
		var n: Node3D = rocket_views[id]
		var target: Vector3 = n.get_meta("target", n.position)
		n.position = n.position.lerp(target, ra)
		fx.smoke_puff(n.position, 1)


# ───────────────────────── FPS ─────────────────────────

## Занять/покинуть турель локальным игроком: своё оружие остаётся видимым, корпус и постамент прячутся.
func set_fps_turret(id: int, yaw: float = 0.0, pitch: float = 0.0) -> void:
	if fps_turret_id != 0 and turret_views.has(fps_turret_id):
		(turret_views[fps_turret_id]["rig"] as TurretRig).show_only_weapon(false)
	fps_turret_id = id
	fps_yaw = yaw
	fps_pitch = pitch
	if id != 0 and turret_views.has(id):
		(turret_views[id]["rig"] as TurretRig).show_only_weapon(true)
		select_ring.visible = false


## Поза камеры «из башни»: чуть позади и выше оси ствола, смотрит вдоль него.
func fps_camera_position() -> Vector3:
	var v: Dictionary = turret_views.get(fps_turret_id, {})
	if v.is_empty():
		return Vector3.ZERO
	var rig: TurretRig = v["rig"]
	var sy := sin(fps_yaw)
	var cy := cos(fps_yaw)
	var sp := sin(fps_pitch)
	var cp := cos(fps_pitch)
	var px := rig.position.x + sy * rig.base_z
	var pz := rig.position.z + cy * rig.base_z
	var py := rig.position.y + rig.head.position.y + rig.pivot.position.y
	return Vector3(
		px - sy * cp * rig.cam_back - sy * sp * rig.cam_up,
		py - sp * rig.cam_back + cp * rig.cam_up,
		pz - cy * cp * rig.cam_back - cy * sp * rig.cam_up)


# ───────────────────────── выбор объектов ─────────────────────────

## Турель, ближайшая к точке экрана (в радиусе px пикселей); 0 — нет.
func pick_turret(cam: Camera3D, screen_pos: Vector2, radius_px: float = 48.0) -> int:
	var best := 0
	var best_d := radius_px
	for id in turret_views.keys():
		var v: Dictionary = turret_views[id]
		var rig: TurretRig = v["rig"]
		var p := rig.position + Vector3(0, 0.9, 0)
		if cam.is_position_behind(p):
			continue
		var d := cam.unproject_position(p).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = id
	return best


## Клетка земли под курсором (или null).
func ground_cell(cam: Camera3D, screen_pos: Vector2) -> Variant:
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	if hit == null:
		return null
	var h: Vector3 = hit
	var c := Vector2i(int(floor(h.x)) + 1, int(floor(h.z)) + 1)
	if c.x < 0 or c.y < 0 or c.x >= nav.size or c.y >= nav.size:
		return null
	return c


## Стена игрока под курсором: идём вдоль луча и ищем клетку со стеной на высоте ≤ высоты стены.
func pick_wall(cam: Camera3D, screen_pos: Vector2) -> Variant:
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var t := 0.0
	while t < 90.0:
		var p := origin + dir * t
		if p.y < -0.05:
			break
		if p.y <= Cfg.WALL_HEIGHT + 0.02:
			var c := Vector2i(int(floor(p.x)) + 1, int(floor(p.z)) + 1)
			if wall_at(c):
				return c
		t += 0.08
	return null
