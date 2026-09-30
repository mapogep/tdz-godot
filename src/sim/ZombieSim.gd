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
			var r = damage(z.id, z.burn_dps * dt, z.burn_src, "fire")
			if r != null and r["killed"]:
				continue
		# игрок рядом: зомби останавливается и кусает его (солдат у ворот удерживает проход)
		var victim: SimPlayer = sim.fps.victim_near(z.x, z.z, Cfg.ATTACK_REACH + float(Cfg.PLAYER["radius"]) + z.radius * 0.5)
		if victim != null:
			if zc.has("explode"):
				suicide(z)             # взрывун у игрока лопается сам
				continue
			sim.fps.hurt(victim, float(zc["attack"]) * float(Cfg.PLAYER["zombie_mul"]) * dt)
			z.vx = 0.0
			z.vz = 0.0
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
					if zc.has("explode"):
						suicide(z)         # взрывун у турели лопается сам
						break
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
		if not zombies.has(z.id):
			continue
		z.vx = (z.x - x0) / dt
		z.vz = (z.z - z0) / dt
		if z.next >= z.route.size():
			reached = true
	return reached


## Наносит урон вида kind (bullet | melee | fire | blast) от игрока src (0 — автоматика) с учётом брони типа.
## При смерти удаляет зомби, начисляет награду РОВНО один раз и очки добившему; взрывун при этом лопается.
## Возвращает {"killed": bool} или null, если зомби уже нет.
func damage(id: int, amount: float, src: int = 0, kind: String = "bullet"):
	var z: SimZombie = zombies.get(id)
	if z == null:
		return null
	var eff := amount * Cfg.armor_mul(z.type, kind)
	sim.score_damage(src, minf(eff, maxf(z.hp, 0.0)))
	z.hp -= eff
	if z.hp > 0.0:
		return {"killed": false}
	zombies.erase(id)
	var reward: int = Cfg.zombie_reward(z.type)
	sim.eco_reward(reward)
	sim.score_kill(src, z.type)
	sim.events["deaths"].append({"id": id, "type": z.type, "x": z.x, "z": z.z, "reward": reward, "by": src})
	if Cfg.ZOMBIES[z.type].has("explode"):
		_explode(z, src)
	return {"killed": true}


## Взрывун дошёл до турели или игрока: взрывается сам, без награды и очков.
func suicide(z: SimZombie) -> void:
	if not zombies.has(z.id):
		return
	zombies.erase(z.id)
	sim.events["deaths"].append({"id": z.id, "type": z.type, "x": z.x, "z": z.z, "reward": 0, "by": 0})
	_explode(z, 0)


## Взрыв взрывуна: урон зомби (засчитывается тому, кто его убил), турелям (на стене — вдвое меньше) и игрокам.
func _explode(z: SimZombie, src: int) -> void:
	var e: Dictionary = Cfg.ZOMBIES[z.type]["explode"]
	var r: float = e["radius"]
	var edge: float = e["edge"]
	sim.events["explosions"].append({"x": z.x, "y": 0.9, "z": z.z, "radius": r, "kind": "acid"})
	var falloff := func(d: float) -> float: return 1.0 - (1.0 - edge) * clampf(d / r, 0.0, 1.0)
	for o: SimZombie in zombies.values():
		var d := Vector2(o.x - z.x, o.z - z.z).length() - o.radius
		if d <= r:
			damage(o.id, float(e["zombie_dmg"]) * falloff.call(maxf(d, 0.0)), src, "blast")
	var tdmg: float = float(e["turret_dmg"]) + float(e["turret_dmg_per_wave"]) * float(sim.wave - 1)
	for t: SimTurret in sim.turrets.turrets.values():
		var d2 := Vector2(t.world_x() - z.x, t.world_z() - z.z).length()
		if d2 <= r + 0.3:
			sim.turrets.damage(t.id, tdmg * falloff.call(d2) * (0.5 if t.elevated else 1.0))
	for p: SimPlayer in sim.fps.players.values():
		if not (p.active and p.alive):
			continue
		var d3 := Vector2(p.x - z.x, p.z - z.z).length()
		if d3 <= r:
			sim.fps.hurt(p, float(e["player_dmg"]) * falloff.call(d3))


## Поджигает зомби: горит time секунд, dps урона в секунду (сильнейший поджог не перебивается слабым).
## Урон от горения засчитывается тому, кто поджёг последним (src).
func ignite(id: int, dps: float, time: float, src: int = 0) -> void:
	var z: SimZombie = zombies.get(id)
	if z == null or dps <= 0.0:
		return
	z.burn_dps = maxf(z.burn_dps if z.burn_left > 0.0 else 0.0, dps)
	z.burn_left = maxf(z.burn_left, time)
	z.burn_src = src

func snapshot() -> Array:
	var out: Array = []
	for z: SimZombie in zombies.values():
		out.append(z.snapshot())
	return out
