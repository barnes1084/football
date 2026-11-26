## One football game: the rules, the clock, all 22 players and the
## computer's play. Pure logic, no drawing: the field draws it, main feeds it
## the person's input, and the tests run it headless.
##
## Field coordinates are in yards: x along the field (0 and 100 are the goal
## lines, the end zones run to -10 and 110), y across it (0 is the far
## sideline at the top of the screen, 53.3 the near one). Each team attacks
## one way (`dir`), and they switch at halftime. Yard lines (`los`) are
## counted from the offense's own goal line.
class_name Game
extends RefCounted

const FIELD_W := 53.33
const HASH_TOP := 23.58
const HASH_BOT := 29.75
const MID_Y := 26.67


class P:
	var id := 0
	var team := 0
	var role := ""
	var slot := ""
	var num := 0
	var skin := "light"
	var at := Vector2.ZERO
	var vel := Vector2.ZERO
	var face := 1
	var spd := 0.5
	var pwr := 0.5
	var tck := 0.5
	var hands := 0.5
	var cov := 0.5
	var arm := 0.5
	var acc := 0.5
	## This play: "qb", "carry", "route", "block", "lead", "rush", "man", "zone", "deep".
	var job := ""
	var route: Array = []
	var route_i := 0
	var route_go := false
	var man: P = null
	var zone := Vector2.ZERO
	var target: P = null
	var tgt := Vector2.ZERO
	var engaged: P = null
	var shed := 0.0
	var free := 0.0
	var stun := 0.0
	var down := 0.0
	var dive := 0.0
	var dive_dir := Vector2.ZERO
	var juke := 0.0
	var juke_dir := Vector2.ZERO
	var juke_cd := 0.0
	var tried := 0.0
	var think := 0.0
	var catch_tried := false
	## The person has steered this player (until then the computer runs him).
	var took := false
	## A one-off action for the drawing: "throw", "catch", "juke", "stiff", "tackled", "tackler", "td".
	var act := ""
	var act_t := 0.0
	var dist := 0.0

	func set_act(a: String) -> void:
		act = a
		act_t = 0.0


var teams := []
## The team the person plays: 0 (home), 1 (away) or -1 (computer vs computer).
var user := 0
var players: Array = []
var carrier: P = null
var qb: P = null
var controlled: P = null
var user_slot := "LB2"
var aiming := false

## "call" (picking plays), "presnap", "live", "dead" (after the whistle),
## "kick" (a punt or field goal in the air) or "final".
var phase := "call"
var phase_t := 0.0
var t := 0.0
var poss := 0
var dir := [1, -1]
var los := 25.0
var down := 1
var togo := 10.0
var ball_y := MID_Y
var score := [0, 0]
var quarter := 1
var clock := 240.0
var first_receiver := 0
var playoff := false
var off_call := {}
var def_call := {}
var handed := false
var past_los := false
var ball := {}
var throw_t := -1.0
var mode_t := 0.0
var kick := {}
var msg := ""
var sub := ""
var msg_t := 0.0
var flag := ""
var events := []
var stats := [{pass_yds = 0, rush_yds = 0, to = 0, sacks = 0, first = 0}, {pass_yds = 0, rush_yds = 0, to = 0, sacks = 0, first = 0}]
var rng := RandomNumberGenerator.new()
var _dt := 0.0
var _next := {}
var plays := 0
## The last play, for the tests and the balance probe.
var last := {}


func _init(home: int, home_type: String, away: int, away_type: String, user_team := 0, seed_value := 0) -> void:
	Tune.ensure()
	rng.seed = seed_value if seed_value != 0 else randi()
	teams = [Teams.make(home, home_type, true, seed_value), Teams.make(away, away_type, false, seed_value)]
	user = user_team
	for i in 2:
		if i != user:
			_shift_ratings(teams[i], _ai_bonus())
	clock = Tune.v.quarterMinutes * 60.0
	first_receiver = rng.randi() % 2
	dir = [1, -1]
	_kickoff(first_receiver, "KICKOFF", "")


func _ai_bonus() -> float:
	match Tune.v.difficulty:
		"easy":
			return Tune.v.aiEasy
		"hard":
			return Tune.v.aiHard
	return 0.0


static func _shift_ratings(team: Dictionary, by: float) -> void:
	if by == 0.0:
		return
	for p in team.offense + team.defense:
		for k in ["spd", "pwr", "tck", "hands", "cov", "arm", "acc"]:
			p[k] = clampf(p[k] + by, 0.03, 0.99)


# ---------- Helpers ----------

## Field x of a yard line, for a team.
func fx(team: int, yl: float) -> float:
	return yl if dir[team] > 0 else 100.0 - yl


## A field x as a yard line, for a team.
func yard(team: int, x: float) -> float:
	return x if dir[team] > 0 else 100.0 - x


func los_x() -> float:
	return fx(poss, los)


func first_down_x() -> float:
	return fx(poss, minf(100.0, los + togo))


func offense() -> Array:
	return players.filter(func(p): return p.team == poss)


func defense() -> Array:
	return players.filter(func(p): return p.team != poss)


func team_of(p: P) -> Dictionary:
	return teams[p.team]


## Which team has the ball right now (the thrower's while it's in the air).
func ball_team() -> int:
	return carrier.team if carrier != null else poss


func ball_pos() -> Vector3:
	if phase == "kick" and not kick.is_empty():
		var s := clampf(kick.t / kick.dur, 0.0, 1.0)
		var g: Vector2 = kick.from.lerp(kick.to, s)
		return Vector3(g.x, g.y, 0.5 + 4.0 * kick.h * s * (1.0 - s))
	if not ball.is_empty():
		var g := _ball_ground()
		return Vector3(g.x, g.y, _ball_z())
	if phase == "presnap":
		return Vector3(los_x() - dir[poss] * 0.2, ball_y, 0.2)
	if carrier != null:
		return Vector3(carrier.at.x + carrier.face * 0.3, carrier.at.y, 1.1)
	return Vector3(los_x(), ball_y, 0.2)


func _ball_s() -> float:
	return clampf((t - ball.t0) / ball.dur, 0.0, 1.2)


func _ball_ground() -> Vector2:
	var s := _ball_s()
	return ball.from.lerp(ball.to, s)


func _ball_z() -> float:
	var s := _ball_s()
	return lerpf(2.0, 1.0, s) + 4.0 * ball.h * s * (1.0 - s) - maxf(0.0, s - 1.0) * 8.0


func _speed(p: P) -> float:
	var s: float = (5.6 + p.spd * 3.6) * Tune.v.runSpeed
	if p == carrier:
		s *= Tune.v.carrySpeed
	if p == controlled:
		s *= Tune.v.userSpeed
	if carrier != null and p.team != carrier.team and p != controlled:
		s *= Tune.v.pursuit
	if p.stun > 0:
		s *= 0.3
	return s


func _seek(p: P, to: Vector2, frac := 1.0, slow := 0.6) -> Vector2:
	var d := to - p.at
	var l := d.length()
	if l < 0.12:
		return Vector2.ZERO
	return d / l * _speed(p) * frac * minf(1.0, l / slow)


func is_user(p: P) -> bool:
	return p != null and p.team == user


func eligible(p: P) -> bool:
	return p.role in ["WR", "TE", "RB", "FB"]


func _banner(head: String, s := "") -> void:
	msg = head
	sub = s
	msg_t = 0.0


func time_text() -> String:
	var c := maxi(0, ceili(clock))
	return "%d:%02d" % [c / 60, c % 60]


func quarter_text() -> String:
	return "OT" if quarter > 4 else ["1ST", "2ND", "3RD", "4TH"][quarter - 1]


func down_text() -> String:
	var d: String = ["1ST", "2ND", "3RD", "4TH"][clampi(down, 1, 4) - 1]
	var dist := "GOAL" if los + togo >= 100.0 else str(maxi(1, roundi(togo)))
	return "%s & %s" % [d, dist]


func spot_text(team: int, yl: float) -> String:
	var y := roundi(yl)
	if y == 50:
		return "the 50"
	if y < 50:
		return "own %d" % y
	return "%s %d" % [teams[1 - team].abbr, 100 - y]


# ---------- Play calling ----------

## For tests and screenshots: `team` has the ball at its own `yl`, 1st & 10.
func give_ball(team: int, yl: float) -> void:
	poss = team
	los = yl
	down = 1
	togo = 10.0
	ball_y = MID_Y
	msg = ""
	sub = ""
	_next = {}
	_to_call()


## What the person has to pick now: "offense", "defense" or "".
func needs_call() -> String:
	if phase != "call" or user < 0:
		return ""
	if user == poss and off_call.is_empty():
		return "offense"
	if user != poss and def_call.is_empty():
		return "defense"
	return ""


func _to_call() -> void:
	phase = "call"
	phase_t = 0.0
	off_call = {}
	def_call = {}
	players.clear()
	carrier = null
	ball = {}
	kick = {}
	if user < 0 or poss != user:
		off_call = Playbook.play(ai_offense_call())
	if user < 0 or poss == user:
		def_call = Playbook.defense(ai_defense_call())
	_maybe_start()


func choose_offense(key: String) -> void:
	if phase == "call":
		off_call = Playbook.play(key)
		_maybe_start()


func choose_defense(key: String) -> void:
	if phase == "call":
		def_call = Playbook.defense(key)
		_maybe_start()


func _maybe_start() -> void:
	if off_call.is_empty() or def_call.is_empty():
		return
	if off_call.kind in ["punt", "fg"]:
		_start_kick()
	else:
		_setup()


func ai_offense_call() -> String:
	var team: Dictionary = teams[poss]
	var fg_dist := 100.0 - los + 17.0
	var late := quarter >= 4 and clock < 120
	var behind: bool = score[poss] < score[1 - poss]
	if down == 4:
		var go: bool = (togo <= Tune.v.aiGoFor4th and los >= 50.0) or (late and behind and score[1 - poss] - score[poss] > 3)
		if not go:
			if fg_dist <= 50.0:
				return "fg"
			return "punt"
	var run_rate: float = team.run_rate
	if togo <= 2.0:
		run_rate += 0.25
	elif togo >= 8.0 and down >= 2:
		run_rate -= 0.3
	if late and behind:
		run_rate -= 0.35
	if rng.randf() < run_rate:
		var runs := Playbook.runs().filter(func(p): return p.key != "sneak" or togo <= 1.5)
		return runs[rng.randi() % runs.size()].key
	var passes := Playbook.passes()
	return passes[rng.randi() % passes.size()].key


func ai_defense_call() -> String:
	var r := rng.randf()
	if quarter >= 4 and clock < 100 and score[1 - poss] - score[poss] >= 7:
		return "prevent" if r < 0.6 else "cover2"
	if togo <= 2.0:
		return "run_stop" if r < 0.55 else ("blitz" if r < 0.75 else "base")
	if togo >= 8.0 and down >= 2:
		return ["nickel", "cover2", "blitz", "base"][rng.randi() % 4]
	return ["base", "base", "cover2", "nickel", "blitz", "run_stop"][rng.randi() % 6]


# ---------- Lining up ----------

func _make_player(team: int, slot: Dictionary, r: Dictionary, at: Vector2) -> P:
	var p := P.new()
	p.id = players.size()
	p.team = team
	p.role = slot.role
	p.slot = slot.slot
	p.num = r.num
	p.skin = r.skin
	for k in ["spd", "pwr", "tck", "hands", "cov", "arm", "acc"]:
		p.set(k, r[k])
	p.at = Vector2(at.x, clampf(at.y, 0.8, FIELD_W - 0.8))
	p.face = dir[team] if team == poss else -dir[poss]
	p.tgt = p.at
	players.append(p)
	return p


func _setup() -> void:
	phase = "presnap"
	phase_t = 0.0
	t = 0.0
	players.clear()
	ball = {}
	kick = {}
	handed = false
	past_los = false
	aiming = false
	throw_t = -1.0
	flag = ""
	var d: int = dir[poss]
	var lx := los_x()
	var form: Array = Playbook.FORMATIONS[off_call.get("form", "single")]
	var o_team: Dictionary = teams[poss]
	var wr_i := 0
	var by_role := {}
	for r in o_team.offense:
		if not by_role.has(r.role):
			by_role[r.role] = []
		by_role[r.role].append(r)
	var ol_i := 0
	for s in form:
		var r: Dictionary
		match s.role:
			"WR":
				r = by_role.WR[wr_i]
				wr_i += 1
			"OL":
				r = by_role.OL[ol_i]
				ol_i += 1
			_:
				r = by_role[s.role][0]
		var p := _make_player(poss, s, r, Vector2(lx + s.dx * d, ball_y + s.dy * d))
		if s.role == "QB":
			qb = p
	carrier = qb
	# Defense: line up, then move the corners and safeties to the receivers.
	var de_team: Dictionary = teams[1 - poss]
	var dlist := []
	for i in Playbook.DEF_FORM.size():
		var s: Dictionary = Playbook.DEF_FORM[i]
		dlist.append(_make_player(1 - poss, s, de_team.defense[i], Vector2(lx + s.dx * d, ball_y + s.dy * d)))
	_assign_jobs()
	if user == poss:
		controlled = null
	elif user >= 0:
		controlled = null
		for p: P in dlist:
			if p.slot == user_slot:
				controlled = p
		if controlled == null:
			controlled = dlist[5]
	else:
		controlled = null
	if user != poss and user >= 0:
		_banner("", "Tap a defender to play him · don't cross the line before the snap")
	elif user == poss:
		_banner("", "Tap to hike")


func _slot(slot: String) -> P:
	for p: P in players:
		if p.slot == slot:
			return p
	return null


## Routes, blocks and coverage for the play called.
func _assign_jobs() -> void:
	var d: int = dir[poss]
	var lx := los_x()
	var off := offense()
	for p: P in off:
		p.route = []
		p.route_i = 0
		match p.role:
			"QB":
				p.job = "qb"
			"OL":
				p.job = "block"
			_:
				p.job = "block"
		if off_call.kind == "run":
			if p.role == off_call.carrier:
				p.job = "carry"
				for pt in off_call.path:
					p.route.append(Vector2(lx + pt[0] * d, ball_y + pt[1] * d))
			elif p.slot == off_call.get("lead", "") or p.role == off_call.get("lead", ""):
				p.job = "lead"
		elif off_call.kind == "pass" and p.role != "QB" and p.role != "OL":
			var rk: String = off_call.routes.get(p.slot, off_call.routes.get(p.role, "block"))
			if rk != "block" and Playbook.ROUTES.has(rk):
				p.job = "route"
				var rt: Dictionary = Playbook.ROUTES[rk]
				var side := signf(p.at.y - ball_y)
				if absf(p.at.y - ball_y) < 0.5:
					side = float(d)
				for pt in rt.pts:
					p.route.append(Vector2(p.at.x + pt[0] * d, clampf(p.at.y + pt[1] * side, 1.0, FIELD_W - 1.0)))
				p.route_go = rt.go
	# Defense.
	var call := def_call
	var rec := off.filter(func(p): return eligible(p))
	# Across the field from the offense's left to its right.
	rec.sort_custom(func(a, b): return (a.at.y - ball_y) * d < (b.at.y - ball_y) * d)
	var wrs := rec.filter(func(p): return p.role == "WR")
	var left_wr: P = wrs[0] if wrs.size() else null
	var right_wr: P = wrs[-1] if wrs.size() > 1 else null
	var others := rec.filter(func(p): return p != left_wr and p != right_wr)
	# Slot receivers first, then the tight end, then the backs.
	var order := {"WR": 0, "TE": 1, "FB": 2, "RB": 3}
	others.sort_custom(func(a, b): return order[a.role] < order[b.role])
	var cb1 := _slot("CB1")
	var cb2 := _slot("CB2")
	var s1 := _slot("S1")
	var s2 := _slot("S2")
	for p: P in defense():
		p.job = "rush" if p.role == "DL" else "zone"
		p.man = null
	var deep: int = call.deep
	if call.cover == "man":
		cb1.job = "man"
		cb1.man = left_wr
		cb2.job = "man"
		cb2.man = right_wr
		var free := []
		s2.job = "deep"
		s2.zone = Vector2(lx + 15 * d, ball_y)
		if deep >= 2:
			s1.job = "deep"
			s1.zone = Vector2(lx + 14 * d, ball_y - 10 * d)
			s2.zone = Vector2(lx + 14 * d, ball_y + 10 * d)
		else:
			free.append(s1)
		if call.get("nickel", false):
			free.push_front(_slot("LB3"))
		for slot in ["LB3", "LB1", "LB2"]:
			var lb := _slot(slot)
			if slot in call.rush:
				lb.job = "rush"
			elif lb not in free:
				free.append(lb)
		for i in others.size():
			if i < free.size():
				free[i].job = "man"
				free[i].man = others[i]
		for i in range(others.size(), free.size()):
			free[i].job = "zone"
			free[i].zone = Vector2(lx + 6 * d, ball_y + (i - 1) * 6 * d)
	else:
		var prevent: bool = call.get("prevent", false)
		var dz := 3.0 if prevent else 1.0
		cb1.zone = Vector2(lx + (20 if prevent else 5) * d, ball_y - 15 * d)
		cb2.zone = Vector2(lx + (20 if prevent else 5) * d, ball_y + 15 * d)
		cb1.job = "deep" if prevent else "zone"
		cb2.job = "deep" if prevent else "zone"
		s1.job = "deep"
		s2.job = "deep"
		s1.zone = Vector2(lx + (26 if prevent else 16) * d, ball_y - 9 * d)
		s2.zone = Vector2(lx + (26 if prevent else 16) * d, ball_y + 9 * d)
		var lbs := ["LB1", "LB2", "LB3"]
		for i in 3:
			var lb := _slot(lbs[i])
			lb.job = "zone"
			lb.zone = Vector2(lx + 7.0 * dz * d, ball_y + (i - 1) * (10 if prevent else 7) * d)
		if prevent:
			var dl := _slot("DL4")
			dl.job = "zone"
			dl.zone = Vector2(lx + 5 * d, ball_y)
	# Run stop: a safety comes down into the box.
	if call.box > 0:
		s1.job = "zone"
		s1.zone = Vector2(lx + 5 * d, ball_y - 3 * d)
	# Line up: corners over their men, safeties at their spots.
	for p: P in defense():
		match p.job:
			"man":
				if p.man != null and p.role in ["CB", "S"]:
					var off_ball := 6.5 if p.role == "CB" else 7.5
					p.at = Vector2(lx + off_ball * d, p.man.at.y)
				elif p.man != null and p.slot == "LB3" and call.get("nickel", false):
					p.at = Vector2(lx + 5.5 * d, p.man.at.y)
			"deep", "zone":
				if p.role in ["CB", "S"]:
					p.at = Vector2(lx + minf(12.0, absf(p.zone.x - lx)) * d, p.zone.y)
				if p.role == "CB" and call.cover == "zone" and not call.get("prevent", false):
					p.at = Vector2(lx + 5 * d, (left_wr.at.y if p.slot == "CB1" and left_wr else (right_wr.at.y if right_wr else p.at.y)))
		p.at.y = clampf(p.at.y, 1.0, FIELD_W - 1.0)
		p.tgt = p.at
		if p.slot in call.rush:
			p.job = "rush"


# ---------- The person's actions ----------

## Snap the ball (the person on offense taps).
func hike() -> void:
	if phase == "presnap" and poss == user:
		_snap()


## Tap on the field: pick the defender nearest the tap.
func select_at(at: Vector2) -> bool:
	if user < 0 or phase not in ["presnap", "live"] or ball_team() == user:
		return false
	var best: P = null
	var bd := 3.5
	for p: P in players:
		if p.team == user and p.down <= 0:
			var dd := p.at.distance_to(at)
			if dd < bd:
				bd = dd
				best = p
	if best != null:
		controlled = best
		user_slot = best.slot
		events.append({type = "select"})
		return true
	return false


## Throwing is possible now (the person's QB, behind the line, ball in hand).
func can_throw() -> bool:
	return phase == "live" and controlled != null and controlled == carrier and carrier == qb \
		and off_call.get("kind", "") == "pass" and not past_los and ball.is_empty()


## A flick on the action side: a juke with the ball, a dive without it.
func flick(v: Vector2) -> void:
	if phase != "live" or controlled == null or v.length() < 0.01:
		return
	var p := controlled
	if p.down > 0 or p.dive > 0 or p.engaged != null:
		return
	if p == carrier:
		if not can_throw():
			_juke(p, v.normalized())
	elif ball_team() != p.team:
		_dive(p, v.normalized())


func _juke(p: P, v: Vector2) -> void:
	if p.juke_cd > 0:
		return
	p.juke = Tune.v.jukeTime
	p.juke_cd = Tune.v.jukeCooldown + Tune.v.jukeTime
	p.juke_dir = v
	p.set_act("juke")
	events.append({type = "juke", team = p.team})
	for o: P in players:
		if o.team != p.team and o.engaged == null and o.down <= 0 and o.at.distance_to(p.at) < 2.8:
			if rng.randf() < Tune.v.jukeFool * (0.6 + p.spd * 0.8) * (1.2 - o.tck * 0.4):
				o.stun = maxf(o.stun, 0.45)
				o.vel *= 0.3


func _dive(p: P, v: Vector2) -> void:
	p.dive = Tune.v.diveTime
	p.dive_dir = v
	p.face = 1 if v.x >= 0 else -1
	p.set_act("dive")
	events.append({type = "dive", team = p.team})


## Where a throw aimed at `raw` really goes: aim assist pulls it toward the
## receiver nearest that spot and leads him. Returns {to, rec}.
func aim_point(raw: Vector2) -> Dictionary:
	if qb == null:
		return {to = raw, rec = null}
	var from := qb.at
	var best: P = null
	var best_to := raw
	var bd: float = Tune.v.aimAssistRange
	for p: P in players:
		if p.team != qb.team or not eligible(p) or p.down > 0:
			continue
		var lead := p.at
		for i in 2:
			lead = p.at + p.vel * flight_time(from.distance_to(lead))
		var dd := lead.distance_to(raw)
		if dd < bd:
			bd = dd
			best = p
			best_to = lead
	var to := raw.lerp(best_to, Tune.v.aimAssist) if best != null else raw
	var reach := max_throw()
	if to.distance_to(from) > reach:
		to = from + (to - from).normalized() * reach
	return {to = to, rec = best}


func max_throw() -> float:
	return Tune.v.maxThrow * (0.75 + (qb.arm if qb else 0.5) * 0.5)


func flight_time(dist: float) -> float:
	var arm := qb.arm if qb else 0.5
	return maxf(0.25, dist / (Tune.v.passSpeed * (0.85 + arm * 0.3)))


## The person throws to `raw` (field position, before aim assist).
func player_throw(raw: Vector2) -> void:
	if not can_throw():
		return
	var a := aim_point(raw)
	_throw(a.to, a.rec)


func _throw(to: Vector2, rec: P) -> void:
	var from := qb.at
	var dist := from.distance_to(to)
	var miss: float = dist * 0.055 * (1.35 - qb.acc) * Tune.v.passScatter
	to += Vector2(rng.randfn(0.0, miss), rng.randfn(0.0, miss * 0.8))
	ball = {from = from, to = to, t0 = t, dur = flight_time(dist), h = minf(8.0, dist * Tune.v.passArc + 0.3), rec = rec, team = qb.team}
	throw_t = t
	carrier = null
	mode_t = t
	qb.set_act("throw")
	aiming = false
	events.append({type = "throw", team = qb.team})
	for p: P in players:
		p.catch_tried = false
	# The person on defense takes the defender nearest where it's going.
	if user >= 0 and user != qb.team and Tune.v.autoSwitch != "never":
		_switch_to_nearest(to)


func _switch_to_nearest(at: Vector2) -> void:
	var best: P = null
	var bd := INF
	for p: P in players:
		if p.team == user and p.down <= 0:
			var dd := p.at.distance_to(at)
			if dd < bd:
				bd = dd
				best = p
	if best != null:
		controlled = best


# ---------- The snap ----------

func _snap() -> void:
	phase = "live"
	phase_t = 0.0
	t = 0.0
	mode_t = 0.0
	msg = ""
	sub = ""
	events.append({type = "hike"})
	for p: P in players:
		p.tgt = p.at
	if user == poss:
		if off_call.kind == "pass" or off_call.get("carrier", "") == "QB":
			controlled = qb
		else:
			controlled = null
	if off_call.kind == "run" and off_call.carrier == "QB":
		handed = true
		qb.job = "carry"
	# Blockers pick their men.
	for p: P in offense():
		if p.job in ["block", "lead"]:
			p.target = _pick_block(p)


func _pick_block(p: P) -> P:
	var best: P = null
	var bd := 7.0 if p.role == "OL" else 9.0
	var d: int = dir[poss]
	for o: P in players:
		if o.team == p.team or o.down > 0:
			continue
		var taken := false
		for q: P in players:
			if q != p and q.team == p.team and q.target == o:
				taken = true
		var dd := o.at.distance_to(p.at) + (2.5 if taken else 0.0)
		# Linemen take the rushers; receivers take the nearest defensive back.
		if p.role == "WR" and o.role not in ["CB", "S"]:
			dd += 6.0
		if (o.at.x - p.at.x) * d < -1.0:
			dd += 4.0
		if dd < bd:
			bd = dd
			best = o
	return best


# ---------- The loop ----------

func step(dt: float, move := Vector2.ZERO) -> void:
	_dt = dt
	msg_t += dt
	phase_t += dt
	match phase:
		"presnap":
			_presnap(dt, move)
		"live":
			_live(dt, move)
		"dead":
			_dead(dt)
		"kick":
			_kick_step(dt)
		"call":
			if user < 0 and phase_t > 0.3:
				pass


func _presnap(dt: float, move: Vector2) -> void:
	if controlled != null and controlled.team != poss:
		var p := controlled
		var want := move * _speed(p) * 0.7
		p.vel = p.vel.move_toward(want, Tune.v.accel * dt)
		p.at += p.vel * dt
		p.at.y = clampf(p.at.y, 0.5, FIELD_W - 0.5)
		p.dist += p.vel.length() * dt
		if absf(p.vel.x) > 0.3:
			p.face = 1 if p.vel.x > 0 else -1
		# Across the line before the snap: offside.
		if (p.at.x - los_x()) * dir[poss] < 0.0:
			_offside()
			return
	var wait: float = Tune.v.snapDelay if user >= 0 and user != poss else 1.2
	if poss != user and phase_t >= wait:
		_snap()


func _offside() -> void:
	flag = "OFFSIDE"
	events.append({type = "whistle"})
	events.append({type = "flag"})
	var yards := 5.0
	if los + yards >= 100.0:
		yards = (100.0 - los) / 2.0
	los += yards
	togo -= yards
	var head := "OFFSIDE, DEFENSE"
	var s := "%d yard penalty · replay %s down" % [roundi(yards), ["1st", "2nd", "3rd", "4th"][down - 1]]
	if togo <= 0.0:
		down = 1
		togo = minf(10.0, 100.0 - los)
		s = "%d yard penalty · automatic first down" % roundi(yards)
	_banner(head, s)
	phase = "dead"
	phase_t = 0.0
	if controlled:
		controlled.vel = Vector2.ZERO
	_next = {action = "replay"}


func _live(dt: float, move: Vector2) -> void:
	t += dt
	clock = maxf(0.0, clock - dt * Tune.v.clockRate)
	for p: P in players:
		p.act_t += dt
		p.stun = maxf(0.0, p.stun - dt)
		p.free = maxf(0.0, p.free - dt)
		p.tried = maxf(0.0, p.tried - dt)
		p.juke_cd = maxf(0.0, p.juke_cd - dt)
		p.think = maxf(0.0, p.think - dt)
		if p.juke > 0:
			p.juke = maxf(0.0, p.juke - dt)
		if p.dive > 0:
			p.dive -= dt
			if p.dive <= 0:
				p.dive = 0.0
				p.down = Tune.v.diveDown
		elif p.down > 0 and phase == "live":
			p.down = maxf(0.0, p.down - dt)
	if controlled != null and move.length() > 0.05:
		controlled.took = true
	_handoff()
	# Movement.
	for p: P in players:
		if p.down > 0:
			p.vel = Vector2.ZERO
			continue
		if p.engaged != null:
			continue
		if p.dive > 0:
			p.vel = p.dive_dir * _speed(p) * Tune.v.diveBurst
		elif p.juke > 0:
			p.vel = p.juke_dir * _speed(p) * Tune.v.jukeBurst
		else:
			var want: Vector2
			if p == controlled and p.took:
				want = move.limit_length(1.0) * _speed(p)
			else:
				want = _brain(p)
			p.vel = p.vel.move_toward(want, Tune.v.accel * dt)
		p.at += p.vel * dt
		p.dist += p.vel.length() * dt
		if absf(p.vel.x) > 0.4:
			p.face = 1 if p.vel.x > 0 else -1
	_blocks(dt)
	_separate()
	if not ball.is_empty():
		_ball_flight()
		if phase != "live":
			return
	if carrier != null:
		if carrier == qb and not past_los and (carrier.at.x - los_x()) * dir[poss] > 0.3:
			past_los = true
		if _check_end():
			return
		_tackles()


func _handoff() -> void:
	if off_call.kind != "run" or handed:
		return
	var rb := _carrier_slot()
	if rb == null:
		return
	var delay: float = off_call.get("delay", 0.0)
	var ready: bool = t > 0.3 + delay and (off_call.get("toss", false) or rb.at.distance_to(qb.at) < 1.4)
	if ready or t > 2.5 + delay:
		handed = true
		carrier = rb
		mode_t = t
		events.append({type = "handoff"})
		if user == poss:
			controlled = rb
		elif user >= 0 and Tune.v.autoSwitch == "always":
			_switch_to_nearest(rb.at)
		qb.job = "fake"


func _carrier_slot() -> P:
	for p: P in players:
		if p.team == poss and p.job == "carry":
			return p
	return null


# ---------- Thinking ----------

## Where a computer-run player wants to go: a velocity.
func _brain(p: P) -> Vector2:
	var bt := ball_team()
	if p == carrier:
		return _run_brain(p)
	if p.team == bt:
		return _offense_brain(p)
	return _defense_brain(p)


func _offense_brain(p: P) -> Vector2:
	var d: int = dir[poss] if p.team == poss else -dir[poss]
	var in_air := not ball.is_empty()
	# A turnover: the new ball carrier's teammates run with him.
	if p.team != poss:
		if carrier == null:
			return Vector2.ZERO
		return _seek(p, carrier.at + Vector2(dir[p.team] * 3.0, (p.at.y - carrier.at.y) * 0.3), 0.85)
	if in_air:
		if p == ball.get("rec") or (p.job == "route" and p.at.distance_to(ball.to) < 6.0):
			return _seek(p, ball.to, 1.0, 0.3)
	match p.job:
		"qb":
			return _qb_brain(p)
		"fake":
			return _seek(p, Vector2(los_x() - 5.0 * d, ball_y + 2.0 * d), 0.6)
		"carry":
			# Before the handoff: run the path (the draw waits a moment first).
			if t < off_call.get("delay", 0.0):
				return Vector2.ZERO
			return _follow(p)
		"route":
			if carrier != null and carrier != qb:
				return _block_brain(p)
			return _follow(p)
		_:
			return _block_brain(p)


func _qb_brain(p: P) -> Vector2:
	var d: int = dir[poss]
	if off_call.kind == "run":
		# Meet the runner at the mesh point.
		var rb := _carrier_slot()
		if rb == null or off_call.get("toss", false):
			return _seek(p, p.at + Vector2(-1.5 * d, 0), 0.5)
		var mesh: Vector2 = rb.route[0] if rb.route.size() else p.at
		return _seek(p, p.at.lerp(mesh, 0.5), 0.7)
	# Play action: show the ball first.
	if off_call.get("fake", false) and t < 0.5:
		return _seek(p, p.at + Vector2(-0.6 * d, 0.8 * d), 0.5)
	var drop_x: float = los_x() - maxf(float(off_call.get("drop", 5.0)), 0.0) * d
	var drop := Vector2(minf(drop_x, p.at.x) if d > 0 else maxf(drop_x, p.at.x), ball_y)
	if user == poss:
		return _seek(p, drop, 0.9)
	# The computer's quarterback: drop, look, throw.
	var at_depth := absf(p.at.x - drop.x) < 0.6
	if not ball.is_empty() or carrier != qb:
		return Vector2.ZERO
	if p.think <= 0 and t > 0.6:
		p.think = 0.2
		_ai_read(at_depth)
	if carrier != qb:
		return Vector2.ZERO
	# Step away from the closest rusher.
	var threat: P = _nearest(p, 1 - p.team, true)
	if threat != null and threat.at.distance_to(p.at) < 3.0 and threat.engaged == null:
		var away := (p.at - threat.at).normalized()
		return Vector2(away.x * 0.3, away.y).normalized() * _speed(p) * 0.6
	return _seek(p, drop, 0.9)


func _ai_read(at_depth: bool) -> void:
	var best: P = null
	var best_score := -INF
	var best_to := Vector2.ZERO
	var best_open := 0.0
	var d: int = dir[poss]
	for r: P in players:
		if r.team != poss or r.job != "route":
			continue
		var lead := r.at
		for i in 2:
			lead = r.at + r.vel * flight_time(qb.at.distance_to(lead))
		if lead.distance_to(qb.at) > max_throw() or lead.y < 1 or lead.y > FIELD_W - 1:
			continue
		var open := INF
		for o: P in players:
			if o.team != poss:
				open = minf(open, o.at.distance_to(lead) + o.at.distance_to(r.at) * 0.3)
		var gain: float = (lead.x - los_x()) * d
		var s := open + clampf(gain, -3.0, 25.0) * 0.06
		if s > best_score:
			best_score = s
			best = r
			best_to = lead
			best_open = open
	var pressure := false
	for o: P in players:
		if o.team != poss and o.engaged == null and o.at.distance_to(qb.at) < 2.6:
			pressure = true
	if best == null:
		return
	if (best_open >= Tune.v.aiThrowOpen and (at_depth or t > 1.6)) or t > Tune.v.aiThrowBy or (pressure and t > 1.0 and best_open > 1.5):
		_throw(best_to, best)


func _follow(p: P) -> Vector2:
	while p.route_i < p.route.size() and p.at.distance_to(p.route[p.route_i]) < 0.8:
		p.route_i += 1
	if p.route_i < p.route.size():
		return _seek(p, p.route[p.route_i], 1.0, 0.2)
	if p == carrier:
		return _free_run(p)
	if p.route_go and p.route.size():
		var last: Vector2 = p.route[-1]
		var prev: Vector2 = p.route[-2] if p.route.size() > 1 else last - Vector2(dir[poss], 0)
		var v := (last - prev).normalized()
		if p.at.y < 2 or p.at.y > FIELD_W - 2:
			v = Vector2(dir[poss], 0)
		return v * _speed(p)
	# Settled in a soft spot: drift a little toward the quarterback.
	if qb != null:
		return _seek(p, p.at + (qb.at - p.at).normalized() * 0.5, 0.15)
	return Vector2.ZERO


func _block_brain(p: P) -> Vector2:
	if p.target == null or p.target.down > 0 or (p.target.engaged != null and p.target.engaged != p) or p.think <= 0:
		p.think = 0.4
		if p.target == null or p.target.down > 0 or (p.target.engaged != null and p.target.engaged != p):
			p.target = _pick_block_for(p)
	var tg := p.target
	if tg == null:
		return Vector2.ZERO
	var protect := carrier.at if carrier != null else qb.at
	# Get between him and the ball.
	var spot := tg.at + (protect - tg.at).normalized() * 0.7
	return _seek(p, spot, 1.0 if p.role != "OL" else 0.9, 0.3)


func _pick_block_for(p: P) -> P:
	var ref := carrier.at if carrier != null else (qb.at if qb else p.at)
	var best: P = null
	var bd := 12.0
	for o: P in players:
		if o.team == p.team or o.down > 0 or o.engaged != null:
			continue
		var dd := o.at.distance_to(p.at) + o.at.distance_to(ref) * 0.8
		if dd < bd:
			bd = dd
			best = o
	return best


func _run_brain(p: P) -> Vector2:
	# A quarterback with the ball behind the line (pocket, or before the handoff).
	if p == qb and not handed and off_call.kind == "pass" and not past_los:
		return _qb_brain(p)
	if p == qb and off_call.kind == "run" and not handed:
		return _qb_brain(p)
	if p.route_i < p.route.size() and p.job == "carry":
		return _follow(p)
	return _free_run(p)


## The computer's ball carrier: head for the end zone, around tacklers.
func _free_run(p: P) -> Vector2:
	var d: int = dir[p.team]
	var push := Vector2.ZERO
	var closest: P = null
	var cd := INF
	for o: P in players:
		if o.team == p.team or o.down > 0 or o.engaged != null:
			continue
		var dv := p.at - o.at
		var l := dv.length()
		if l < 0.01 or l > 7.0:
			continue
		if (o.at.x - p.at.x) * d < -1.5:
			continue
		push += dv / l * (7.0 - l) / 7.0 * 1.6
		if l < cd:
			cd = l
			closest = o
	var want := Vector2(d, 0) + Vector2(push.x * 0.25, push.y)
	if p.at.y < 3.0:
		want.y += (3.0 - p.at.y) * 0.4
	elif p.at.y > FIELD_W - 3.0:
		want.y -= (p.at.y - FIELD_W + 3.0) * 0.4
	if want.x * d < 0.2:
		want.x = 0.2 * d
	# Juke a tackler who's about to get there.
	if closest != null and cd < 2.4 and p.juke_cd <= 0 and p.think <= 0:
		p.think = 0.5
		if rng.randf() < Tune.v.aiJuke:
			var side := signf(p.at.y - closest.at.y)
			if side == 0:
				side = 1.0
			_juke(p, Vector2(0.5 * d, side).normalized())
	return want.normalized() * _speed(p)


func _defense_brain(p: P) -> Vector2:
	var d: int = dir[poss]
	var react := 0.15 + (1.0 - p.cov) * 0.35
	# A turnover: chase the man with the ball.
	if carrier != null and carrier.team != poss:
		return _pursue(p)
	if not ball.is_empty():
		if p.at.distance_to(ball.to) < 10.0 and t - throw_t > react:
			return _seek(p, ball.to, 1.0, 0.3)
		return _cover(p, d)
	if carrier == null:
		return Vector2.ZERO
	# The run is on: everyone flows to the ball after reading it.
	var run_on: bool = carrier != qb or past_los
	if run_on:
		var read := react + (0.1 if p.role in ["CB", "S"] else 0.0)
		if p.job == "man" and t - mode_t < read + 0.3:
			return _cover(p, d)
		if t - mode_t < read * 0.5:
			return p.vel
		return _pursue(p)
	# Before the handoff on a run: linebackers read and fill.
	if off_call.kind == "run" and p.role == "LB" and p.job != "rush":
		var read: float = def_call.get("run_read", 0.35 * (1.3 - p.cov))
		if t > read:
			var rb := _carrier_slot()
			if rb != null:
				return _seek(p, rb.at + Vector2(1.5 * d, 0), 0.9)
	if off_call.get("fake", false) and p.role == "LB" and t < 0.6:
		return _seek(p, p.at - Vector2(d * 1.0, 0), 0.5)
	if p.job == "rush":
		return _seek(p, carrier.at, 1.0, 0.2)
	return _cover(p, d)


func _cover(p: P, d: int) -> Vector2:
	match p.job:
		"rush":
			return _seek(p, (carrier.at if carrier else qb.at), 1.0, 0.2)
		"man":
			var r := p.man
			if r == null:
				return Vector2.ZERO
			# Keep the cushion: give ground as he comes, never step up into him.
			var depth := clampf((p.at.x - r.at.x) * d, 1.0, 7.0)
			var want := r.at + r.vel * 0.3 + Vector2(d * depth, 0)
			p.tgt = p.tgt.lerp(want, clampf(_dt * (2.0 + p.cov * 6.0), 0.0, 1.0))
			return _seek(p, p.tgt, 1.0, 0.4)
		"deep":
			var deepest: P = null
			for r: P in players:
				if r.team == poss and eligible(r) and absf(r.at.y - p.zone.y) < 14.0:
					if deepest == null or (r.at.x - deepest.at.x) * d > 0:
						deepest = r
			var want := p.zone
			if deepest != null:
				var dx := maxf((p.zone.x - los_x()) * d, (deepest.at.x - los_x()) * d + 3.0)
				want = Vector2(los_x() + dx * d, lerpf(p.zone.y, deepest.at.y, 0.6))
			return _seek(p, want, 0.95, 0.8)
		_:
			var near: P = null
			var nd := 7.5
			for r: P in players:
				if r.team == poss and eligible(r):
					var dd := r.at.distance_to(p.zone)
					if dd < nd:
						nd = dd
						near = r
			var want := p.zone if near == null else p.zone.lerp(near.at, 0.65)
			return _seek(p, want, 0.9, 0.8)


func _pursue(p: P) -> Vector2:
	var c := carrier
	var l := p.at.distance_to(c.at)
	var lead := clampf(l / maxf(1.0, _speed(p)) * 0.55, 0.0, 1.2)
	return _seek(p, c.at + c.vel * lead, 1.0, 0.2)


func _nearest(p: P, team: int, free_only := false) -> P:
	var best: P = null
	var bd := INF
	for o: P in players:
		if o.team != team or o.down > 0 or (free_only and o.engaged != null):
			continue
		var dd := o.at.distance_to(p.at)
		if dd < bd:
			bd = dd
			best = o
	return best


# ---------- Contact ----------

func _blocks(dt: float) -> void:
	var bt := ball_team()
	# New blocks.
	for p: P in players:
		if p.team != poss or bt != poss or p.engaged != null or p.down > 0 or p.stun > 0:
			continue
		if p.job not in ["block", "lead"] and not (p.job == "route" and carrier != null and carrier != qb):
			continue
		for o: P in players:
			if o.team == p.team or o.engaged != null or o.free > 0 or o.down > 0 or o.dive > 0:
				continue
			if o.at.distance_to(p.at) < Tune.v.blockReach:
				p.engaged = o
				o.engaged = p
				o.vel = Vector2.ZERO
				p.vel = Vector2.ZERO
				var hold: float = rng.randf_range(0.8, 2.2) * Tune.v.blockHold * (1.0 + (p.pwr - o.pwr) * 1.3)
				if p.role != "OL":
					hold *= 0.6
				o.shed = maxf(0.25, hold)
				events.append({type = "block", team = p.team})
				break
	# Blocks in progress.
	var d: int = dir[poss]
	for p: P in players:
		var o := p.engaged
		if o == null or p.team != poss:
			continue
		var rate := 1.0
		var ref := carrier.at if carrier != null else (_ball_ground() if not ball.is_empty() else qb.at)
		if o.at.distance_to(ref) < 2.4:
			rate = 2.5
		if o == controlled:
			rate *= 1.5
		o.shed -= dt * rate
		if o.shed <= 0 or p.down > 0 or bt != poss:
			o.engaged = null
			p.engaged = null
			o.free = 0.9
			p.stun = 0.3
			continue
		var push: Vector2
		if carrier == qb and off_call.get("kind", "") == "pass" and not past_los:
			push = (qb.at - o.at).normalized() * clampf(0.5 + (o.pwr - p.pwr) * 1.5, 0.15, 1.4)
		else:
			push = Vector2(d, 0) * clampf(0.4 + (p.pwr - o.pwr) * 2.0, -0.8, 1.4)
		p.at += push * dt
		var side := (o.at - p.at)
		if side.length() < 0.01:
			side = Vector2(d, 0)
		o.at = p.at + side.normalized() * 0.85
		o.at += push * dt
		p.vel = push
		o.vel = push
		p.face = 1 if (o.at.x - p.at.x) > 0 else -1
		o.face = -p.face


func _separate() -> void:
	var n := players.size()
	for i in n:
		var a: P = players[i]
		if a.down > 0:
			continue
		for j in range(i + 1, n):
			var b: P = players[j]
			if b.down > 0 or a.engaged == b:
				continue
			var dv := b.at - a.at
			var l := dv.length()
			if l < 0.6 and l > 0.001:
				var fix := dv / l * (0.6 - l) * 0.5
				a.at -= fix
				b.at += fix


func _tackles() -> void:
	var c := carrier
	for o: P in players:
		if o.team == c.team or o.engaged != null or o.down > 0 or o.stun > 0 or o.tried > 0:
			continue
		var reach: float = Tune.v.diveReach if o.dive > 0 else Tune.v.tackleReach
		if o.at.distance_to(c.at) > reach:
			continue
		o.tried = 0.6
		var p: float = Tune.v.tackleBase + (o.tck - c.pwr * 0.6 - c.spd * 0.4) * Tune.v.tackleRating
		if o.dive > 0:
			p += Tune.v.diveBonus
		if c.juke > 0:
			p *= 1.0 - Tune.v.jukeEvade
		# Behind the line the quarterback is easy pickings.
		if c == qb and not past_los:
			p += 0.15
		if rng.randf() < clampf(p, 0.05, 0.97):
			o.set_act("tackler")
			c.set_act("tackled")
			o.down = 1.0
			c.down = 1.0
			var fall := c.vel.normalized() * 0.6 if c.vel.length() > 1 else Vector2.ZERO
			c.at += fall
			events.append({type = "tackle", team = c.team, big = c.vel.length() > 6.0})
			var sack: bool = c == qb and not past_los and off_call.get("kind", "") == "pass"
			_whistle("sack" if sack else "tackle", c)
			return
		o.stun = Tune.v.missStun
		o.vel *= 0.2
		c.set_act("stiff")
		c.vel *= 0.75
		events.append({type = "miss", team = o.team})


func _ball_flight() -> void:
	var s := _ball_s()
	var g := _ball_ground()
	var z := _ball_z()
	if s >= 0.8 and z < 3.2:
		var cands := players.filter(func(p): return not p.catch_tried and p.down <= 0 and p.engaged == null \
			and (eligible(p) if p.team == ball.team else true) and p.at.distance_to(g) < Tune.v.catchReach)
		cands.sort_custom(func(a, b): return a.at.distance_to(g) < b.at.distance_to(g))
		for p in cands:
			p.catch_tried = true
			if p.team == ball.team:
				var chance: float = Tune.v.catchBase + (p.hands - 0.5) * 0.4
				var dd := INF
				for o: P in players:
					if o.team != p.team:
						dd = minf(dd, o.at.distance_to(p.at))
				if dd < 2.6:
					chance -= Tune.v.coverPenalty * (1.0 - dd / 2.6)
				if rng.randf() < chance:
					_caught(p)
					return
			else:
				var rec_near := players.any(func(r): return r.team == ball.team and eligible(r) and r.at.distance_to(g) < Tune.v.catchReach)
				var chance: float = Tune.v.intChance * (0.5 + p.hands) * (0.6 if rec_near else 1.0)
				if rng.randf() < chance:
					_caught(p)
					return
				if rng.randf() < 0.45:
					p.set_act("catch")
					_banner("BROKEN UP!")
					_whistle("incomplete", null)
					return
	if s >= 1.0 and z <= 0.15:
		_whistle("incomplete", null)


func _caught(p: P) -> void:
	carrier = p
	ball = {}
	mode_t = t
	p.set_act("catch")
	p.route_i = p.route.size()
	if p.team == poss:
		events.append({type = "catch", team = p.team})
		if user == p.team:
			controlled = p
		elif user >= 0 and Tune.v.autoSwitch == "always":
			_switch_to_nearest(p.at)
	else:
		events.append({type = "int", team = p.team})
		stats[poss].to += 1
		_banner("INTERCEPTED!")
		if user == p.team:
			controlled = p
		elif user >= 0:
			_switch_to_nearest(p.at)


## The play is over if the ball carrier scored, stepped out or ran out the back.
func _check_end() -> bool:
	var c := carrier
	var yl := yard(c.team, c.at.x)
	if yl >= 100.0:
		_whistle("td", c)
		return true
	if c.at.y < 0.0 or c.at.y > FIELD_W:
		_whistle("out", c)
		return true
	if yl < -10.0:
		_whistle("out", c)
		return true
	return false


# ---------- After the whistle ----------

func _whistle(kind: String, c: P) -> void:
	phase = "dead"
	phase_t = 0.0
	plays += 1
	events.append({type = "whistle"})
	var head := ""
	var s := ""
	var runs := true
	var kickoff_to := -1
	var lx := los_x()
	if kind == "incomplete":
		runs = false
		if msg == "":
			head = "INCOMPLETE"
		else:
			head = msg
		_advance_down(0.0)
		s = _down_line()
		if _next.get("action", "") == "downs":
			head = "TURNOVER ON DOWNS"
	elif kind == "td":
		var team := c.team
		score[team] += 6
		c.set_act("td")
		events.append({type = "td", team = team})
		var good: bool = rng.randf() < Tune.v.patChance
		if good:
			score[team] += 1
		if team == poss:
			var gain: float = (c.at.x - lx) * dir[poss]
			_count_gain(c, gain)
		head = "TOUCHDOWN!"
		s = "%s · extra point %s" % [teams[team].name.to_upper(), "good" if good else "no good"]
		kickoff_to = 1 - team
		runs = false
	else:
		var team := c.team
		var yl := yard(team, c.at.x)
		if kind == "out":
			runs = false
		if team == poss:
			var gain: float = (c.at.x - lx) * dir[poss]
			_count_gain(c, gain)
			if yl <= 0.0:
				score[1 - team] += 2
				events.append({type = "td", team = 1 - team})
				head = "SAFETY!"
				s = "2 points for %s" % teams[1 - team].name
				_next = {action = "free", to = 1 - team}
			else:
				head = "SACK!" if kind == "sack" else _gain_text(gain, kind == "out")
				if kind == "sack":
					stats[1 - poss].sacks += 1
				los = clampf(yl, 1.0, 99.0)
				_advance_down(gain)
				s = _down_line()
				if _next.get("action", "") == "downs":
					head = "TURNOVER ON DOWNS"
		else:
			# A turnover was returned.
			if yl <= 0.0:
				yl = 20.0
				s = "Touchback"
			head = msg if msg != "" else "TURNOVER"
			poss = team
			los = clampf(yl, 1.0, 99.0)
			down = 1
			togo = minf(10.0, 100.0 - los)
			ball_y = clampf(c.at.y, HASH_TOP, HASH_BOT)
			if s == "":
				s = "%s ball at %s" % [teams[poss].name, spot_text(poss, los)]
			_next = {action = "call"}
	if c != null:
		ball_y = clampf(c.at.y, HASH_TOP, HASH_BOT)
	if kickoff_to >= 0:
		_next = {action = "kickoff", to = kickoff_to}
	if runs:
		clock = maxf(0.0, clock - Tune.v.runoff)
	_banner(head, s)
	last = {play = off_call.get("key", ""), def = def_call.get("key", ""), kind = kind, head = head, gain = roundi((c.at.x - lx) * dir[1 - poss if kind == "td" and false else (c.team)]) if c != null else 0, team = c.team if c != null else -1}
	ball = {}
	carrier = null if kind == "incomplete" else carrier
	if controlled:
		controlled.vel = Vector2.ZERO


func _count_gain(c: P, gain: float) -> void:
	if off_call.get("kind", "") == "pass" and c != qb:
		stats[poss].pass_yds += roundi(gain)
	elif c == qb and off_call.get("kind", "") == "pass" and not past_los:
		pass
	else:
		stats[poss].rush_yds += roundi(gain)


func _gain_text(gain: float, out: bool) -> String:
	var g := roundi(gain)
	var tail := " · OUT OF BOUNDS" if out else ""
	if g > 0:
		return "GAIN OF %d%s" % [g, tail]
	if g < 0:
		return "LOSS OF %d%s" % [-g, tail]
	return "NO GAIN" + tail


func _down_line() -> String:
	if _next.get("action", "") == "downs":
		return "%s ball at %s" % [teams[poss].name, spot_text(poss, los)]
	if down == 1:
		return "FIRST DOWN · %s" % down_text()
	return down_text()


## After a play by the offense that gained `gain` (los already moved).
func _advance_down(gain: float) -> void:
	_next = {action = "call"}
	togo -= gain
	if togo <= 0.0:
		down = 1
		togo = minf(10.0, 100.0 - los)
		stats[poss].first += 1
		events.append({type = "first"})
		return
	down += 1
	if down > 4:
		poss = 1 - poss
		los = 100.0 - los
		down = 1
		togo = minf(10.0, 100.0 - los)
		_next = {action = "downs"}


func _dead(dt: float) -> void:
	for p: P in players:
		p.act_t += dt
		if p.engaged:
			p.engaged.engaged = null
			p.engaged = null
		p.vel = p.vel.move_toward(Vector2.ZERO, 12.0 * dt)
		p.at += p.vel * dt
	if phase_t < Tune.v.deadTime:
		return
	_advance()


func _advance() -> void:
	var nx := _next
	_next = {}
	var action: String = nx.get("action", "call")
	if action == "replay":
		_setup()
		return
	# Sudden death: the first score ends overtime.
	if quarter > 4 and score[0] != score[1]:
		_final()
		return
	if clock <= 0.0 and _end_of_quarter(nx):
		return
	match action:
		"kickoff":
			_kickoff(nx.to, "KICKOFF", "")
		"free":
			poss = nx.to
			los = 35.0
			down = 1
			togo = 10.0
			ball_y = MID_Y
			players.clear()
			_banner("FREE KICK", "%s ball at %s" % [teams[poss].name, spot_text(poss, los)])
			phase = "dead"
			phase_t = 0.0
			_next = {action = "call"}
		_:
			_to_call()


## The clock has run out: next quarter (keeping what was to happen next),
## halftime, overtime or the end.
func _end_of_quarter(nx: Dictionary) -> bool:
	quarter += 1
	clock = Tune.v.quarterMinutes * 60.0
	if quarter == 3:
		dir = [-1, 1]
		_kickoff(1 - first_receiver, "HALFTIME", "%s %d · %s %d" % [teams[0].abbr, score[0], teams[1].abbr, score[1]])
		return true
	if quarter >= 5:
		if score[0] != score[1] or not playoff:
			_final()
			return true
		dir = [1, -1] if quarter % 2 == 1 else [-1, 1]
		_kickoff(rng.randi() % 2, "OVERTIME", "Next score wins")
		return true
	_banner("END OF THE %s QUARTER" % ["1ST", "2ND", "3RD", "4TH"][quarter - 2], "")
	phase = "dead"
	phase_t = 0.0
	players.clear()
	_next = nx
	return true


func _kickoff(to: int, head: String, s: String) -> void:
	poss = to
	los = Tune.v.touchback
	down = 1
	togo = 10.0
	ball_y = MID_Y
	players.clear()
	carrier = null
	_banner(head, s if s != "" else "%s ball at %s" % [teams[to].name, spot_text(to, los)])
	if head == "KICKOFF" and s == "":
		_banner(head, "Touchback · %s ball at %s" % [teams[to].name, spot_text(to, los)])
	phase = "dead"
	phase_t = 0.0
	_next = {action = "call"}
	events.append({type = "kick"})


func _final() -> void:
	phase = "final"
	phase_t = 0.0
	players.clear()
	var w := winner()
	_banner("FINAL", "%s %d · %s %d" % [teams[0].abbr, score[0], teams[1].abbr, score[1]])
	events.append({type = "final", winner = w})


## 0 or 1, or -1 for a tie.
func winner() -> int:
	if score[0] == score[1]:
		return -1
	return 0 if score[0] > score[1] else 1


# ---------- Kicks ----------

func _start_kick() -> void:
	_setup_kick_lineup()
	phase = "kick"
	phase_t = 0.0
	var team: Dictionary = teams[poss]
	var k: float = team.kick
	var punt: bool = off_call.kind == "punt"
	var d: int = dir[poss]
	var from := Vector2(fx(poss, los - (12.0 if punt else 7.0)), ball_y)
	if punt:
		var dist: float = Tune.v.puntDistance + (k - 0.6) * 15.0 + rng.randf_range(-6.0, 6.0)
		var land := los + dist
		kick = {kind = "punt", from = from, to = Vector2(fx(poss, minf(land, 108.0)), ball_y + rng.randf_range(-8, 8)), t = 0.0, dur = 2.2, h = 12.0, land = land, dist = dist}
	else:
		var dist := 100.0 - los + 17.0
		var p: float = 1.0 - maxf(0.0, dist - Tune.v.fgRange) * Tune.v.fgFalloff * (1.5 - k)
		var good: bool = rng.randf() < clampf(p, 0.02, 0.99)
		var miss_y := (rng.randf_range(3.6, 7.0) * (1.0 if rng.randf() < 0.5 else -1.0)) if not good else rng.randf_range(-2.2, 2.2)
		kick = {kind = "fg", from = from, to = Vector2(fx(poss, 110.0), MID_Y + miss_y), t = 0.0, dur = 1.7, h = 5.0 + dist * 0.06, good = good, dist = dist}
	if qb != null:
		qb.at = from - Vector2(d * 0.8, 0)
		qb.set_act("throw")
	events.append({type = "kick"})


func _setup_kick_lineup() -> void:
	var saved := off_call
	off_call = Playbook.play("dive").duplicate()
	off_call.form = "single"
	off_call.key = saved.key
	_setup()
	off_call = saved
	phase = "kick"
	msg = ""
	sub = ""
	controlled = null


func _kick_step(dt: float) -> void:
	kick.t += dt
	for p: P in players:
		p.act_t += dt
	if kick.t < kick.dur:
		return
	clock = maxf(0.0, clock - (6.0 if kick.kind == "punt" else 4.0))
	phase = "dead"
	phase_t = 0.0
	plays += 1
	if kick.kind == "punt":
		var land: float = kick.land
		var kicker := poss
		poss = 1 - poss
		if land >= 100.0:
			los = 20.0
			_banner("PUNT · %d YARDS" % roundi(kick.dist), "Touchback · %s ball at %s" % [teams[poss].name, spot_text(poss, los)])
		else:
			los = clampf(100.0 - land, 1.0, 99.0)
			_banner("PUNT · %d YARDS" % roundi(kick.dist), "Fair catch · %s ball at %s" % [teams[poss].name, spot_text(poss, los)])
		down = 1
		togo = 10.0
		_next = {action = "call"}
		if kicker == poss:
			pass
	else:
		if kick.good:
			score[poss] += 3
			events.append({type = "fg", team = poss})
			_banner("FIELD GOAL IS GOOD!", "%d yards · %s 3 points" % [roundi(kick.dist), teams[poss].name])
			_next = {action = "kickoff", to = 1 - poss}
		else:
			events.append({type = "miss_fg", team = poss})
			var spot := los - 7.0
			poss = 1 - poss
			los = maxf(20.0, 100.0 - spot)
			down = 1
			togo = 10.0
			_banner("NO GOOD!", "%d yards · %s ball at %s" % [roundi(kick.dist), teams[poss].name, spot_text(poss, los)])
			_next = {action = "call"}
	kick = {}
