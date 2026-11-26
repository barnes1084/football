## Runs the game: the fixed-step loop, the touch controls (pull back to
## throw, flick to juke or dive, a move stick to run), the keyboard, the HUD
## and the menus (title, team and strength picks, the season, play calling,
## pause, results).
extends Node

const STEP := 1.0 / 120.0

var screen := "title"
var g: Game
var field: Field
var hud: Hud
var menu: Control
var settings: SettingsUI
var drag = null
var stick = null
var acc := 0.0
var touch := DisplayServer.is_touchscreen_available()
var season_game := false
var _pick := {team = 0, type = "balanced", quick = false}
var _call_tab := "run"
var _shown_call := ""


func _ready() -> void:
	Tune.ensure()
	League.load_data()
	field = Field.new()
	add_child(field)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 1
	add_child(hud_layer)
	hud = Hud.new()
	hud.main = self
	hud_layer.add_child(hud)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 2
	add_child(menu_layer)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.theme = UI.theme()
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(menu)
	var settings_layer := CanvasLayer.new()
	settings_layer.layer = 3
	add_child(settings_layer)
	settings = SettingsUI.new()
	settings.visible = false
	settings_layer.add_child(settings)
	settings.changed.connect(_settings_changed)
	get_viewport().size_changed.connect(_apply_insets)
	_apply_insets.call_deferred()
	show_title()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot.call_deferred(arg.substr(7))


## For automated checks: `-- --shot=<what>,<file>` sets up a screen, lets it
## run, saves a screenshot and quits. <what> is title, call, presnap, live,
## defense or input (plays touches through the real input path and checks
## the controls work).
func _shot(spec: String) -> void:
	var parts := spec.split(",")
	var what := parts[0]
	var file := parts[1] if parts.size() > 1 else "user://shot.png"
	match what:
		"call":
			_start_game(5, "balanced", 3, "strong_d", false, 0)
			g.give_ball(0, 25.0)
		"presnap", "live", "input":
			_start_game(5, "balanced", 3, "strong_d", false, 0)
			g.give_ball(0, 25.0)
			_choose_offense("verticals" if what != "presnap" else "power_l")
			await _wait(0.6)
			if what == "live":
				g.hike()
				await _wait(1.0)
			elif what == "input":
				var ok := await _input_check()
				print("INPUT CHECK -> ", "ok" if ok else "FAILED")
				if not ok:
					get_tree().quit(1)
					return
		"defense":
			_start_game(5, "balanced", 3, "strong_d", false, 1)
			g.give_ball(0, 35.0)
			_choose_defense("base")
			await _wait(4.5)
		"call_settings":
			# SETTINGS from the play call menu, then back to the play call.
			_start_game(5, "balanced", 3, "strong_d", false, 0)
			g.give_ball(0, 25.0)
			await _run_until(func(): return _shown_call != "", 5.0)
			var shown := _shown_call
			_open_settings(func(): pass)
			await _wait(0.3)
			var opened := settings.visible
			settings.close()
			await _wait(0.3)
			print("CALL SETTINGS shown=%s opened=%s back=%s" % [shown, opened, _shown_call])
			pause()
			await _wait(0.2)
			var paused := screen == "paused"
			resume()
			await _wait(0.3)
			print("CALL PAUSE paused=%s back=%s" % [paused, _shown_call])
		"carrier":
			# The computer runs it: the red ring follows the ball carrier.
			_start_game(5, "balanced", 3, "strong_d", false, 1)
			g.give_ball(0, 35.0)
			g.off_call = Playbook.play("power_r")
			_choose_defense("base")
			await _run_until(func(): return g.handed, 8.0)
			await _wait(0.4)
		"teams":
			_pick_team(false)
		"types":
			_pick.team = 6
			_pick_type()
		"season":
			League.new_season(6, "air_raid", 5)
			League.record(League.next_game()[0], League.next_game()[1], 24, 17)
			show_season()
		_:
			await _wait(1.5)
	await _wait(0.3)
	var img := get_viewport().get_texture().get_image()
	img.save_png(file)
	print("saved ", ProjectSettings.globalize_path(file))
	get_tree().quit()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _run_until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()


## Pulls back on the action side to throw, through the real touch events.
func _input_check() -> bool:
	var vs := get_viewport().get_visible_rect().size
	var touch_ev := func(i: int, pos: Vector2, down: bool):
		var e := InputEventScreenTouch.new()
		e.index = i
		e.position = pos
		e.pressed = down
		Input.parse_input_event(e)
	var drag_ev := func(i: int, pos: Vector2):
		var e := InputEventScreenDrag.new()
		e.index = i
		e.position = pos
		Input.parse_input_event(e)
	# A tap hikes the ball.
	touch_ev.call(0, Vector2(vs.x * 0.7, vs.y * 0.5), true)
	await get_tree().process_frame
	touch_ev.call(0, Vector2(vs.x * 0.7, vs.y * 0.5), false)
	await _wait(0.2)
	var hiked := g.phase == "live"
	# Run with the stick on the right while the quarterback drops.
	var st := Vector2(vs.x * 0.8, vs.y * 0.7)
	touch_ev.call(1, st, true)
	await get_tree().process_frame
	for i in 6:
		drag_ev.call(1, st + Vector2(0, -12.0 * (i + 1)))
		await get_tree().process_frame
	var y0 := g.qb.at.y
	await _wait(0.3)
	var moved := absf(g.qb.at.y - y0) > 0.3
	touch_ev.call(1, st + Vector2(0, -72), false)
	await get_tree().process_frame
	var can := g.can_throw()
	# Pull back on the left and let go: a throw downfield.
	var a := Vector2(vs.x * 0.3, vs.y * 0.5)
	touch_ev.call(0, a, true)
	await get_tree().process_frame
	var pull := Vector2(-g.dir[g.poss] * vs.y * 0.18, 0)
	for i in 4:
		drag_ev.call(0, a + pull * (i + 1) / 4.0)
		await get_tree().process_frame
	var aimed := field.aim != null
	touch_ev.call(0, a + pull, false)
	await get_tree().process_frame
	var threw: bool = not g.ball.is_empty() or g.last.get("kind", "") in ["incomplete", "td"] or (g.carrier != null and g.carrier != g.qb)
	print("INPUT CHECK hiked=%s moved=%s could_throw=%s aimed=%s threw=%s (phase %s, %s)" % [hiked, moved, can, aimed, threw, g.phase, g.msg])
	return hiked and moved and can and aimed and threw


# ---------- Games ----------

func demo() -> void:
	var a := randi() % 8
	var b := (a + 1 + randi() % 7) % 8
	var types := Teams.TYPES.keys()
	_set_game(Game.new(a, types[randi() % types.size()], b, types[randi() % types.size()], -1))


func _set_game(game: Game) -> void:
	g = game
	field.set_game(g)
	_cancel_pointers()


## Starts a game you play. `side` 0 = you're the home team, 1 = away.
func _start_game(me: int, me_type: String, them: int, them_type: String, playoff: bool, side := 0) -> void:
	var home := me if side == 0 else them
	var away := them if side == 0 else me
	var game := Game.new(home, me_type if side == 0 else them_type, away, them_type if side == 0 else me_type, side, League.data.seed if season_game else 0)
	game.playoff = playoff
	_set_game(game)
	screen = "play"
	clear_menu()
	Sfx.music("game")
	Sfx.crowd(true)


func _play_season_game() -> void:
	var m := League.next_game()
	if m.is_empty():
		show_season()
		return
	season_game = true
	var me: int = League.data.team
	var side := 0 if m[0] == me else 1
	var them: int = m[1] if side == 0 else m[0]
	_start_game(me, League.data.type, them, League.type_of(them), League.is_bowl(), side)


func finish_game() -> void:
	screen = "result"
	Sfx.crowd(false)
	Sfx.music("menu")
	var me := g.user
	var won := g.winner() == me
	var tie := g.winner() == -1
	var bowl := false
	if season_game:
		bowl = League.is_bowl()
		League.record(g.teams[0].index, g.teams[1].index, g.score[0], g.score[1])
	clear_menu()
	var box := UI.screen(menu, 1100)
	var head := "VICTORY!" if won else ("TIE GAME" if tie else "DEFEAT")
	if bowl and won:
		head = "NORTH BOWL CHAMPIONS!"
	box.add_child(UI.title(head, 76, Color("#ffdc3c") if won else (Color.WHITE if tie else Color("#ff8a8a"))))
	box.add_child(UI.label("%s %d   ·   %s %d" % [Teams.full_name(g.teams[0].index), g.score[0], Teams.full_name(g.teams[1].index), g.score[1]], 34))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 50)
	for row in [["", g.teams[0].abbr, g.teams[1].abbr], ["Passing yards", str(g.stats[0].pass_yds), str(g.stats[1].pass_yds)],
			["Rushing yards", str(g.stats[0].rush_yds), str(g.stats[1].rush_yds)], ["First downs", str(g.stats[0].first), str(g.stats[1].first)],
			["Turnovers", str(g.stats[0].to), str(g.stats[1].to)], ["Sacks", str(g.stats[0].sacks), str(g.stats[1].sacks)]]:
		for i in 3:
			grid.add_child(UI.label(row[i], 26, UI.PALE if i == 0 else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_CENTER))
	var c := CenterContainer.new()
	c.add_child(grid)
	box.add_child(c)
	if season_game:
		box.add_child(UI.button("CONTINUE SEASON", show_season, "big"))
	else:
		box.add_child(UI.button("PLAY AGAIN", func(): _start_game(_pick.team, _pick.type, g.teams[1 - me].index, g.teams[1 - me].type, false, me), "big"))
	box.add_child(UI.button("TITLE SCREEN", show_title))


# ---------- Menus ----------

func clear_menu() -> void:
	for c in menu.get_children():
		c.queue_free()
	_shown_call = ""


func show_title() -> void:
	screen = "title"
	season_game = false
	Sfx.music("menu")
	Sfx.crowd(false)
	demo()
	clear_menu()
	var box := UI.screen(menu, 900)
	var t := UI.title("GRIDIRON NORTH", 92)
	box.add_child(t)
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			_title_tap())
	box.add_child(UI.label("Eleven on eleven, old-school. Eight northern teams, one North Bowl.", 26, UI.PALE))
	box.add_child(_gap(6))
	if League.data.active and not League.season_over():
		box.add_child(UI.button("CONTINUE SEASON · %s %s" % [Teams.info(League.data.team).abbr, League.record_text(League.data.team)], show_season, "big"))
		box.add_child(UI.button("NEW SEASON", _confirm_new))
	else:
		box.add_child(UI.button("NEW SEASON", func(): _pick_team(false), "big"))
	box.add_child(UI.button("QUICK GAME", func(): _pick_team(true)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UI.button("HOW TO PLAY", _how_to))
	row.add_child(UI.button("SETTINGS", func(): _open_settings(show_title)))
	box.add_child(row)


func _confirm_new() -> void:
	clear_menu()
	var box := UI.screen(menu, 760)
	box.add_child(UI.title("NEW SEASON?", 60))
	box.add_child(UI.label("Your current season will be lost.", 28, UI.PALE))
	box.add_child(UI.button("START OVER", func(): _pick_team(false), "big"))
	box.add_child(UI.button("CANCEL", show_title))


func _pick_team(quick: bool) -> void:
	screen = "menu"
	_pick.quick = quick
	clear_menu()
	var box := UI.screen(menu, 1500)
	box.add_child(UI.title("PICK YOUR TEAM", 60))
	for div in ["AFC North", "NFC North"]:
		box.add_child(UI.label(div.to_upper(), 24, UI.PALE))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in Teams.TEAMS.size():
			var t: Dictionary = Teams.TEAMS[i]
			if t.div != div:
				continue
			var b := UI.button("%s\n%s" % [t.city, t.name], func():
				_pick.team = i
				_pick_type())
			UI.style_button(b, Color(t.jersey), Color(t.helmet).lightened(0.2) if Color(t.helmet) != Color(t.jersey) else Color(t.trim))
			b.custom_minimum_size = Vector2(300, 130)
			b.add_theme_font_size_override("font_size", 26)
			row.add_child(b)
		box.add_child(row)
	box.add_child(UI.button("BACK", show_title))


func _pick_type() -> void:
	clear_menu()
	var box := UI.screen(menu, 1500)
	box.add_child(UI.title("TEAM STRENGTH", 60))
	box.add_child(UI.label("How do the %s play?" % Teams.full_name(_pick.team), 26, UI.PALE))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for key in Teams.TYPES:
		var ty: Dictionary = Teams.TYPES[key]
		var b := UI.button(ty.label, func():
			_pick.type = key
			if _pick.quick:
				_quick_game()
			else:
				League.new_season(_pick.team, key)
				show_season(), "big" if key != "tank" else "")
		b.custom_minimum_size = Vector2(440, 0)
		var v := VBoxContainer.new()
		v.add_child(b)
		var l := UI.label(ty.about, 20, UI.PALE)
		l.custom_minimum_size = Vector2(440, 70)
		v.add_child(l)
		grid.add_child(v)
	var c := CenterContainer.new()
	c.add_child(grid)
	box.add_child(c)
	box.add_child(UI.button("BACK", func(): _pick_team(_pick.quick)))


func _quick_game() -> void:
	season_game = false
	var them: int = (int(_pick.team) + 1 + randi() % 7) % 8
	var pool := Teams.TYPES.keys().filter(func(t): return t != "tank")
	_start_game(_pick.team, _pick.type, them, pool[randi() % pool.size()], false, randi() % 2)


func show_season() -> void:
	screen = "menu"
	season_game = false
	Sfx.music("menu")
	Sfx.crowd(false)
	if g == null or g.user >= 0:
		demo()
	clear_menu()
	var d := League.data
	var box := UI.screen(menu, 1300)
	var me: int = d.team
	box.add_child(UI.title(Teams.full_name(me).to_upper(), 56))
	box.add_child(_line("%s · %s" % [Teams.TYPES[d.type].label, League.record_text(me)], 26, UI.PALE))
	var cols := HBoxContainer.new()
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_theme_constant_override("separation", 50)
	# Standings.
	var st := VBoxContainer.new()
	st.add_theme_constant_override("separation", 4)
	st.add_child(_line("STANDINGS", 24, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	var rank := 1
	for r in League.standings():
		var t := Teams.info(r.team)
		var line := "%d. %-12s %d-%d%s   %d-%d" % [rank, t.city, r.w, r.l, ("-%d" % r.t) if r.t else "", r.pf, r.pa]
		st.add_child(_line(line, 22, UI.GOLD if r.team == me else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
		rank += 1
	cols.add_child(st)
	# Your schedule.
	var sc := VBoxContainer.new()
	sc.add_theme_constant_override("separation", 4)
	sc.add_child(_line("SCHEDULE", 24, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	for w in League.weeks():
		for m in d.schedule[w]:
			if int(m[0]) != me and int(m[1]) != me:
				continue
			var home := int(m[0]) == me
			var opp := int(m[1]) if home else int(m[0])
			var res := ""
			for r in d.results:
				if int(r.week) == w and int(r.home) == int(m[0]) and int(r.away) == int(m[1]):
					var mine := int(r.hs) if home else int(r.as_)
					var theirs := int(r.as_) if home else int(r.hs)
					res = "  %s %d-%d" % ["W" if mine > theirs else ("L" if mine < theirs else "T"), mine, theirs]
			sc.add_child(_line("Wk %d  %s %s%s" % [w + 1, "vs" if home else "at", Teams.info(opp).city, res], 22, Color.WHITE if res != "" or w != d.week else UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	cols.add_child(sc)
	box.add_child(cols)
	if League.season_over():
		var champ: int = d.champion
		var b: Dictionary = d.bowl
		box.add_child(_line("NORTH BOWL: %s %d · %s %d" % [Teams.info(int(b.home)).abbr, int(b.get("hs", 0)), Teams.info(int(b.away)).abbr, int(b.get("as_", 0))], 28, UI.GOLD))
		box.add_child(UI.title("%s WIN IT ALL!" % Teams.full_name(champ).to_upper() if champ != me else "YOU WON THE NORTH BOWL!", 40, Color("#ffdc3c")))
		box.add_child(UI.button("NEW SEASON", func(): _pick_team(false), "big"))
	else:
		var m := League.next_game()
		if m.is_empty():
			box.add_child(UI.label("Season over: you didn't make the North Bowl.", 26, UI.PALE))
			box.add_child(UI.button("NEW SEASON", func(): _pick_team(false), "big"))
		else:
			var opp: int = m[1] if m[0] == me else m[0]
			var what := "NORTH BOWL" if League.is_bowl() else "WEEK %d" % (d.week + 1)
			box.add_child(UI.button("PLAY %s · %s %s (%s)" % [what, "VS" if m[0] == me else "AT", Teams.full_name(opp).to_upper(), Teams.TYPES[League.type_of(opp)].label], _play_season_game, "big"))
	box.add_child(UI.button("TITLE SCREEN", show_title))


func _how_to() -> void:
	clear_menu()
	var box := UI.screen(menu, 1300)
	box.add_child(UI.title("HOW TO PLAY", 60))
	var lines := [
		"Before each play, pick a play: runs, passes, or a punt or field goal on 4th down. On defense, pick a defense.",
		"OFFENSE: tap to hike. RIGHT side: drag to run. As the quarterback, pull back on the LEFT side and let go to throw (the farther you pull, the farther it goes; the green ring means a receiver is there).",
		"With the ball in a runner's or receiver's hands, flick on the LEFT side to juke that way. Tacklers miss more during a juke.",
		"DEFENSE: tap any defender to play him. Move him before the snap, but cross the blue line and it's offside: 5 yards.",
		"After the snap, RIGHT side runs and a flick on the LEFT side is a diving tackle. Miss, and you're on the ground for a moment.",
		"Keyboard: arrows or WASD to run, Space to hike / throw to the open man / juke / dive, Tab to switch defender, P to pause.",
	]
	for l in lines:
		box.add_child(UI.label(l, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(UI.button("GOT IT", show_title, "big"))


var _taps := 0
var _tap_at := 0


func _title_tap() -> void:
	var now := Time.get_ticks_msec()
	_taps = _taps + 1 if now - _tap_at < 900 else 1
	_tap_at = now
	if _taps >= 7 and Tune.can_toggle_dev():
		_taps = 0
		Tune.set_dev(not Tune.dev)
		_settings_changed()
		Sfx.play("select")
		_toast("Developer settings ON" if Tune.dev else "Developer settings OFF")


func _toast(text: String) -> void:
	var l := UI.label(text, 30, Color("#ffdc3c"))
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l.position.y -= 90
	l.position.x -= 300
	l.custom_minimum_size.x = 600
	menu.add_child(l)
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _open_settings(back: Callable) -> void:
	clear_menu()
	settings.open()
	for c in settings.closed.get_connections():
		settings.closed.disconnect(c.callable)
	settings.closed.connect(back, CONNECT_ONE_SHOT)


func _settings_changed() -> void:
	Sfx.apply()


## A one-line label (labels in a row would otherwise wrap letter by letter).
static func _line(text: String, size := 24, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := UI.label(text, size, color, align)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


static func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func pause() -> void:
	if screen != "play" or g == null or g.phase == "final":
		return
	screen = "paused"
	_cancel_pointers()
	clear_menu()
	var box := UI.screen(menu, 760)
	box.add_child(UI.title("TIME OUT", 70))
	box.add_child(UI.label("%s %d · %s %d · %s %s" % [g.teams[0].abbr, g.score[0], g.teams[1].abbr, g.score[1], g.quarter_text(), g.time_text()], 26, UI.PALE))
	box.add_child(UI.button("RESUME", resume, "big"))
	box.add_child(UI.button("SETTINGS", func(): _open_settings(func():
		screen = "play"
		pause())))
	box.add_child(UI.button("QUIT GAME", func():
		if season_game:
			_confirm_forfeit()
		else:
			show_title()))


func _confirm_forfeit() -> void:
	clear_menu()
	var box := UI.screen(menu, 800)
	box.add_child(UI.title("QUIT?", 60))
	box.add_child(UI.label("A season game you quit counts as a loss.", 28, UI.PALE))
	box.add_child(UI.button("FORFEIT", func():
		var me := g.user
		var them := 1 - me
		g.score[them] = maxi(g.score[them], g.score[me] + 1)
		finish_game(), "big"))
	box.add_child(UI.button("KEEP PLAYING", func():
		screen = "play"
		pause()))


func resume() -> void:
	screen = "play"
	clear_menu()


# ---------- Play calling ----------

func _show_call(kind: String) -> void:
	_shown_call = kind
	for c in menu.get_children():
		c.queue_free()
	var box := UI.screen(menu, 1700)
	var me := g.user
	var line := "%s · ball on %s" % [g.down_text(), g.spot_text(g.poss, g.los)]
	box.add_child(UI.label(("YOUR BALL · " if kind == "offense" else "DEFENSE · ") + line, 30, UI.GOLD))
	if kind == "offense":
		var tabs := HBoxContainer.new()
		tabs.alignment = BoxContainer.ALIGNMENT_CENTER
		for tab in [["run", "RUN"], ["pass", "PASS"], ["kick", "KICK"]]:
			var b := UI.button(tab[1], func():
				_call_tab = tab[0]
				_show_call(kind))
			UI.style_button(b, UI.RED if _call_tab == tab[0] else Color("#2c4a8a"), UI.GOLD if _call_tab == tab[0] else Color(1, 1, 1, 0.3))
			b.custom_minimum_size.x = 220
			tabs.add_child(b)
		box.add_child(tabs)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		var list: Array = Playbook.runs() if _call_tab == "run" else (Playbook.passes() if _call_tab == "pass" else Playbook.KICKS)
		for p in list:
			var card := PlayCard.new()
			card.play = p
			card.mirror = g.dir[g.poss] < 0
			card.custom_minimum_size = Vector2(380, 250)
			var fg_dist := 100.0 - g.los + 17.0
			if p.key == "fg":
				card.note = "%d yards" % roundi(fg_dist)
				card.disabled = fg_dist > 65.0
			card.chosen.connect(_choose_offense)
			grid.add_child(card)
		var c := CenterContainer.new()
		c.add_child(grid)
		box.add_child(c)
	else:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		for d in Playbook.DEFENSES:
			var card := PlayCard.new()
			card.play = d
			card.defense = true
			card.custom_minimum_size = Vector2(480, 230)
			card.chosen.connect(_choose_defense)
			grid.add_child(card)
		var c := CenterContainer.new()
		c.add_child(grid)
		box.add_child(c)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var score := UI.label("%s %d · %s %d · %s %s" % [g.teams[0].abbr, g.score[0], g.teams[1].abbr, g.score[1], g.quarter_text(), g.time_text()], 24, UI.PALE)
	score.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(score)
	var pause_btn := UI.button("PAUSE", pause)
	pause_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pause_btn)
	# Settings, then straight back to picking the play.
	var set_btn := UI.button("SETTINGS", func(): _open_settings(func(): pass))
	set_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(set_btn)
	box.add_child(row)


func _choose_offense(key: String) -> void:
	Sfx.play("tick")
	clear_menu()
	g.choose_offense(key)


func _choose_defense(key: String) -> void:
	Sfx.play("tick")
	clear_menu()
	g.choose_defense(key)


# ---------- Input ----------

## Which half of the screen is the action side (throw, juke, dive).
func _is_action_side(pos: Vector2) -> bool:
	var left := pos.x < get_viewport().get_visible_rect().size.x / 2
	return left != bool(Tune.v.swapSides)


func _px(v: float) -> float:
	return v * get_viewport().get_visible_rect().size.y / 540.0


func _press(id: int, pos: Vector2) -> void:
	if _is_action_side(pos):
		if drag == null:
			drag = {id = id, start = pos, at = pos, moved = false, t = Time.get_ticks_msec()}
	elif stick == null:
		stick = {id = id, origin = pos, at = pos, moved = false}


func _move(id: int, pos: Vector2) -> void:
	if drag != null and drag.id == id:
		drag.at = pos
		if not drag.moved and pos.distance_to(drag.start) > _px(Tune.v.tapSlop):
			drag.moved = true
		if drag.moved and g.can_throw():
			g.aiming = true
			_update_aim()
	elif stick != null and stick.id == id:
		stick.at = pos
		if pos.distance_to(stick.origin) > _px(Tune.v.tapSlop):
			stick.moved = true


func _release(id: int, pos: Vector2) -> void:
	if drag != null and drag.id == id:
		drag.at = pos
		if not drag.moved:
			_tap(pos)
		elif g.can_throw():
			_update_aim()
			if field.aim != null and field.aim.ok:
				g.player_throw(field.aim.raw)
		elif pos.distance_to(drag.start) > _px(Tune.v.flickMin):
			g.flick(field.drag_to_field(pos - drag.start))
		drag = null
		field.aim = null
		g.aiming = false
	elif stick != null and stick.id == id:
		if not stick.moved:
			_tap(pos)
		stick = null


func _tap(pos: Vector2) -> void:
	if g.phase == "presnap" and g.poss == g.user:
		g.hike()
	elif g.user >= 0 and g.ball_team() != g.user:
		g.select_at(field.to_field(pos))


## Pull back from where the finger went down: the throw goes the other way,
## farther the longer the pull.
func _update_aim() -> void:
	if drag == null or not g.can_throw():
		field.aim = null
		return
	var vs := get_viewport().get_visible_rect().size
	var pull: Vector2 = drag.start - drag.at
	var frac := clampf(pull.length() / (Tune.v.dragFull * vs.y), 0.0, 1.0)
	var dir_f := field.drag_to_field(pull).normalized()
	var raw := g.qb.at + dir_f * frac * g.max_throw()
	var a := g.aim_point(raw)
	field.aim = {from = g.qb.at, to = a.to, rec = a.rec, raw = raw, ok = frac >= Tune.v.minPull}


func stick_vector() -> Vector2:
	if stick == null:
		return Vector2.ZERO
	var r := _px(Tune.v.stickSize)
	var v: Vector2 = (stick.at - stick.origin) / r
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() < Tune.v.stickDeadzone:
		return Vector2.ZERO
	# The field is squashed on screen: up and down on the stick cover more ground.
	return v


func _cancel_pointers() -> void:
	drag = null
	stick = null
	if field:
		field.aim = null
	if g:
		g.aiming = false


const MOUSE_ID := 1000


func _unhandled_input(e: InputEvent) -> void:
	if screen != "play" or settings.visible or g == null or g.needs_call() != "":
		if e is InputEventScreenTouch or e is InputEventMouseButton:
			_cancel_pointers()
		return
	if e is InputEventScreenTouch:
		touch = true
		if e.pressed:
			_press(e.index, e.position)
		else:
			_release(e.index, e.position)
	elif e is InputEventScreenDrag:
		_move(e.index, e.position)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.device != InputEvent.DEVICE_ID_EMULATION:
		if e.pressed:
			_press(MOUSE_ID, e.position)
		else:
			_release(MOUSE_ID, e.position)
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION:
		_move(MOUSE_ID, e.position)


func _unhandled_key_input(e: InputEvent) -> void:
	if not e.pressed or e.echo or settings.visible:
		return
	match e.keycode:
		KEY_P, KEY_ESCAPE:
			if screen == "play":
				pause()
			elif screen == "paused":
				resume()
		KEY_TAB:
			if screen == "play":
				_cycle()
		KEY_SPACE, KEY_ENTER:
			if screen == "play":
				_space()


## Space: hike, throw to the most open man, juke or dive (toward where you're running).
func _space() -> void:
	if g.phase == "presnap" and g.poss == g.user:
		g.hike()
		return
	var mv := (_key_move() + stick_vector()).limit_length(1.0)
	if g.can_throw():
		var best = null
		var bd := -INF
		for p in g.players:
			if p.team == g.user and g.eligible(p):
				var open := INF
				for o in g.players:
					if o.team != g.user:
						open = minf(open, o.at.distance_to(p.at))
				if open > bd:
					bd = open
					best = p
		if best != null:
			g.player_throw(best.at + best.vel * g.flight_time(g.qb.at.distance_to(best.at)))
		return
	if g.controlled != null:
		var d := mv if mv.length() > 0.1 else Vector2(g.dir[g.ball_team()] if g.controlled.team == g.ball_team() else -g.dir[g.ball_team()], 0)
		if g.controlled == g.carrier and mv.length() > 0.1:
			d = Vector2(mv.x * 0.4, mv.y).normalized()
		elif g.controlled != g.carrier and g.carrier != null:
			d = (g.carrier.at - g.controlled.at).normalized()
		g.flick(d)


func _cycle() -> void:
	if g.user < 0 or g.ball_team() == g.user:
		return
	var mine := g.players.filter(func(p): return p.team == g.user)
	if mine.is_empty():
		return
	var i := mine.find(g.controlled)
	var p = mine[(i + 1) % mine.size()]
	g.select_at(p.at)


func _key_move() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1
	return v


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if settings.visible:
				settings.close()
			elif screen == "play":
				pause()
			elif screen == "paused":
				resume()
			elif screen in ["menu", "result"]:
				show_title()
			else:
				get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			pause()


## Room kept clear at the screen's edges (notch, rounded corners).
var inset_left := 0.0
var inset_right := 0.0


func _apply_insets() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := safe_area_insets(view)
	inset_left = safe.x
	inset_right = safe.y
	hud.position = Vector2(inset_left, safe.z)
	for c in [menu, settings]:
		c.offset_left = inset_left
		c.offset_right = -inset_right
		c.offset_top = safe.z


static func safe_area_insets(view: Vector2) -> Vector3:
	if not OS.has_feature("mobile"):
		return Vector3.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return Vector3.ZERO
	var kk := view.x / win.x
	return Vector3(
		clampf(safe.position.x, 0, win.x * 0.2) * kk,
		clampf(win.x - safe.end.x, 0, win.x * 0.2) * kk,
		clampf(safe.position.y, 0, win.y * 0.2) * (view.y / win.y))


# ---------- Loop ----------

func _process(delta: float) -> void:
	if g == null:
		return
	var running := not settings.visible and screen in ["play", "title", "menu", "result"]
	if running:
		# The person picks a play: the game waits.
		var need := g.needs_call() if screen == "play" else ""
		if need != "":
			if _shown_call != need:
				_cancel_pointers()
				_call_tab = "pass" if g.togo >= 8 and g.down >= 2 else ("kick" if g.down == 4 and g.togo > 2 else "run")
				_show_call(need)
		acc += minf(delta, 0.1) * Tune.v.gameSpeed
		var move := (_key_move() + stick_vector()).limit_length(1.0) if screen == "play" else Vector2.ZERO
		while acc >= STEP:
			g.step(STEP, move)
			acc -= STEP
		for e in g.events:
			if screen == "play":
				Sfx.event(e, g.user)
				if e.type == "tackle" and e.get("big", false):
					field.shake = 1.0
		g.events.clear()
		if screen == "play" and g.phase == "final" and g.phase_t > 2.5:
			finish_game()
		if screen != "play" and g.phase == "final" and g.phase_t > 3.0:
			demo()
	else:
		acc = 0.0
	if drag != null and g.aiming:
		_update_aim()
	hud.queue_redraw()


# ---------- A play card (with a little diagram) ----------

class PlayCard:
	extends Button
	signal chosen(key: String)
	var play: Dictionary
	var defense := false
	var mirror := false
	var note := ""

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		UI.style_button(self, Color("#1d3f1f"), Color(1, 1, 1, 0.35))
		pressed.connect(func():
			if not disabled:
				chosen.emit(play.key))

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var f := UI.font
		draw_string(f, Vector2(22, 44), play.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 30, 30, Color("#ffe8a0") if not disabled else Color(1, 1, 1, 0.3))
		var about: String = play.about + ("  · " + note if note != "" else "")
		draw_string(f, Vector2(22, size.y - 20), about, HORIZONTAL_ALIGNMENT_LEFT, size.x - 30, 17, Color(1, 1, 1, 0.7))
		var area := Rect2(20, 58, size.x - 40, size.y - 100)
		if defense:
			_draw_defense(area)
		elif play.kind in ["run", "pass"]:
			_draw_offense(area)
		if r.size.x < 0:
			pass

	## Offense coords (dx downfield, dy across) to the card: the line of
	## scrimmage runs across, the offense goes up.
	func _pt(area: Rect2, dx: float, dy: float) -> Vector2:
		var los_y := area.position.y + area.size.y * 0.72
		return Vector2(area.get_center().x + dy * area.size.x / 40.0, clampf(los_y - dx * area.size.y / 26.0, area.position.y, area.end.y))

	func _draw_offense(area: Rect2) -> void:
		var los_y: float = _pt(area, 0, 0).y
		draw_line(Vector2(area.position.x, los_y), Vector2(area.end.x, los_y), Color(1, 1, 1, 0.25), 2)
		var form: Array = Playbook.FORMATIONS[play.form]
		var col := Color("#9ad0ff")
		var line_col := Color("#ffd23c")
		for s in form:
			var at := _pt(area, s.dx, s.dy)
			if play.kind == "run" and s.role == play.carrier:
				var prev := at
				var last := at
				for pt in play.path:
					var nx := _pt(area, pt[0], pt[1])
					draw_line(prev, nx, line_col, 3)
					last = prev
					prev = nx
				_arrow(prev, prev - last, line_col)
			elif play.kind == "run" and (s.slot == play.get("lead", "") or s.role == play.get("lead", "")):
				var tip := _pt(area, s.dx + 3.5, s.dy * 0.6)
				draw_line(at, tip, Color("#ff9a5a"), 3)
				draw_line(tip + Vector2(-7, 0), tip + Vector2(7, 0), Color("#ff9a5a"), 3)
			elif play.kind == "pass" and s.role != "OL" and s.role != "QB":
				var rk: String = play.routes.get(s.slot, play.routes.get(s.role, "block"))
				if rk != "block":
					var rt: Dictionary = Playbook.ROUTES[rk]
					var side := signf(s.dy) if absf(s.dy) > 0.5 else 1.0
					var prev := at
					var last := at
					for pt in rt.pts:
						var nx := _pt(area, s.dx + pt[0], clampf(s.dy + pt[1] * side, -19, 19))
						draw_line(prev, nx, line_col, 3)
						last = prev
						prev = nx
					_arrow(prev, prev - last, line_col)
			draw_circle(at, 7, col if s.role != "QB" else Color.WHITE)

	func _draw_defense(area: Rect2) -> void:
		var los_y := area.end.y - 8
		draw_line(Vector2(area.position.x, los_y), Vector2(area.end.x, los_y), Color(1, 1, 1, 0.25), 2)
		var depth := {DL = 1.0, LB = 5.0, CB = 7.0, S = 12.0}
		for s in Playbook.DEF_FORM:
			var dx: float = depth[s.role]
			var dy: float = s.dy
			if play.get("prevent", false) and s.role in ["CB", "S"]:
				dx += 7
			if play.box > 0 and s.slot == "S1":
				dx = 5
				dy = -3
			if play.get("nickel", false) and s.slot == "LB3":
				dy = 10
			var at := Vector2(area.get_center().x + dy * area.size.x / 40.0, maxf(area.position.y + 8, los_y - dx * (area.size.y - 16) / 19.0))
			var rush: bool = s.role == "DL" or s.slot in play.rush
			var c := Color("#ff7a7a") if rush else Color("#ffd23c")
			draw_line(at + Vector2(-6, -6), at + Vector2(6, 6), c, 3)
			draw_line(at + Vector2(-6, 6), at + Vector2(6, -6), c, 3)
			if rush:
				draw_line(at, at + Vector2(0, 14), c, 2)

	func _arrow(at: Vector2, d: Vector2, col: Color) -> void:
		if d.length() < 0.01:
			return
		var u := d.normalized()
		var n := Vector2(-u.y, u.x)
		draw_colored_polygon(PackedVector2Array([at + u * 8, at - u * 6 + n * 7, at - u * 6 - n * 7]), col)


# ---------- HUD ----------

class Hud:
	extends Control
	var main
	var pause_btn: Button

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		theme = UI.theme()
		pause_btn = Button.new()
		pause_btn.text = "II"
		pause_btn.focus_mode = Control.FOCUS_NONE
		pause_btn.add_theme_font_size_override("font_size", 34)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.08, 0.2, 0.5)
		sb.set_corner_radius_all(48)
		sb.set_content_margin_all(0)
		for st in ["normal", "hover", "pressed", "focus"]:
			pause_btn.add_theme_stylebox_override(st, sb)
		pause_btn.custom_minimum_size = Vector2(96, 96)
		pause_btn.pressed.connect(func(): main.pause())
		add_child(pause_btn)

	func _draw() -> void:
		var g: Game = main.g
		var vs := get_viewport_rect().size
		pause_btn.position = Vector2(vs.x - 130 - main.inset_right - main.inset_left, 24)
		pause_btn.visible = main.screen == "play"
		if g == null or main.screen not in ["play", "paused"]:
			return
		_scorebug(g, vs, 1.0)
		# The banner after a play.
		var f := UI.font
		if g.msg != "" and (g.phase in ["dead", "kick", "final"] or g.msg_t < 2.5):
			_center(g.msg, vs.y * 0.3, 78, Color("#ffe03c"))
			if g.sub != "":
				_center(g.sub, vs.y * 0.3 + 70, 34, Color.WHITE)
		elif g.phase == "presnap" and g.sub != "":
			_center(g.sub, vs.y - 90, 32, Color.WHITE)
		elif g.phase == "live" and g.controlled != null and main.screen == "play":
			var hint := ""
			var sides := ["left", "right"] if not Tune.v.swapSides else ["right", "left"]
			if g.can_throw():
				hint = "Pull back on the %s side to throw" % sides[0]
			elif g.controlled == g.carrier:
				hint = "Flick on the %s side to juke" % sides[0]
			elif g.controlled.team != g.ball_team():
				hint = "Flick on the %s side to dive" % sides[0]
			if hint != "" and g.t < 3.0:
				_center(hint, vs.y - 80, 28, Color(1, 1, 1, 0.75))
		if g.flag != "" and g.phase == "dead":
			# A yellow penalty flag.
			var fc := Vector2(vs.x / 2 - main.inset_left, vs.y * 0.3 - 140)
			draw_line(fc + Vector2(-30, 40), fc + Vector2(-30, -30), Color.WHITE, 5)
			draw_colored_polygon(PackedVector2Array([fc + Vector2(-30, -30), fc + Vector2(30, -20), fc + Vector2(-30, 5)]), Color("#ffe03c"))
		_draw_stick(vs)

	func _center(s: String, y: float, size: int, col: Color) -> void:
		var f := UI.font
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := Vector2(get_viewport_rect().size.x / 2 - w / 2 - float(main.inset_left), y)
		draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, Color(0, 0, 0, 0.8))
		draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

	## The score bug: both teams, the quarter and clock, down and distance.
	func _scorebug(g: Game, vs: Vector2, alpha: float) -> void:
		var f := UI.font
		var w := 900.0
		var x0: float = vs.x / 2 - w / 2 - main.inset_left
		var y0 := 18.0
		draw_rect(Rect2(x0, y0, w, 70), Color(0.03, 0.05, 0.1, 0.85 * alpha))
		for i in 2:
			var t: Dictionary = g.teams[i]
			var bx: float = x0 + (0.0 if i == 0 else w - 300.0)
			draw_rect(Rect2(bx, y0, 300, 70), Color(t.jersey, 0.95 * alpha))
			draw_rect(Rect2(bx + (0.0 if i == 0 else 292.0), y0, 8, 70), Color(t.helmet if Color(t.helmet) != Color(t.jersey) else t.trim, alpha))
			draw_string(f, Vector2(bx + 24, y0 + 50), t.abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(1, 1, 1, alpha))
			draw_string(f, Vector2(bx + 180, y0 + 52), str(g.score[i]), HORIZONTAL_ALIGNMENT_RIGHT, 90, 46, Color(1, 1, 1, alpha))
			if g.poss == i and g.phase != "final":
				draw_circle(Vector2(bx + 140, y0 + 35), 9, Color("#c98a3a", alpha))
		var mid := "%s  %s" % [g.quarter_text(), g.time_text()] if g.phase != "final" else "FINAL"
		var mw := f.get_string_size(mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		draw_string(f, Vector2(x0 + w / 2 - mw / 2, y0 + 48), mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 1, 1, alpha))
		if g.phase in ["call", "presnap", "live"]:
			var dd := "%s · %s" % [g.down_text(), g.spot_text(g.poss, g.los)]
			var dw := f.get_string_size(dd, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			draw_rect(Rect2(x0 + w / 2 - dw / 2 - 20, y0 + 70, dw + 40, 44), Color(0.03, 0.05, 0.1, 0.75 * alpha))
			draw_string(f, Vector2(x0 + w / 2 - dw / 2, y0 + 103), dd, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#ffe03c", alpha))

	func _draw_stick(vs: Vector2) -> void:
		var st = main.stick
		if st == null:
			return
		var r: float = main._px(Tune.v.stickSize)
		var o: Vector2 = st.origin - position
		draw_circle(o, r, Color(1, 1, 1, 0.12))
		draw_arc(o, r, 0, TAU, 40, Color(1, 1, 1, 0.35), 3)
		var knob: Vector2 = o + (st.at - st.origin).limit_length(r)
		draw_circle(knob, r * 0.45, Color(1, 1, 1, 0.45))
