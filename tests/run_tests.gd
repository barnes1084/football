## Headless tests: godot --headless --path . -s res://tests/run_tests.gd
extends SceneTree

var failed := 0
var passed := 0


func check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", what)


func _init() -> void:
	Tune.ensure()
	Tune.reset()
	var unknown := Tune.load_defaults_file()
	check(unknown.is_empty(), "default_settings.cfg has unknown settings: %s" % [unknown])
	Tune.reset()
	test_teams()
	test_playbook()
	test_formation()
	test_offside()
	test_hike_and_throw()
	test_dive_tackle()
	test_juke()
	test_wall()
	test_drill()
	test_drill_run()
	test_downs()
	test_kicks()
	test_quarter_keeps_kickoff()
	test_schedule()
	test_season()
	test_full_games()
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)


## The wall numbers the mechanics tests were written for, so tuning the
## defaults in default_settings.cfg doesn't change what they check.
func pin_wall() -> void:
	for kv in [["wallSquare", 0.65], ["wallEdge", 1.2], ["wallSet", 1.0], ["wallSetSpeed", 4.0], ["wallGive", 1.6],
			["wallPush", 0.55], ["wallRunPush", 0.05], ["wallPower", 1.8], ["wallHelp", 0.2], ["wallSlip", 1.4],
			["wallGap", 1.1], ["blockReach", 1.0], ["lineSplit", 2.2]]:
		Tune.v[kv[0]] = kv[1]


func step_until(g: Game, cond: Callable, sec := 30.0, move := Vector2.ZERO) -> bool:
	var n := int(sec * 120)
	for i in n:
		if cond.call():
			return true
		g.step(1.0 / 120.0, move)
		g.events.clear()
	return cond.call()


## A game where the person (home) has the ball at their own `yl`.
func user_offense(yl := 25.0, play := "dive", seed_value := 42) -> Game:
	var g := Game.new(0, "balanced", 4, "balanced", 0, seed_value)
	g.give_ball(0, yl)
	g.choose_offense(play)
	return g


func user_defense(yl := 25.0, call := "base", seed_value := 42) -> Game:
	var g := Game.new(0, "balanced", 4, "balanced", 0, seed_value)
	g.give_ball(1, yl)
	g.choose_defense(call)
	return g


func test_teams() -> void:
	check(Teams.TEAMS.size() == 8, "eight teams")
	var divs := {}
	for t in Teams.TEAMS:
		divs[t.div] = divs.get(t.div, 0) + 1
	check(divs.get("AFC North", 0) == 4 and divs.get("NFC North", 0) == 4, "four AFC North and four NFC North teams")
	for key in ["smashmouth", "run_gun", "air_raid", "balanced", "strong_d", "tank"]:
		check(Teams.TYPES.has(key), "strength type %s" % key)
	var strong := Teams.strength(Teams.make(0, "strong_d", true, 1))
	var tank := Teams.strength(Teams.make(0, "tank", true, 1))
	var air := Teams.make(0, "air_raid", true, 1)
	var smash := Teams.make(0, "smashmouth", true, 1)
	check(strong.def > tank.def + 0.1, "strong defense beats tank on defense")
	check(air.offense[0].arm > smash.offense[0].arm, "air raid QB has the bigger arm")
	check(smash.offense[1].pwr > air.offense[1].pwr, "smashmouth RB runs harder")
	var t := Teams.make(3, "balanced", true, 9)
	check(t.offense.size() == 12 and t.defense.size() == 11, "rosters: 12 on offense (FB or 3rd WR), 11 on defense")


func test_playbook() -> void:
	for name in Playbook.FORMATIONS:
		check(Playbook.FORMATIONS[name].size() == 11, "formation %s has 11" % name)
	check(Playbook.DEF_FORM.size() == 11, "defense has 11")
	check(Playbook.runs().size() >= 6, "several running plays")
	check(Playbook.passes().size() >= 6, "several passing plays")
	for p in Playbook.passes():
		for slot in p.routes:
			var rk: String = p.routes[slot]
			check(rk == "block" or Playbook.ROUTES.has(rk), "%s: route %s exists" % [p.key, rk])


func test_formation() -> void:
	var g := user_offense(25.0, "slants")
	check(g.phase == "presnap", "after both calls the teams line up")
	check(g.players.size() == 22, "22 players on the field")
	var lx := g.los_x()
	var d: int = g.dir[g.poss]
	var ok := true
	for p in g.players:
		var side: float = (p.at.x - lx) * d
		if p.team == g.poss and side > 0.01:
			ok = false
		if p.team != g.poss and side < 0.0:
			ok = false
	check(ok, "everyone lines up on their own side of the ball")


func test_offside() -> void:
	var g := user_defense(30.0)
	check(g.controlled != null and g.controlled.team == 0, "on defense you control a defender")
	var los := g.los
	var down := g.down
	# Run your man across the line before the snap.
	var toward := Vector2(-g.dir[g.poss], 0)
	var flagged := step_until(g, func(): return g.flag == "OFFSIDE", 3.0, toward)
	check(flagged, "crossing the line before the snap is offside")
	check(is_equal_approx(g.los, los + 5.0), "offside gives the offense 5 yards (%.1f -> %.1f)" % [los, g.los])
	check(g.down == down, "the down is replayed")
	check(g.togo == 5.0, "5 yards to go after the penalty (%s)" % g.togo)
	step_until(g, func(): return g.phase == "presnap", 5.0)
	check(g.phase == "presnap" and g.flag == "", "the play lines up again")
	# Selecting a defender by tapping near him.
	var target = g.players.filter(func(p): return p.team == 0 and p.slot == "CB2")[0]
	check(g.select_at(target.at + Vector2(0.5, 0.3)), "tapping near a defender selects him")
	check(g.controlled == target, "the tapped defender is yours")
	# Moving freely on your own side is fine.
	var g2 := user_defense(30.0)
	step_until(g2, func(): return g2.phase != "presnap", 2.0, Vector2(0, 1))
	check(g2.flag == "", "moving along your own side is not offside")


func test_hike_and_throw() -> void:
	var g := user_offense(25.0, "verticals")
	g.step(0.5)
	check(g.phase == "presnap", "the offense waits for you to hike")
	g.hike()
	check(g.phase == "live", "hike starts the play")
	check(g.controlled == g.qb, "on a pass you're the quarterback")
	step_until(g, func(): return g.t > 1.2 or g.phase != "live", 3.0)
	check(g.can_throw(), "you can throw from the pocket")
	var target: Vector2 = g.qb.at + Vector2(g.dir[0] * 20.0, 0)
	g.player_throw(target)
	check(not g.ball.is_empty(), "the throw is in the air")
	check(not g.can_throw(), "only one throw")
	step_until(g, func(): return g.phase != "live" or g.carrier != null, 6.0)
	check(g.phase == "dead" or g.carrier != null, "the pass is caught or falls (phase %s)" % g.phase)
	# A run play hands the ball to the back, and you take him.
	var r := user_offense(25.0, "dive")
	r.hike()
	step_until(r, func(): return r.handed, 3.0)
	check(r.handed and r.carrier != null and r.carrier.role == "RB", "the dive goes to the running back")
	check(r.controlled == r.carrier, "you control the runner after the handoff")


func test_dive_tackle() -> void:
	var g := user_defense(30.0, "base")
	step_until(g, func(): return g.phase == "live" and g.carrier != null and g.carrier != g.qb, 8.0)
	if g.carrier == null or g.phase != "live":
		check(false, "the computer got a ball carrier (phase %s)" % g.phase)
		return
	# Put your defender next to the carrier and dive at him.
	var c = g.carrier
	g.controlled.engaged = null
	g.controlled.at = c.at - Vector2(1.2, 0)
	g.controlled.stun = 0.0
	g.controlled.tried = 0.0
	g.flick(c.at - g.controlled.at)
	check(g.controlled.dive > 0, "a flick on defense is a dive")
	var tackled := 0
	for i in 20:
		var h := user_defense(30.0, "base", 100 + i)
		step_until(h, func(): return h.phase == "live" and h.carrier != null and h.carrier != h.qb, 8.0)
		if h.carrier == null:
			continue
		var cc = h.carrier
		if h.controlled.engaged != null:
			h.controlled.engaged.engaged = null
		h.controlled.engaged = null
		# A yard away in his path, diving at him.
		var ahead: Vector2 = cc.vel.normalized() if cc.vel.length() > 0.5 else Vector2(h.dir[h.poss], 0)
		h.controlled.at = cc.at + ahead * 1.0
		h.flick(cc.at - h.controlled.at)
		for j in 30:
			h.step(1.0 / 120.0)
		if h.phase == "dead":
			tackled += 1
	check(tackled >= 12, "dive tackles from a yard away usually work (%d of 20)" % tackled)


func test_juke() -> void:
	var g := user_offense(25.0, "dive")
	g.hike()
	step_until(g, func(): return g.handed, 3.0)
	var c = g.carrier
	g.flick(Vector2(0, 1))
	check(c.juke > 0, "a flick with the ball is a juke")
	check(c.juke_cd > 0, "jukes have a cooldown")
	var before: float = c.juke_cd
	g.flick(Vector2(0, -1))
	check(c.juke_cd == before, "no second juke during the cooldown")
	# Jukes make tackles miss more.
	var made := [0, 0]
	for juking in [0, 1]:
		for i in 60:
			var h := user_offense(25.0, "dive", 200 + i)
			h.hike()
			step_until(h, func(): return h.handed, 3.0)
			var rb = h.carrier
			for p in h.players:
				if p.team != 0:
					p.at = Vector2(200, 0)
			var o = h.players.filter(func(p): return p.team != 0)[0]
			o.at = rb.at + Vector2(0.5, 0)
			o.stun = 0.0
			o.tried = 0.0
			o.engaged = null
			if juking:
				rb.juke = 0.3
			h._tackles()
			if h.phase == "dead":
				made[juking] += 1
	check(made[1] < made[0], "jukes break tackles (%d tackles without, %d with)" % made)


## Seconds until a computer rusher of the given power gets around his
## lineman while you hold the ball in the pocket.
func wall_time(power: float, seed_value: int) -> float:
	var g := user_offense(30.0, "slants", seed_value)
	var dl = g.players.filter(func(p): return p.team == 1 and p.slot == "DL2")[0]
	dl.pwr = power
	g.hike()
	# Just the line, the quarterback and this rusher.
	for p in g.players:
		if p != dl and p != g.qb and p.role != "OL":
			p.down = 9999.0
			p.job = "out"
	for i in 1800:
		g.step(1.0 / 120.0)
		g.events.clear()
		if dl.free > 0 or dl.act == "tackler":
			return g.t
		if g.phase != "live":
			break
	return 99.0


func test_wall() -> void:
	pin_wall()
	var g := user_offense(30.0, "slants")
	g.hike()
	step_until(g, func(): return g.t > 0.5, 2.0)
	var line := g.players.filter(func(p): return p.team == 0 and p.role == "OL")
	check(line.all(func(p): return p.wall), "the offensive line forms the wall")
	var engaged := line.filter(func(p): return p.engaged != null).size()
	check(engaged >= 2, "the wall picks up the rushers (%d blocking)" % engaged)
	var d: int = g.dir[g.poss]
	var held := g.players.filter(func(p): return p.role == "DL").all(func(o):
		return line.all(func(p): return absf(o.at.y - p.at.y) > Tune.v.wallSquare or (o.at.x - p.at.x) * d > 0.0))
	check(held, "no rusher walks through the wall")
	# A defender can't walk through the wall: he has to push his man back.
	var strong := 0.0
	var weak := 0.0
	for i in 4:
		strong += wall_time(0.95, 500 + i)
		weak += wall_time(0.35, 500 + i)
	print("wall: a strong rusher gets around in %.1f s, a weak one in %.1f s (99 = never)" % [strong / 4, weak / 4])
	check(strong / 4 < 14.0, "a strong rusher gets around (%.1f s avg)" % (strong / 4))
	check(strong < weak, "stronger rushers push the wall back faster (%.1f s vs %.1f s)" % [strong / 4, weak / 4])
	# You at defensive tackle, pushing straight at the quarterback.
	var h := user_defense(30.0, "base", 77)
	var dl = h.players.filter(func(p): return p.team == 0 and p.slot == "DL2")[0]
	h.select_at(dl.at)
	dl.took = true
	h._snap()
	for i in 60:
		h.step(1.0 / 120.0, Vector2(-h.dir[h.poss], 0))
		h.events.clear()
	var blocker = dl.engaged
	check(blocker != null and blocker.role == "OL", "a lineman takes the rusher in his square")
	if blocker != null:
		var depth: float = (dl.at.x - blocker.at.x) * h.dir[h.poss]
		check(depth > 0.5, "the rusher is held in front of the wall (%.2f yd)" % depth)


## Runs drill reps; returns them. `steer`: you push toward the ball
## (otherwise the computer plays your man).
func drill_reps(cfg: Dictionary, n: int, steer := false) -> Array:
	var g := Game.new(3, "balanced", 5, "balanced", 0, 900)
	g.start_drill(cfg)
	var guard := 0
	while g.drill_log.size() < n and guard < 120 * 20 * n:
		if g.phase == "presnap":
			g.drill_snap()
		var move := Vector2.ZERO
		if steer and g.phase == "live" and g.controlled != null:
			var target: Vector2 = g.carrier.at if g.carrier != null else g.qb.at
			move = (target - g.controlled.at).normalized()
		g.step(1.0 / 120.0, move)
		g.events.clear()
		guard += 1
	return g.drill_log


func wins(log: Array) -> int:
	return log.filter(func(r): return r.won).size()


func avg_gain(log: Array) -> float:
	var t := 0.0
	for r in log:
		t += r.gain
	return t / maxf(1.0, log.size())


func test_drill() -> void:
	pin_wall()
	var g := Game.new(3, "balanced", 5, "balanced", 0, 1)
	g.start_drill({play = "pass", line = 1, qb = false, rb = false, lb = false, side = "defense", dl = 0.7, ol = 0.7})
	check(g.players.size() == 2, "the 1 on 1 drill has just two players")
	check(g.controlled != null and g.controlled.role == "DL", "you play the defensive lineman")
	# The pass rush.
	var strong := wins(drill_reps({play = "pass", line = 1, side = "watch", dl = 0.95, ol = 0.4}, 6))
	var weak := wins(drill_reps({play = "pass", line = 1, side = "watch", dl = 0.35, ol = 0.95}, 6))
	check(strong >= 5, "a strong rusher beats a weak lineman (%d of 6)" % strong)
	check(weak <= 1, "a strong lineman holds off a weak rusher (%d of 6 sacks)" % weak)
	var pushing := wins(drill_reps({play = "pass", line = 1, side = "defense", dl = 0.7, ol = 0.7}, 4, true))
	check(pushing >= 3, "driving at the quarterback wins an even matchup (%d of 4)" % pushing)
	# Five on five, with a quarterback, a back and linebackers.
	var f := Game.new(3, "balanced", 5, "balanced", 0, 1)
	f.start_drill({play = "pass", line = 5, qb = true, rb = true, lb = true, side = "defense"})
	var count := func(role): return f.players.filter(func(p): return p.role == role).size()
	check(count.call("OL") == 5 and count.call("DL") == 5, "five linemen on each side")
	check(count.call("QB") == 1 and count.call("RB") == 1, "the quarterback and back are on the field")
	check(count.call("LB") == 3, "three linebackers when they're switched on")
	check(f.players.size() == 15, "nobody else (%d players)" % f.players.size())
	var apart: float = absf(f.players.filter(func(p): return p.role == "DL")[0].at.x - f.players.filter(func(p): return p.role == "OL")[0].at.x)
	check(is_equal_approx(apart, Tune.v.lineSplit), "the lines set up %.1f yd apart (%.2f)" % [Tune.v.lineSplit, apart])
	check(f.select_at(f.players.filter(func(p): return p.role == "LB")[0].at), "you can pick a linebacker")
	f.drill_snap()
	for i in 120:
		f.step(1.0 / 120.0)
		f.events.clear()
	var blocked := f.players.filter(func(p): return p.role == "OL" and p.engaged != null).size()
	check(blocked >= 4, "the wall picks up the rush (%d of 5 blocking)" % blocked)
	check(f.qb.at.distance_to(f.qb.home) > 2.0, "the quarterback drops back")
	var sacks := drill_reps({play = "pass", line = 5, qb = true, rb = true, lb = true, side = "watch"}, 3)
	check(sacks.size() == 3, "pass rush reps with a quarterback finish (%d)" % sacks.size())
	# Toggling a position off takes it off the field.
	var h := Game.new(3, "balanced", 5, "balanced", 0, 1)
	h.start_drill({play = "pass", line = 5, qb = true, rb = false, lb = false, side = "defense"})
	check(h.players.filter(func(p): return p.role == "RB" or p.role == "LB").is_empty(), "positions switched off aren't on the field")


func test_drill_run() -> void:
	pin_wall()
	# A run: the line drives the defense back and the back carries it.
	var g := Game.new(3, "balanced", 5, "balanced", 0, 1)
	g.start_drill({play = "run", line = 5, qb = true, rb = true, lb = true, side = "offense"})
	g.drill_snap()
	step_until(g, func(): return g.handed or g.phase != "live", 3.0)
	check(g.handed and g.carrier != null and g.carrier.role == "RB", "the quarterback hands off to the back")
	check(g.controlled == g.carrier, "on offense you take the back after the handoff")
	# With no quarterback the back takes a direct snap.
	var d := Game.new(3, "balanced", 5, "balanced", 0, 1)
	d.start_drill({play = "run", line = 1, qb = false, rb = false, lb = false, side = "watch"})
	check(d.players.any(func(p): return p.role == "RB"), "a run always has a ball carrier")
	d.drill_snap()
	check(d.carrier != null and d.carrier.role == "RB", "with no quarterback the back takes the snap")
	# A strong line opens holes; a weak one gets stuffed.
	var strong := drill_reps({play = "run", line = 5, qb = true, rb = true, lb = true, side = "watch", dl = 0.35, ol = 0.95}, 5)
	var weak := drill_reps({play = "run", line = 5, qb = true, rb = true, lb = true, side = "watch", dl = 0.95, ol = 0.35}, 5)
	print("drill runs: strong line %.1f yd a carry, weak line %.1f" % [avg_gain(strong), avg_gain(weak)])
	check(avg_gain(strong) > avg_gain(weak), "a strong line gains more on the ground (%.1f vs %.1f yd)" % [avg_gain(strong), avg_gain(weak)])
	# You on defense, going after the runner.
	var you := drill_reps({play = "run", line = 1, qb = false, rb = true, lb = false, side = "defense", dl = 0.7, ol = 0.7}, 4, true)
	check(you.size() == 4, "run reps against you finish (%d)" % you.size())
	Tune.reset()


func test_downs() -> void:
	var g := Game.new(0, "balanced", 4, "balanced", -1, 5)
	g.give_ball(0, 40.0)
	g.down = 4
	g.togo = 8.0
	var key := g.ai_offense_call()
	check(key in ["punt", "fg"], "4th and long: kick (%s)" % key)
	g.los = 75.0
	check(g.ai_offense_call() == "fg", "4th and long in range: field goal")
	# Turnover on downs.
	var h := user_offense(50.0, "dive")
	h.down = 4
	h.togo = 30.0
	h.hike()
	step_until(h, func(): return h.phase == "dead", 20.0)
	check(h.poss == 1, "failing on 4th down turns it over (poss %d, msg %s)" % [h.poss, h.msg])


func test_kicks() -> void:
	var g := user_offense(80.0, "fg")
	check(g.phase == "kick", "a field goal is kicked")
	var s0: int = g.score[0]
	step_until(g, func(): return g.phase == "dead", 5.0)
	check(g.score[0] == s0 + 3 or g.poss == 1, "the field goal scores 3 or the other team gets the ball")
	var p := user_offense(30.0, "punt")
	step_until(p, func(): return p.phase == "dead", 5.0)
	check(p.poss == 1, "after a punt the other team has the ball")
	check(p.los > 1.0 and p.los <= 50.0, "the punt pins them deep (their %.0f)" % p.los)


func test_quarter_keeps_kickoff() -> void:
	# A touchdown on the last play of the 1st quarter: the kickoff still happens after the break.
	var g := Game.new(0, "balanced", 4, "balanced", -1, 8)
	g.give_ball(0, 98.0)
	g.clock = 0.005
	g.phase = "live"
	g.players.clear()
	g.choose_offense("sneak")
	g.choose_defense("base")
	g.off_call = Playbook.play("sneak")
	g.def_call = Playbook.defense("base")
	g._setup()
	g._snap()
	g.carrier.at.x = g.fx(0, 100.5)
	g.step(1.0 / 120.0)
	check(g.score[0] == 6 or g.score[0] == 7, "touchdown counted (%d)" % g.score[0])
	step_until(g, func(): return g.phase == "presnap", 10.0)
	check(g.quarter == 2, "on to the 2nd quarter")
	check(g.poss == 1 and is_equal_approx(g.los, Tune.v.touchback), "the other team gets the kickoff after the quarter break (poss %d, los %.0f)" % [g.poss, g.los])


func test_schedule() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var s := League.schedule(8, 7, rng)
	check(s.size() == 7, "7 weeks")
	var met := {}
	var ok := true
	for w in s:
		var seen := {}
		for m in w:
			for t in m:
				if seen.has(t):
					ok = false
				seen[t] = true
			met[[mini(m[0], m[1]), maxi(m[0], m[1])]] = true
		if seen.size() != 8:
			ok = false
	check(ok, "everyone plays once a week")
	check(met.size() == 28, "everyone plays everyone once (%d pairs)" % met.size())


func test_season() -> void:
	League.new_season(2, "smashmouth", 77)
	check(League.data.active and League.weeks() == int(Tune.v.seasonGames), "a season starts")
	check(League.data.types[2] == "smashmouth", "your team plays your type")
	var guard := 0
	while not League.season_over() and guard < 20:
		guard += 1
		var m := League.next_game()
		if m.is_empty():
			break
		League.record(m[0], m[1], 21, 14)
	check(League.data.week == League.weeks(), "every week is played")
	check(League.data.results.size() == League.weeks() * 4, "every game has a result")
	check(League.season_over(), "the North Bowl is decided")
	var st := League.standings()
	check(st[0].w >= st[-1].w, "standings are sorted")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(League.PATH))


## Steps a game until it's over (or a limit), auto-calling plays.
func run_game(g: Game, max_steps := 400000) -> int:
	var steps := 0
	while g.phase != "final" and steps < max_steps:
		g.step(1.0 / 60.0)
		g.events.clear()
		steps += 1
	return steps


func test_full_games() -> void:
	var total := 0
	for seed_value in [1, 2, 3, 4]:
		var g := Game.new(seed_value % 8, Teams.TYPES.keys()[seed_value % 6], (seed_value + 3) % 8, "balanced", -1, seed_value)
		var steps := run_game(g)
		check(g.phase == "final", "game %d finished (phase %s, quarter %d)" % [seed_value, g.phase, g.quarter])
		check(g.plays > 30, "game %d had a real number of plays (%d)" % [seed_value, g.plays])
		total += g.score[0] + g.score[1]
		print("game %d: %s %d - %s %d in %d plays" % [seed_value, g.teams[0].abbr, g.score[0], g.teams[1].abbr, g.score[1], g.plays])
	check(total / 4 < 90, "scores look like football (avg %d combined)" % (total / 4))
