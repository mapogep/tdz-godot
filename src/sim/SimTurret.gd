class_name SimTurret
extends RefCounted
## РЎРѕСЃС‚РѕСЏРЅРёРµ РѕРґРЅРѕР№ С‚СѓСЂРµР»Рё. Р‘РѕРµРІР°СЏ Р»РѕРіРёРєР° вЂ” РІ TurretSim.

var id: int = 0
var weapon: String = "gun"
var cx: int = 0
var cy: int = 0
var level: int = 1
var invested: int = 0          # РІР»РѕР¶РµРЅРѕ РґРµРЅРµРі: Р±Р°Р·Р° + СѓР»СѓС‡С€РµРЅРёСЏ (РґР»СЏ СЂР°СЃС‡С‘С‚Р° РїСЂРѕРґР°Р¶Рё)
var yaw: float = -PI / 2.0
var pitch: float = 0.0
var cooldown: float = 0.0      # РґРѕ СЃР»РµРґСѓСЋС‰РµРіРѕ РІС‹СЃС‚СЂРµР»Р°; РјРѕР¶РµС‚ СѓС…РѕРґРёС‚СЊ РІ РјРёРЅСѓСЃ РЅР° РґРѕР»СЋ С‚РёРєР°
var reload_left: float = 0.0
var ammo: int = 0
var hp: float = 1.0
var elevated: bool = false     # СЃС‚РѕРёС‚ РЅР° СЃС‚РµРЅРµ: РІС‹С€Рµ Рё РІРЅРµ РјР°СЂС€СЂСѓС‚Р° Р·РѕРјР±Рё
var controlled_by: int = 0     # id РёРіСЂРѕРєР° РІ Р±Р°С€РЅРµ (FPS), 0 вЂ” РЅРёРєРѕРіРѕ
var in_yaw: float = -PI / 2.0        # РІРІРѕРґ РёРіСЂРѕРєР°
var in_pitch: float = 0.0
var in_firing: bool = false


func stats() -> Dictionary:
	return Cfg.turret_stats(level, weapon)


func muzzle_y() -> float:
	return float(Cfg.TURRET["muzzle"]) + (Cfg.WALL_HEIGHT if elevated else 0.0)


func world_x() -> float:
	return cx - 1 + 0.5


func world_z() -> float:
	return cy - 1 + 0.5


func snapshot() -> Dictionary:
	var st := stats()
	return {
		"id": id, "weapon": weapon, "cx": cx, "cy": cy, "level": level, "yaw": yaw, "pitch": pitch,
		"ammo": ammo, "reloading": reload_left > 0.0, "hp": maxi(0, int(ceil(hp))), "max_hp": int(st["hp"]),
		"elevated": elevated, "invested": invested, "controlled_by": controlled_by,
	}

