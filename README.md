# Gridiron North

Old-school, side-scrolling, eleven-on-eleven football for Android, in the
spirit of the 8-bit football games: call a play from the playbook, then run
it. Built with [Godot 4](https://godotengine.org/), set up the same way as
Snowball Fight.

Eight teams in the colors of the AFC North and NFC North cities play a
season. Everyone plays everyone once, and the top two meet in the
**North Bowl**.

## How it plays

### Calling plays

Before every snap you pick a play from a grid of cards with diagrams. The
play call screen also has PAUSE and SETTINGS.

- **Offense**: eight runs (HB Dive, Power Left/Right, Sweep Left/Right,
  Counter, Draw, QB Sneak), eight passes (Slants, Curl Flat, Quick Outs, Post
  Corner, Four Verts, PA Deep, HB Screen, Mesh Dig) and two kicks (Punt,
  Field Goal).
- **Defense**: Base 4-3, LB Blitz, Run Stop, Cover 2, Nickel and Prevent.

The computer calls its plays from the down, the distance, the score and its
team's strength type. It punts and kicks field goals on 4th down, and
sometimes goes for it.

### Offense

- **Tap** to hike.
- **Run**: drag on the **right** half of the screen. A move stick appears
  under your finger.
- **Throw** (quarterback): pull back on the **left** half and let go. The
  farther you pull, the farther the throw. Gold dots show the arc. The ring
  turns green when a receiver is there: aim assist pulls the throw to him
  and leads him.
- **Juke** (running back, or a receiver after the catch): flick on the
  **left** half in the direction you want to cut. Tacklers miss more during
  the cut, and ones close by can stumble.

### Defense

- **Pick your man**: tap any defender. Before the snap he moves freely, but
  if he crosses the line of scrimmage (the blue line), the whistle blows:
  **offside, 5 yards** to the offense, replay the down (an automatic first
  down if that reaches the line to gain).
- **Run**: drag on the **right** half.
- **Dive tackle**: flick on the **left** half toward the ball carrier. If you
  miss, you're on the ground for a moment.
- When the ball is thrown, you switch to the defender nearest to where it's
  going. You can change that in the settings.
- Your player has a yellow ring. Whoever has the ball for the computer gets
  a pulsing red ring, so you can follow it through a handoff, a catch or an
  interception return.

Left-handed? **Settings → Throw / juke / tackle with the right side** swaps
the two halves.

### Keyboard and mouse

| | |
|---|---|
| Run | Arrows or WASD |
| Hike / throw to the open man / juke / dive | Space |
| Switch defender | Tab |
| Pause | P or Esc |

### The offensive line: a wall

The five offensive linemen block as a wall. Each one holds a square of it,
crouched low, and slides across only as far as the edge of his square to
stay in front of his man (the tackles at the ends reach a little farther
outside for the edge rushers). Nobody walks through the wall: a defensive
lineman has to drive his blocker back toward the quarterback until there's
room to get around him. Stronger rushers push faster, a lineman with a free
neighbor gets help (a double team), and on running plays the line drives the
defense back instead. Playing a defensive lineman yourself, push toward the
ball to drive your man back, or across to slip off the edge of his square.
Every number for it is a developer setting (Players → Wall).

### Line drill (for trying out the wall)

**LINE DRILL** on the title screen puts just the linemen on the field, with
a circle where the quarterback stands: **1 ON 1** (one offensive lineman
against one defensive lineman) or **5 ON 5** (the whole line). Both lines
set up in the three-point stance, `lineSplit` apart. Tap to snap; in 5 on 5,
tap a rusher to play him. You play a defensive lineman: push toward the QB
to drive your man back, or up and down to slip off the edge of his square.
Get around him and reach the QB for a sack, or he holds you off for 6
seconds. Blockers punch with their hands out (`art-source/pass_block.png`);
rushers drive in low. The bar at the top shows how far your blocker has
been driven back against how far it takes to get around him. Along the
bottom: rush yourself or watch the computer, 1 on 1 or 5 on 5, each side's
power, reset the record, or exit. The wall's developer settings apply here
too.

### Rules

Four downs to gain ten yards. Quarters are 4 minutes of game clock by
default. The clock runs during plays and between plays that end in bounds,
and stops for incompletions, going out of bounds, scores and turnovers. You
get touchdowns (with an automatic extra point), field goals, safeties,
sacks, interceptions (which can be run back), turnovers on downs, punts and
touchbacks. Halftime switches ends. A tied season game stays a tie; a tied
North Bowl goes to sudden-death overtime.

## Teams

| AFC North | NFC North |
|---|---|
| Baltimore Talons (purple, black) | Chicago Gales (navy, orange) |
| Cincinnati Blaze (orange, black) | Detroit Motors (Honolulu blue, silver) |
| Cleveland Hounds (brown, orange) | Green Bay Lumberjacks (green, gold) |
| Pittsburgh Forge (black, gold) | Minnesota Loons (purple, gold) |

The nicknames are made up. Cities, nicknames and colors are in
`scripts/teams.gd`. The home team wears its colors and the away team wears
white, with its own helmet.

### Team strength types

When you pick your team you also pick how it's built. The other seven teams
get types of their own each season.

| Type | What it means |
|---|---|
| Smashmouth | Great running back and line, weaker passing game |
| Run & Gun | Quick quarterback, fast backs and receivers, softer defense |
| Air Raid | Big arm, sure hands, thin running game and defense |
| Balanced | A little above average everywhere |
| Strong Defense | Great line, linebackers and secondary; a plain offense |
| Tank for the Draft | Weak everywhere: the hard mode |

Every player has ratings (speed, power, tackling, hands, coverage, and arm
and accuracy for quarterbacks). They come from the position, the team type
and a little luck, and they decide everything on the field: who wins a
block, who runs past whom, whether a tackle sticks or a pass is caught.

## The art

The players are cut from the two sprite sheets in `art-source/`
(`players_light.png` and `players_dark.png`: the same poses with light and
dark skin) by `tools/cut_players.py`. It writes one image per pose to
`assets/players/`, plus a mask for each that marks the helmet and the
uniform, so the game can paint any team's colors on the same art with a
shader. Run it again after changing the sheets:

```
python3 tools/cut_players.py    # needs numpy, scipy, pillow
python3 tools/make_icon.py      # the app icon, from the cut poses
python3 tools/make_audio.py     # all music and sound effects
```

The music (a marching-band fight song in the menus, a drumline cadence and
the crowd during games) and every sound effect are generated from scratch
by `tools/make_audio.py`.

## Settings

**SETTINGS** on the title screen and the pause menu has the player
settings: difficulty, quarter length, volumes, vibration, screen shake,
swapping the sides, the move stick's size, defender switching and the
field view:

- **Whole field** (the default): zoomed out so both sidelines are always in
  view, like the old 8-bit games. The camera only scrolls along the field.
  The player size for this view is its own setting.
- **Zoomed in**: closer, and the camera follows the ball both ways.
  **Yards across the screen** sets how close.

### Developer settings

As in Snowball Fight, every number in the game is a developer setting:
speeds, the juke and dive, tackling, blocking, passing, kicking and the
computer's play.

| Build | Settings |
|---|---|
| `gridiron-north.apk` (sideload, from the build's downloads or a release) | Every developer setting, always |
| `gridiron-north.aab` (Google Play) | Only the player settings |
| The Godot editor or a desktop run | Tap the GRIDIRON NORTH title 7 times to turn developer mode on or off |

The defaults live in **`default_settings.cfg`**: one line per setting with
a comment saying what it is and its range. Tune the game in the APK, tap
**COPY AS DEFAULTS**, paste it over the file and commit. After adding a
setting to `scripts/tune.gd`, rewrite the file with
`godot --headless --path . -s res://tools/write_default_settings.gd`.

## Building

Every push builds on GitHub Actions (`.github/workflows/android.yml`):

1. runs the tests (`tests/run_tests.gd`: the rules, offside, the juke and
   dive tackle, kicks, the schedule, a season and full computer-vs-computer
   games),
2. plays touches through the real input path (hike, run, pull back and
   throw),
3. builds `gridiron-north.apk` (signed with the sideload key in `android/`),
4. launches it on an Android emulator,
5. builds the Google Play bundle if the upload key secrets are set
   (`PLAY_UPLOAD_KEYSTORE_BASE64`, `PLAY_UPLOAD_KEYSTORE_PASSWORD`,
   `PLAY_UPLOAD_KEY_ALIAS`), and
6. on `main`, publishes the APK as a release.

To run locally with Godot 4.7:

```
godot --path .                                           # play
godot --headless --path . -s res://tests/run_tests.gd    # tests
godot --headless --path . -s res://tests/balance_probe.gd  # how every play call does
```

### Not set up yet

Compared with Snowball Fight, this project has no ads and no iOS build yet.
Both need their own IDs: an AdMob app and ad units, and an App Store bundle.

## Files

| | |
|---|---|
| `scripts/game.gd` | The rules, clock, players and computer play (no drawing; the tests run it) |
| `scripts/playbook.gd` | Formations, routes, plays and defenses |
| `scripts/teams.gd` | Teams, colors, strength types and ratings |
| `scripts/league.gd` | The season: schedule, results, standings, North Bowl |
| `scripts/field.gd` | Draws the field, the players in team colors and the ball |
| `scripts/main.gd` | Menus, play calling, the touch controls and the HUD |
| `scripts/tune.gd` | Every setting with its range and default |
| `scripts/sfx.gd` | Sound effects, crowd and music |
