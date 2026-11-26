## The season: your team and its strength type, the schedule (everyone plays
## everyone once, then the top two meet in the North Bowl), the results and
## the standings. Saved on the device.
class_name League

const PATH := "user://season.json"

static var data := {}


static func fresh() -> Dictionary:
	return {active = false, team = 0, type = "balanced", types = [], week = 0, schedule = [], results = [], bowl = {}, champion = -1, seed = 0}


static func load_data() -> void:
	data = fresh()
	if not FileAccess.file_exists(PATH):
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for key in data:
		if raw.has(key) and typeof(raw[key]) == typeof(data[key]):
			data[key] = raw[key]
	for key in ["team", "week", "champion", "seed"]:
		data[key] = int(data[key])
	if data.types.size() != Teams.TEAMS.size():
		data.active = false


static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


## A new season for `team`, playing as `type`. The other teams get types
## of their own.
static func new_season(team: int, type: String, seed_value := 0) -> void:
	Tune.ensure()
	data = fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else randi()
	data.seed = rng.randi() % 100000 + 1
	data.active = true
	data.team = team
	data.type = type
	var pool := Teams.TYPES.keys().filter(func(t): return t != "tank")
	for i in Teams.TEAMS.size():
		data.types.append(type if i == team else pool[rng.randi() % pool.size()])
	data.schedule = schedule(Teams.TEAMS.size(), int(Tune.v.seasonGames), rng)
	save()


## Round robin by the circle method: n-1 weeks with every team playing once
## a week. More weeks than that repeat it with home and away swapped.
static func schedule(n: int, weeks: int, rng: RandomNumberGenerator) -> Array:
	var ids := range(n)
	var rounds := []
	for r in n - 1:
		var week := []
		for i in n / 2:
			var a: int = ids[i]
			var b: int = ids[n - 1 - i]
			week.append([a, b] if (r + i) % 2 == 0 else [b, a])
		rounds.append(week)
		# Keep the first team fixed, turn the rest.
		var last: int = ids.pop_back()
		ids.insert(1, last)
	var order := range(rounds.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var out := []
	for w in weeks:
		var base: Array = rounds[order[w % rounds.size()]]
		if (w / rounds.size()) % 2 == 1:
			base = base.map(func(m): return [m[1], m[0]])
		out.append(base)
	return out


static func weeks() -> int:
	return data.schedule.size()


static func in_regular_season() -> bool:
	return data.active and data.week < weeks()


static func season_over() -> bool:
	return data.active and data.champion >= 0


## This week's game for you: [home, away], or the North Bowl, or [].
static func next_game() -> Array:
	if not data.active or data.champion >= 0:
		return []
	if data.week < weeks():
		for m in data.schedule[data.week]:
			if int(m[0]) == data.team or int(m[1]) == data.team:
				return [int(m[0]), int(m[1])]
		return []
	var b: Dictionary = data.bowl
	if b.is_empty():
		_make_bowl()
		b = data.bowl
	if int(b.home) == data.team or int(b.away) == data.team:
		return [int(b.home), int(b.away)]
	return []


static func is_bowl() -> bool:
	return data.active and data.week >= weeks() and data.champion < 0


static func _make_bowl() -> void:
	var st := standings()
	data.bowl = {home = st[0].team, away = st[1].team}


static func type_of(team: int) -> String:
	return data.types[team] if team < data.types.size() else "balanced"


## Records your game, plays out the rest of the week, and moves on.
static func record(home: int, away: int, hs: int, as_: int) -> void:
	if is_bowl():
		data.bowl.hs = hs
		data.bowl.as_ = as_
		data.champion = home if hs > as_ else away
		save()
		return
	data.results.append({week = data.week, home = home, away = away, hs = hs, as_ = as_})
	for m in data.schedule[data.week]:
		var h := int(m[0])
		var a := int(m[1])
		if h == home and a == away:
			continue
		var s := sim(h, a)
		data.results.append({week = data.week, home = h, away = a, hs = s[0], as_ = s[1]})
	data.week += 1
	if data.week >= weeks():
		_make_bowl()
		# You're not in it: it's played without you.
		if int(data.bowl.home) != data.team and int(data.bowl.away) != data.team:
			var s := sim(int(data.bowl.home), int(data.bowl.away), true)
			data.bowl.hs = s[0]
			data.bowl.as_ = s[1]
			data.champion = int(data.bowl.home) if s[0] > s[1] else int(data.bowl.away)
	save()


## A score for a game nobody watched, from the teams' strengths.
static func sim(home: int, away: int, no_tie := false) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([data.seed, data.week, home, away])
	var th := Teams.make(home, type_of(home), true, data.seed)
	var ta := Teams.make(away, type_of(away), false, data.seed)
	var sh := Teams.strength(th)
	var sa := Teams.strength(ta)
	var avg: float = Tune.v.simScore
	var hp := _points(avg * clampf(1.0 + (sh.off - sa.def) * 1.5, 0.4, 1.8) + 1.5, rng)
	var ap := _points(avg * clampf(1.0 + (sa.off - sh.def) * 1.5, 0.4, 1.8), rng)
	if hp == ap and (no_tie or rng.randf() < 0.8):
		if rng.randf() < 0.5:
			hp += 3
		else:
			ap += 3
	return [hp, ap]


## Football-shaped points: touchdowns and field goals.
static func _points(mean: float, rng: RandomNumberGenerator) -> int:
	var pts := 0
	var target := maxf(0.0, rng.randfn(mean, mean * 0.35))
	while pts < target - 2.0:
		pts += 7 if rng.randf() < 0.62 else 3
	return pts


## Every team's record, best first: [{team, w, l, t, pf, pa}].
static func standings() -> Array:
	var rows := []
	for i in Teams.TEAMS.size():
		rows.append({team = i, w = 0, l = 0, t = 0, pf = 0, pa = 0})
	for r in data.results:
		var h: Dictionary = rows[int(r.home)]
		var a: Dictionary = rows[int(r.away)]
		h.pf += int(r.hs)
		h.pa += int(r.as_)
		a.pf += int(r.as_)
		a.pa += int(r.hs)
		if r.hs > r.as_:
			h.w += 1
			a.l += 1
		elif r.hs < r.as_:
			a.w += 1
			h.l += 1
		else:
			h.t += 1
			a.t += 1
	rows.sort_custom(func(x, y):
		var px: float = x.w + x.t * 0.5
		var py: float = y.w + y.t * 0.5
		if px != py:
			return px > py
		if x.pf - x.pa != y.pf - y.pa:
			return x.pf - x.pa > y.pf - y.pa
		return x.team < y.team)
	return rows


static func record_text(team: int) -> String:
	for r in standings():
		if r.team == team:
			return "%d-%d" % [r.w, r.l] + ("-%d" % r.t if r.t > 0 else "")
	return "0-0"
