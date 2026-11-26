## Plays the sound effects (several variants of each, picked at random), the
## crowd and the music: a marching-band fight song in the menus and a drum
## cadence during a game.
extends Node

## Effect name -> how many variants (name0.wav, name1.wav, ...); 0 = one file, no number.
const EFFECTS := {
	whistle = 0, hike = 2, hit = 3, hit_big = 2, throw = 2, catch = 2, juke = 2, dive = 2, step = 3,
	cheer = 2, groan = 0, kick = 0, td = 0, flag = 0, tick = 0, select = 0, first = 0,
}
const TRACKS := ["menu", "game"]

var _streams := {}
var _last := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _crowd: AudioStreamPlayer
var _track := ""
var _fade := 0.0
var _crowd_on := false
var _last_step := 0


func _load(path: String) -> AudioStream:
	return load(path) if ResourceLoader.exists(path) else null


func _ready() -> void:
	Tune.ensure()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for name in EFFECTS:
		var count: int = EFFECTS[name]
		var list := []
		if count == 0:
			list.append(_load("res://assets/audio/%s.wav" % name))
		else:
			for i in count:
				list.append(_load("res://assets/audio/%s%d.wav" % [name, i]))
		list = list.filter(func(s): return s != null)
		if list.size():
			_streams[name] = list
	for t in TRACKS + ["crowd"]:
		var song: AudioStreamWAV = _load("res://assets/audio/%s.wav" % t)
		if song == null:
			continue
		song.loop_mode = AudioStreamWAV.LOOP_FORWARD
		song.loop_begin = 0
		song.loop_end = int(song.get_length() * song.mix_rate)
		_streams["music_" + t] = [song]
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_crowd = AudioStreamPlayer.new()
	add_child(_crowd)
	if _streams.has("music_crowd"):
		_crowd.stream = _streams.music_crowd[0]
	music("menu")
	apply()


func _db(v: float) -> float:
	return linear_to_db(maxf(0.0001, v))


## Applies the volume settings.
func apply() -> void:
	_music.volume_db = _db(Tune.v.musicVolume * 0.7)
	_music.stream_paused = Tune.v.musicVolume <= 0
	_crowd.volume_db = _db(Tune.v.crowdVolume * 0.6)
	_crowd.stream_paused = Tune.v.crowdVolume <= 0 or not _crowd_on


## Switches the music to a track ("menu" or "game"), with a quick fade.
func music(track: String) -> void:
	if track == _track or not _streams.has("music_" + track):
		return
	_track = track
	_fade = 1.0
	_music.stream = _streams["music_" + track][0]
	_music.play()
	apply()
	_music.volume_db -= 18.0


## The crowd murmur under a game.
func crowd(on: bool) -> void:
	if on == _crowd_on:
		return
	_crowd_on = on
	if on and _crowd.stream != null:
		_crowd.play()
	apply()


func _process(delta: float) -> void:
	if _fade > 0:
		_fade = maxf(0.0, _fade - delta * 3.0)
		_music.volume_db = _db(Tune.v.musicVolume * 0.7) - 18.0 * _fade


## Plays a random variant of an effect (never the same one twice in a row).
func play(name: String, gain := 1.0, pitch := 1.0) -> void:
	if Tune.v.sfxVolume <= 0 or not _streams.has(name):
		return
	var list: Array = _streams[name]
	var i := randi() % list.size()
	if list.size() > 1 and i == _last.get(name, -1):
		i = (i + 1) % list.size()
	_last[name] = i
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = list[i]
	p.volume_db = _db(Tune.v.sfxVolume * gain)
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()


## Sound for a game event. `user` is the person's team (-1 in the demo).
func event(e: Dictionary, user: int) -> void:
	var mine: bool = e.get("team", -2) == user
	match e.type:
		"whistle":
			play("whistle", 0.55)
		"hike":
			play("hike", 0.8)
		"throw":
			play("throw", 0.8)
		"catch":
			play("catch")
			play("cheer", 0.35)
		"int":
			play("catch")
			play("cheer" if not mine else "cheer", 0.6)
		"handoff":
			play("catch", 0.5)
		"tackle":
			play("hit_big" if e.get("big", false) else "hit")
			if Tune.v.vibrate and user >= 0:
				Input.vibrate_handheld(60)
		"block":
			play("hit", 0.25, 0.8)
		"miss":
			play("juke", 0.6)
		"juke":
			play("juke", 0.8)
		"dive":
			play("dive", 0.8)
		"td":
			play("td")
			play("cheer", 0.9)
		"fg":
			play("cheer", 0.8)
		"miss_fg":
			play("groan", 0.7)
		"kick":
			play("kick")
		"flag":
			play("flag")
		"first":
			play("first", 0.6)
		"select":
			play("select", 0.6)
		"final":
			play("cheer", 0.9)
