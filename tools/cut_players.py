"""Cuts the player sprite sheets in art-source/ into one image per pose.

art-source/players_light.png and players_dark.png show the same player in
the same poses, one with light skin and one with dark skin, in a white
uniform on a white background, all facing right. For each figure this:
- makes the background clear (flood fill from the edges),
- cuts the figure out and lines it up on its feet,
- writes a second image, the uniform mask, that says which pixels are the
  helmet (red) and the uniform (green), so the
  game can paint every team's colors on the same art,
- saves the loose football on the throwing row as the ball sprite.

Extra poses come from single-figure images (EXTRA below): the blocking
stance in art-source/pass_block.png is scaled to the size of a pose from the
sheets, and its skin is recolored to the light and dark skin tones.

Run: python3 tools/cut_players.py   (writes assets/players/<skin>/<pose>.png,
<pose>_mask.png, assets/players/ball.png and assets/players/meta.json)
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
src_dir = os.path.join(root, 'art-source')
out = os.path.join(root, 'assets', 'players')

SKINS = {'light': 'players_light.png', 'dark': 'players_dark.png'}

# The figures on each row, left to right (the loose ball is not a figure).
ROWS = [
    ['stand', 'ready', 'set', 'stance', 'stance2', 'run1', 'run2', 'run3', 'run4', 'run5'],
    ['sprint1', 'sprint2', 'sprint3', 'stiff', 'burst', 'hurdle', 'block', 'push1', 'push2'],
    ['hold', 'hold2', 'windup', 'windup2', 'release', 'follow', 'reach', 'catch', 'catch2', 'tuck', 'carry1', 'carry2'],
    ['crouch', 'lunge', 'dive', 'layout', 'down', 'pile', 'getup', 'lb', 'lb2'],
]
PAD = 4

# Extra poses from one-figure images: pose -> (file, pose on the sheets to match in height).
EXTRA = {'passblock': ('pass_block.png', 'block')}
# The skin tones of the two sheets (a mid tone; shading keeps its lightness).
SKIN_TONE = {'light': np.array([240, 178, 104]), 'dark': np.array([112, 50, 8])}


def key_out(a):
    px = a[..., :3].astype(int)
    light = (px.min(axis=2) > 225) & (px.max(axis=2) - px.min(axis=2) < 30)
    lab, _ = ndimage.label(light)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    bg = np.isin(lab, edge[edge > 0])
    a = a.copy()
    a[bg] = 0
    # Soften the light fringe left around the outlines.
    near = ndimage.binary_dilation(bg, iterations=2) & ~bg
    a[near & (px.min(axis=2) > 200), 3] = 0
    return a


def row_bands(fg):
    lab, _ = ndimage.label(fg.sum(axis=1) > 3)
    return [(s.start, s.stop) for (s,) in ndimage.find_objects(lab) if s.stop - s.start > 40]


def uniform_mask(img, force_upright=None):
    """Which pixels are uniform (white/grey, not skin, not outline), split
    into helmet, jersey and pants by the outlines between them."""
    px = img[..., :3].astype(float)
    alpha = img[..., 3] > 128
    mx = px.max(axis=2)
    mn = px.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1)
    cloth = alpha & (sat < 0.16) & (mx > 120)
    h, w = cloth.shape
    lab, n = ndimage.label(cloth)
    region = np.zeros((h, w), np.uint8)  # 0 none, 1 helmet, 2 jersey, 3 pants
    if n == 0:
        return region
    ys, xs = np.nonzero(alpha)
    top, bottom = ys.min(), ys.max()
    height = bottom - top + 1
    # The head: the highest part of the figure, front-most when lying down.
    upright = height > w * 0.6 if force_upright is None else force_upright
    sizes = ndimage.sum(cloth, lab, range(1, n + 1))
    cents = ndimage.center_of_mass(cloth, lab, range(1, n + 1))
    objs = ndimage.find_objects(lab)
    # The helmet is the biggest piece in the top of the figure (upright)
    # or at its front end (lying down).
    if upright:
        score = [(-(c[0] - top) / height + (sizes[i] / sizes.max()) * 0.35, i) for i, c in enumerate(cents)]
        cand = [(s, i) for s, i in score if (objs[i][0].stop - top) < height * 0.42 and sizes[i] > 60]
    else:
        right = xs.max()
        score = [(-(right - c[1]) / w + (sizes[i] / sizes.max()) * 0.3 - (c[0] - top) / height * 0.3, i) for i, c in enumerate(cents)]
        cand = [(s, i) for s, i in score if (right - objs[i][1].start) < w * 0.4 and sizes[i] > 60]
    helmet = max(cand)[1] if cand else -1
    hel_y = cents[helmet][0] if helmet >= 0 else top
    # Below the belt is pants: a little under the middle of what's left.
    body_top = objs[helmet][0].stop if helmet >= 0 else top
    belt = body_top + (bottom - body_top) * (0.42 if upright else 0.5)
    for i in range(n):
        m = lab == i + 1
        if i == helmet:
            region[m] = 1
        elif not upright:
            # Lying down: the legs are at the back (left).
            region[m] = 3 if cents[i][1] < w * 0.45 else 2
        else:
            region[m] = 3 if cents[i][0] > belt else 2
    # Shirt and pants often run together with no outline between them, so
    # telling them apart flickers from frame to frame: the whole uniform is
    # one color (the jersey) under a helmet of its own color.
    region[region == 3] = 2
    return region


def main():
    os.makedirs(out, exist_ok=True)
    meta = {}
    for skin, fname in SKINS.items():
        a = np.asarray(Image.open(os.path.join(src_dir, fname)).convert('RGBA'))
        a = key_out(a)
        fg = a[..., 3] > 40
        os.makedirs(os.path.join(out, skin), exist_ok=True)
        for row, (y0, y1) in zip(ROWS, row_bands(fg)):
            y0 = max(0, y0 - 6)
            y1 = min(a.shape[0], y1 + 6)
            lab, _ = ndimage.label(fg[y0:y1], structure=np.ones((3, 3)))
            pieces = []
            for i, s in enumerate(ndimage.find_objects(lab)):
                area = (lab[s] == i + 1).sum()
                if area >= 30:
                    pieces.append((s[1].start, s[1].stop, i + 1, area))
            pieces.sort()
            figures = [p for p in pieces if p[3] > 5000]
            loose = [p for p in pieces if p[3] <= 5000]
            assert len(figures) == len(row), (skin, len(figures), len(row))
            if row[0] == 'hold' and loose and skin == 'light':
                x0, x1, li, _ = loose[0]
                m = lab == li
                ys, xs = np.nonzero(m)
                ball = a[y0:y1][ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()
                ball[~m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]] = 0
                Image.fromarray(ball).save(os.path.join(out, 'ball.png'))
                meta['ball'] = {'size': [int(ball.shape[1]), int(ball.shape[0])]}
            for name, (x0, x1, li, _) in zip(row, figures):
                m = lab == li
                ys, xs = np.nonzero(m)
                cut = a[y0:y1][ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()
                cut[~m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]] = 0
                cut = np.pad(cut, ((PAD, PAD), (PAD, PAD), (0, 0)))
                h, w = cut.shape[:2]
                # The feet: the middle of the lowest few rows of the figure.
                opaque = cut[..., 3] > 128
                rows_any = np.nonzero(opaque.any(axis=1))[0]
                foot_y = int(rows_any.max())
                low = opaque[foot_y - 12:foot_y + 1].any(axis=0)
                fx = np.nonzero(low)[0]
                foot_x = int((fx.min() + fx.max()) / 2)
                Image.fromarray(cut).save(os.path.join(out, skin, name + '.png'))
                region = uniform_mask(cut)
                mask = np.zeros((h, w, 4), np.uint8)
                mask[region == 1] = [255, 0, 0, 255]
                mask[region == 2] = [0, 255, 0, 255]
                mask[region == 3] = [0, 0, 255, 255]
                Image.fromarray(mask).save(os.path.join(out, skin, name + '_mask.png'))
                if skin == 'light':
                    meta[name] = {'size': [w, h], 'foot': [foot_x, foot_y], 'top': int(rows_any.min())}
    for name, (fname, ref) in EXTRA.items():
        cut_extra(name, fname, ref, meta)
    with open(os.path.join(out, 'meta.json'), 'w') as f:
        json.dump(meta, f, indent=1)
    print('wrote', len(meta) - 1, 'poses')


def cut_extra(name, fname, ref, meta):
    """One figure from its own image, scaled to the height of `ref`, in both skins."""
    a = key_out(np.asarray(Image.open(os.path.join(src_dir, fname)).convert('RGBA')))
    ys, xs = np.nonzero(a[..., 3] > 40)
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    ref_h = meta[ref]['foot'][1] - meta[ref]['top']
    scale = ref_h / a.shape[0]
    img = Image.fromarray(a).resize((max(1, round(a.shape[1] * scale)), max(1, round(a.shape[0] * scale))), Image.LANCZOS)
    a = np.asarray(img).copy()
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
    px = a[..., :3].astype(float)
    skin = (a[..., 3] > 0) & (px[..., 0] - px[..., 2] > 50) & (px.max(axis=2) > 50)
    lum = px.mean(axis=2) / max(1.0, px[skin].mean(axis=1).mean()) if skin.any() else None
    cut = np.pad(a, ((PAD, PAD), (PAD, PAD), (0, 0)))
    skin = np.pad(skin, PAD)
    lum = np.pad(lum, PAD, constant_values=1.0) if lum is not None else None
    h, w = cut.shape[:2]
    opaque = cut[..., 3] > 128
    rows_any = np.nonzero(opaque.any(axis=1))[0]
    foot_y = int(rows_any.max())
    low = opaque[foot_y - 12:foot_y + 1].any(axis=0)
    fx = np.nonzero(low)[0]
    foot_x = int((fx.min() + fx.max()) / 2)
    for skin_name, tone in SKIN_TONE.items():
        out_img = cut.copy()
        if lum is not None:
            out_img[skin, :3] = np.clip(tone[None, :] * lum[skin][:, None], 0, 255).astype(np.uint8)
        Image.fromarray(out_img).save(os.path.join(out, skin_name, name + '.png'))
        region = uniform_mask(out_img, force_upright=True)
        mask = np.zeros((h, w, 4), np.uint8)
        mask[region == 1] = [255, 0, 0, 255]
        mask[region == 2] = [0, 255, 0, 255]
        Image.fromarray(mask).save(os.path.join(out, skin_name, name + '_mask.png'))
    meta[name] = {'size': [w, h], 'foot': [foot_x, foot_y], 'top': int(rows_any.min())}


if __name__ == '__main__':
    main()
