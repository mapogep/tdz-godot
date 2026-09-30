class_name Cfg
extends RefCounted
## Все игровые параметры и формулы (порт packages/shared/src/config.ts).
## Никаких «магических чисел» в логике — баланс меняется только здесь.

# ───────────── Поле и экономика ─────────────
const FIELD_SIZE := 20            # размер поля, м (клеток)
const GATE_WIDTH := 2             # ширина ворот, клеток
const PREP_TIME := 120.0          # секунд подготовки между волнами
const START_MONEY := 100
const START_WALLS := 20
const START_TURRETS := 3          # бесплатный запас базовых турелей (gun)
const WALL_COST := 10
const WALL_HEIGHT := 1.2          # высота стены игрока, м
const TICK_RATE := 20             # частота симуляции, Гц

# ───────────── Зомби ─────────────
const ZOMBIE_TYPES := ["normal", "fat", "fast"]
const ATTACK_REACH := 0.85        # с какого расстояния до центра клетки турели зомби бьёт её
const ZOMBIES := {
	# Средний: базовый зомби
	"normal": {"speed": 1.5, "hp": 40.0, "hp_per_wave": 6.0, "reward": 10, "radius": 0.45, "height": 1.8, "attack": 14.0, "scale": 1.0},
	# Толстый: медленный, очень много HP, сильно бьёт
	"fat": {"speed": 0.8, "hp": 170.0, "hp_per_wave": 27.0, "reward": 35, "radius": 0.65, "height": 2.3, "attack": 26.0, "scale": 1.35},
	# Быстрый: мало HP, летит к воротам
	"fast": {"speed": 3.0, "hp": 22.0, "hp_per_wave": 3.0, "reward": 8, "radius": 0.4, "height": 1.6, "attack": 8.0, "scale": 0.85},
}

# ───────────── Волны ─────────────
const WAVE := {
	"base_count": 1, "count_per_wave": 1, "spawn_interval": 1.0, "reward_mul": 2.0,
	"fast_from": 3, "fast_share": 0.3, "fat_from": 4, "fat_share": 0.2,
}

# ───────────── Оружие / турели ─────────────
const WEAPON_TYPES := ["gun", "machinegun", "rocket", "flame"]
const TURRET := {
	"max_level": 10, "sell_mul": 0.5, "fps_mul": 2.0, "muzzle": 1.4, "aim_tol": 0.05, "min_reload": 0.4,
}
const WEAPONS := {
	# Базовая турель: точная, дешёвая, один выстрел в секунду
	"gun": {
		"kind": "hitscan", "cost": 100, "upgrade": 50, "priority": "nearest",
		"base": {"damage": 10.0, "rate": 1.0, "range": 5.0, "turn": 4.0, "hp": 120.0, "mag": 12.0, "reload": 2.0},
		"per": {"damage": 2.0, "rate": 0.1, "range": 0.5, "turn": 0.4, "hp": 30.0, "mag": 2.0, "reload": -0.12},
		"spread": 0.0, "splash": 0.0, "speed": 0.0, "cone": 0.0, "edge": 1.0, "burn": 0.0, "burn_time": 0.0,
	},
	# Пулемёт: высокая скорострельность, разброс, большой магазин
	"machinegun": {
		"kind": "hitscan", "cost": 150, "upgrade": 60, "priority": "nearest",
		"base": {"damage": 3.5, "rate": 8.0, "range": 5.5, "turn": 5.0, "hp": 110.0, "mag": 40.0, "reload": 2.6},
		"per": {"damage": 0.7, "rate": 0.4, "range": 0.4, "turn": 0.4, "hp": 25.0, "mag": 6.0, "reload": -0.15},
		"spread": 0.05, "splash": 0.0, "speed": 0.0, "cone": 0.0, "edge": 1.0, "burn": 0.0, "burn_time": 0.0,
	},
	# Ракетомёт: медленный, дальний, взрыв по площади (урон рассеивается от центра к краю), поджигает
	"rocket": {
		"kind": "rocket", "cost": 300, "upgrade": 110, "priority": "first",
		"base": {"damage": 28.0, "rate": 0.5, "range": 6.5, "turn": 2.2, "hp": 100.0, "mag": 3.0, "reload": 4.5},
		"per": {"damage": 6.0, "rate": 0.03, "range": 0.3, "turn": 0.2, "hp": 25.0, "mag": 0.5, "reload": -0.25},
		"spread": 0.0, "splash": 1.6, "speed": 9.0, "cone": 0.0, "edge": 0.25, "burn": 0.15, "burn_time": 2.5,
	},
	# Огнемёт: очень короткая дальность, жжёт всех в конусе, урон убывает с расстоянием
	"flame": {
		"kind": "flame", "cost": 180, "upgrade": 70, "priority": "nearest",
		"base": {"damage": 4.6, "rate": 10.0, "range": 3.6, "turn": 3.5, "hp": 100.0, "mag": 50.0, "reload": 3.0},
		"per": {"damage": 0.5, "rate": 0.2, "range": 0.15, "turn": 0.3, "hp": 25.0, "mag": 6.0, "reload": -0.2},
		"spread": 0.0, "splash": 0.0, "speed": 0.0, "cone": 0.4, "edge": 0.45, "burn": 0.3, "burn_time": 2.0,
	},
}


## Количество зомби в волне N (N с единицы).
static func zombie_count(wave: int) -> int:
	return int(WAVE["base_count"]) + int(WAVE["count_per_wave"]) * (wave - 1)


static func zombie_hp(wave: int, type: String = "normal") -> float:
	var z: Dictionary = ZOMBIES[type]
	return float(z["hp"]) + float(z["hp_per_wave"]) * (wave - 1)


static func zombie_reward(type: String) -> int:
	return int(round(float(ZOMBIES[type]["reward"]) * float(WAVE["reward_mul"])))


## Умножение 32-битных беззнаковых (аналог Math.imul).
static func _imul(a: int, b: int) -> int:
	return (a * b) & 0xFFFFFFFF


## mulberry32: детерминированный ГСЧ; state — массив из одного числа.
static func _mulberry(state: Array) -> float:
	state[0] = (int(state[0]) + 0x6d2b79f5) & 0xFFFFFFFF
	var t: int = state[0]
	t = _imul(t ^ (t >> 15), t | 1)
	t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


## Состав волны — порядок появления зомби (детерминирован: клиент показывает то же самое).
static func wave_composition(wave: int) -> Array:
	var n := zombie_count(wave)
	var fat := 0
	var fast := 0
	if wave >= int(WAVE["fat_from"]):
		fat = maxi(1, int(floor(n * float(WAVE["fat_share"]))))
	if wave >= int(WAVE["fast_from"]):
		fast = maxi(1, int(ceil(n * float(WAVE["fast_share"]))))
	while fat + fast > n:
		if fast >= fat:
			fast -= 1
		else:
			fat -= 1
	var list: Array = []
	for i in fat: list.append("fat")
	for i in fast: list.append("fast")
	for i in n - fat - fast: list.append("normal")
	var st: Array = [(wave * 7919) & 0xFFFFFFFF]
	for i in range(list.size() - 1, 0, -1):
		var j := int(floor(_mulberry(st) * (i + 1)))
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
	return list


## Характеристики турели типа type на уровне level (1..max_level) — единственное место формул.
static func turret_stats(level: int, type: String = "gun") -> Dictionary:
	var n := level - 1
	var w: Dictionary = WEAPONS[type]
	var b: Dictionary = w["base"]
	var p: Dictionary = w["per"]
	return {
		"damage": float(b["damage"]) + float(p["damage"]) * n,
		"rate": float(b["rate"]) + float(p["rate"]) * n,
		"range": float(b["range"]) + float(p["range"]) * n,
		"turn": float(b["turn"]) + float(p["turn"]) * n,
		"hp": float(b["hp"]) + float(p["hp"]) * n,
		"mag": int(round(float(b["mag"]) + float(p["mag"]) * n)),
		"reload": maxf(float(TURRET["min_reload"]), float(b["reload"]) + float(p["reload"]) * n),
	}


static func turret_cost(type: String = "gun") -> int:
	return int(WEAPONS[type]["cost"])


## Цена улучшения с уровня level на level+1.
static func upgrade_cost(level: int, type: String = "gun") -> int:
	return int(WEAPONS[type]["upgrade"]) * level


## Цена продажи при вложенных invested (база + все улучшения).
static func sell_value(invested: int) -> int:
	return int(floor(invested * float(TURRET["sell_mul"])))


# ───────────── «Свободный FPS»: личный солдат игрока ─────────────

const PLAYER := {
	"hp": 100.0, "speed": 4.6, "sprint_mul": 1.55, "radius": 0.32, "eye": 1.65,
	"spawn_x": 18.6, "spawn_z": 10.0,      # у восточных ворот, внутри стены
	"zombie_mul": 0.8,                     # урон зомби по игроку = attack * mul в секунду
	"bounds_min": -6.0, "bounds_max": 26.0,
}

# личное оружие: АК-47 (mags — запасные магазины) и холодное (выдаётся случайно)
const PWEAPONS := {
	"ak": {"damage": 24.0, "rate": 9.0, "mag": 30, "mags": 3, "reload": 2.3, "spread": 0.016, "range": 90.0},
	"machete": {"damage": 34.0, "range": 2.1, "cooldown": 0.55, "arc": 1.05},
	"axe": {"damage": 58.0, "range": 2.0, "cooldown": 0.95, "arc": 1.05},
}
const MELEE_TYPES := ["machete", "axe"]