## Draws a game: the field seen from the side stands (it scrolls with the
## ball), the players in their team colors, the ball, the throw preview,
## and the line of scrimmage and first-down markers.
class_name Field
extends Node2D

const POSES_RUN := ["run1", "run2", "run3", "run4", "run5"]
const POSES_CARRY := ["carry1", "burst", "carry2", "burst"]
const SHADER := """
shader_type canvas_item;
uniform sampler2D mask_tex : filter_linear_mipmap;
uniform vec4 helmet : source_color = vec4(1.0);
uniform vec4 jersey : source_color = vec4(1.0);
uniform float flash = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec4 m = texture(mask_tex, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float shade = clamp((l - 0.25) / 0.75, 0.0, 1.0);
	vec3 j = jersey.rgb * (0.42 + 0.66 * shade) + vec3(0.1) * shade * shade;
	vec3 h = helmet.rgb * (0.45 + 0.6 * shade) + vec3(0.3) * pow(shade, 8.0);
	vec3 col = mix(c.rgb, j, m.g);
	col = mix(col, h, m.r);
	col = mix(col, vec3(1.0, 0.95, 0.6), flash);
	COLOR = vec4(col, c.a * COLOR.a);
}
"""

static var _shader: Shader
static var _meta := {}
static var _tex := {}

var g: Game
var view := Vector2(1920, 1080)
var k := 56.0
## How flat the field looks (depth squash): from the setting.
var sq := 0.55
## Room at the top of the screen kept for the scoreboard, in pixels.
const TOP_PX := 140.0
const BOTTOM_PX := 16.0
## How much past each sideline the whole-field view shows, in yards.
const SIDE_MARGIN := 2.5
var cam := Vector2(50, 26.67)
var aim = null  ## {from, to, rec, raw} while the person aims a throw
var shake := 0.0
var font: Font

var ground: Node2D
var shadows: Node2D
var actors: Node2D
var overlay: Node2D
var sprites := {}  # P -> Sprite2D
var _players_key := []


func _ready() -> void:
	font = load("res://assets/fonts/russo-one.woff2")
	ground = _layer(Ground)
	shadows = _layer(Shadows)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	overlay = _layer(Overlay)


func _layer(script) -> Node2D:
	var n: Node2D = script.new()
	n.set("f", self)
	add_child(n)
	return n


static func meta(pose: String) -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/players/meta.json"))
	return _meta.get(pose, _meta.stand)


static func tex(skin: String, pose: String, mask := false) -> Texture2D:
	var key := "%s/%s%s" % [skin, pose, "_mask" if mask else ""]
	if not _tex.has(key):
		_tex[key] = load("res://assets/players/%s.png" % key)
	return _tex[key]


static func ball_tex() -> Texture2D:
	if not _tex.has("ball"):
		_tex.ball = load("res://assets/players/ball.png")
	return _tex.ball


func set_game(game: Game) -> void:
	g = game
	for s in sprites.values():
		s.queue_free()
	sprites.clear()
	_players_key = []
	if g:
		cam = Vector2(g.los_x(), Game.MID_Y)


# ---------- Projection ----------

func layout() -> void:
	view = get_viewport_rect().size
	sq = Tune.v.fieldTilt
	if whole_field():
		# Zoom out until both sidelines fit under the scoreboard.
		k = (view.y - TOP_PX - BOTTOM_PX) / ((Game.FIELD_W + SIDE_MARGIN * 2) * sq)
	else:
		k = view.x / Tune.v.fieldZoom


## How big the players are drawn, for the current view.
static func player_scale() -> float:
	return Tune.v.playerScaleWide if Tune.v.fieldView == "sidelines" else Tune.v.playerScale


func whole_field() -> bool:
	return Tune.v.fieldView == "sidelines"


func P(x: float, y: float, z := 0.0) -> Vector2:
	return Vector2((x - cam.x) * k + view.x / 2, (y - cam.y) * k * sq + view.y / 2 - z * k * 0.75)


func to_field(s: Vector2) -> Vector2:
	return Vector2((s.x - view.x / 2) / k + cam.x, (s.y - view.y / 2) / (k * sq) + cam.y)


## A screen-space drag as a field direction (undoing the depth squash).
func drag_to_field(d: Vector2) -> Vector2:
	return Vector2(d.x, d.y / sq) / k


# ---------- Every frame ----------

func _process(dt: float) -> void:
	layout()
	if g == null:
		return
	_follow(dt)
	_sync_players()
	shake = maxf(0.0, shake - dt * 3.0)
	if shake > 0:
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 10.0 * Tune.v.shake
	else:
		position = Vector2.ZERO
	for n in [ground, shadows, overlay]:
		n.queue_redraw()


func _focus() -> Vector2:
	match g.phase:
		"presnap", "call":
			return Vector2(g.los_x() + g.dir[g.poss] * 4.0, g.ball_y)
		"kick":
			var b := g.ball_pos()
			return Vector2(b.x, b.y)
	if g.controlled != null and g.controlled.team != g.ball_team() and g.carrier != null:
		# On defense: keep both your man and the ball carrier in view.
		return g.carrier.at.lerp(g.controlled.at, 0.3)
	var b := g.ball_pos()
	return Vector2(b.x, b.y)


func _follow(dt: float) -> void:
	var want := _focus()
	var half_w := view.x / 2 / k
	var half_h := view.y / 2 / (k * sq)
	want.x = clampf(want.x, -13.0 + half_w, 113.0 - half_w)
	if whole_field():
		# Both sidelines always in view: only scroll along the field.
		want.y = -SIDE_MARGIN + (view.y / 2 - TOP_PX) / (k * sq)
	else:
		want.y = clampf(want.y, -9.0 + half_h, Game.FIELD_W + 4.0 - half_h) if half_h * 2 < Game.FIELD_W + 13 else Game.FIELD_W / 2 - 2.5
	cam = cam.lerp(want, clampf(dt * 4.0, 0.0, 1.0))
	if whole_field():
		cam.y = want.y


func _sync_players() -> void:
	if g.players != _players_key:
		for s in sprites.values():
			s.queue_free()
		sprites.clear()
		_players_key = g.players.duplicate()
		for p in g.players:
			var s := Sprite2D.new()
			s.centered = false
			var mat := ShaderMaterial.new()
			if _shader == null:
				_shader = Shader.new()
				_shader.code = SHADER
			mat.shader = _shader
			var team: Dictionary = g.teams[p.team]
			mat.set_shader_parameter("helmet", team.helmet_color)
			mat.set_shader_parameter("jersey", team.jersey_color)
			s.material = mat
			actors.add_child(s)
			sprites[p] = s
	var sc: float = player_scale() * k / 56.5
	for p in g.players:
		var s: Sprite2D = sprites[p]
		var pose := pose_for(p)
		var m := meta(pose)
		s.texture = tex(p.skin, pose)
		s.material.set_shader_parameter("mask_tex", tex(p.skin, pose, true))
		s.material.set_shader_parameter("flash", 0.35 if p == g.controlled and fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.12 else 0.0)
		var flip: bool = p.face < 0
		s.flip_h = flip
		var foot_x: float = m.foot[0]
		if flip:
			foot_x = m.size[0] - foot_x
		s.offset = Vector2(-foot_x, -m.foot[1])
		s.scale = Vector2(sc, sc)
		s.position = P(p.at.x, p.at.y)


## Which picture of a player to show.
func pose_for(p) -> String:
	var phase := g.phase
	var moving: bool = p.vel.length() > 0.6
	var cyc := int(p.dist / 0.9)
	if p.act == "td" and phase == "dead":
		return "catch2" if int(p.act_t * 3) % 2 == 0 else "carry2"
	if p.act == "tackled" or (p.down > 0 and p.act != "tackler" and p.act != "dive"):
		return "down" if p.act_t > 0.25 or p.act != "tackled" else "lunge"
	if p.act == "tackler":
		return "dive" if p.act_t < 0.2 else "layout"
	if p.dive > 0:
		return "dive"
	if p.act == "dive" and p.down > 0:
		return "layout"
	if phase == "presnap" or (phase == "kick" and p != g.qb):
		if moving:
			return POSES_RUN[cyc % 5]
		match p.role:
			"OL", "DL":
				return "stance" if p.id % 2 == 0 else "stance2"
			"QB":
				return "hold"
			"RB", "FB":
				return "ready"
			"WR", "TE":
				return "set"
			"LB":
				return "lb" if p.id % 2 == 0 else "lb2"
			_:
				return "ready"
	if phase == "kick" and p == g.qb:
		return "follow" if p.act_t > 0.15 else "release"
	if p.act == "throw" and p.act_t < 0.5:
		return "release" if p.act_t < 0.18 else "follow"
	if p.act == "catch" and p.act_t < 0.35:
		return "catch2"
	if p.act == "juke" and p.act_t < 0.35:
		return "tuck"
	if p.act == "stiff" and p.act_t < 0.35:
		return "stiff"
	# The wall: linemen block from the low crouch, rocking as they're pushed.
	if p.wall and phase in ["live", "dead"] and p.vel.length() < 3.0:
		if p.engaged != null:
			return "lb" if int(Time.get_ticks_msec() / 260 + p.id) % 2 == 0 else "lb2"
		return "lb"
	if p.engaged != null:
		var push := int(Time.get_ticks_msec() / 220 + p.id) % 2 == 0
		if p.team == g.poss:
			return "push1" if push else "push2"
		return "block" if push else "push1"
	if p == g.carrier:
		if p == g.qb and g.aiming and g.can_throw():
			return "windup2" if p.act_t < 0 else "windup"
		if not moving:
			return "hold" if p == g.qb else "hold2"
		if p == g.qb and g.off_call.get("kind", "") == "pass" and not g.past_los:
			return "hold" if not moving else POSES_CARRY[cyc % 4]
		return POSES_CARRY[cyc % 4]
	if phase == "live" and not g.ball.is_empty():
		var bp := g.ball_pos()
		if Vector2(bp.x, bp.y).distance_to(p.at) < 2.6 and bp.z > 0.6:
			return "catch"
	if phase == "dead" and not moving:
		return "stand" if p.role not in ["OL", "DL"] else "ready"
	if moving:
		return POSES_RUN[cyc % 5]
	if p.team != g.poss:
		return "lb" if p.role in ["LB", "S", "CB"] else "ready"
	return "ready" if p.role != "QB" else "hold"


func text(ci: CanvasItem, s: String, pos: Vector2, size: int, color: Color, outline := 8) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	var at := pos - Vector2(w / 2, -size * 0.35)
	if outline > 0:
		ci.draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, 0.75))
	ci.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# ---------- The field ----------

class Ground:
	extends Node2D
	var f

	func _draw() -> void:
		var g: Game = f.g
		var k: float = f.k
		var v: Vector2 = f.view
		# Stands at the top, behind the far sideline.
		var top_y: float = f.P(0, -4.0).y
		draw_rect(Rect2(-20, -20, v.x + 40, top_y + 20), Color("#2a2f3a"))
		_crowd(top_y)
		# The surround (sideline area) and the field.
		draw_rect(Rect2(-20, top_y, v.x + 40, v.y - top_y + 20), Color("#2f6b2a"))
		var x0: float = f.to_field(Vector2(-40, 0)).x
		var x1: float = f.to_field(Vector2(v.x + 40, 0)).x
		var yt: float = f.P(0, 0).y
		var yb: float = f.P(0, Game.FIELD_W).y
		# Grass stripes every 5 yards.
		var s0 := floori(maxf(-10.0, x0) / 5.0) * 5
		var xx := float(s0)
		while xx < minf(110.0, x1):
			var a: float = f.P(xx, 0).x
			var b: float = f.P(minf(xx + 5.0, 110.0), 0).x
			var dark := int(floor(xx / 5.0)) % 2 == 0
			draw_rect(Rect2(a, yt, b - a, yb - yt), Color("#3c8c34") if dark else Color("#43983a"))
			xx += 5.0
		# End zones.
		for side in [0, 1]:
			var ex0 := -10.0 if side == 0 else 100.0
			var a: float = f.P(ex0, 0).x
			var b: float = f.P(ex0 + 10.0, 0).x
			if b < -20 or a > v.x + 20:
				continue
			# The team defending this end zone: the one attacking the other way.
			var owner := 0 if (g.dir[0] > 0) == (side == 0) else 1
			var team: Dictionary = g.teams[owner]
			draw_rect(Rect2(a, yt, b - a, yb - yt), Color(team.jersey).darkened(0.15))
			_endzone_name(team, (a + b) / 2.0, (yt + yb) / 2.0, side == 0)
		# Lines: sidelines, end lines, yard lines, hash marks.
		var white := Color(1, 1, 1, 0.92)
		var lw := maxf(2.0, k * 0.12)
		draw_line(f.P(-10, 0), f.P(110, 0), white, lw * 1.4)
		draw_line(f.P(-10, Game.FIELD_W), f.P(110, Game.FIELD_W), white, lw * 1.4)
		for x in [-10.0, 110.0]:
			draw_line(f.P(x, 0), f.P(x, Game.FIELD_W), white, lw * 1.4)
		for i in 21:
			var x := i * 5.0
			if x < x0 - 5 or x > x1 + 5:
				continue
			draw_line(f.P(x, 0), f.P(x, Game.FIELD_W), white, lw * (1.6 if i == 0 or i == 20 else 1.0))
		for i in range(1, 100):
			var x := float(i)
			if i % 5 == 0 or x < x0 - 1 or x > x1 + 1:
				continue
			for hy in [0.4, Game.HASH_TOP, Game.HASH_BOT, Game.FIELD_W - 0.4]:
				draw_line(f.P(x, hy - 0.35), f.P(x, hy + 0.35), white, lw * 0.8)
		# Yard numbers.
		for i in range(1, 10):
			var x := i * 10.0
			if x < x0 - 5 or x > x1 + 5:
				continue
			var n := str(i * 10 if i <= 5 else (10 - i) * 10)
			for ny in [7.0, Game.FIELD_W - 7.0]:
				f.text(self, n, f.P(x, ny), int(k * 1.6), Color(1, 1, 1, 0.85), 0)
		# Midfield logo.
		var mid: Vector2 = f.P(50, Game.MID_Y)
		if mid.x > -200 and mid.x < v.x + 200:
			var r := k * 4.0
			var pts := PackedVector2Array()
			for j in 40:
				var an := TAU * j / 40
				pts.append(mid + Vector2(cos(an) * r, sin(an) * r * f.sq))
			draw_colored_polygon(pts, Color(1, 1, 1, 0.12))
			f.text(self, "NORTH", mid, int(k * 1.1), Color(1, 1, 1, 0.5), 0)
		# Line of scrimmage and the first-down line, before the snap.
		if g.phase in ["presnap", "call"]:
			var lx := g.los_x()
			draw_line(f.P(lx, 0), f.P(lx, Game.FIELD_W), Color("#3d7cff"), lw * 1.6)
			if g.los + g.togo < 100.0:
				var fd := g.first_down_x()
				draw_line(f.P(fd, 0), f.P(fd, Game.FIELD_W), Color("#ffe03c"), lw * 1.6)
		# Near-side wall.
		var wall: float = f.P(0, Game.FIELD_W + 4.5).y
		draw_rect(Rect2(-20, wall, v.x + 40, v.y - wall + 40), Color("#1d3a1b"))

	func _endzone_name(team: Dictionary, cx: float, cy: float, left: bool) -> void:
		var k: float = f.k
		var s: String = team.name.to_upper()
		var size := int(k * 2.6)
		var w: float = f.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var max_w: float = Game.FIELD_W * k * f.sq * 0.85
		if w > max_w:
			size = int(size * max_w / w)
			w = max_w
		draw_set_transform(Vector2(cx, cy), -PI / 2 if left else PI / 2, Vector2.ONE)
		draw_string_outline(f.font, Vector2(-w / 2, size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color(0, 0, 0, 0.35))
		draw_string(f.font, Vector2(-w / 2, size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(team.trim) if Color(team.trim) != Color(team.jersey) else Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	func _crowd(bottom: float) -> void:
		var k: float = f.k
		var rows := 9
		var step := k * 0.55
		var cam_x: float = f.cam.x
		for r in rows:
			var y := bottom - (r + 1) * step * 0.9
			if y < -step:
				break
			draw_rect(Rect2(-20, y - step * 0.5, f.view.x + 40, 4), Color(0, 0, 0, 0.25))
			var i0 := int(floor((cam_x - f.view.x / 2 / k) / 0.55)) - 2
			var n := int(f.view.x / step) + 5
			for i in n:
				var idx := i0 + i
				var x: float = (idx * 0.55 - cam_x) * k + f.view.x / 2 + (r % 2) * step * 0.5
				var h := absi((idx * 7919 + r * 104729) % 97)
				var col := Color.from_hsv((h % 12) / 12.0, 0.45, 0.55 + (h % 5) * 0.08)
				var bob := sin(Time.get_ticks_msec() / 180.0 + h) * (2.0 if f.g.phase == "dead" else 0.5)
				draw_circle(Vector2(x, y + bob), step * 0.32, col)
				draw_circle(Vector2(x, y + bob - step * 0.32), step * 0.2, Color("#e8c0a0") if h % 3 else Color("#7a4a2a"))


class Shadows:
	extends Node2D
	var f

	func _draw() -> void:
		var g: Game = f.g
		var k: float = f.k
		for p in g.players:
			var c: Vector2 = f.P(p.at.x, p.at.y)
			if p == g.controlled:
				var col := Color("#ffe03c")
				var r := Vector2(k * 0.95, k * 0.95 * f.sq)
				var pts := PackedVector2Array()
				for i in 33:
					var a := TAU * i / 32
					pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
				draw_polyline(pts, col, maxf(3.0, k * 0.1))
			_ellipse(c, Vector2(k * 0.55, k * 0.22), Color(0, 0, 0, 0.28))
		# The ball's shadow.
		var b := g.ball_pos()
		if b.z > 0.4:
			_ellipse(f.P(b.x, b.y), Vector2(k * 0.25, k * 0.1), Color(0, 0, 0, 0.3))
		# The throw preview: dots along the arc and the landing ring.
		if f.aim != null:
			var a: Dictionary = f.aim
			var from: Vector2 = a.from
			var to: Vector2 = a.to
			var n: int = int(Tune.v.aimDots)
			var dist := from.distance_to(to)
			var h := minf(8.0, dist * Tune.v.passArc + 0.3)
			for i in n:
				var s := (i + 1.0) / (n + 1.0)
				var gp := from.lerp(to, s)
				var z := lerpf(2.0, 1.0, s) + 4.0 * h * s * (1.0 - s)
				draw_circle(f.P(gp.x, gp.y, z), maxf(3.0, k * 0.09), Color(1, 0.9, 0.3, 0.85))
			var rc: Vector2 = f.P(to.x, to.y)
			var col := Color("#ff4040") if a.rec == null else Color("#40ff70")
			var pts := PackedVector2Array()
			for i in 33:
				var an := TAU * i / 32
				pts.append(rc + Vector2(cos(an) * k * 0.8, sin(an) * k * 0.8 * f.sq))
			draw_polyline(pts, col, maxf(3.0, k * 0.08))

	func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, col)


class Overlay:
	extends Node2D
	var f

	func _draw() -> void:
		var g: Game = f.g
		var k: float = f.k
		# Goal posts at the back of each end zone.
		for gx in [-10.0, 110.0]:
			var yel := Color("#ffd23c")
			var w := maxf(3.0, k * 0.14)
			var base: Vector2 = f.P(gx, Game.MID_Y)
			if base.x < -200 or base.x > f.view.x + 200:
				continue
			draw_line(base, f.P(gx, Game.MID_Y, 3.3), yel, w * 1.3)
			draw_line(f.P(gx, Game.MID_Y - 3.08, 3.3), f.P(gx, Game.MID_Y + 3.08, 3.3), yel, w)
			for py in [Game.MID_Y - 3.08, Game.MID_Y + 3.08]:
				draw_line(f.P(gx, py, 3.3), f.P(gx, py, 11.0), yel, w)
		# The ball, when it's not in someone's hands.
		var b := g.ball_pos()
		var in_hands := g.carrier != null and g.phase in ["live", "dead"]
		if not in_hands:
			var bt := Field.ball_tex()
			var at: Vector2 = f.P(b.x, b.y, b.z)
			var sc := k * 0.75 / bt.get_width()
			var spin := Time.get_ticks_msec() / 90.0 if b.z > 0.5 else 0.0
			draw_set_transform(at, sin(spin) * 0.5, Vector2(sc, sc))
			draw_texture(bt, -bt.get_size() / 2)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		# A marker over your player.
		var c = g.controlled
		if c != null and g.phase in ["presnap", "live"]:
			var m := Field.meta("stand")
			var head: Vector2 = f.P(c.at.x, c.at.y) - Vector2(0, (m.foot[1] - m.top) * Field.player_scale() * k / 56.5 + k * 0.5)
			var s := maxf(k * 0.35, 12.0)
			draw_colored_polygon(PackedVector2Array([head + Vector2(-s, -s), head + Vector2(s, -s), head + Vector2(0, s * 0.4)]), Color("#ffe03c"))
			f.text(self, str(c.num), head - Vector2(0, maxf(s, 12.0) * 1.6), maxi(22, int(k * 0.55)), Color.WHITE, 6)
		# Receivers' numbers while you aim.
		if f.aim != null and f.aim.rec != null:
			var r = f.aim.rec
			f.text(self, str(r.num), f.P(r.at.x, r.at.y) - Vector2(0, k * 2.8), maxi(22, int(k * 0.55)), Color("#40ff70"), 6)
