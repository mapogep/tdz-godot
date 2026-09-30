class_name SimPlayer
extends RefCounted
## Личный солдат игрока в режиме «Свободный FPS». Состояние хранится и между заходами в режим
## (патроны и здоровье не сбрасываются переключением F1/F2), обновляется в PlayerSim.

var id := 0
var active := false          # игрок сейчас в режиме «Свободный FPS» (тело есть в мире)
var alive := true
var x := 0.0
var z := 0.0
var yaw := PI / 2.0 * -1.0   # смотрит на запад (yaw=0 → +Z, запад — -X)
var pitch := 0.0
var hp: float = float(Cfg.PLAYER["hp"])
var weapon := "ak"           # ak | melee
var melee := "machete"       # machete | axe (случайно)
var ammo: int = int(Cfg.PWEAPONS["ak"]["mag"])
var mags: int = int(Cfg.PWEAPONS["ak"]["mags"])
var reload_left := 0.0
var cd := 0.0                # перезарядка выстрела/удара
var fire := false
var budget := 0.0            # сколько метров игрок ещё вправе пройти (защита от читерских перемещений)
var sprint := false


func max_hp() -> float:
	return float(Cfg.PLAYER["hp"])


func snapshot() -> Dictionary:
	var rel := 0.0
	if reload_left > 0.0:
		rel = 1.0 - reload_left / float(Cfg.PWEAPONS["ak"]["reload"])
	return {"id": id, "active": active, "alive": alive, "x": x, "z": z, "yaw": yaw, "pitch": pitch,
		"hp": hp, "max_hp": max_hp(), "weapon": weapon, "melee": melee, "ammo": ammo, "mags": mags,
		"reload": rel, "fire": fire}