class_name TurretSim
extends RefCounted
## Турели: создание, улучшение, вход игрока, боевая логика (базовая, пулемёт, ракета, огнемёт) и ракеты.
## Автоогонь и ручной огонь из FPS используют одни характеристики; ручной — × fps_mul.

var sim
var turrets: Dictionary = {}         # id -> SimTurret
var rockets: Dictionary = {}         # id -> Dictionary
var rng := RandomNumberGenerator.new()
var _next_id := 1
var _next_rocket := 1


func _init(p_sim) -> void:
	sim = p_sim
	rng.randomize()


# ───────────── коллекция ─────────────

func create(cx: int, cy: int, weapon: String = "gun") -> SimTurret:
	var t := SimTurret.new()
	t.id = _next_id
	_next_id += 1
	t.weapon = weapon
	t.cx = cx
	t.cy = cy
	t.level = 1
	t.invested = Cfg.turret_cost(weapon)
	var st := t.stats()
	t.ammo = int(st["mag"])
	t.hp = float(st["hp"])
	turrets[t.id] = t
	return t


func remove(id: int) -> void:
	turrets.erase(id)


func at_cell(cx: int, cy: int) -> SimTurret:
	for t: SimTurret in turrets.values():
		if t.cx == cx and t.cy == cy:
			return t
	return null


func reset() -> void:
	turrets.clear()
	rockets.clear()


## Урон по турели (зомби на пути). При разрушении турель исчезает, игрок в ней выходит.
func damage(id: int, amount: float) -> bool:
	var t: SimTurret = turrets.get(id)
	if t == null:
		return false
	t.hp -= amount
	if t.hp > 0.0:
		return false
	turrets.erase(id)
	sim.events["destroyed"].append({"id": id, "x": t.world_x(), "z": t.world_z(), "elevated": t.elevated})
	return true


## Полный ремонт всех турелей (между волнами).
func repair_all() -> void:
	for t: SimTurret in turrets.values():
		t.hp = float(t.stats()["hp"])


func upgrade(id: int) -> Dictionary:
	var t: SimTurret = turrets.get(id)
	if t == null:
		return GameSim.fail("noSuchObject")
	if t.level >= int(Cfg.TURRET["max_level"]):
		return GameSim.fail("maxLevel")
	var cost := Cfg.upgrade_cost(t.level, t.weapon)
	if not sim.eco_spend(cost):
		return GameSim.fail("noResources")
	t.level += 1
	t.invested += cost
	var st := t.stats()
	t.ammo = int(st["mag"])
	t.hp = float(st["hp"])
	return GameSim.ok()


## Игрок занимает турель. Один игрок — одна турель, одна турель — один игрок.
func enter(id: int, player: int) -> Dictionary:
	var t: SimTurret = turrets.get(id)
	if t == null:
		return GameSim.fail("noSuchObject")
	if t.controlled_by != 0 and t.controlled_by != player:
		return GameSim.fail("alreadyControlled")
	release_player(player)
	t.controlled_by = player
	t.in_yaw = t.yaw
	t.in_pitch = t.pitch
	t.in_firing = false
	return GameSim.ok()


func release_player(player: int) -> void:
	for t: SimTurret in turrets.values():
		if t.controlled_by == player:
			t.controlled_by = 0
			t.in_firing = false


func release_all() -> void:
	for t: SimTurret in turrets.values():
		t.controlled_by = 0
		t.in_firing = false


func turret_of(player: int) -> SimTurret:
	for t: SimTurret in turrets.values():
		if t.controlled_by == player:
			return t
	return null


func set_input(player: int, yaw: float, pitch: float, firing: bool) -> void:
	var t := turret_of(player)
	if t != null:
		t.in_yaw = yaw
		t.in_pitch = pitch
		t.in_firing = firing


# ───────────── бой ─────────────

func update(dt: float) -> void:
	for t: SimTurret in turrets.values():
		_update_turret(t, dt)
	_update_rockets(dt)


func _update_turret(t: SimTurret, dt: float) -> void:
	var st := t.stats()
	var w: Dictionary = Cfg.WEAPONS[t.weapon]
	t.cooldown -= dt
	if t.reload_left > 0.0:
		t.reload_left -= dt
		if t.reload_left <= 0.0:
			t.reload_left = 0.0
			t.ammo = int(st["mag"])

	var want_fire := false
	var target: SimZombie = null
	var has_aim := false
	var aim_point := Vector3.ZERO

	if t.controlled_by != 0:
		t.yaw = SimMath.wrap_angle(t.in_yaw)
		t.pitch = clampf(t.in_pitch, -1.2, 1.2)
		want_fire = t.in_firing
	else:
		target = select_target(t)
		if target != null:
			aim_point = _aim_point_for(t, target)
			has_aim = true
			var dx := aim_point.x - t.world_x()
			var dz := aim_point.z - t.world_z()
			var desired := atan2(dx, dz)
			t.yaw = SimMath.step_angle(t.yaw, desired, float(st["turn"]) * dt)
			t.pitch = atan2(aim_point.y - t.muzzle_y(), sqrt(dx * dx + dz * dz))
			var tol: float = float(Cfg.TURRET["aim_tol"])
			if w["kind"] == "flame":
				tol = maxf(tol, float(w["cone"]) * 0.6)
			elif float(w["spread"]) > 0.0 or w["kind"] == "rocket":
				tol = 0.09
			want_fire = absf(SimMath.wrap_angle(desired - t.yaw)) <= tol
		elif t.ammo < int(st["mag"]) and t.reload_left == 0.0:
			t.reload_left = float(st["reload"])   # пока тихо — перезаряжаемся

	if not want_fire or t.reload_left > 0.0:
		if t.cooldown < 0.0:
			t.cooldown = 0.0    # «накопленное» время выстрела не копим впрок
		if want_fire and t.reload_left == 0.0 and t.ammo <= 0:
			t.reload_left = float(st["reload"])
		return

	# несколько выстрелов за тик допустимы (скорострельные типы)
	var guard := 0
	while guard < 4 and t.cooldown <= 0.0:
		guard += 1
		if t.ammo <= 0:
			t.reload_left = float(st["reload"])
			t.cooldown = maxf(t.cooldown, 0.0)
			break
		t.ammo -= 1
		t.cooldown += 1.0 / float(st["rate"])
		_shoot(t, target, has_aim, aim_point)
		if t.ammo == 0:
			t.reload_left = float(st["reload"])
			if t.cooldown < 0.0:
				t.cooldown = 0.0
			break


## Цель по приоритету оружия среди зомби в радиусе.
func select_target(t: SimTurret) -> SimZombie:
	var rng_m: float = float(t.stats()["range"])
	var prio: String = Cfg.WEAPONS[t.weapon]["priority"]
	var best: SimZombie = null
	var best_key := INF
	for z: SimZombie in sim.zombies.zombies.values():
		var d := Vector2(z.x - t.world_x(), z.z - t.world_z()).length()
		if d > rng_m:
			continue
		var key: float
		match prio:
			"first": key = -z.travelled
			"last": key = z.travelled
			"lowestHp": key = z.hp
			_: key = d
		if key < best_key:
			best_key = key
			best = z
	return best


## Точка прицеливания: центр зомби; для ракеты — с упреждением по скорости зомби.
func _aim_point_for(t: SimTurret, z: SimZombie) -> Vector3:
	var y := z.height * 0.5
	var w: Dictionary = Cfg.WEAPONS[t.weapon]
	if w["kind"] != "rocket":
		return Vector3(z.x, y, z.z)
	var d := Vector2(z.x - t.world_x(), z.z - t.world_z()).length()
	var flight := d / float(w["speed"])
	return Vector3(z.x + z.vx * flight, y, z.z + z.vz * flight)


func _muzzle(t: SimTurret) -> Vector3:
	return Vector3(t.world_x(), t.muzzle_y(), t.world_z())


func _shoot(t: SimTurret, target: SimZombie, has_aim: bool, aim_point: Vector3) -> void:
	var w: Dictionary = Cfg.WEAPONS[t.weapon]
	var manual := t.controlled_by != 0
	var st := t.stats()
	var damage: float = float(st["damage"]) * (float(Cfg.TURRET["fps_mul"]) if manual else 1.0)
	var from := _muzzle(t)

	# направление выстрела: из FPS — куда смотрит игрок, автоматически — на цель
	var dir: Vector3
	if manual or not has_aim:
		dir = SimMath.aim_direction(t.yaw, t.pitch)
	else:
		dir = (aim_point - from).normalized()

	match w["kind"]:
		"hitscan":
			# базовая турель автоматически не промахивается; пулемёт и ручной огонь — лучом
			if not manual and float(w["spread"]) == 0.0 and target != null:
				sim.events["shots"].append({
					"turret": t.id, "weapon": t.weapon, "from": from,
					"to": Vector3(target.x, target.height * 0.5, target.z), "hit": target.id, "manual": false})
				sim.zombies.damage(target.id, damage)
				return
			_fire_ray(t, from, _jitter(dir, float(w["spread"])), float(st["range"]), damage, manual)
		"rocket":
			var start := from + dir * 0.6
			_launch(start, dir, float(w["speed"]), damage, float(w["splash"]), float(st["range"]) * 1.4,
				float(w["edge"]), damage * float(w["burn"]), float(w["burn_time"]))
			sim.events["shots"].append({
				"turret": t.id, "weapon": t.weapon, "from": start, "to": start + dir * 2.0, "hit": 0, "manual": manual})
		"flame":
			_burn(t, from, dir, float(st["range"]), damage, float(w["cone"]), manual)


## Луч: ближайший зомби на линии в пределах дальности.
func _fire_ray(t: SimTurret, origin: Vector3, dir: Vector3, range_m: float, damage: float, manual: bool) -> void:
	var hit: SimZombie = null
	var hit_t := range_m
	for z: SimZombie in sim.zombies.zombies.values():
		var d := SimMath.ray_vs_cylinder(origin, dir, z.x, z.z, z.radius, z.height)
		if d >= 0.0 and d <= hit_t:
			hit_t = d
			hit = z
	var to := origin + dir * hit_t
	sim.events["shots"].append({
		"turret": t.id, "weapon": t.weapon, "from": origin, "to": to,
		"hit": hit.id if hit != null else 0, "manual": manual})
	if hit != null:
		sim.zombies.damage(hit.id, damage)


## Огнемёт: рассеянный урон по конусу. Чем дальше от сопла и от оси струи, тем слабее удар
## (у края дальности — edge, у края конуса — 60%); всех задетых поджигает.
func _burn(t: SimTurret, origin: Vector3, dir: Vector3, range_m: float, damage: float, half_angle: float, manual: bool) -> void:
	var w: Dictionary = Cfg.WEAPONS[t.weapon]
	var burn_dps: float = damage * float(t.stats()["rate"]) * float(w["burn"])
	var any_id := 0
	for z: SimZombie in sim.zombies.zombies.values():
		var v := Vector3(z.x - origin.x, z.height * 0.5 - origin.y, z.z - origin.z)
		var dist := v.length()
		if dist > range_m + z.radius:
			continue
		var c := v.dot(dir) / maxf(dist, 0.0001)
		var angle := acos(clampf(c, -1.0, 1.0))
		var slack := atan2(z.radius, maxf(dist, 0.1))
		if angle > half_angle + slack:
			continue
		any_id = z.id
		var k_dist := 1.0 - (1.0 - float(w["edge"])) * minf(1.0, dist / (range_m + z.radius))
		var k_angle := 1.0 - 0.4 * minf(1.0, angle / (half_angle + slack))
		var res = sim.zombies.damage(z.id, damage * k_dist * k_angle)
		if res != null and not res["killed"]:
			sim.zombies.ignite(z.id, burn_dps * k_dist, float(w["burn_time"]))
	sim.events["shots"].append({
		"turret": t.id, "weapon": t.weapon, "from": origin, "to": origin + dir * range_m, "hit": any_id, "manual": manual})


func _jitter(dir: Vector3, spread: float) -> Vector3:
	if spread <= 0.0:
		return dir
	var j := func() -> float: return (rng.randf() - 0.5) * 2.0 * spread
	return Vector3(dir.x + j.call(), dir.y + j.call(), dir.z + j.call()).normalized()


# ───────────── ракеты ─────────────

func _launch(from: Vector3, dir: Vector3, speed: float, damage: float, splash: float, max_dist: float,
		edge: float, burn_dps: float, burn_time: float) -> void:
	rockets[_next_rocket] = {
		"id": _next_rocket, "p": from, "d": dir, "speed": speed, "damage": damage, "splash": splash,
		"edge": edge, "burn_dps": burn_dps, "burn_time": burn_time, "travelled": 0.0, "max": max_dist,
	}
	_next_rocket += 1


## Публичный запуск (для тестов и песочницы).
func launch_rocket(from: Vector3, dir: Vector3, speed: float, damage: float, splash: float, max_dist: float,
		edge: float = 0.25, burn_dps: float = 0.0, burn_time: float = 0.0) -> void:
	_launch(from, dir, speed, damage, splash, max_dist, edge, burn_dps, burn_time)


func _update_rockets(dt: float) -> void:
	for r: Dictionary in rockets.values():
		# шагаем мелкими шагами, чтобы не пролетать сквозь зомби
		var left: float = float(r["speed"]) * dt
		var exploded := false
		while left > 0.0 and not exploded:
			var step := minf(left, 0.2)
			left -= step
			r["p"] = r["p"] + r["d"] * step
			r["travelled"] += step
			var hit := _rocket_hit(r)
			if hit != 0:
				_explode(r, hit)
				exploded = true
			elif r["p"].y <= 0.05 or r["travelled"] >= r["max"]:
				_explode(r, 0)
				exploded = true


func _rocket_hit(r: Dictionary) -> int:
	var p: Vector3 = r["p"]
	for z: SimZombie in sim.zombies.zombies.values():
		if p.y < 0.0 or p.y > z.height:
			continue
		if Vector2(z.x - p.x, z.z - p.z).length() <= z.radius + 0.12:
			return z.id
	return 0


func _explode(r: Dictionary, direct: int) -> void:
	rockets.erase(r["id"])
	var p: Vector3 = r["p"]
	sim.events["explosions"].append({"x": p.x, "y": maxf(p.y, 0.2), "z": p.z, "radius": r["splash"]})
	# копия списка: damage() удаляет убитых зомби во время обхода
	for z: SimZombie in sim.zombies.zombies.values():
		var reach: float = float(r["splash"]) + z.radius
		var d := Vector2(z.x - p.x, z.z - p.z).length()
		if d > reach:
			continue
		# урон рассеивается от центра к краю: в эпицентре 100%, на границе — edge; всех задетых поджигает
		var k := 1.0 if z.id == direct else 1.0 - (1.0 - float(r["edge"])) * minf(1.0, d / reach)
		var res = sim.zombies.damage(z.id, float(r["damage"]) * k)
		if res != null and not res["killed"] and float(r["burn_dps"]) > 0.0:
			sim.zombies.ignite(z.id, float(r["burn_dps"]) * k, float(r["burn_time"]))


func rockets_snapshot() -> Array:
	var out: Array = []
	for r: Dictionary in rockets.values():
		out.append({"id": r["id"], "p": r["p"], "d": r["d"]})
	return out


func snapshot() -> Array:
	var out: Array = []
	for t: SimTurret in turrets.values():
		out.append(t.snapshot())
	return out
