## The league's eight teams (made-up names, in the colors of the AFC North
## and NFC North cities), the team strength types, and the rosters: every
## player's ratings come from their position, the team's type and a little
## luck.
class_name Teams

## jersey: home uniform; helmet: helmet color; trim: lettering and end zone
## text. Away teams wear white with their own helmets.
const TEAMS := [
	{key = "bal", city = "Baltimore", name = "Talons", abbr = "BAL", div = "AFC North", jersey = "#3d2177", helmet = "#1b1b22", trim = "#c9a227"},
	{key = "cin", city = "Cincinnati", name = "Blaze", abbr = "CIN", div = "AFC North", jersey = "#f05a1a", helmet = "#1b1b1b", trim = "#ffffff"},
	{key = "cle", city = "Cleveland", name = "Hounds", abbr = "CLE", div = "AFC North", jersey = "#4b2a17", helmet = "#f26a21", trim = "#ffffff"},
	{key = "pit", city = "Pittsburgh", name = "Forge", abbr = "PIT", div = "AFC North", jersey = "#202020", helmet = "#ffb612", trim = "#ffb612"},
	{key = "chi", city = "Chicago", name = "Gales", abbr = "CHI", div = "NFC North", jersey = "#0d1e3c", helmet = "#0d1e3c", trim = "#e8601c"},
	{key = "det", city = "Detroit", name = "Motors", abbr = "DET", div = "NFC North", jersey = "#0076b6", helmet = "#b0b7bc", trim = "#ffffff"},
	{key = "gb", city = "Green Bay", name = "Lumberjacks", abbr = "GB", div = "NFC North", jersey = "#203731", helmet = "#ffb612", trim = "#ffb612"},
	{key = "min", city = "Minnesota", name = "Loons", abbr = "MIN", div = "NFC North", jersey = "#4f2683", helmet = "#4f2683", trim = "#ffc62f"},
]

const AWAY_JERSEY := "#f2f2f2"

## Strength types: how each position group compares with an average team,
## and how often the computer calls a run.
const TYPES := {
	"smashmouth": {label = "Smashmouth", about = "Power running behind a big line. Hard to stop on the ground, plain through the air.",
		run = 0.68, mod = {qb = -0.08, rb = 0.2, rec = -0.08, ol = 0.18, dl = 0.05, lb = 0.06, db = -0.04, k = 0.0}},
	"run_gun": {label = "Run & Gun", about = "A quick quarterback who runs and throws, with fast backs and receivers. The defense gives up yards.",
		run = 0.5, mod = {qb = 0.14, rb = 0.12, rec = 0.12, ol = 0.0, dl = -0.06, lb = -0.06, db = -0.04, k = 0.0}},
	"air_raid": {label = "Air Raid", about = "A big arm and sure-handed receivers. Throws all day; the running game and defense are thin.",
		run = 0.28, mod = {qb = 0.22, rb = -0.1, rec = 0.2, ol = 0.04, dl = -0.08, lb = -0.08, db = -0.06, k = 0.05}},
	"balanced": {label = "Balanced", about = "Solid everywhere and weak nowhere.",
		run = 0.5, mod = {qb = 0.05, rb = 0.05, rec = 0.05, ol = 0.05, dl = 0.05, lb = 0.05, db = 0.05, k = 0.05}},
	"strong_d": {label = "Strong Defense", about = "A defense that hits hard and covers everyone. The offense just has to not lose the game.",
		run = 0.55, mod = {qb = -0.07, rb = -0.03, rec = -0.06, ol = -0.03, dl = 0.2, lb = 0.2, db = 0.2, k = 0.05}},
	"tank": {label = "Tank for the Draft", about = "Slow, small and unlucky everywhere. Winning with this team is the real challenge.",
		run = 0.5, mod = {qb = -0.2, rb = -0.2, rec = -0.2, ol = -0.2, dl = -0.2, lb = -0.2, db = -0.2, k = -0.15}},
}

## Base ratings by position (0..1), before the team type and luck.
const BASE := {
	QB = {spd = 0.42, pwr = 0.4, tck = 0.2, hands = 0.5, cov = 0.1, arm = 0.6, acc = 0.6},
	RB = {spd = 0.7, pwr = 0.6, tck = 0.25, hands = 0.5, cov = 0.1},
	FB = {spd = 0.45, pwr = 0.75, tck = 0.3, hands = 0.45, cov = 0.1},
	TE = {spd = 0.52, pwr = 0.65, tck = 0.3, hands = 0.62, cov = 0.1},
	WR = {spd = 0.78, pwr = 0.35, tck = 0.2, hands = 0.7, cov = 0.1},
	OL = {spd = 0.15, pwr = 0.7, tck = 0.2, hands = 0.2, cov = 0.1},
	DL = {spd = 0.32, pwr = 0.7, tck = 0.65, hands = 0.25, cov = 0.2},
	LB = {spd = 0.52, pwr = 0.55, tck = 0.7, hands = 0.4, cov = 0.48},
	CB = {spd = 0.78, pwr = 0.3, tck = 0.45, hands = 0.48, cov = 0.66},
	S = {spd = 0.7, pwr = 0.42, tck = 0.6, hands = 0.48, cov = 0.6},
}
const GROUP := {QB = "qb", RB = "rb", FB = "rb", TE = "rec", WR = "rec", OL = "ol", DL = "dl", LB = "lb", CB = "db", S = "db"}

## Who suits up: the offense (one formation uses the FB, the others a third WR)
## and the defense.
const OFFENSE := ["QB", "RB", "FB", "TE", "WR", "WR", "WR", "OL", "OL", "OL", "OL", "OL"]
const DEFENSE := ["DL", "DL", "DL", "DL", "LB", "LB", "LB", "CB", "CB", "S", "S"]
const NUMBERS := {QB = [7, 12, 4, 9], RB = [22, 28, 32, 26], FB = [44, 38], TE = [85, 88, 87], WR = [80, 11, 84, 81, 18, 13, 83],
	OL = [72, 65, 74, 77, 66, 70, 61, 76], DL = [91, 95, 99, 93, 97, 90], LB = [52, 55, 54, 50, 56], CB = [24, 21, 23, 29], S = [20, 31, 33, 25]}


static func info(i: int) -> Dictionary:
	return TEAMS[clampi(i, 0, TEAMS.size() - 1)]


static func full_name(i: int) -> String:
	var t := info(i)
	return "%s %s" % [t.city, t.name]


## A team for one game: colors, type and a roster with ratings. The same
## seed always gives the same players.
static func make(i: int, type: String, home: bool, seed_value := 0) -> Dictionary:
	var t := info(i).duplicate()
	var ty: Dictionary = TYPES.get(type, TYPES.balanced)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%s/%d" % [t.key, type, seed_value])
	t.index = i
	t.type = type
	t.type_label = ty.label
	t.run_rate = ty.run
	t.home = home
	t.jersey_color = Color(t.jersey) if home else Color(AWAY_JERSEY)
	t.helmet_color = Color(t.helmet)
	t.trim_color = Color(t.trim)
	t.kick = clampf(0.6 + ty.mod.k + rng.randf_range(-0.08, 0.08), 0.15, 0.98)
	var used := {}
	t.offense = []
	for role in OFFENSE:
		t.offense.append(_player(role, ty.mod, rng, used))
	t.defense = []
	for role in DEFENSE:
		t.defense.append(_player(role, ty.mod, rng, used))
	return t


static func _player(role: String, mod: Dictionary, rng: RandomNumberGenerator, used: Dictionary) -> Dictionary:
	var base: Dictionary = BASE[role]
	var bonus: float = mod[GROUP[role]]
	var p := {role = role, skin = "dark" if rng.randf() < 0.55 else "light"}
	for k in ["spd", "pwr", "tck", "hands", "cov", "arm", "acc"]:
		p[k] = clampf(float(base.get(k, 0.4)) + bonus + rng.randf_range(-0.06, 0.06), 0.05, 0.98)
	var nums: Array = NUMBERS[role]
	var n: int = nums[0]
	for c in nums:
		if not used.has(c):
			n = c
			break
	used[n] = true
	p.num = n
	return p


## How strong a team is overall (0..1), for simulating the other games.
static func strength(team: Dictionary) -> Dictionary:
	var off := 0.0
	for p in team.offense:
		off += p.spd + p.pwr + p.hands + p.get("arm", 0.0) * 0.5
	var def := 0.0
	for p in team.defense:
		def += p.spd + p.pwr + p.tck + p.cov
	return {off = off / (team.offense.size() * 3.0), def = def / (team.defense.size() * 4.0)}
