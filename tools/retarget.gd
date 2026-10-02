extends RefCounted
## Перенос анимаций с пака «Polyart Zombies» (скелет 3ds Max Biped, assets/source/zombie_pack.glb) на наши скелеты
## гуманоидов (16 костей, tools/bake_all.gd). Перенос по направлениям костей: для каждой нашей кости ищется поворот,
## при котором она смотрит туда же, куда соответствующая кость исходника (пропорции не важны); таз и грудь берут ещё
## и поворот вокруг оси (по линии бёдер/плеч). Ступни прижимаются к земле, циклы ходьбы вырезаются по автокорреляции,
## длина шага (м на цикл) считается по движению стоп — по ней игра синхронизирует шаги с перемещением (ноги не скользят).

const PACK := "res://assets/source/zombie_pack.glb"
const FPS := 30.0

# наша кость → [кость исходника, конец направления (кость исходника), «боковая» пара для поворота вокруг оси или ""]
const MAP := {
	"hips": ["Pelvis", "Spine", "Thigh"],
	"spine": ["Spine", "Spine1", ""],
	"chest": ["Spine1", "Neck", "UpperArm"],
	"neck": ["Neck", "Head", ""],
	"head": ["Head", "HeadNub", ""],
	"upperarm_L": ["L UpperArm", "L Forearm", ""],
	"forearm_L": ["L Forearm", "L Hand", ""],
	"upperarm_R": ["R UpperArm", "R Forearm", ""],
	"forearm_R": ["R Forearm", "R Hand", ""],
	"thigh_L": ["L Thigh", "L Calf", ""],
	"shin_L": ["L Calf", "L Foot", ""],
	"foot_L": ["L Foot", "L Toe0Nub", ""],
	"thigh_R": ["R Thigh", "R Calf", ""],
	"shin_R": ["R Calf", "R Foot", ""],
	"foot_R": ["R Foot", "R Toe0Nub", ""],
}
const ORDER := ["hips", "spine", "chest", "neck", "head", "upperarm_L", "forearm_L", "upperarm_R", "forearm_R",
	"thigh_L", "shin_L", "foot_L", "thigh_R", "shin_R", "foot_R"]

var scene: Node3D
var ap: AnimationPlayer
var anim_name := ""
var length := 0.0
var skels: Array = []                   # Skeleton3D исходника по номеру зомби
var samples: Array = []                 # [зомби][кадр] -> {кость: Vector3} в системе цели (лицом к -Z)
var _names: Dictionary = {}             # Skeleton3D -> канонические имена костей


## Загружает пак и снимает позиции суставов всех 10 зомби с шагом 1/FPS.
func load_pack(tree_root: Node) -> bool:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(PACK), state) != OK:
		return false
	scene = doc.generate_scene(state)
	tree_root.add_child(scene)
	ap = scene.find_children("*", "AnimationPlayer", true, false)[0]
	anim_name = ap.get_animation_list()[0]
	length = ap.get_animation(anim_name).length
	skels = scene.find_children("*", "Skeleton3D", true, false)
	for sk: Skeleton3D in skels:
		_names[sk] = canonical_names(sk)
	ap.play(anim_name)
	ap.pause()
	var n := int(floor(length * FPS))
	for k in skels.size():
		samples.append([])
	for f in n + 1:
		ap.seek(minf(f / FPS, length), true)
		for k in skels.size():
			samples[k].append(_joints(skels[k]))
	for k in skels.size():
		var miss: Array = []
		for nm in KNOWN:
			if not samples[k][0].has(nm):
				miss.append(nm)
		if not miss.is_empty():
			push_error("pack zombie %d: missing bones %s" % [k, miss])
	# у каждого зомби пака своё направление взгляда: среднее по клипу «вперёд» = (бедро L − бедро R) × вверх
	# разворачиваем к -Z (так смотрят наши модели)
	for k in skels.size():
		var fwd := Vector3.ZERO
		for j: Dictionary in samples[k]:
			fwd += ((j["L Thigh"] as Vector3) - (j["R Thigh"] as Vector3)).cross(Vector3.UP)
		fwd.y = 0.0
		var yaw := atan2(fwd.x, fwd.z) - atan2(0.0, -1.0)
		var q := Quaternion(Vector3.UP, -yaw)
		for j: Dictionary in samples[k]:
			for key in j.keys():
				j[key] = q * (j[key] as Vector3)
		print("  pack zombie %d: facing correction %.0f deg" % [k, rad_to_deg(-yaw)])
	return true


func free_pack() -> void:
	if scene != null:
		scene.free()


const KNOWN := ["Pelvis", "Spine", "Spine1", "Neck", "Head", "HeadNub", "jaw", "jawNub",
	"L Clavicle", "L UpperArm", "L Forearm", "L Hand", "R Clavicle", "R UpperArm", "R Forearm", "R Hand",
	"L Thigh", "L Calf", "L Foot", "L Toe0", "L Toe0Nub", "R Thigh", "R Calf", "R Foot", "R Toe0", "R Toe0Nub"]


## Канонические имена костей скелета: в копиях Biped 3ds Max переименовывает кости по-своему («Spine014»,
## «Spine015», «Toe007»), поэтому берём буквенную основу имени и порядок: первая «Spine» — Spine, вторая — Spine1.
static func canonical_names(sk: Skeleton3D) -> PackedStringArray:
	var out := PackedStringArray()
	var spines := 0
	for i in sk.get_bone_count():
		var s := sk.get_bone_name(i).trim_prefix("bip ")
		var u := s.rfind("_")
		if u > 0:
			s = s.substr(0, u)
		var side := ""
		if s.begins_with("L ") or s.begins_with("R "):
			side = s.left(2)
			s = s.substr(2)
		var letters := ""
		for ch in s:
			if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z"):
				letters += ch
			else:
				break
		var nub := s.contains("Nub")
		var base := letters
		match letters:
			"Spine":
				base = "Spine" if spines == 0 else "Spine1"
				spines += 1
			"Toe":
				base = "Toe0Nub" if nub else "Toe0"
			"Head", "jaw":
				base = letters + ("Nub" if nub else "")
		out.append(side + base)
	return out

## Позиции суставов в системе сцены пака (разворот к -Z — в load_pack, по каждому зомби отдельно).
func _joints(sk: Skeleton3D) -> Dictionary:
	var out := {}
	var xf := sk.global_transform
	var names: PackedStringArray = _names[sk]
	for i in sk.get_bone_count():
		out[names[i]] = xf * sk.get_bone_global_pose(i).origin
	return out


static func _pt(j: Dictionary, name: String) -> Vector3:
	if j.has(name):
		return j[name]
	if name.ends_with("Thigh") or name.ends_with("UpperArm"):
		return j.get("L " + name, Vector3.ZERO)
	return Vector3.ZERO


# ───────────── анализ ─────────────

## Положение стоп относительно таза вдоль «вперёд» (-Z) и высоты кистей — признаки для поиска цикла и удара.
func features(k: int, f: int) -> PackedFloat32Array:
	var j: Dictionary = samples[k][f]
	var pel: Vector3 = j["Pelvis"]
	var out := PackedFloat32Array()
	for nm in ["L Foot", "R Foot", "L Hand", "R Hand", "L Calf", "R Calf", "Head"]:
		var p: Vector3 = (j[nm] as Vector3) - pel
		out.append_array([p.x, p.y, p.z])
	return out


func _dist(k: int, a: int, b: int) -> float:
	var fa := features(k, a)
	var fb := features(k, b)
	var s := 0.0
	for i in fa.size():
		s += (fa[i] - fb[i]) * (fa[i] - fb[i])
	return sqrt(s / fa.size())


## Последний кадр, где поза ещё меняется (клипы зомби разной длины; после конца поза замирает).
func active_end(k: int) -> int:
	var n: int = samples[k].size()
	for f in range(n - 2, 0, -1):
		if _dist(k, f, f + 1) > 0.0005:
			return f + 1
	return n - 1


## Цикл в активной части: [начальный кадр, длина в кадрах, ошибка]. Берём самый короткий период, чья ошибка
## совпадения начала и конца близка к лучшей (иначе вместо одного шага выбирается двойной).
func best_cycle(k: int, min_len: int, max_len: int) -> Array:
	var n: int = active_end(k) + 1
	var per: Dictionary = {}
	var best_e := INF
	for p in range(min_len, mini(max_len, n - 1) + 1):
		var e_p := INF
		var s_p := 0
		for s in range(0, n - p, 2):
			var e := _dist(k, s, s + p)
			if e < e_p:
				e_p = e
				s_p = s
		per[p] = [s_p, e_p]
		best_e = minf(best_e, e_p)
	for p in range(min_len, mini(max_len, n - 1) + 1):
		var r: Array = per[p]
		if float(r[1]) <= best_e * 1.6 + 0.004:
			return [r[0], p, r[1]]
	return [0, min_len, INF]


## Петля удара вокруг кадра выноса кисти: начало и конец с похожей позой.
func attack_cycle(k: int) -> Array:
	var sf := strike_frame(k)
	var n: int = active_end(k) + 1
	var best := [maxi(0, sf - 20), 40]
	var best_e := INF
	for s in range(maxi(0, sf - 40), maxi(1, sf - 10)):
		for e in range(mini(n - 1, sf + 10), mini(n - 1, sf + 40)):
			var d := _dist(k, s, e) + 0.0004 * (e - s)
			if d < best_e:
				best_e = d
				best = [s, e - s]
	return [best[0], best[1], best_e]

## Ход стопы вперёд-назад относительно таза за цикл, м (системы исходника) — для длины шага.
func foot_travel(k: int, start: int, frames: int) -> float:
	var mn := INF
	var mx := -INF
	for f in range(start, start + frames + 1):
		var j: Dictionary = samples[k][f]
		var z := ((j["L Foot"] as Vector3) - (j["Pelvis"] as Vector3)).z
		mn = minf(mn, z)
		mx = maxf(mx, z)
	return mx - mn


## Путь, пройденный за цикл, м (системы исходника): опорная (нижняя) стопа движется назад относительно таза
## со скоростью ходьбы — суммируем её смещения. Работает при любом числе шагов в цикле.
func loop_distance(k: int, start: int, frames: int) -> float:
	var d := 0.0
	for f in range(start, start + frames):
		var j0: Dictionary = samples[k][f]
		var j1: Dictionary = samples[k][f + 1]
		var foot := "L Foot" if (j0["L Foot"] as Vector3).y < (j0["R Foot"] as Vector3).y else "R Foot"
		var z0 := ((j0[foot] as Vector3) - (j0["Pelvis"] as Vector3)).z
		var z1 := ((j1[foot] as Vector3) - (j1["Pelvis"] as Vector3)).z
		d += maxf(0.0, z1 - z0)
	return d

## Высота ноги исходника (бедро → стопа) — масштаб для перевода метров.
func leg_length(k: int) -> float:
	var j: Dictionary = samples[k][0]
	return (j["L Thigh"] as Vector3).distance_to(j["L Calf"]) + (j["L Calf"] as Vector3).distance_to(j["L Foot"])


## Кадр самого дальнего выноса кисти вперёд (удар).
func strike_frame(k: int) -> int:
	var best := 0
	var best_v := -INF
	for f in samples[k].size():
		var j: Dictionary = samples[k][f]
		var pel: Vector3 = j["Pelvis"]
		var v := -minf(((j["L Hand"] as Vector3) - pel).z, ((j["R Hand"] as Vector3) - pel).z)
		if v > best_v:
			best_v = v
			best = f
	return best


# ───────────── перенос ─────────────

static func _frame(primary: Vector3, side: Vector3) -> Basis:
	var y := primary.normalized()
	var x := (side - y * side.dot(y)).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)


static func _arc(a: Vector3, b: Vector3) -> Quaternion:
	var an := a.normalized()
	var bn := b.normalized()
	if an.dot(bn) > 0.99999:
		return Quaternion.IDENTITY
	if an.dot(bn) < -0.99999:
		var ax := an.cross(Vector3.UP)
		if ax.length() < 0.01:
			ax = an.cross(Vector3.RIGHT)
		return Quaternion(ax.normalized(), PI)
	return Quaternion(an.cross(bn).normalized(), an.angle_to(bn))


## Поворот тела вокруг вертикали (0 — лицом к -Z): по линии бёдер.
static func _body_yaw(j: Dictionary) -> float:
	var f := ((j["L Thigh"] as Vector3) - (j["R Thigh"] as Vector3)).cross(Vector3.UP)
	return atan2(-f.x, -f.z)


static func _rotate_about_pelvis(j: Dictionary, yaw: float) -> Dictionary:
	var q := Quaternion(Vector3.UP, yaw)
	var pel: Vector3 = j["Pelvis"]
	var out := {}
	for key in j.keys():
		out[key] = pel + q * ((j[key] as Vector3) - pel)
	return out


## Позы нашего скелета на кадре исходника: {кость: [локальный поворот Quaternion]}, смещение таза.
## rig: {"bones": [...], "segs": [...]} из bake_all (позы покоя в системе модели, базисы покоя — единичные).
static func pose_for(rig: Dictionary, j: Dictionary, j_rest: Dictionary, leg_ratio: float, damp: Dictionary = {}) -> Dictionary:
	var rest := {}
	var parent := {}
	for b in rig["bones"]:
		rest[b["name"]] = b["pos"]
		parent[b["name"]] = b["parent"]
	var tip := {}
	for s in rig["segs"]:
		tip[s[0]] = s[2]
	var G := {"root": Quaternion.IDENTITY}
	var local := {}
	for bn in ORDER:
		var m: Array = MAP[bn]
		var d_src: Vector3 = _pt(j, m[1]) - _pt(j, m[0])
		var d_rest: Vector3 = (tip[bn] as Vector3) - (rest[bn] as Vector3)
		var gp: Quaternion = G[parent[bn]]
		var g: Quaternion
		if m[2] != "":
			# таз и грудь: полный поворот по основному направлению и линии «лево-право»
			var side_src: Vector3 = _pt(j, "L " + m[2]) - _pt(j, "R " + m[2])
			var side_rest: Vector3
			if bn == "hips":
				side_rest = (rest["thigh_L"] as Vector3) - (rest["thigh_R"] as Vector3)
			else:
				side_rest = (rest["upperarm_L"] as Vector3) - (rest["upperarm_R"] as Vector3)
			var fs := _frame(d_src, side_src)
			var fr := _frame(d_rest, side_rest)
			g = (fs * fr.inverse()).get_rotation_quaternion()
		else:
			g = _arc(gp * d_rest, d_src) * gp
		var lq := gp.inverse() * g
		if damp.has(bn):
			lq = Quaternion.IDENTITY.slerp(lq, float(damp[bn]))      # ослабленный размах (дети считаются от него)
			g = gp * lq
		G[bn] = g
		local[bn] = lq
	# смещение таза: от позы покоя исходника, в масштабе ног цели
	var dp: Vector3 = ((j["Pelvis"] as Vector3) - (j_rest["Pelvis"] as Vector3)) * leg_ratio
	return {"local": local, "global": G, "hips_off": dp}


## Позиции суставов цели при данной позе (прямая кинематика) — для прижатия стоп к земле.
static func fk(rig: Dictionary, G: Dictionary, hips_off: Vector3) -> Dictionary:
	var rest := {}
	var parent := {}
	for b in rig["bones"]:
		rest[b["name"]] = b["pos"]
		parent[b["name"]] = b["parent"]
	var pos := {"root": rest["root"]}
	pos["hips"] = (rest["hips"] as Vector3) + hips_off
	for bn in ORDER:
		if bn == "hips":
			continue
		var pb: String = parent[bn]
		pos[bn] = (pos[pb] as Vector3) + (G[pb] as Quaternion) * ((rest[bn] as Vector3) - (rest[pb] as Vector3))
	var tips := {}
	for s in rig["segs"]:
		var bn: String = s[0]
		if pos.has(bn):
			tips[bn] = (pos[bn] as Vector3) + (G[bn] as Quaternion) * ((s[2] as Vector3) - (s[1] as Vector3))
	return {"pos": pos, "tips": tips}


## Анимация для цели из кадров [start, start+frames] зомби k. loop — зациклить; ground — прижимать стопы к земле.
## damp — {кость: доля движения} (1 — как в исходнике): ослабляет размах, если сетка его не выдерживает.
## yaw_window — полуширина сглаживания разворота, кадров (0 — тело всегда смотрит строго вперёд).
func build_animation(rig: Dictionary, k: int, start: int, frames: int, loop: bool, ground: bool = true, damp: Dictionary = {},
		yaw_window: int = 12) -> Animation:
	var a := Animation.new()
	a.length = frames / FPS
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks := {}
	for bn in ORDER:
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, "Skeleton3D:" + bn)
		a.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)
		tracks[bn] = t
	var hp := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(hp, "Skeleton3D:hips")
	var rest := {}
	for b in rig["bones"]:
		rest[b["name"]] = b["pos"]
	var j_rest: Dictionary = samples[k][0]
	var leg_t := (rest["thigh_L"] as Vector3).distance_to(rest["shin_L"]) + (rest["shin_L"] as Vector3).distance_to(rest["foot_L"])
	var ratio := leg_t / leg_length(k)
	# опорный уровень: самая низкая точка стоп в позе покоя цели
	var ground_y := INF
	for s in rig["segs"]:
		if str(s[0]).begins_with("foot"):
			ground_y = minf(ground_y, minf((s[1] as Vector3).y, (s[2] as Vector3).y))
	# средняя по циклу высота таза исходника — смещение по высоте считаем от неё (поза покоя Biped бывает «в присяде»)
	var mean := Vector3.ZERO
	for f in range(start, start + frames + 1):
		mean += samples[k][f]["Pelvis"]
	mean /= float(frames + 1)
	var j_mean := j_rest.duplicate()
	j_mean["Pelvis"] = mean
	# медленные развороты исходника (зомби пака во время удара оглядываются) убираем: поворот тела вокруг вертикали,
	# сглаженный за ±0,4 с, вычитается из каждого кадра; быстрое покачивание бёдер остаётся
	var yaws := PackedFloat32Array()
	var n_all: int = samples[k].size()
	for f in n_all:
		yaws.append(_body_yaw(samples[k][f]))
	for f in range(1, n_all):
		yaws[f] = yaws[f - 1] + wrapf(yaws[f] - yaws[f - 1], -PI, PI)     # без скачков через ±π
	var max_ang := {}
	for i in frames + 1:
		var f := start + i
		var sm := 0.0
		var cnt := 0
		for q in range(maxi(0, f - yaw_window), mini(n_all, f + yaw_window + 1)):
			sm += yaws[q]
			cnt += 1
		var jf := _rotate_about_pelvis(samples[k][f], -sm / cnt)
		var p := pose_for(rig, jf, j_mean, ratio, damp)
		if OS.get_environment("RT_DEBUG") != "":
			for bn in ["hips", "spine", "chest", "neck", "head"]:
				max_ang[bn] = maxf(float(max_ang.get(bn, 0.0)), rad_to_deg((p["local"][bn] as Quaternion).get_angle()))
		var off: Vector3 = p["hips_off"]
		if ground:
			var kin := fk(rig, p["global"], off)
			var low := INF
			for bn in ["foot_L", "foot_R"]:
				low = minf(low, minf((kin["pos"][bn] as Vector3).y, (kin["tips"][bn] as Vector3).y))
			off.y += ground_y - low
		var t := i / FPS
		if i == frames and loop:
			t = a.length
		for bn in ORDER:
			a.rotation_track_insert_key(tracks[bn], t, p["local"][bn])
		a.position_track_insert_key(hp, t, (rest["hips"] as Vector3) - (rest["root"] as Vector3) + off)
	if not max_ang.is_empty():
		print("      max local angles: ", max_ang)
	return a


# ───────────── набор анимаций для зомби ─────────────

# какие клипы пака что изображают (раскадровка: tests/probe_pack.gd): 7 — классическая ходьба с вытянутыми руками,
# 9 — шаркающая, 5 — бег; 0 и 1 — выпад с ударом; 2 — покачивание на месте (6 — переминание почти без шага, не берём).
const WALKS := {"walk_a": 7, "walk_b": 9, "run": 5}
const ATTACKS := {"attack_a": 0, "attack_b": 1}
const IDLES := {"idle": 2}


## Библиотека анимаций для скелета rig: walks — какие клипы походки взять. Возвращает [AnimationLibrary, meta]:
## meta = {"walks": [...], "attacks": [...], "stride": {имя: метров за цикл в системе модели}}.
func zombie_library(rig: Dictionary, walks: Array, damp: Dictionary = {}) -> Array:
	var lib := AnimationLibrary.new()
	var rest := {}
	for b in rig["bones"]:
		rest[b["name"]] = b["pos"]
	var leg_t := (rest["thigh_L"] as Vector3).distance_to(rest["shin_L"]) + (rest["shin_L"] as Vector3).distance_to(rest["foot_L"])
	var meta := {"walks": [], "attacks": [], "stride": {}}
	for name in walks:
		var k: int = WALKS[name]
		var c := best_cycle(k, 18, 75)
		lib.add_animation(name, build_animation(rig, k, c[0], c[1], true, true, damp))
		var stride := loop_distance(k, c[0], c[1]) * leg_t / leg_length(k)
		meta["walks"].append(name)
		meta["stride"][name] = stride
		print("    %s <- z%d frames %d..%d (%.2fs), stride %.2f" % [name, k, c[0], c[0] + c[1], c[1] / FPS, stride])
	for name in ATTACKS.keys():
		var k: int = ATTACKS[name]
		var c := attack_cycle(k)
		# в ударе зомби пака резко скручивают корпус почти на 90° — на наших сетках это выглядит как разворот,
		# поэтому скрутку корпуса ослабляем
		var ad := damp.duplicate()
		ad.merge({"spine": 0.55, "chest": 0.45, "neck": 0.7}, true)
		lib.add_animation(name, build_animation(rig, k, c[0], c[1], true, true, ad, 0))
		meta["attacks"].append(name)
	for name in IDLES.keys():
		var k: int = IDLES[name]
		var c := best_cycle(k, 30, 75)
		lib.add_animation(name, build_animation(rig, k, c[0], c[1], true))
	return [lib, meta]