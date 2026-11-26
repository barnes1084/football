"""Renders the game's music and sound effects to WAV files.

Music (all original):
- menu.wav: a marching-band fight song (brass, glockenspiel, snare, bass drum)
- game.wav: a drumline cadence that loops under a game
- crowd.wav: a stadium crowd murmur that loops

Effects come in a few variants so repeats don't sound identical: the
referee's whistle, the quarterback's "hut", hits and big hits, throws,
catches, jukes, dives, footsteps, cheers, a groan, a kick, a touchdown
fanfare, a penalty-flag whistle and menu clicks.

Run: python3 tools/make_audio.py   (writes assets/audio/*.wav; needs numpy and scipy)
"""
import os
import wave

import numpy as np
from scipy import signal

SR = 32000
rng = np.random.default_rng(11)
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'audio')
os.makedirs(out, exist_ok=True)


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack, decay, sustain=0.0):
    x = np.arange(n) / SR
    e = np.minimum(1, x / max(attack, 1e-4))
    return e * (sustain + (1 - sustain) * np.exp(-np.maximum(0, x - attack) / max(decay, 1e-4) * 4))


def filt(x, kind, f, order=2):
    if kind == 'band':
        b, a = signal.butter(order, [f[0] / (SR / 2), min(0.99, f[1] / (SR / 2))], 'band')
    else:
        b, a = signal.butter(order, min(0.99, f / (SR / 2)), kind)
    return signal.lfilter(b, a, x)


def noise(sec):
    return rng.standard_normal(int(SR * sec))


def tone(sec, f, kind='sine', slide=1.0):
    n = int(SR * sec)
    freq = f * np.power(slide, np.arange(n) / max(1, n))
    ph = 2 * np.pi * np.cumsum(freq) / SR
    if kind == 'sine':
        return np.sin(ph)
    if kind == 'square':
        return np.sign(np.sin(ph)) * 0.6
    if kind == 'saw':
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    raise ValueError(kind)


def place(buf, x, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    n = min(len(x), len(buf) - i)
    buf[i:i + n] += x[:n]


def save(name, x, peak=0.9):
    x = np.asarray(x, float)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(out, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def note_hz(n):
    return 440.0 * 2 ** ((n - 69) / 12)


# ---------- Effects ----------

def fx_whistle(sec=0.55, chirp=False):
    t = t_axis(sec)
    trill = 1 + 0.03 * np.sign(np.sin(2 * np.pi * 38 * t))
    x = np.sin(2 * np.pi * np.cumsum(3100 * trill) / SR) + 0.3 * filt(noise(sec), 'band', (2500, 4200))
    e = env(len(t), 0.01, sec * 0.9, 0.7)
    e[-int(0.05 * SR):] *= np.linspace(1, 0, int(0.05 * SR))
    if chirp:
        e *= (np.sin(2 * np.pi * 7 * t) > -0.3)
    return x * e


def fx_hut(k):
    sec = 0.28
    t = t_axis(sec)
    f0 = 150 + k * 25
    voice = tone(sec, f0, 'saw', 0.85)
    v = filt(voice, 'band', (500, 1500)) + 0.6 * filt(voice, 'band', (1800, 2600))
    breath = filt(noise(sec), 'band', (800, 3000)) * env(len(t), 0.005, 0.05) * 0.8
    return (v * env(len(t), 0.02, 0.22) + breath) * 0.9


def fx_hit(k, big=False):
    sec = 0.4 if big else 0.25
    t = t_axis(sec)
    thump = tone(sec, (70 if big else 95) + k * 8, 'sine', 0.45) * env(len(t), 0.002, sec * 0.7)
    pads = filt(noise(sec), 'band', (300, 2200)) * env(len(t), 0.001, 0.06 if not big else 0.1)
    clack = filt(noise(sec), 'band', (2500, 6000)) * env(len(t), 0.001, 0.02) * (0.7 if big else 0.4)
    return thump * 1.3 + pads * 0.8 + clack


def fx_throw(k):
    sec = 0.35
    t = t_axis(sec)
    sweep = filt(noise(sec), 'band', (500 + k * 200, 2200)) * np.sin(np.pi * np.minimum(1, t / sec)) ** 2
    return sweep


def fx_catch(k):
    sec = 0.18
    t = t_axis(sec)
    pop = tone(sec, 220 + k * 40, 'sine', 0.6) * env(len(t), 0.001, 0.06)
    slap = filt(noise(sec), 'band', (900, 4000)) * env(len(t), 0.001, 0.03)
    return pop + slap * 0.9


def fx_juke(k):
    sec = 0.3
    t = t_axis(sec)
    swish = filt(noise(sec), 'band', (1200, 5000)) * np.sin(np.pi * np.minimum(1, t / sec)) ** 3
    squeak = tone(0.12, 1800 + k * 300, 'sine', 1.4) * env(int(0.12 * SR), 0.005, 0.08) * 0.35
    x = swish * 0.8
    place(x, squeak, 0.04)
    return x


def fx_dive(k):
    x = fx_throw(k) * 0.6
    place(x, fx_hit(k) * 0.7, 0.2)
    return x


def fx_step(k):
    sec = 0.09
    t = t_axis(sec)
    return filt(noise(sec), 'band', (150 + k * 40, 1200)) * env(len(t), 0.002, 0.03)


def crowd_bed(sec, excite=0.0):
    t = t_axis(sec)
    voices = np.zeros(len(t))
    for i in range(10):
        f = rng.uniform(300, 900)
        mod = 1 + 0.5 * np.sin(2 * np.pi * rng.uniform(0.2, 1.5) * t + rng.uniform(0, 6))
        voices += filt(noise(sec), 'band', (f, f * 1.8)) * mod
    hiss = filt(noise(sec), 'band', (1500, 5000)) * (0.2 + excite * 0.6)
    return voices * 0.15 + hiss


def fx_cheer(k):
    sec = 2.4
    t = t_axis(sec)
    x = crowd_bed(sec, 1.0) * 2.0
    swell = np.minimum(1, t / 0.25) * np.exp(-np.maximum(0, t - 0.6) * 1.6)
    whoops = np.zeros(len(t))
    for i in range(6):
        w = tone(0.35, rng.uniform(500, 900), 'saw', rng.uniform(1.3, 1.8))
        w = filt(w, 'band', (600, 2500)) * env(len(w), 0.03, 0.3)
        place(whoops, w * 0.3, rng.uniform(0.1, 1.2))
    return (x + whoops) * swell


def fx_groan():
    sec = 1.6
    t = t_axis(sec)
    x = np.zeros(len(t))
    for i in range(8):
        v = tone(1.2, rng.uniform(120, 220), 'saw', 0.7)
        v = filt(v, 'band', (300, 1100)) * env(len(v), 0.1, 1.0)
        place(x, v * 0.4, rng.uniform(0, 0.25))
    return x + crowd_bed(sec) * 0.5 * np.exp(-t * 1.5)


def fx_kick():
    sec = 0.3
    t = t_axis(sec)
    return tone(sec, 110, 'sine', 0.5) * env(len(t), 0.001, 0.12) * 1.4 + filt(noise(sec), 'band', (400, 3000)) * env(len(t), 0.001, 0.03)


def brass(note, sec, vol=1.0):
    n = int(SR * sec)
    f = note_hz(note)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * np.arange(n) / SR)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    x = sum(np.sin(ph * h) / h ** 0.9 for h in range(1, 9))
    x = filt(x, 'low', 2600)
    return x * env(n, 0.03, sec * 1.4, 0.75) * vol * np.minimum(1, (n - np.arange(n)) / (0.03 * SR))


def glock(note, sec):
    n = int(SR * sec)
    f = note_hz(note + 24)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2.76 * t)) * env(n, 0.001, 0.5) * 0.35


def snare(vol=1.0):
    sec = 0.18
    t = t_axis(sec)
    return (filt(noise(sec), 'band', (1500, 7000)) * env(len(t), 0.001, 0.12) + tone(sec, 190, 'sine', 0.7) * env(len(t), 0.001, 0.05) * 0.6) * vol


def bass_drum(vol=1.0):
    sec = 0.35
    t = t_axis(sec)
    return tone(sec, 75, 'sine', 0.55) * env(len(t), 0.002, 0.25) * 1.5 * vol


def tenor(note, vol=1.0):
    sec = 0.2
    t = t_axis(sec)
    return tone(sec, note, 'sine', 0.8) * env(len(t), 0.001, 0.12) * vol + filt(noise(sec), 'band', (800, 3000)) * env(len(t), 0.001, 0.02) * 0.3


def cymbal(vol=1.0):
    sec = 1.0
    t = t_axis(sec)
    return filt(noise(sec), 'high', 5000) * env(len(t), 0.002, 0.8) * 0.5 * vol


def fx_td():
    beat = 0.16
    x = np.zeros(int(SR * 1.8))
    for i, (n, d) in enumerate([(67, 1), (67, 1), (67, 1), (72, 4), (76, 2), (79, 6)]):
        at = sum(dd for _, dd in [(67, 1), (67, 1), (67, 1), (72, 4), (76, 2), (79, 6)][:i]) * beat
        place(x, brass(n, d * beat * 0.95) + brass(n - 12, d * beat * 0.95) * 0.6, at)
    place(x, cymbal(), 0.48)
    place(x, snare(), 0.0)
    place(x, snare(), 0.16)
    place(x, snare(), 0.32)
    place(x, bass_drum(), 0.48)
    return x


def fx_tick():
    sec = 0.05
    t = t_axis(sec)
    return tone(sec, 1400, 'square') * env(len(t), 0.001, 0.02)


def fx_select():
    sec = 0.12
    t = t_axis(sec)
    return tone(sec, 880, 'sine', 1.5) * env(len(t), 0.002, 0.08)


def fx_first():
    x = np.zeros(int(SR * 0.6))
    place(x, brass(72, 0.18) * 0.7, 0)
    place(x, brass(79, 0.35) * 0.7, 0.15)
    return x


def make_effects():
    save('whistle', fx_whistle())
    save('flag', fx_whistle(0.9, True), 0.8)
    for k in range(2):
        save('hike%d' % k, fx_hut(k))
        save('throw%d' % k, fx_throw(k), 0.6)
        save('catch%d' % k, fx_catch(k))
        save('juke%d' % k, fx_juke(k), 0.7)
        save('dive%d' % k, fx_dive(k), 0.8)
        save('hit_big%d' % k, fx_hit(k, True))
        save('cheer%d' % k, fx_cheer(k), 0.8)
    for k in range(3):
        save('hit%d' % k, fx_hit(k))
        save('step%d' % k, fx_step(k), 0.5)
    save('groan', fx_groan(), 0.7)
    save('kick', fx_kick())
    save('td', fx_td(), 0.85)
    save('tick', fx_tick(), 0.5)
    save('select', fx_select(), 0.6)
    save('first', fx_first(), 0.7)


# ---------- Music ----------

def fight_song():
    """An original fight song in B-flat, 32 bars at 132 bpm."""
    bpm = 132
    beat = 60 / bpm
    # (note, beats); 0 = rest. Four 8-bar phrases: A A' B A''.
    a = [(70, 1), (72, 0.5), (74, 0.5), (75, 1), (77, 1), (79, 2), (77, 1), (75, 1),
         (74, 1), (75, 0.5), (77, 0.5), (74, 1), (70, 1), (72, 3), (0, 1),
         (70, 1), (72, 0.5), (74, 0.5), (75, 1), (77, 1), (79, 2), (82, 1), (79, 1),
         (77, 1), (75, 1), (74, 1), (72, 1), (70, 3), (0, 1)]
    b = [(77, 1.5), (77, 0.5), (79, 1), (77, 1), (75, 2), (74, 2),
         (75, 1.5), (75, 0.5), (77, 1), (75, 1), (74, 2), (72, 2),
         (74, 1), (75, 1), (77, 1), (79, 1), (81, 2), (82, 2),
         (81, 1), (79, 1), (77, 1), (75, 1), (77, 4)]
    end = [(70, 1), (72, 0.5), (74, 0.5), (75, 1), (77, 1), (79, 2), (82, 1), (79, 1),
           (77, 1), (79, 1), (81, 1), (77, 1), (82, 3), (0, 1)]
    melody = a + b + end
    total = sum(d for _, d in melody)
    sec = total * beat + 1.0
    x = np.zeros(int(SR * sec))
    at = 0.0
    for n, d in melody:
        if n:
            place(x, brass(n, d * beat * 0.92) * 0.8, at)
            place(x, glock(n, d * beat), at)
        at += d * beat
    # Harmony: root on each bar, by phrase.
    roots = ([46, 46, 51, 51, 46, 46, 53, 46] * 2 + [53, 51, 53, 48, 50, 51, 53, 53] + [46, 46, 51, 51, 46, 53, 46, 46])
    bars = int(total / 4)
    for bar in range(bars):
        r = roots[bar % len(roots)]
        for bt in range(4):
            t0 = (bar * 4 + bt) * beat
            place(x, brass(r - 12 if bt % 2 == 0 else r - 5, beat * 0.8, 0.5), t0)
            place(x, bass_drum(0.8 if bt % 2 == 0 else 0.4), t0)
            place(x, snare(0.5), t0 + beat * 0.5)
            if bt % 2 == 1:
                place(x, snare(0.8), t0)
        if bar % 8 == 0:
            place(x, cymbal(0.7), bar * 4 * beat)
    return x[:int(total * beat * SR)]


def cadence():
    """A drumline cadence: 8 bars at 112 bpm, snare grooves over tenors and bass."""
    bpm = 112
    beat = 60 / bpm
    bars = 8
    x = np.zeros(int(SR * bars * 4 * beat))
    six = beat / 4
    groove = [1, 0, 0.5, 1, 0, 0.5, 1, 0, 1, 0, 0.5, 1, 0.5, 0.5, 1, 1]
    for bar in range(bars):
        for i, v in enumerate(groove):
            t0 = (bar * 16 + i) * six
            if v:
                place(x, snare(0.55 * v), t0)
            if i % 4 == 0:
                place(x, bass_drum(0.9 if i % 8 == 0 else 0.6), t0)
            if bar % 2 == 1 and i in (2, 6, 10, 14):
                place(x, tenor([220, 180, 150, 120][(i // 4)], 0.5), t0)
        if bar % 4 == 3:
            for j in range(8):
                place(x, tenor([260, 220, 180, 150, 260, 220, 180, 150][j], 0.6), (bar * 16 + 8 + j) * six)
        if bar % 4 == 0:
            place(x, cymbal(0.4), bar * 16 * six)
    return x


def crowd():
    sec = 8.0
    x = crowd_bed(sec)
    # Crossfade the ends so it loops smoothly.
    n = int(0.5 * SR)
    fade = np.linspace(0, 1, n)
    x[:n] = x[:n] * fade + x[-n:] * (1 - fade)
    return x[:-n]


if __name__ == '__main__':
    make_effects()
    save('menu', fight_song(), 0.75)
    save('game', cadence(), 0.7)
    save('crowd', crowd(), 0.6)
    print('wrote', len(os.listdir(out)), 'files to', os.path.abspath(out))
