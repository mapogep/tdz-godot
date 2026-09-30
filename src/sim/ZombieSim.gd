class_name ZombieSim
extends RefCounted
## Хранит зомби, двигает их по маршруту, принимает урон и поджог.
## Не знает про волны и состояние игры.

var sim                              # GameSim (без типа — избегаем циклических ссылок)
var zombies: Dictionary = {}         # id -> SimZombie
var _next_id := 1
var _spawn_toggle := 0


func _init(p_sim) -> void:
	sim = p_sim


func count() -> int:
	return zombies.size()


func clear() -> void:
	zombies.clear()


## Создаёт зомби типа type на очередных западных воротах. false — пути нет.
func spawn(wave: int, type: String = "normal") -> bool:
	var spawns: Array = sim.nav.spawn_cells()
	var cell: Vector2i = spawns[_spawn_toggle % spawns.size()]
	_spawn_toggle += 1
	# турели на земле зомби обходят, если есть другой путь (см. NavSim.path_from)
	var turret_cells: Array = []
	for t in sim.turrets.turrets.values():
		if not t.elevated:
			turret_cells.append(Vector2i(t.cx, t.cy))
	var path: Array = sim.nav.path_from(cell, turret_cells)
	if path.is_empty():
		return false
	var route: Array = []
	for c in path:
		route.append(NavSim.cell_to_world(c))
	var zc: Dictionary = Cfg.ZOMBIES[type]
	var z := SimZombie.new()
	z.id = _next_id
	_next_id += 1
	z.type = type
	z.x = route[0].x
	z.z = route[0].y
	z.hp = Cfg.zombie_hp(wave, type)
	z.max_hp = z.hp
	z.radius = zc["radius"]
	z.height = zc["height"]
	z.route = route
	z.next = 1
	zombies[z.id] = z
	return true


## Двигает зомби. Турель на маршруте (если обойти нельзя) — зомби останавливается и разрушает её.
## Возвращает true, если кто-то достиг восточных ворот.
func update(dt: float) -> bool:
	var reached := false
	for z: SimZombie in zombies.values():
		if not zombies.has(z.id):
			continue
		var zc: Dictionary = Cfg.ZOMBIES[z.type]
		# поджог: урон со временем
		if z.burn_left > 0.0:
			z.burn_left -= dt
			var r = damage(z.id, z.burn_dps * dt)
			if r != null and r["killed"]:
				continue
		var x0 := z.x
		var z0 := z.z
		var budget: float = float(zc["speed"]) * dt
		while budget > 0.0 and z.next < z.route.size():
			var t: Vector2 = z.route[z.next]
			var dx := t.x - z.x
			var dz := t.y - z.z
			var d := sqrt(dx * dx + dz * dz)
			var blocker: SimTurret = sim.turrets.at_cell(int(floor(t.x)) + 1, int(floor(t.y)) + 1)
			if blocker != null:
				var gap := d - Cfg.ATTACK_REACH
				if gap > 0.0:
					var step := minf(budget, gap)
					z.x += dx / d * step
					z.z += dz / d * step
					z.travelled += step
				if gap <= budget:
					sim.turrets.damage(blocker.id, float(zc["attack"]) * dt)
				break
			if d <= budget:
				z.x = t.x
				z.z = t.y
				budget -= d
				z.travelled += d
				z.next += 1
			else:
				z.x += dx / d * budget
				z.z += dz / d * budget
				z.travelled += budget
				budget = 0.0
		z.vx = (z.x - x0) / dt
		z.vz = (z.z - z0) / dt
		if z.next >= z.route.size():
			reached = true
	return reached


## Наносит урон. При смерти удаляет зомби и начисляет награду РОВНО один раз.
## Возвращает {"killed": bool} или null, если зомби уже нет.
func damage(id: int, amount: float):
	var z: SimZombie = zombies.get(id)
	if z == null:
		return null
	z.hp -= amount
	if z.hp > 0.0:
		return {"killed": false}
	zombies.erase(id)
	var reward: int = Cfg.zombie_reward(z.type)
	sim.eco_reward(reward)
	sim.events["deaths"].append({"id": id, "type": z.type, "x": z.x, "z": z.z, "reward": reward})
	return {"killed": true}


## Поджигает зомби: горит time секунд, dps урона в секунду (сильнейший поджог не перебивается слабым).
func ignite(id: int, dps: float, time: float) -> void:
	var z: SimZombie = zombies.get(id)
	if z == null or dps <= 0.0:
		return
	z.burn_dps = maxf(z.burn_dps if z.burn_left > 0.0 else 0.0, dps)
	z.burn_left = maxf(z.burn_left, time)


func snapshot() -> Array:
	var out: Array = []
	for z: SimZombie in zombies.values():
		out.append(z.snapshot())
	return out
