## Plays many computer-vs-computer plays and prints how each play call does:
##   godot --headless --path . -s res://tests/balance_probe.gd
extends SceneTree


func _init() -> void:
	Tune.ensure()
	var by := {}
	var scores := []
	for g_i in 8:
		var g := Game.new(g_i % 8, Teams.TYPES.keys()[g_i % 6], (g_i + 3) % 8, Teams.TYPES.keys()[(g_i + 2) % 6], -1, 100 + g_i)
		var n := 0
		while g.phase != "final" and n < 400000:
			var before := g.plays
			g.step(1.0 / 60.0)
			g.events.clear()
			n += 1
			if g.plays != before and not g.last.is_empty():
				var k: String = g.last.play
				if not by.has(k):
					by[k] = {n = 0, yds = 0, td = 0, inc = 0, sack = 0, int = 0, big = 0}
				var b: Dictionary = by[k]
				b.n += 1
				if g.last.kind == "incomplete":
					b.inc += 1
				elif g.last.kind == "td":
					b.td += 1
				elif g.last.kind == "sack":
					b.sack += 1
				if g.last.head == "INTERCEPTED!":
					b.int += 1
				b.yds += g.last.gain if g.last.team == g.poss or g.last.kind != "td" else 0
				if g.last.gain >= 20:
					b.big += 1
				g.last = {}
		scores.append("%d-%d" % g.score)
	print("scores: ", ", ".join(scores))
	for k in by:
		var b: Dictionary = by[k]
		print("%-12s n=%3d avg=%5.1f td=%2d inc=%3d sack=%2d int=%2d 20+=%2d" % [k, b.n, float(b.yds) / b.n, b.td, b.inc, b.sack, b.int, b.big])
	quit()
