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
		"z_normal": "Обычный", "z_fat": "Толстый", "z_fast": "Быстрый", "incoming": "ВОЛНА СОСТОИТ ИЗ",
		"fuel": "Топливо", "splash": "Взрыв", "per_tick": "за тик", "range": "Дальность", "fire_rate": "Скорострельность",
		"ammo": "Патроны", "reloading": "ПЕРЕЗАРЯДКА", "upgrade": "УЛУЧШИТЬ", "sell": "ПРОДАТЬ", "move": "ПЕРЕМЕСТИТЬ",
		"exit_fps": "ESC — выйти из турели", "move_hint": "Выберите новую клетку для турели (ESC — отмена)",
		"players": "Игроки", "host": "Host", "you": "вы", "in_turret": "в турели",
		"hint_build": "Турели на стенах зомби не достают · ЛКМ — действие · ПКМ + мышь, WASD — камера · Q/E или СКМ + мышь — поворот · колесо — zoom · T — следующая турель · F2 — свободный FPS",
		"hint_guest": "Строит только Host. Выберите турель и войдите в неё, чтобы стрелять · WASD/ПКМ — камера · Q/E — поворот · колесо — zoom · F2 — свободный FPS",
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
		"z_normal": "Normal", "z_fat": "Fat", "z_fast": "Fast", "incoming": "THIS WAVE",
		"fuel": "Fuel", "splash": "Blast", "per_tick": "per tick", "range": "Range", "fire_rate": "Fire rate",
		"ammo": "Ammo", "reloading": "RELOADING", "upgrade": "UPGRADE", "sell": "SELL", "move": "MOVE",
		"exit_fps": "ESC — leave turret", "move_hint": "Pick a new cell for the turret (ESC — cancel)",
		"players": "Players", "host": "Host", "you": "you", "in_turret": "in turret",
		"hint_build": "Turrets on walls are safe from zombies · LMB — act · RMB drag, WASD — camera · Q/E or MMB drag — rotate · wheel — zoom · T — next turret · F2 — free FPS",
		"hint_guest": "Only the Host builds. Select a turret and enter it to shoot · WASD/RMB — camera · Q/E — rotate · wheel — zoom · F2 — free FPS",
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
