## Every number in the game, with its range and default. The game reads
## `Tune.v` live, so a change in the settings applies at once (field size
## applies from the next game). Values are saved on the device.
## The defaults come from default_settings.cfg (edit that, not `def` below).
class_name Tune

const PATH := "user://tuning.json"

const ITEMS := [
	{group = "GAME"},
	{key = "difficulty", label = "Difficulty", type = "choice", def = "normal", options = {"easy": "Rookie", "normal": "Pro", "hard": "All-Pro"}, note = "how good the computer's players are"},
	{key = "gameSpeed", label = "Game speed", min = 0.4, max = 2, step = 0.05, def = 1, unit = "×"},
	{key = "quarterMinutes", label = "Quarter length", min = 1, max = 15, step = 0.5, def = 4, unit = "min", note = "game clock"},
	{key = "clockRate", label = "Clock speed during a play", min = 0.5, max = 6, step = 0.1, def = 1.5, unit = "×"},
	{key = "runoff", label = "Clock runs between plays", min = 0, max = 40, step = 1, def = 18, unit = "s", note = "after a play that ends in bounds"},
	{key = "snapDelay", label = "Computer snaps the ball after", min = 1, max = 10, step = 0.25, def = 3.5, unit = "s", note = "time to pick and move your defender"},
	{key = "deadTime", label = "Pause after the whistle", min = 0.5, max = 5, step = 0.1, def = 1.8, unit = "s"},
	{key = "seasonGames", label = "Season games", min = 1, max = 14, step = 1, def = 7, note = "7 = everyone plays everyone once; then the top two meet in the North Bowl"},
	{key = "shake", label = "Screen shake on big hits", min = 0, max = 3, step = 0.1, def = 1, unit = "×"},
	{key = "vibrate", label = "Vibrate on tackles", type = "bool", def = true},
	{key = "sfxVolume", label = "Sound effects volume", min = 0, max = 1, step = 0.05, def = 0.6, pct = true},
	{key = "musicVolume", label = "Music volume", min = 0, max = 1, step = 0.05, def = 0.25, pct = true},
	{key = "crowdVolume", label = "Crowd volume", min = 0, max = 1, step = 0.05, def = 0.35, pct = true},
	{group = "CONTROLS"},
	{key = "swapSides", label = "Throw / juke / tackle with the right side, run with the left", type = "bool", def = false},
	{key = "stickSize", label = "Move stick size", min = 30, max = 220, step = 5, def = 60, unit = "px"},
	{key = "stickDeadzone", label = "Move stick dead zone", min = 0, max = 0.5, step = 0.01, def = 0.08, pct = true},
	{key = "tapSlop", label = "Tap tolerance", min = 2, max = 40, step = 1, def = 12, unit = "px", note = "moves smaller than this are taps"},
	{key = "dragFull", label = "Pull length for the longest throw", min = 0.1, max = 0.8, step = 0.01, def = 0.32, pct = true, note = "share of the screen height"},
	{key = "minPull", label = "Shorter pulls cancel the throw", min = 0, max = 0.5, step = 0.01, def = 0.08, pct = true, note = "share of the longest pull"},
	{key = "aimAssist", label = "Aim assist", min = 0, max = 1, step = 0.05, def = 0.85, pct = true, note = "pulls your throw toward the receiver nearest where you aim, and leads him"},
	{key = "aimAssistRange", label = "Aim assist reach", min = 1, max = 15, step = 0.5, def = 7, unit = "yd"},
	{key = "aimDots", label = "Throw preview dots", min = 0, max = 40, step = 1, def = 14, note = "0 = no preview"},
	{key = "flickMin", label = "Flick length for a juke or dive", min = 5, max = 80, step = 1, def = 18, unit = "px"},
	{key = "autoSwitch", label = "Switch to the defender nearest the ball", type = "choice", def = "throw", options = {"never": "Never", "throw": "When the ball is thrown", "always": "On every catch or handoff too"}},
	{key = "fieldView", label = "Field view", type = "choice", def = "sidelines", options = {"sidelines": "Whole field (both sidelines)", "zoom": "Zoomed in"}, note = "whole field: zoomed out to show the field from sideline to sideline"},
	{key = "fieldZoom", label = "Zoomed in: yards across the screen", min = 18, max = 60, step = 1, def = 34, unit = "yd"},
	{key = "fieldTilt", label = "Field tilt", min = 0.35, max = 1, step = 0.01, def = 0.55, note = "how flat the field looks: lower is flatter (and fits more when zoomed out)"},
	{key = "playerScale", label = "Player size (zoomed in)", min = 0.3, max = 1.5, step = 0.01, def = 0.62, unit = "×"},
	{key = "playerScaleWide", label = "Player size (whole field)", min = 0.3, max = 2, step = 0.01, def = 0.85, unit = "×", note = "players drawn bigger than life, like the old games"},
	{group = "PLAYERS"},
	{key = "runSpeed", label = "Run speed", min = 0.4, max = 2, step = 0.05, def = 1, unit = "×", note = "everyone"},
	{key = "accel", label = "Acceleration", min = 4, max = 60, step = 1, def = 20, unit = "yd/s²"},
	{key = "userSpeed", label = "Your player's speed boost", min = 0.8, max = 1.5, step = 0.01, def = 1.04, unit = "×"},
	{key = "carrySpeed", label = "Speed with the ball", min = 0.6, max = 1.2, step = 0.01, def = 0.93, unit = "×"},
	{key = "pursuit", label = "Computer tacklers' pursuit speed", min = 0.7, max = 1.4, step = 0.01, def = 1.06, unit = "×", note = "chasing the ball carrier"},
	{key = "jukeTime", label = "Juke: how long the cut lasts", min = 0.1, max = 1, step = 0.05, def = 0.3, unit = "s"},
	{key = "jukeBurst", label = "Juke: burst speed", min = 1, max = 3, step = 0.05, def = 1.5, unit = "×"},
	{key = "jukeEvade", label = "Juke: tackles missed during the cut", min = 0, max = 1, step = 0.05, def = 0.7, pct = true},
	{key = "jukeFool", label = "Juke: chance nearby tacklers stumble", min = 0, max = 1, step = 0.05, def = 0.45, pct = true},
	{key = "jukeCooldown", label = "Juke: wait before the next one", min = 0, max = 3, step = 0.05, def = 0.8, unit = "s"},
	{key = "diveTime", label = "Dive tackle: how long the lunge lasts", min = 0.1, max = 1, step = 0.05, def = 0.35, unit = "s"},
	{key = "diveBurst", label = "Dive tackle: lunge speed", min = 1, max = 3, step = 0.05, def = 1.6, unit = "×"},
	{key = "diveReach", label = "Dive tackle: reach", min = 0.5, max = 3, step = 0.05, def = 1.6, unit = "yd"},
	{key = "diveDown", label = "Dive tackle: time on the ground after", min = 0, max = 3, step = 0.05, def = 0.9, unit = "s"},
	{key = "tackleReach", label = "Tackle reach", min = 0.3, max = 2, step = 0.05, def = 0.95, unit = "yd"},
	{key = "tackleBase", label = "Tackle chance (even matchup)", min = 0, max = 1, step = 0.01, def = 0.72, pct = true},
	{key = "tackleRating", label = "How much ratings change tackle chance", min = 0, max = 2, step = 0.05, def = 0.6},
	{key = "diveBonus", label = "Extra tackle chance on a dive", min = 0, max = 1, step = 0.01, def = 0.25, pct = true},
	{key = "missStun", label = "Stumble after a missed tackle", min = 0, max = 2, step = 0.05, def = 0.7, unit = "s"},
	{key = "blockHold", label = "How long blocks hold", min = 0.2, max = 4, step = 0.05, def = 1, unit = "×"},
	{key = "blockReach", label = "Blocking reach", min = 0.4, max = 2, step = 0.05, def = 1, unit = "yd"},
	{group = "PASSING"},
	{key = "passSpeed", label = "Pass speed", min = 8, max = 40, step = 0.5, def = 22, unit = "yd/s", note = "at an average arm"},
	{key = "maxThrow", label = "Longest throw", min = 20, max = 80, step = 1, def = 55, unit = "yd"},
	{key = "passArc", label = "Pass arc height", min = 0, max = 0.4, step = 0.01, def = 0.12, unit = "per yd"},
	{key = "passScatter", label = "Pass inaccuracy", min = 0, max = 3, step = 0.05, def = 1, unit = "×"},
	{key = "catchReach", label = "Catch reach", min = 0.4, max = 3, step = 0.05, def = 1.35, unit = "yd"},
	{key = "catchBase", label = "Catch chance (open receiver)", min = 0, max = 1, step = 0.01, def = 0.8, pct = true, note = "plus his hands rating"},
	{key = "coverPenalty", label = "Catch chance lost with a defender on him", min = 0, max = 1, step = 0.01, def = 0.55, pct = true},
	{key = "intChance", label = "Interception chance for a defender at the ball", min = 0, max = 1, step = 0.01, def = 0.35, pct = true},
	{key = "aiThrowOpen", label = "Computer QB throws when a man is this open", min = 0.5, max = 10, step = 0.25, def = 3.5, unit = "yd"},
	{key = "aiThrowBy", label = "Computer QB throws by", min = 1, max = 8, step = 0.1, def = 3.2, unit = "s", note = "after the snap"},
	{group = "KICKING"},
	{key = "puntDistance", label = "Average punt", min = 20, max = 70, step = 1, def = 42, unit = "yd"},
	{key = "fgRange", label = "Field goal: sure thing up to", min = 10, max = 50, step = 1, def = 28, unit = "yd"},
	{key = "fgFalloff", label = "Field goal: chance lost per yard beyond that", min = 0, max = 0.1, step = 0.001, def = 0.019, pct = true},
	{key = "patChance", label = "Extra point chance", min = 0, max = 1, step = 0.01, def = 0.96, pct = true},
	{key = "touchback", label = "Ball after a kickoff", min = 1, max = 50, step = 1, def = 25, unit = "yd line"},
	{group = "COMPUTER"},
	{key = "aiEasy", label = "Rookie: computer ratings", min = -0.4, max = 0, step = 0.01, def = -0.12},
	{key = "aiHard", label = "All-Pro: computer ratings", min = 0, max = 0.4, step = 0.01, def = 0.1},
	{key = "aiJuke", label = "Computer runners juke", min = 0, max = 1, step = 0.05, def = 0.2, pct = true, note = "chance when a tackler closes in"},
	{key = "aiGoFor4th", label = "Computer goes for it on 4th and", min = 0, max = 5, step = 0.5, def = 1.5, unit = "yd or less", note = "past midfield"},
	{key = "simScore", label = "Other games: average points", min = 7, max = 40, step = 1, def = 20},
]

## The settings players see. Everything else is a developer setting: hidden
## and fixed at its default unless developer mode is on. Developer mode is
## always on in the sideload APK (export feature "dev_build"), never in the
## store builds ("play_store", "app_store"), and toggled by tapping the title 7 times
## anywhere else (the editor, desktop).
const PLAYER_KEYS := ["difficulty", "quarterMinutes", "sfxVolume", "musicVolume", "crowdVolume", "vibrate", "shake", "swapSides", "stickSize", "autoSwitch", "fieldView", "fieldZoom"]

## Developer mode: every setting is shown and saved changes to them apply.
static var dev := false

## The default settings, editable without touching code. Every value in it
## replaces the `def` above; settings missing from it keep `def`.
const DEFAULTS_PATH := "res://default_settings.cfg"
static var _file_defaults := {}

## The current values, by key. Read as `Tune.v.gravity`.
static var v := {}
static var _loaded := false


static func items() -> Array:
	return ITEMS


static func ensure() -> void:
	if not _loaded:
		load_values()


## The sideload APK: every developer setting, always.
static func is_dev_build() -> bool:
	return OS.has_feature("dev_build")


## A store build (Google Play or the App Store): only the player settings,
## never developer mode.
static func is_store_build() -> bool:
	return OS.has_feature("play_store") or OS.has_feature("app_store")


## Whether developer mode can be switched on and off (tapping the title).
static func can_toggle_dev() -> bool:
	return not is_dev_build() and not is_store_build()


## A setting's default: from default_settings.cfg if it's there, else `def`.
static func def_of(t: Dictionary):
	return _file_defaults.get(t.key, t.def)


## Reads default_settings.cfg. Returns the keys in it that aren't settings.
static func load_defaults_file(path := DEFAULTS_PATH) -> Array:
	_file_defaults.clear()
	var unknown := []
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section("defaults"):
		return unknown
	var by_key := {}
	for t in ITEMS:
		if t.has("key"):
			by_key[t.key] = t
	for key in cfg.get_section_keys("defaults"):
		if not by_key.has(key):
			unknown.append(key)
			continue
		var t: Dictionary = by_key[key]
		var value = cfg.get_value("defaults", key)
		if t.get("type", "") == "" and typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			unknown.append(key)
			continue
		_file_defaults[key] = _norm(t, value)
	return unknown


## Every setting as default_settings.cfg text, with the current values:
## paste it over that file to make them the defaults.
static func defaults_text() -> String:
	var lines := [
		"; Gridiron North: default settings.",
		";",
		"; Every value here is the setting's default: what a new player gets, and",
		"; what RESET puts it back to. Change a number, save, and the next build",
		"; uses it. A setting left out of this file uses the default in",
		"; scripts/tune.gd. Values outside a setting's range are clamped.",
		";",
		"; Tip: tune the game on your phone in the APK (developer settings), then",
		"; tap COPY AS DEFAULTS in the settings and paste over this whole file.",
		"",
		"[defaults]",
	]
	for t in ITEMS:
		if not t.has("key"):
			lines.append("")
			lines.append("; ---------- %s ----------" % t.group)
			continue
		var about: String = t.label
		match t.get("type", ""):
			"bool":
				about += " (true / false)"
			"choice":
				about += " (%s)" % ", ".join(t.options.keys().map(func(o): return "\"%s\"" % o))
			_:
				if t.get("pct", false):
					about += " (%s to %s, as a fraction: 0.01 = 1%%)" % [_num(t.min), _num(t.max)]
				else:
					about += " (%s to %s%s)" % [_num(t.min), _num(t.max), " " + t.unit if t.has("unit") else ""]
		if t.has("note"):
			about += ": " + t.note
		lines.append("; " + about)
		var val = v.get(t.key, def_of(t))
		var text := ""
		match t.get("type", ""):
			"bool":
				text = "true" if val else "false"
			"choice":
				text = "\"%s\"" % val
			_:
				text = _num(val)
		lines.append("%s=%s" % [t.key, text])
	return "\n".join(lines) + "\n"


static func _num(x) -> String:
	var f := float(x)
	if is_equal_approx(f, roundf(f)):
		return str(int(roundf(f)))
	return str(snappedf(f, 0.0001))


static func reset() -> void:
	for t in ITEMS:
		if t.has("key"):
			v[t.key] = _norm(t, def_of(t))


static func _norm(t: Dictionary, value):
	match t.get("type", ""):
		"bool":
			return bool(value)
		"choice":
			return str(value) if t.options.has(str(value)) else str(t.def)
		_:
			return clampf(float(value), float(t.min), float(t.max))


static func load_values() -> void:
	_loaded = true
	load_defaults_file()
	reset()
	dev = is_dev_build()
	if not FileAccess.file_exists(PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) == TYPE_DICTIONARY:
		apply_saved(data)


## Applies saved values (as stored by save()).
static func apply_saved(data: Dictionary) -> void:
	reset()
	dev = is_dev_build() or (can_toggle_dev() and bool(data.get("_dev", false)))
	for t in ITEMS:
		# Outside developer mode, only the player settings are taken from the save.
		if t.has("key") and data.has(t.key) and (dev or t.key in PLAYER_KEYS):
			var value = data[t.key]
			var old_defs = data.get("_defaults", {})
			if typeof(old_defs) == TYPE_DICTIONARY and old_defs.has(t.key) and str(old_defs[t.key]) == str(value):
				continue
			if t.get("type", "") == "" and typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
				continue
			v[t.key] = _norm(t, value)


static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		var data := v.duplicate()
		data["_dev"] = dev
		# The defaults at the time, so values never changed from them follow
		# new defaults in a later version.
		var defs := {}
		for t in ITEMS:
			if t.has("key"):
				defs[t.key] = _norm(t, def_of(t))
		data["_defaults"] = defs
		f.store_string(JSON.stringify(data))


## Turns developer mode on or off. Turning it off puts every developer
## setting back to its default.
static func set_dev(on: bool) -> void:
	if not can_toggle_dev():
		return
	dev = on
	if not on:
		for t in ITEMS:
			if t.has("key") and t.key not in PLAYER_KEYS:
				v[t.key] = _norm(t, def_of(t))
	save()


## The items the settings screen shows right now.
static func visible_items() -> Array:
	if dev:
		return ITEMS
	return ITEMS.filter(func(t): return t.has("key") and t.key in PLAYER_KEYS)


static func is_default(t: Dictionary) -> bool:
	var d = _norm(t, def_of(t))
	if typeof(d) == TYPE_FLOAT:
		return is_equal_approx(float(v[t.key]), d)
	return v[t.key] == d
