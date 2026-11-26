## Formations, offensive plays and defensive calls.
##
## Positions are in yards from the ball, from the offense's point of view:
## dx is downfield (negative = in the backfield), dy is across (+ = the
## offense's right). The game turns them into field positions.
class_name Playbook

const FORMATIONS := {
	"i_form": [
		{slot = "C", role = "OL", dx = -0.6, dy = 0.0}, {slot = "LG", role = "OL", dx = -0.7, dy = -1.3}, {slot = "RG", role = "OL", dx = -0.7, dy = 1.3},
		{slot = "LT", role = "OL", dx = -0.8, dy = -2.6}, {slot = "RT", role = "OL", dx = -0.8, dy = 2.6},
		{slot = "QB", role = "QB", dx = -1.4, dy = 0.0}, {slot = "FB", role = "FB", dx = -4.2, dy = 0.0}, {slot = "RB", role = "RB", dx = -6.8, dy = 0.0},
		{slot = "TE", role = "TE", dx = -0.9, dy = 3.9}, {slot = "X", role = "WR", dx = -0.6, dy = -17.0}, {slot = "Z", role = "WR", dx = -1.2, dy = 14.0},
	],
	"single": [
		{slot = "C", role = "OL", dx = -0.6, dy = 0.0}, {slot = "LG", role = "OL", dx = -0.7, dy = -1.3}, {slot = "RG", role = "OL", dx = -0.7, dy = 1.3},
		{slot = "LT", role = "OL", dx = -0.8, dy = -2.6}, {slot = "RT", role = "OL", dx = -0.8, dy = 2.6},
		{slot = "QB", role = "QB", dx = -1.4, dy = 0.0}, {slot = "RB", role = "RB", dx = -6.0, dy = 0.0},
		{slot = "TE", role = "TE", dx = -0.9, dy = 3.9}, {slot = "X", role = "WR", dx = -0.6, dy = -17.0}, {slot = "Z", role = "WR", dx = -1.2, dy = 15.0},
		{slot = "SL", role = "WR", dx = -1.2, dy = -9.0},
	],
	"shotgun": [
		{slot = "C", role = "OL", dx = -0.6, dy = 0.0}, {slot = "LG", role = "OL", dx = -0.7, dy = -1.3}, {slot = "RG", role = "OL", dx = -0.7, dy = 1.3},
		{slot = "LT", role = "OL", dx = -0.8, dy = -2.6}, {slot = "RT", role = "OL", dx = -0.8, dy = 2.6},
		{slot = "QB", role = "QB", dx = -5.0, dy = 0.0}, {slot = "RB", role = "RB", dx = -5.0, dy = 1.8},
		{slot = "TE", role = "TE", dx = -1.0, dy = 4.2}, {slot = "X", role = "WR", dx = -0.6, dy = -17.0}, {slot = "Z", role = "WR", dx = -1.2, dy = 16.0},
		{slot = "SL", role = "WR", dx = -1.2, dy = -10.0},
	],
}

## Routes: waypoints relative to where the receiver lines up. dy here is
## "out" (+, toward his sideline) or "in" (-, toward the middle); the game
## mirrors it by side. `go` = keep running the last leg when done.
const ROUTES := {
	"go": {pts = [[32, 0]], go = true},
	"fade": {pts = [[30, 3]], go = true},
	"slant": {pts = [[2.5, 0], [12, -9]], go = true},
	"post": {pts = [[11, 0], [28, -10]], go = true},
	"corner": {pts = [[11, 0], [24, 8]], go = true},
	"out": {pts = [[8, 0], [7.5, 9]], go = false},
	"dig": {pts = [[12, 0], [12, -14]], go = true},
	"curl": {pts = [[11, 0], [9, -1.5]], go = false},
	"comeback": {pts = [[15, 0], [12, 3]], go = false},
	"hitch": {pts = [[6, 0], [5, 0]], go = false},
	"seam": {pts = [[26, -1.5]], go = true},
	"flat": {pts = [[1, 4], [3, 11]], go = false},
	"drag": {pts = [[3, 0], [5, -18]], go = true},
	"swing": {pts = [[-1, 4], [2, 10]], go = false},
	"wheel": {pts = [[0, 6], [4, 11], [24, 12]], go = true},
	"screen": {pts = [[-2.5, 5]], go = false},
	"angle": {pts = [[3, 3], [7, -3]], go = false},
}

## Offensive plays. Runs give the ball carrier's path (offense coords
## relative to the ball, not the runner); passes give each receiver a route
## (or "block"). drop = how far the quarterback drops back.
const PLAYS := [
	{key = "dive", name = "HB Dive", kind = "run", form = "i_form", carrier = "RB", path = [[-1.5, 0.7], [3, 0.7], [12, 0.7]], lead = "FB", about = "Up the middle behind the fullback"},
	{key = "power_l", name = "Power Left", kind = "run", form = "i_form", carrier = "RB", path = [[-2.5, -2.5], [1, -3.4], [12, -3.6]], lead = "FB", about = "Off left tackle"},
	{key = "power_r", name = "Power Right", kind = "run", form = "i_form", carrier = "RB", path = [[-2.5, 2.5], [1, 3.4], [12, 3.6]], lead = "FB", about = "Off right tackle"},
	{key = "sweep_l", name = "Sweep Left", kind = "run", form = "single", carrier = "RB", path = [[-4, -4], [-3, -9], [2, -11], [14, -11]], lead = "TE", toss = true, about = "Pitch it wide and turn the corner"},
	{key = "sweep_r", name = "Sweep Right", kind = "run", form = "single", carrier = "RB", path = [[-4, 4], [-3, 9], [2, 11], [14, 11]], lead = "TE", toss = true, about = "Pitch it wide and turn the corner"},
	{key = "counter", name = "Counter", kind = "run", form = "i_form", carrier = "RB", path = [[-6, 2], [-3, -1.5], [2, -2.5], [12, -3]], lead = "FB", about = "Step right, cut back left"},
	{key = "draw", name = "Draw", kind = "run", form = "shotgun", carrier = "RB", path = [[-4, 0.6], [2, 0.6], [12, 0.6]], delay = 0.7, about = "Fake a pass, run it up the middle"},
	{key = "sneak", name = "QB Sneak", kind = "run", form = "i_form", carrier = "QB", path = [[1, 0.5], [6, 0.5]], about = "For a yard when you need one"},

	{key = "slants", name = "Slants", kind = "pass", form = "single", drop = 3.0, routes = {X = "slant", Z = "slant", SL = "slant", TE = "flat", RB = "block"}, about = "Quick throws over the middle"},
	{key = "curls", name = "Curl Flat", kind = "pass", form = "single", drop = 5.0, routes = {X = "curl", Z = "curl", SL = "flat", TE = "curl", RB = "swing"}, about = "Sit down in the soft spots"},
	{key = "outs", name = "Quick Outs", kind = "pass", form = "shotgun", drop = 3.0, routes = {X = "out", Z = "out", SL = "hitch", TE = "angle", RB = "flat"}, about = "Get it to the sideline fast"},
	{key = "post_corner", name = "Post Corner", kind = "pass", form = "i_form", drop = 7.0, routes = {X = "post", Z = "corner", TE = "dig", FB = "block", RB = "swing"}, about = "Two deep cuts, TE underneath"},
	{key = "verticals", name = "Four Verts", kind = "pass", form = "shotgun", drop = 6.0, routes = {X = "go", Z = "go", SL = "seam", TE = "seam", RB = "block"}, about = "Everybody deep"},
	{key = "pa_deep", name = "PA Deep", kind = "pass", form = "i_form", drop = 7.0, fake = true, routes = {X = "go", Z = "post", TE = "drag", FB = "block", RB = "flat"}, about = "Fake the handoff, then go deep"},
	{key = "screen", name = "HB Screen", kind = "pass", form = "shotgun", drop = 5.0, routes = {X = "go", Z = "go", SL = "drag", TE = "block", RB = "screen"}, about = "Let them rush, dump it off"},
	{key = "dig", name = "Mesh Dig", kind = "pass", form = "single", drop = 5.0, routes = {X = "dig", Z = "drag", SL = "corner", TE = "seam", RB = "wheel"}, about = "Crossing routes and a wheel"},
]

const KICKS := [
	{key = "punt", name = "Punt", kind = "punt", about = "Kick it away"},
	{key = "fg", name = "Field Goal", kind = "fg", about = "Three points if it's good"},
]

## Defensive calls: who rushes, and how the rest cover.
const DEFENSES := [
	{key = "base", name = "Base 4-3", about = "Four rush, man on the outside, safeties deep", box = 0, rush = [], cover = "man", deep = 2},
	{key = "blitz", name = "LB Blitz", about = "Send two linebackers. Man everywhere, one deep", box = 0, rush = ["LB1", "LB3"], cover = "man", deep = 1},
	{key = "run_stop", name = "Run Stop", about = "A safety in the box and linebackers attack the run", box = 1, rush = [], cover = "man", deep = 1, run_read = 0.0},
	{key = "cover2", name = "Cover 2", about = "Zones: corners in the flats, two deep halves", box = 0, rush = [], cover = "zone", deep = 2},
	{key = "nickel", name = "Nickel", about = "An extra cover man on the slot", box = 0, rush = [], cover = "man", deep = 2, nickel = true},
	{key = "prevent", name = "Prevent", about = "Three rush, everyone else deep. Gives up the short stuff", box = 0, rush = [], cover = "zone", deep = 3, prevent = true},
]

## Where the defense lines up (dx = yards off the ball on the defense's
## side; dy offense coords). CBs and safeties are moved to the receivers.
const DEF_FORM := [
	{slot = "DL1", role = "DL", dx = 0.9, dy = -3.6}, {slot = "DL2", role = "DL", dx = 0.9, dy = -1.2},
	{slot = "DL3", role = "DL", dx = 0.9, dy = 1.2}, {slot = "DL4", role = "DL", dx = 0.9, dy = 3.6},
	{slot = "LB1", role = "LB", dx = 4.5, dy = -5.0}, {slot = "LB2", role = "LB", dx = 4.8, dy = 0.0}, {slot = "LB3", role = "LB", dx = 4.5, dy = 5.0},
	{slot = "CB1", role = "CB", dx = 6.5, dy = -16.0}, {slot = "CB2", role = "CB", dx = 6.5, dy = 15.0},
	{slot = "S1", role = "S", dx = 12.0, dy = -8.0}, {slot = "S2", role = "S", dx = 12.0, dy = 8.0},
]


static func play(key: String) -> Dictionary:
	for p in PLAYS + KICKS:
		if p.key == key:
			return p
	return PLAYS[0]


static func defense(key: String) -> Dictionary:
	for d in DEFENSES:
		if d.key == key:
			return d
	return DEFENSES[0]


static func runs() -> Array:
	return PLAYS.filter(func(p): return p.kind == "run")


static func passes() -> Array:
	return PLAYS.filter(func(p): return p.kind == "pass")
