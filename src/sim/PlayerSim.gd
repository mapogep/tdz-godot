class_name PlayerSim
extends RefCounted
## Свободный FPS: солдаты игроков. Host — авторитет: клиент присылает позицию/прицел/огонь (fpsMove),
## Host проверяет скорость и столкновения, ведёт патроны, стрельбу, удары и урон от зомби.
## События тика (fps_events) уходят в снапшоте: выстрелы, удары, перезарядки, урон, смерть, воскрешение.

var sim
var players: Dictionary = {}     # pid -> SimPlayer
var rng := RandomNumberGenerator.new()


func _init(p_sim) -> void:
	sim = p_sim
	rng.randomize()


func get_player(pid: int) -> SimPlayer:
	return players.get(pid)


func add(pid: int) -> SimPlayer:
	var p := SimPlayer.new()
	p.id = pid
	p.melee = Cfg.MELEE_TYPES[rng.randi() % Cfg.MELEE_TYPES.size()]
	players[pid] = p
	return p


func remove(pid: int) -> void:
	players.erase(pid)


func _ev(e: Dictionary) -> void:
	sim.events["fps"].append(e)


# ───────────── вход/выход ─────────────

func enter(pid: int) -> Dictionary:
	var p: SimPlayer = players.get(pid)
	if p == null:
		return GameSim.fail("invalid")
	if not p.alive:
		return GameSim.fail("dead")
	if sim.state == "GameOver":
		return GameSim.fail("wrongPhase")
	if p.active:
		return GameSim.ok()
	sim.turrets.release_player(pid)
	p.active = true
	# несколько игроков не должны появляться в одной точке
	var k := 0
	for q: SimPlayer in players.values():
		if q != p and q.active:
			k += 1
	p.x = float(Cfg.PLAYER["spawn_x"])
	p.z = float(Cfg.PLAYER["spawn_z"]) + float((k + 1) / 2) * 0.7 * (1.0 if k % 2 == 1 else -1.0)
	p.yaw = -PI / 2.0
	p.pitch = 0.0
	p.fire = false
	p.budget = 1.0
	_ev({"k": "enter", "pid": pid})
	return GameSim.ok()


func exit(pid: int) -> void:
	var p: SimPlayer = players.get(pid)
	if p != null and p.active:
		p.active = false
		p.fire = false


func deactivate_all() -> void:
	for p: SimPlayer in players.values():
		p.active = false
		p.fire = false


## Волна отражена (или новая игра): все убитые возрождаются, боезапас и здоровье восстанавливаются.
func revive_and_refill() -> void:
	for p: SimPlayer in players.values():
		if not p.alive:
			p.alive = true
			p.melee = Cfg.MELEE_TYPES[rng.randi() % Cfg.MELEE_TYPES.size()]
			_ev({"k": "revive", "pid": p.id})
		p.hp = p.max_hp()
		p.ammo = int(Cfg.PWEAPONS["ak"]["mag"])
		p.mags = int(Cfg.PWEAPONS["ak"]["mags"])
		p.reload_left = 0.0


# ───────────── движение ─────────────

func blocked_at(px: float, pz: float) -> bool:
	var cx := int(floor(px)) + 1
	var cy := int(floor(pz)) + 1
	if not sim.nav.in_bounds(cx, cy):
		return false      # за внешней стеной (город) — свободно
	if sim.nav.is_blocked(cx, cy):
		return true
	return sim.turrets.at_cell(cx, cy) != null


func _free(px: float, pz: float) -> bool:
	var r := float(Cfg.PLAYER["radius"])
	return not (blocked_at(px - r, pz - r) or blocked_at(px + r, pz - r) or blocked_at(px - r, pz + r) or blocked_at(px + r, pz + r))


func move(pid: int, msg: Dictionary) -> Dictionary:
	var p: SimPlayer = players.get(pid)
	if p == null or not (msg.has("x") and msg.has("z") and msg.has("yaw") and msg.has("pitch")):
		return GameSim.fail("invalid")
	if not (p.active and p.alive):
		return GameSim.ok()
	p.yaw = float(msg["yaw"])
	p.pitch = clampf(float(msg["pitch"]), -1.4, 1.4)
	p.fire = bool(msg.get("fire", false))
	var w := str(msg.get("weapon", p.weapon))
	if w == "ak" or w == "melee":
		if w != p.weapon:
			p.weapon = w
			p.reload_left = 0.0
	p.sprint = bool(msg.get("sprint", false))
	var nx := float(msg["x"])
	var nz := float(msg["z"])
	var dx := nx - p.x
	var dz := nz - p.z
	var d := sqrt(dx * dx + dz * dz)
	if d > 0.0001:
		if d > p.budget:
			var k := p.budget / d
			dx *= k
			dz *= k
			d = p.budget
		var lo := float(Cfg.PLAYER["bounds_min"])
		var hi := float(Cfg.PLAYER["bounds_max"])
		var tx := clampf(p.x + dx, lo, hi)
		var tz := clampf(p.z + dz, lo, hi)
		if _free(tx, tz):
			p.x = tx
			p.z = tz
		elif _free(tx, p.z):
			p.x = tx
		elif _free(p.x, tz):
			p.z = tz
		p.budget = maxf(0.0, p.budget - d)
	return GameSim.ok()


func reload(pid: int) -> Dictionary:
	var p: SimPlayer = players.get(pid)
	if p == null:
		return GameSim.fail("invalid")
	_start_reload(p)
	return GameSim.ok()


func _start_reload(p: SimPlayer) -> void:
	var mag := int(Cfg.PWEAPONS["ak"]["mag"])
	if p.reload_left > 0.0 or p.mags <= 0 or p.ammo >= mag or not (p.active and p.alive):
		return
	p.reload_left = float(Cfg.PWEAPONS["ak"]["reload"])
	_ev({"k": "reload", "pid": p.id})


# ───────────── тик ─────────────

func update(dt: float) -> void:
	for p: SimPlayer in players.values():
		if not (p.active and p.alive):
			continue
		p.budget = minf(p.budget + float(Cfg.PLAYER["speed"]) * float(Cfg.PLAYER["sprint_mul"]) * 1.35 * dt, 1.6)
		p.cd = maxf(p.cd - dt, -dt)
		if p.reload_left > 0.0:
			p.reload_left -= dt
			if p.reload_left <= 0.0:
				p.reload_left = 0.0
				var mag := int(Cfg.PWEAPONS["ak"]["mag"])
				p.ammo = mag
				p.mags -= 1
		if p.weapon == "ak":
			var interval := 1.0 / float(Cfg.PWEAPONS["ak"]["rate"])
			while p.fire and p.cd <= 0.0 and p.ammo > 0 and p.reload_left <= 0.0:
				_shoot(p)
				p.ammo -= 1
				p.cd += interval
			if p.ammo == 0 and p.mags > 0:
				_start_reload(p)
		elif p.fire and p.cd <= 0.0:
			_swing(p)
			p.cd = float(Cfg.PWEAPONS[p.melee]["cooldown"])


func _eye(p: SimPlayer) -> Vector3:
	return Vector3(p.x, float(Cfg.PLAYER["eye"]), p.z)


func _shoot(p: SimPlayer) -> void:
	var w: Dictionary = Cfg.PWEAPONS["ak"]
	var origin := _eye(p)
	var dir := SimMath.aim_direction(p.yaw, p.pitch)
	var sp := float(w["spread"])
	dir = (dir + Vector3(rng.randfn(0.0, sp), rng.randfn(0.0, sp), rng.randfn(0.0, sp))).normalized()
	var hit: SimZombie = null
	var hit_t := float(w["range"])
	if dir.y < -0.001:
		hit_t = minf(hit_t, origin.y / -dir.y)     # пуля упирается в землю
	for z: SimZombie in sim.zombies.zombies.values():
		var d := SimMath.ray_vs_cylinder(origin, dir, z.x, z.z, z.radius, z.height)
		if d >= 0.0 and d <= hit_t:
			hit_t = d
			hit = z
	var to := origin + dir * hit_t
	_ev({"k": "shot", "pid": p.id, "from": origin, "to": to, "hit": hit.id if hit != null else 0})
	if hit != null:
		sim.zombies.damage(hit.id, float(w["damage"]))


func _swing(p: SimPlayer) -> void:
	var w: Dictionary = Cfg.PWEAPONS[p.melee]
	var fwd := Vector2(sin(p.yaw), cos(p.yaw))
	var hits: Array = []
	for z: SimZombie in sim.zombies.zombies.values():
		var v := Vector2(z.x - p.x, z.z - p.z)
		var dist := v.length()
		if dist > float(w["range"]) + z.radius:
			continue
		if dist > 0.35 and absf(fwd.angle_to(v)) > float(w["arc"]):
			continue
		hits.append(z.id)
	_ev({"k": "swing", "pid": p.id, "melee": p.melee, "hits": hits})
	for id in hits:
		sim.zombies.damage(int(id), float(w["damage"]))


# ───────────── урон игроку ─────────────

## Ближайший живой игрок в зоне досягаемости зомби; null — никого.
func victim_near(zx: float, zz: float, reach: float) -> SimPlayer:
	var best: SimPlayer = null
	var best_d := reach
	for p: SimPlayer in players.values():
		if not (p.active and p.alive):
			continue
		var d := Vector2(p.x - zx, p.z - zz).length()
		if d <= best_d:
			best_d = d
			best = p
	return best


func hurt(p: SimPlayer, amount: float) -> void:
	if not (p.active and p.alive):
		return
	p.hp -= amount
	_ev({"k": "hurt", "pid": p.id, "amount": amount})
	if p.hp <= 0.0:
		p.hp = 0.0
		p.alive = false
		p.active = false
		p.fire = false
		_ev({"k": "die", "pid": p.id, "x": p.x, "z": p.z})


func snapshot_of(pid: int) -> Dictionary:
	var p: SimPlayer = players.get(pid)
	return p.snapshot() if p != null else {}