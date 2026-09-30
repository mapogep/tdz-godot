extends SceneTree
## Тесты логики (порт тестов исходной версии). Запуск:
##   godot --headless --path . -s tests/run_tests.gd
## Код возврата 0 — все проверки прошли.

var passed := 0
var failed := 0
var _section := ""


func check(name: String, cond: bool, extra: String = "") -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL  [%s] %s  %s" % [_section, name, extra])


func near(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps


func make(money: int = 0) -> Array:
	var g := GameSim.new(Cfg.START_MONEY)
	var host := 1
	g.add_player(host)
	g.add_player(2)
	g.money = money
	return [g, host, 2]


func run(g: GameSim, seconds: float) -> void:
	var n := int(seconds * Cfg.TICK_RATE)
	for i in n:
		g.tick(1.0 / Cfg.TICK_RATE)


func spawn_at(g: GameSim, type: String, x: float, z: float, hp: float = 1000.0) -> SimZombie:
	g.zombies.spawn(1, type)
	var ids: Array = g.zombies.zombies.keys()
	var zom: SimZombie = g.zombies.zombies[ids[ids.size() - 1]]
	zom.x = x
	zom.z = z
	zom.hp = hp
	zom.max_hp = hp
	return zom


func manual_turret(g: GameSim, host: int, weapon: String) -> SimTurret:
	var r := g.handle(host, {"t": "buildTurret", "x": 5, "y": 10, "weapon": weapon})
	check("manual turret built", r["ok"])
	var t := g.turrets.at_cell(5, 10)
	check("enter turret", g.handle(host, {"t": "enterTurret", "id": t.id})["ok"])
	return t


func _init() -> void:
	test_config()
	test_nav()
	test_building()
	test_turrets_economy()
	test_walls_and_zombie_attacks()
	test_waves_and_combat()
	test_zombie_types()
	test_weapons()
	test_save()
	print("\n%d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


# ───────────────────────────────────────── config
func test_config() -> void:
	_section = "config"
	# состав волн совпадает с исходной версией (детерминированный ГСЧ)
	check("wave 1 = normal", Cfg.wave_composition(1) == ["normal"])
	check("wave 6 composition", Cfg.wave_composition(6) == ["normal", "fat", "normal", "normal", "fast", "fast"], str(Cfg.wave_composition(6)))
	check("wave 10 composition", Cfg.wave_composition(10) == ["fast", "fat", "normal", "normal", "fat", "fast", "normal", "normal", "normal", "fast"], str(Cfg.wave_composition(10)))
	check("wave 3 has fast, no fat", Cfg.wave_composition(3).has("fast") and not Cfg.wave_composition(3).has("fat"))
	for w in [4, 6, 10, 25]:
		var c := Cfg.wave_composition(w)
		check("size wave %d" % w, c.size() == Cfg.zombie_count(w))
		check("fat+fast wave %d" % w, c.has("fat") and c.has("fast"))
		check("deterministic wave %d" % w, c == Cfg.wave_composition(w))
	check("stats L10 damage", near(Cfg.turret_stats(10, "gun")["damage"], 10.0 + 9 * 2.0))
	check("reload floor", Cfg.turret_stats(10, "gun")["reload"] >= float(Cfg.TURRET["min_reload"]))
	check("reward normal", Cfg.zombie_reward("normal") == 20)
	check("reward fat", Cfg.zombie_reward("fat") == 70)
	check("reward fast", Cfg.zombie_reward("fast") == 16)
	for wname in Cfg.WEAPON_TYPES:
		var a := Cfg.turret_stats(1, wname)
		var b := Cfg.turret_stats(10, wname)
		check("scale %s" % wname, b["damage"] > a["damage"] and b["range"] > a["range"] and b["hp"] > a["hp"])


# ───────────────────────────────────────── навигация
func test_nav() -> void:
	_section = "nav"
	var n := NavSim.new()
	check("size 22", n.size == 22)
	check("gate rows", n.gate_rows == [10, 11], str(n.gate_rows))
	check("gate open", not n.is_blocked(0, 10) and not n.is_blocked(21, 11))
	check("ring blocked", n.is_blocked(0, 5) and n.is_blocked(10, 0))
	var p := n.path_from(Vector2i(0, 10))
	check("straight path", p.size() > 0 and p[0] == Vector2i(0, 10) and n.is_east_gate(p[-1].x, p[-1].y))
	for y in range(1, 16):
		n.set_blocked(10, y, true)
	p = n.path_from(Vector2i(0, 10))
	var detour := false
	for c in p:
		if c.y > 15: detour = true
	check("goes around wall", p.size() > 0 and detour)
	for y in range(1, 21):
		n.set_blocked(10, y, true)
	check("sealed = no path", n.path_from(Vector2i(0, 10)).is_empty())
	# без срезания углов: между двумя диагональными стенами не проходим
	var m := NavSim.new()
	for y in range(1, 21):
		m.set_blocked(10, y, true)
	m.set_blocked(10, 10, false)
	m.set_blocked(9, 10, true)
	m.set_blocked(9, 11, false)
	var q := m.path_from(Vector2i(0, 10))
	var ok_corner := true
	for i in range(1, q.size()):
		var a: Vector2i = q[i - 1]
		var b: Vector2i = q[i]
		if a.x != b.x and a.y != b.y:
			if m.is_blocked(a.x, b.y) or m.is_blocked(b.x, a.y):
				ok_corner = false
	check("no corner cutting", ok_corner)


# ───────────────────────────────────────── строительство
func test_building() -> void:
	_section = "building"
	var s := make()
	var g: GameSim = s[0]
	var host: int = s[1]
	var guest: int = s[2]
	check("guest cannot build", g.handle(guest, {"t": "buildWall", "x": 5, "y": 5}) == {"ok": false, "error": "notHost"})
	check("host builds", g.handle(host, {"t": "buildWall", "x": 5, "y": 5})["ok"])
	g.handle(host, {"t": "startWave"})
	check("no building in wave", g.handle(host, {"t": "buildWall", "x": 6, "y": 5}) == {"ok": false, "error": "wrongPhase"})

	# лимит стен: запас, потом деньги
	s = make()
	g = s[0]
	host = s[1]
	for i in Cfg.START_WALLS:
		check("wall %d" % i, g.handle(host, {"t": "buildWall", "x": 6 + 4 * (i / 10), "y": 2 + 2 * (i % 10)})["ok"])
	check("stock 0", g.wall_stock == 0)
	check("needs money", g.handle(host, {"t": "buildWall", "x": 16, "y": 2}) == {"ok": false, "error": "noResources"})
	g.eco_add_money(Cfg.WALL_COST)
	check("buys wall", g.handle(host, {"t": "buildWall", "x": 16, "y": 2})["ok"])
	check("money spent", g.money == 0)

	# нельзя перекрыть путь; ресурсы не тратятся
	s = make()
	g = s[0]
	host = s[1]
	for y in range(1, 20):
		check("col %d" % y, g.handle(host, {"t": "buildWall", "x": 10, "y": y})["ok"])
	g.eco_add_money(1000)
	var stock := g.wall_stock
	check("seal refused", g.handle(host, {"t": "buildWall", "x": 10, "y": 20}) == {"ok": false, "error": "pathBlocked"})
	check("no spend", g.wall_stock == stock and g.money == 1000 and not g.nav.is_blocked(10, 20))

	# снос возвращает стену в запас
	s = make()
	g = s[0]
	host = s[1]
	g.handle(host, {"t": "buildWall", "x": 5, "y": 5})
	check("stock -1", g.wall_stock == Cfg.START_WALLS - 1)
	check("remove ok", g.handle(host, {"t": "removeWall", "x": 5, "y": 5})["ok"])
	check("stock restored", g.wall_stock == Cfg.START_WALLS)
	check("remove again", g.handle(host, {"t": "removeWall", "x": 5, "y": 5}) == {"ok": false, "error": "noSuchObject"})

	# недопустимые клетки
	for c in [[0, 10], [21, 10], [0, 0], [-1, 5], [5, 22]]:
		check("invalid %s" % str(c), not g.handle(host, {"t": "buildWall", "x": c[0], "y": c[1]})["ok"])


# ───────────────────────────────────────── турели и экономика
func test_turrets_economy() -> void:
	_section = "turrets"
	var s := make()
	var g: GameSim = s[0]
	var host: int = s[1]
	check("place turret", g.handle(host, {"t": "buildTurret", "x": 5, "y": 5, "weapon": "gun"})["ok"])
	check("free stock -1", g.turret_stock == Cfg.START_TURRETS - 1)
	var t := g.turrets.at_cell(5, 5)
	check("occupied", g.handle(host, {"t": "buildTurret", "x": 5, "y": 5, "weapon": "gun"}) == {"ok": false, "error": "occupied"})
	check("upgrade no money", g.handle(host, {"t": "upgradeTurret", "id": t.id}) == {"ok": false, "error": "noResources"})
	g.eco_add_money(5000)
	for l in range(1, int(Cfg.TURRET["max_level"])):
		check("upgrade L%d" % l, g.handle(host, {"t": "upgradeTurret", "id": t.id})["ok"])
	check("max level", t.level == int(Cfg.TURRET["max_level"]))
	check("maxLevel error", g.handle(host, {"t": "upgradeTurret", "id": t.id}) == {"ok": false, "error": "maxLevel"})
	var invested := Cfg.turret_cost("gun")
	for l in range(1, int(Cfg.TURRET["max_level"])):
		invested += Cfg.upgrade_cost(l, "gun")
	check("invested", t.invested == invested)
	check("move ok", g.handle(host, {"t": "moveTurret", "id": t.id, "x": 9, "y": 9})["ok"])
	check("move kept level", t.level == int(Cfg.TURRET["max_level"]))
	check("moved cell", g.turrets.at_cell(5, 5) == null and g.turrets.at_cell(9, 9) == t)
	check("move to gate refused", not g.handle(host, {"t": "moveTurret", "id": t.id, "x": 0, "y": 5})["ok"])
	var m := g.money
	check("sell", g.handle(host, {"t": "sellTurret", "id": t.id})["ok"])
	check("sell 50%", g.money == m + Cfg.sell_value(invested))
	check("gone", g.turrets.turrets.is_empty())

	# оружие: только gun использует бесплатный запас
	s = make(0)
	g = s[0]
	host = s[1]
	check("mg needs money", g.handle(host, {"t": "buildTurret", "x": 3, "y": 3, "weapon": "machinegun"}) == {"ok": false, "error": "noResources"})
	check("stock untouched", g.turret_stock == Cfg.START_TURRETS)
	check("gun free", g.handle(host, {"t": "buildTurret", "x": 3, "y": 3, "weapon": "gun"})["ok"])
	g.money = Cfg.turret_cost("machinegun")
	check("mg bought", g.handle(host, {"t": "buildTurret", "x": 3, "y": 4, "weapon": "machinegun"})["ok"])
	check("money 0", g.money == 0)
	check("unknown weapon", g.handle(host, {"t": "buildTurret", "x": 3, "y": 6, "weapon": "laser"}) == {"ok": false, "error": "invalid"})

	# улучшения и продажа по прайсу оружия
	s = make(5000)
	g = s[0]
	host = s[1]
	g.handle(host, {"t": "buildTurret", "x": 3, "y": 3, "weapon": "rocket"})
	var rt := g.turrets.at_cell(3, 3)
	var before := g.money
	g.handle(host, {"t": "upgradeTurret", "id": rt.id})
	check("rocket upgrade price", before - g.money == Cfg.upgrade_cost(1, "rocket"))
	check("rocket invested", rt.invested == Cfg.turret_cost("rocket") + Cfg.upgrade_cost(1, "rocket"))


# ───────────────────────────────────────── стены под турелями, атаки зомби
func seal_with_turrets(g: GameSim, host: int, gaps: Array) -> void:
	for y in range(1, 21):
		if not gaps.has(y):
			g.handle(host, {"t": "buildWall", "x": 5, "y": y})
	for y in gaps:
		check("seal turret %d" % y, g.handle(host, {"t": "buildTurret", "x": 5, "y": y, "weapon": "gun"})["ok"])


func test_walls_and_zombie_attacks() -> void:
	_section = "walls+attacks"
	var s := make()
	var g: GameSim = s[0]
	var host: int = s[1]
	g.handle(host, {"t": "buildWall", "x": 7, "y": 7})
	check("turret on wall", g.handle(host, {"t": "buildTurret", "x": 7, "y": 7, "weapon": "gun"})["ok"])
	var t := g.turrets.at_cell(7, 7)
	check("elevated", t.elevated)
	check("muzzle raised", near(t.muzzle_y(), float(Cfg.TURRET["muzzle"]) + Cfg.WALL_HEIGHT))
	check("wall under turret stays", g.handle(host, {"t": "removeWall", "x": 7, "y": 7}) == {"ok": false, "error": "occupied"})
	check("move down", g.handle(host, {"t": "moveTurret", "id": t.id, "x": 9, "y": 9})["ok"] and not t.elevated)
	check("now removable", g.handle(host, {"t": "removeWall", "x": 7, "y": 7})["ok"])

	# стена под стоящей на земле турелью поднимает её
	s = make()
	g = s[0]
	host = s[1]
	g.handle(host, {"t": "buildTurret", "x": 6, "y": 6, "weapon": "gun"})
	var t2 := g.turrets.at_cell(6, 6)
	check("ground", not t2.elevated)
	g.handle(host, {"t": "buildWall", "x": 6, "y": 6})
	check("lifted by wall", t2.elevated)

	# зомби ОБХОДИТ турель, если есть путь, и её не трогает
	s = make()
	g = s[0]
	host = s[1]
	g.handle(host, {"t": "buildTurret", "x": 5, "y": 10, "weapon": "gun"})
	g.handle(host, {"t": "buildTurret", "x": 5, "y": 11, "weapon": "gun"})
	for tt: SimTurret in g.turrets.turrets.values():
		tt.ammo = 0
		tt.reload_left = 1e9
	g.handle(host, {"t": "startWave"})
	run(g, 30)
	check("zombie reached gate (walked around)", g.state == "GameOver")
	var full := true
	for tt: SimTurret in g.turrets.turrets.values():
		if tt.hp != float(tt.stats()["hp"]): full = false
	check("turrets untouched", full)

	# обойти нельзя — ломает
	s = make()
	g = s[0]
	host = s[1]
	seal_with_turrets(g, host, [10, 11])
	for tt: SimTurret in g.turrets.turrets.values():
		tt.ammo = 0
		tt.reload_left = 1e9
	g.handle(host, {"t": "startWave"})
	var destroyed := 0
	var held := true
	for i in 20 * 25:
		if destroyed != 0: break
		g.tick(0.05)
		for tt: SimTurret in g.turrets.turrets.values():
			tt.ammo = 0
			tt.reload_left = 1e9
		destroyed += g.events["destroyed"].size()
		g.snapshot()
		var zz: SimZombie = null
		for q in g.zombies.zombies.values():
			zz = q
			break
		if zz != null and g.turrets.turrets.size() == 2 and zz.x >= 4.6:
			held = false
	check("destroyed one turret", destroyed == 1)
	check("held at the turrets", held)

	# минимальное число турелей на запасном маршруте
	s = make(1000)
	g = s[0]
	host = s[1]
	seal_with_turrets(g, host, [10, 11])
	g.handle(host, {"t": "buildTurret", "x": 4, "y": 10, "weapon": "gun"})
	var cells: Array = []
	for tt: SimTurret in g.turrets.turrets.values():
		cells.append(Vector2i(tt.cx, tt.cy))
	var route := g.nav.path_from(Vector2i(0, 10), cells)
	var crossed := 0
	for c in route:
		if g.turrets.at_cell(c.x, c.y) != null: crossed += 1
	check("goes through fewest turrets", crossed == 1, str(crossed))

	# ремонт между волнами и вылет игрока при разрушении
	s = make()
	g = s[0]
	host = s[1]
	g.handle(host, {"t": "buildTurret", "x": 5, "y": 10, "weapon": "gun"})
	var tc := g.turrets.at_cell(5, 10)
	g.handle(host, {"t": "enterTurret", "id": tc.id})
	tc.hp = 5
	check("destroy", g.turrets.damage(tc.id, 50.0))
	check("player freed", g.turrets.turret_of(host) == null)
	g.handle(host, {"t": "buildTurret", "x": 6, "y": 10, "weapon": "gun"})
	var t3 := g.turrets.at_cell(6, 10)
	t3.hp = 10
	g.handle(host, {"t": "startWave"})
	for i in 20 * 30:
		if g.state == "Preparation": break
		g.tick(0.05)
	if g.state == "Preparation":
		check("repaired", t3.hp == float(t3.stats()["hp"]))


# ───────────────────────────────────────── волны и бой
func test_waves_and_combat() -> void:
	_section = "waves"
	var s := make()
	var g: GameSim = s[0]
	var host: int = s[1]
	g.handle(host, {"t": "buildTurret", "x": 6, "y": 10, "weapon": "gun"})
	g.handle(host, {"t": "buildTurret", "x": 6, "y": 12, "weapon": "gun"})
	g.handle(host, {"t": "startWave"})
	run(g, 20)
	check("not game over", g.state != "GameOver")
	check("killed 1", g.zombies_killed == 1)
	check("reward paid", g.money == Cfg.zombie_reward("normal"))
	check("no double reward", g.zombies.damage(1, 999.0) == null and g.money == Cfg.zombie_reward("normal"))

	# без защиты — поражение и заморозка, потом рестарт
	s = make()
	g = s[0]
	host = s[1]
	g.handle(host, {"t": "startWave"})
	run(g, 30)
	check("game over", g.state == "GameOver")
	check("no build after over", not g.handle(host, {"t": "buildWall", "x": 5, "y": 5})["ok"])
	check("restart", g.handle(host, {"t": "restart"})["ok"])
	check("preparation", g.state == "Preparation" and g.wave == 1)
	check("walls reset", g.wall_stock == Cfg.START_WALLS)

	# волна завершается, наступает подготовка
	s = make()
	g = s[0]
	host = s[1]
	for y in [9, 11, 13]:
		g.handle(host, {"t": "buildTurret", "x": 4, "y": y, "weapon": "gun"})
	g.handle(host, {"t": "startWave"})
	run(g, 25)
	check("next prep", g.state == "Preparation" and g.wave == 2)

	# FPS: ручной огонь ×2
	s = make()
	g = s[0]
	host = s[1]
	var mt := manual_turret(g, host, "gun")
	check("guest cannot steal", g.handle(2, {"t": "enterTurret", "id": mt.id}) == {"ok": false, "error": "alreadyControlled"})
	g.handle(host, {"t": "startWave"})
	var fired := false
	for i in 20 * 15:
		if fired: break
		g.tick(0.05)
		var z: SimZombie = null
		for q in g.zombies.zombies.values():
			z = q
			break
		if z == null: continue
		var dx := z.x - mt.world_x()
		var dz := z.z - mt.world_z()
		var dist := sqrt(dx * dx + dz * dz)
		if dist < 3.0:
			var hp0 := z.hp
			g.handle(host, {"t": "input", "yaw": atan2(dx, dz), "pitch": -atan2(float(Cfg.TURRET["muzzle"]) - 0.9, dist), "firing": true})
			g.tick(0.05)
			g.handle(host, {"t": "input", "yaw": mt.yaw, "pitch": mt.pitch, "firing": false})
			var after: SimZombie = null
			for q in g.zombies.zombies.values():
				after = q
				break
			var dealt := hp0 - (after.hp if after != null else 0.0)
			check("manual x2 damage", near(dealt, float(Cfg.turret_stats(1, "gun")["damage"]) * float(Cfg.TURRET["fps_mul"])), str(dealt))
			fired = true
	check("manual fired", fired)

	# выход хоста → гость становится Host
	s = make()
	g = s[0]
	host = s[1]
	g.handle(host, {"t": "buildTurret", "x": 6, "y": 10, "weapon": "gun"})
	var ht := g.turrets.at_cell(6, 10)
	g.handle(host, {"t": "enterTurret", "id": ht.id})
	g.remove_player(host)
	check("turret freed", ht.controlled_by == 0)
	check("guest is host", g.is_host(2))


# ───────────────────────────────────────── типы зомби
func test_zombie_types() -> void:
	_section = "zombies"
	var zn: Dictionary = Cfg.ZOMBIES["normal"]
	var zf: Dictionary = Cfg.ZOMBIES["fat"]
	var zq: Dictionary = Cfg.ZOMBIES["fast"]
	check("speeds", zf["speed"] < zn["speed"] and zn["speed"] < zq["speed"])
	check("hp", zf["hp"] > zn["hp"] * 3 and zq["hp"] < zn["hp"])
	check("scale", zf["scale"] > 1.0 and zq["scale"] < 1.0)
	check("reward order", Cfg.zombie_reward("fat") > Cfg.zombie_reward("normal"))
	var s := make()
	var g: GameSim = s[0]
	for type in Cfg.ZOMBIE_TYPES:
		var before := g.zombies.count()
		check("spawn %s" % type, g.zombies.spawn(3, type))
		var ids: Array = g.zombies.zombies.keys()
		var z: SimZombie = g.zombies.zombies[ids[ids.size() - 1]]
		check("type %s" % type, z.type == type and near(z.hp, Cfg.zombie_hp(3, type)))
		var t0 := z.travelled
		g.zombies.update(1.0)
		check("speed %s" % type, near(z.travelled - t0, float(Cfg.ZOMBIES[type]["speed"]), 0.1))
	# награда по типу и ровно один раз
	s = make()
	g = s[0]
	for type in Cfg.ZOMBIE_TYPES:
		g.zombies.spawn(1, type)
		var ids2: Array = g.zombies.zombies.keys()
		var z2: SimZombie = g.zombies.zombies[ids2[ids2.size() - 1]]
		var m := g.money
		check("killed %s" % type, g.zombies.damage(z2.id, 1e6) == {"killed": true})
		check("dead null %s" % type, g.zombies.damage(z2.id, 1e6) == null)
		check("reward %s" % type, g.money - m == Cfg.zombie_reward(type))
	# волна спавнит свой состав
	s = make()
	g = s[0]
	g.wave = 6
	g.handle(s[1], {"t": "startWave"})
	var seen: Array = []
	for i in 20 * 12:
		var before_ids: Dictionary = {}
		for id in g.zombies.zombies.keys(): before_ids[id] = true
		g.tick(0.05)
		for z3: SimZombie in g.zombies.zombies.values():
			if not before_ids.has(z3.id): seen.append(z3.type)
	seen.sort()
	var want := Cfg.wave_composition(6)
	want.sort()
	check("wave spawns composition", seen == want, str(seen))


# ───────────────────────────────────────── оружие
func test_weapons() -> void:
	_section = "weapons"
	# пулемёт: ~rate выстрелов в секунду при 20 Гц
	var s := make(2000)
	var g: GameSim = s[0]
	var host: int = s[1]
	var t := manual_turret(g, host, "machinegun")
	g.handle(host, {"t": "input", "yaw": 0.0, "pitch": 0.0, "firing": true})
	var shots := 0
	for i in 20:
		g.tick(0.05)
		shots += g.snapshot()["shots"].size()
	var rate: float = Cfg.turret_stats(1, "machinegun")["rate"]
	check("mg rate", shots >= rate - 1 and shots <= rate + 1, str(shots))
	check("mg ammo", t.ammo == int(Cfg.turret_stats(1, "machinegun")["mag"]) - shots)

	# пулемёт перезаряжается
	s = make(2000)
	g = s[0]
	host = s[1]
	t = manual_turret(g, host, "machinegun")
	g.handle(host, {"t": "input", "yaw": 0.0, "pitch": 0.0, "firing": true})
	var reloaded := false
	for i in 20 * 8:
		if reloaded: break
		g.tick(0.05)
		if t.reload_left > 0.0: reloaded = true
	check("mg reloads", reloaded)
	for i in 20 * 4: g.tick(0.05)
	check("mg refilled", t.ammo > 0)

	# ракета: урон рассеивается от эпицентра, задетые горят
	s = make(2000)
	g = s[0]
	var w: Dictionary = Cfg.WEAPONS["rocket"]
	var a := spawn_at(g, "normal", 8.0, 10.5)
	var b := spawn_at(g, "normal", 8.9, 10.5)
	var c := spawn_at(g, "normal", 9.3, 10.5)
	var far := spawn_at(g, "normal", 14.0, 10.5)
	g.turrets.launch_rocket(Vector3(5.5, 0.9, 10.5), Vector3(1, 0, 0), float(w["speed"]), 40.0, float(w["splash"]), 12.0, float(w["edge"]), 8.0, float(w["burn_time"]))
	var boom := 0
	for i in 20 * 2:
		g.tick(0.05)
		boom += g.snapshot()["explosions"].size()
	check("one explosion", boom == 1)
	var da := 1000.0 - a.hp
	var db := 1000.0 - b.hp
	var dc := 1000.0 - c.hp
	check("direct hit full", near(da, 40.0, 0.01), str(da))
	check("falloff", da > db and db > dc and dc > 0.0, "%f %f %f" % [da, db, dc])
	check("burning", b.burn_left > 0.0)
	check("outside untouched", far.hp == 1000.0)
	check("rocket gone", g.turrets.rockets.is_empty())

	# ракета: турель стреляет и убивает
	s = make(5000)
	g = s[0]
	host = s[1]
	g.handle(host, {"t": "buildTurret", "x": 5, "y": 10, "weapon": "rocket"})
	var zr := spawn_at(g, "normal", 4.5 + 4.0, 9.5, 30.0)
	var launched := 0
	for i in 20 * 6:
		if g.zombies.count() == 0: break
		g.tick(0.05)
		launched += g.snapshot()["shots"].size()
	check("rocket launched", launched >= 1)
	check("rocket damaged", zr.hp < 30.0)

	# огнемёт: конус, рассеянный урон, поджог
	s = make(2000)
	g = s[0]
	host = s[1]
	t = manual_turret(g, host, "flame")
	var near_z := spawn_at(g, "normal", t.world_x() + 1.0, t.world_z())
	var far_z := spawn_at(g, "normal", t.world_x() + 3.2, t.world_z())
	var behind := spawn_at(g, "normal", t.world_x() - 2.0, t.world_z())
	var aside := spawn_at(g, "normal", t.world_x() + 2.0, t.world_z() + 2.5)
	g.handle(host, {"t": "input", "yaw": PI / 2.0, "pitch": atan2(0.9 - t.muzzle_y(), 2.0), "firing": true})
	g.tick(0.05)
	var dn := 1000.0 - near_z.hp
	var df := 1000.0 - far_z.hp
	check("flame near>far", dn > df and df > 0.0, "%f %f" % [dn, df])
	check("flame ignites", near_z.burn_left > 0.0 and far_z.burn_left > 0.0)
	check("flame cone", behind.hp == 1000.0 and aside.hp == 1000.0)
	g.handle(host, {"t": "input", "yaw": 0.0, "pitch": 0.0, "firing": false})
	var hp := near_z.hp
	for i in 10: g.zombies.update(0.05)
	check("burn dot", near_z.hp < hp)

	# огонь убивает — награда ровно один раз
	s = make(0)
	g = s[0]
	var zb := spawn_at(g, "normal", 8, 9.5, 5.0)
	g.zombies.ignite(zb.id, 100.0, 2.0)
	for i in 10: g.zombies.update(0.05)
	check("burn kill", g.zombies.count() == 0 and g.money == Cfg.zombie_reward("normal"))

	# автотурели всех типов убивают одинокого зомби
	for weapon in Cfg.WEAPON_TYPES:
		s = make(2000)
		g = s[0]
		host = s[1]
		g.handle(host, {"t": "buildTurret", "x": 5, "y": 10, "weapon": weapon})
		var zk := spawn_at(g, "normal", 4.5 + 2.5, 9.5, 40.0)
		for i in 20 * 15:
			if zk.hp <= 0.0: break
			g.tick(0.05)
		check("auto %s kills" % weapon, zk.hp <= 0.0)

	# толстый ломает турель быстрее обычного (если обойти нельзя)
	var times: Dictionary = {}
	for type in ["normal", "fat"]:
		s = make(0)
		g = s[0]
		host = s[1]
		for y in range(1, 21):
			if y != 10: g.handle(host, {"t": "buildWall", "x": 5, "y": y})
		g.handle(host, {"t": "buildTurret", "x": 5, "y": 10, "weapon": "gun"})
		var tt := g.turrets.at_cell(5, 10)
		tt.ammo = 0
		tt.reload_left = 1e9
		g.zombies.spawn(1, type)
		var ids: Array = g.zombies.zombies.keys()
		var z: SimZombie = g.zombies.zombies[ids[0]]
		var idx := -1
		for i in z.route.size():
			var p: Vector2 = z.route[i]
			if int(floor(p.x)) + 1 == 5 and int(floor(p.y)) + 1 == 10:
				idx = i
				break
		check("route via gap %s" % type, idx > 0)
		z.x = z.route[idx - 1].x
		z.z = z.route[idx - 1].y
		z.next = idx
		var steps := 0
		while g.turrets.at_cell(5, 10) != null and steps < 20 * 60:
			g.zombies.update(0.05)
			steps += 1
		times[type] = steps * 0.05
		check("turret destroyed %s" % type, g.turrets.at_cell(5, 10) == null)
	check("fat faster", times["fat"] < times["normal"])


# ───────────────────────────────────────── сохранение
func test_save() -> void:
	_section = "save"
	var s := make(500)
	var g: GameSim = s[0]
	var host: int = s[1]
	g.handle(host, {"t": "buildWall", "x": 5, "y": 5})
	g.handle(host, {"t": "buildTurret", "x": 8, "y": 8, "weapon": "rocket"})
	var t := g.turrets.at_cell(8, 8)
	g.handle(host, {"t": "upgradeTurret", "id": t.id})
	g.wave = 4
	var d := g.to_save()
	var j: Dictionary = JSON.parse_string(JSON.stringify(d))     # через JSON, как на диске
	var g2 := GameSim.new()
	check("load ok", g2.from_save(j))
	check("wave", g2.wave == 4)
	check("money", g2.money == g.money)
	check("walls", g2.build.wall_cells().size() == 1 and g2.nav.is_blocked(5, 5))
	var t2 := g2.turrets.at_cell(8, 8)
	check("turret restored", t2 != null and t2.level == 2 and t2.weapon == "rocket")
	check("state", g2.state == "Preparation")
	check("bad save", not GameSim.new().from_save({"v": 9}))
