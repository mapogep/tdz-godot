class_name SimZombie
extends RefCounted
## Зомби в симуляции.

var id: int = 0
var type: String = "normal"
var x: float = 0.0
var z: float = 0.0
var vx: float = 0.0            # скорость за последний тик, м/с (для упреждения ракет)
var vz: float = 0.0
var hp: float = 1.0
var max_hp: float = 1.0
var radius: float = 0.45
var height: float = 1.8
var route: Array = []          # мировые точки Vector2(x, z) — центры клеток
var next: int = 1
var travelled: float = 0.0
var burn_left: float = 0.0     # поджог: сколько ещё горит и сколько урона в секунду
var burn_dps: float = 0.0


func snapshot() -> Dictionary:
	return {"id": id, "type": type, "x": x, "z": z, "hp": hp, "max_hp": max_hp, "burning": burn_left > 0.0}
