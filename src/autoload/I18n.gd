extends Node
## Локализация RU/EN. I18n.t("key") — строка на текущем языке.

signal language_changed

var lang := "ru"

const D := {
	"ru": {
		"wave": "ВОЛНА", "next_wave_in": "СЛЕДУЮЩАЯ ВОЛНА ЧЕРЕЗ", "wave_running": "ВОЛНА ИДЁТ",
		"start_wave": "НАЧАТЬ СЛЕДУЮЩУЮ ВОЛНУ", "money": "ДЕНЬГИ", "walls": "СТЕНЫ", "turrets": "ТУРЕЛИ",
		"free": "бесплатно", "city_destroyed": "ГОРОД УНИЧТОЖЕН", "zombies_killed": "Убито зомби",
		"money_earned": "Заработано", "restart": "ЗАНОВО", "to_menu": "В МЕНЮ", "wait_host": "Ждём, пока Host перезапустит игру…",
		"connecting": "Подключение к серверу…", "connected": "Подключено", "disconnected": "Связь потеряна",
		"tool_select": "Выбор", "tool_wall": "Стена", "tool_remove": "Снести", "turret": "ТУРЕЛЬ",
		"level": "Уровень", "max": "МАКС", "damage": "Урон", "dps": "Урон/с", "hp": "Прочность",
		"w_gun": "Турель", "w_machinegun": "Пулемёт", "w_rocket": "Ракетомёт", "w_flame": "Огнемёт",
		"z_normal": "Ходок", "z_fat": "Толстый", "z_fast": "Бегунья", "z_armored": "Броненосец", "z_boomer": "Взрывун", "z_brute": "Громила", "incoming": "ВОЛНА СОСТОИТ ИЗ",
		"hk_strategy": "F1 Стратегия · F2 Свободный FPS · F5 Начать волну · 1–7 Инструменты · T Турель · Q/E Поворот · WASD Камера · Tab Счёт · F11 Экран · Esc Отмена", "hk_turret": "F1 Выйти из турели · F2 Свободный FPS · F5 Начать волну · ЛКМ Огонь · Tab Счёт · F11 Экран · Esc Пауза", "hk_free": "F1 Стратегия · F5 Начать волну · WASD Ход · Shift Бег · ЛКМ Огонь/удар · R Перезарядка · 1/2 Оружие · Tab Счёт · F11 Экран · Esc Пауза",
		"zd_armored": "Новый враг — БРОНЕНОСЕЦ: пули и клинки почти не берут, жгите и взрывайте", "zd_boomer": "Новый враг — ВЗРЫВУН: лопается и ранит всех вокруг. Убивайте издалека — лучше в толпе", "zd_brute": "БОСС — ГРОМИЛА: огромный запас здоровья, ломает турели за пару ударов",
		"score": "Очки", "kills": "Убийства", "deaths": "Смерти", "rank": "#", "player": "Игрок", "wave_rating": "ВОЛНА %d ОТРАЖЕНА — РЕЙТИНГ", "wave_pts": "За волну", "auto_kills": "Автотурели: %d убийств", "scoreboard": "СЧЁТ (Tab)", "final_rating": "ИТОГОВЫЙ РЕЙТИНГ", "close_hint": "клик — закрыть",
		"fuel": "Топливо", "splash": "Взрыв", "per_tick": "за тик", "range": "Дальность", "fire_rate": "Скорострельность",
		"ammo": "Патроны", "reloading": "ПЕРЕЗАРЯДКА", "upgrade": "УЛУЧШИТЬ", "sell": "ПРОДАТЬ", "move": "ПЕРЕМЕСТИТЬ",
		"exit_fps": "ESC — выйти из турели", "move_hint": "Выберите новую клетку для турели (ESC — отмена)",
		"players": "Игроки", "host": "Host", "you": "вы", "in_turret": "в турели",
		"hint_build": "Турели на стенах зомби не достают · ЛКМ — действие · ПКМ + мышь — двигать камеру · колесо — масштаб",
		"hint_guest": "Строит только Host. Выберите турель в списке справа и войдите в неё, чтобы стрелять",
		"pause_title": "Управление приостановлено", "pause_resume": "Кликните, чтобы продолжить прицеливание",
		"pause_leave": "Выйти из турели (ESC)",
		"err_notHost": "Это может делать только Host", "err_wrongPhase": "Сейчас это недоступно",
		"err_invalidCell": "Сюда строить нельзя", "err_dead": "Вы погибли — только наблюдение до конца волны",
		"free_title": "СВОБОДНЫЙ FPS", "free_hint": "WASD — ход · Shift — бег · ЛКМ — огонь/удар · R — перезарядка · 1/2 или колесо — оружие · ESC — пауза · F1 — стратегия", "w_ak": "АК-47", "w_machete": "Мачете", "w_axe": "Топор", "free_mags": "магазины", "dead_banner": "ВЫ ПОГИБЛИ · наблюдение, возрождение после отражения волны", "revived": "Вы возрождены", "free_no_ammo": "Нет патронов — пополнение между волнами", "err_occupied": "Клетка занята",
		"err_pathBlocked": "Нельзя перекрывать путь зомби!", "err_noResources": "Не хватает денег или запаса",
		"err_noSuchObject": "Объект не найден", "err_maxLevel": "Максимальный уровень",
		"err_alreadyControlled": "Турель уже занята другим игроком", "err_invalid": "Некорректная команда",
		"menu_title": "TOWER DEFENSE\nZOMBIE", "menu_single": "Одиночная игра", "menu_host": "Создать игру (Host)",
		"menu_join": "Подключиться", "menu_options": "Настройки", "menu_quit": "Выход", "menu_ip": "Адрес хоста",
		"menu_port": "Порт", "menu_back": "Назад", "menu_continue": "Продолжить сохранённую игру",
		"opt_quality": "Качество графики", "opt_volume": "Громкость", "opt_language": "Язык", "opt_fullscreen": "Полный экран",
		"q_low": "Низкое", "q_medium": "Среднее", "q_high": "Высокое", "q_ultra": "Ультра",
		"hosting": "Игра создана. Адрес для друзей:", "join_failed": "Не удалось подключиться",
		"paused": "ПАУЗА", "resume": "Продолжить", "toggle_lang": "EN", "loading": "Загрузка…",
		"tip_gate": "Зомби идут с запада к восточным воротам", "fps_hint": "ЛКМ — огонь (можно держать) · ESC — пауза",
	},
	"en": {
		"wave": "WAVE", "next_wave_in": "NEXT WAVE IN", "wave_running": "WAVE IN PROGRESS",
		"start_wave": "START NEXT WAVE", "money": "MONEY", "walls": "WALLS", "turrets": "TURRETS",
		"free": "free", "city_destroyed": "CITY DESTROYED", "zombies_killed": "Zombies killed",
		"money_earned": "Money earned", "restart": "RESTART", "to_menu": "TO MENU", "wait_host": "Waiting for the Host to restart…",
		"connecting": "Connecting to server…", "connected": "Connected", "disconnected": "Connection lost",
		"tool_select": "Select", "tool_wall": "Wall", "tool_remove": "Remove", "turret": "TURRET",
		"level": "Level", "max": "MAX", "damage": "Damage", "dps": "DPS", "hp": "Durability",
		"w_gun": "Turret", "w_machinegun": "Machine gun", "w_rocket": "Rocket launcher", "w_flame": "Flamethrower",
		"z_normal": "Walker", "z_fat": "Fat", "z_fast": "Runner", "z_armored": "Armored", "z_boomer": "Boomer", "z_brute": "Brute", "incoming": "THIS WAVE",
		"hk_strategy": "F1 Strategy · F2 Free FPS · F5 Start wave · 1–7 Tools · T Turret · Q/E Rotate · WASD Camera · Tab Score · F11 Fullscreen · Esc Cancel", "hk_turret": "F1 Leave turret · F2 Free FPS · F5 Start wave · LMB Fire · Tab Score · F11 Fullscreen · Esc Pause", "hk_free": "F1 Strategy · F5 Start wave · WASD Move · Shift Sprint · LMB Fire/strike · R Reload · 1/2 Weapon · Tab Score · F11 Fullscreen · Esc Pause",
		"zd_armored": "New enemy — ARMORED: bullets and blades barely hurt it, use fire and rockets", "zd_boomer": "New enemy — BOOMER: bursts and hurts everything nearby. Kill it from afar, ideally inside a crowd", "zd_brute": "BOSS — BRUTE: huge health pool, wrecks turrets in a couple of blows",
		"score": "Score", "kills": "Kills", "deaths": "Deaths", "rank": "#", "player": "Player", "wave_rating": "WAVE %d CLEARED — RATING", "wave_pts": "This wave", "auto_kills": "Auto turrets: %d kills", "scoreboard": "SCORE (Tab)", "final_rating": "FINAL RATING", "close_hint": "click to close",
		"fuel": "Fuel", "splash": "Blast", "per_tick": "per tick", "range": "Range", "fire_rate": "Fire rate",
		"ammo": "Ammo", "reloading": "RELOADING", "upgrade": "UPGRADE", "sell": "SELL", "move": "MOVE",
		"exit_fps": "ESC — leave turret", "move_hint": "Pick a new cell for the turret (ESC — cancel)",
		"players": "Players", "host": "Host", "you": "you", "in_turret": "in turret",
		"hint_build": "Turrets on walls are safe from zombies · LMB — act · RMB drag — move camera · wheel — zoom",
		"hint_guest": "Only the Host builds. Pick a turret in the list on the right and enter it to shoot",
		"pause_title": "Control paused", "pause_resume": "Click to resume aiming", "pause_leave": "Leave turret (ESC)",
		"err_notHost": "Only the Host can do that", "err_wrongPhase": "Not available right now",
		"err_invalidCell": "Cannot build here", "err_dead": "You are dead — spectating until the wave ends",
		"free_title": "FREE FPS", "free_hint": "WASD — move · Shift — sprint · LMB — fire/strike · R — reload · 1/2 or wheel — weapon · ESC — pause · F1 — strategy", "w_ak": "AK-47", "w_machete": "Machete", "w_axe": "Axe", "free_mags": "mags", "dead_banner": "YOU DIED · spectating, respawn when the wave is cleared", "revived": "You are back", "free_no_ammo": "Out of ammo — refilled between waves", "err_occupied": "Cell is occupied",
		"err_pathBlocked": "You cannot block the zombies' path!", "err_noResources": "Not enough money or stock",
		"err_noSuchObject": "Object not found", "err_maxLevel": "Already max level",
		"err_alreadyControlled": "Turret is used by another player", "err_invalid": "Invalid command",
		"menu_title": "TOWER DEFENSE\nZOMBIE", "menu_single": "Single player", "menu_host": "Host a game",
		"menu_join": "Join a game", "menu_options": "Options", "menu_quit": "Quit", "menu_ip": "Host address",
		"menu_port": "Port", "menu_back": "Back", "menu_continue": "Continue saved game",
		"opt_quality": "Graphics quality", "opt_volume": "Volume", "opt_language": "Language", "opt_fullscreen": "Fullscreen",
		"q_low": "Low", "q_medium": "Medium", "q_high": "High", "q_ultra": "Ultra",
		"hosting": "Game created. Address for friends:", "join_failed": "Could not connect",
		"paused": "PAUSED", "resume": "Resume", "toggle_lang": "RU", "loading": "Loading…",
		"tip_gate": "Zombies walk from the west to the east gate", "fps_hint": "LMB — fire (hold) · ESC — pause",
	},
}


func t(key: String) -> String:
	var d: Dictionary = D[lang]
	if d.has(key):
		return d[key]
	return key


func set_language(l: String) -> void:
	if l != lang and D.has(l):
		lang = l
		language_changed.emit()


func toggle() -> void:
	set_language("en" if lang == "ru" else "ru")
