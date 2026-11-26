"""Draws the app icon (icon.png, 512x512) and the iOS/App Store one
(assets/icons/ios_1024.png): a ball carrier in navy and gold on a striped
field. Run: python3 tools/make_icon.py (after tools/cut_players.py)."""
import os

import numpy as np
from PIL import Image, ImageDraw

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')


def colored(pose, skin='dark', jersey=(24, 44, 92), helmet=(240, 182, 30)):
    img = np.asarray(Image.open(os.path.join(root, 'assets/players', skin, pose + '.png')).convert('RGBA')).astype(float)
    mask = np.asarray(Image.open(os.path.join(root, 'assets/players', skin, pose + '_mask.png')).convert('RGBA')).astype(float) / 255
    lum = (img[..., :3] @ np.array([0.299, 0.587, 0.114])) / 255
    shade = np.clip((lum - 0.25) / 0.75, 0, 1)[..., None]
    j = np.array(jersey) / 255 * (0.42 + 0.66 * shade) + 0.1 * shade ** 2
    h = np.array(helmet) / 255 * (0.45 + 0.6 * shade) + 0.3 * shade ** 8
    col = img[..., :3] / 255
    col = col * (1 - mask[..., 1:2]) + j * mask[..., 1:2]
    col = col * (1 - mask[..., 0:1]) + h * mask[..., 0:1]
    out = np.concatenate([np.clip(col, 0, 1) * 255, img[..., 3:4]], axis=2)
    return Image.fromarray(out.astype(np.uint8))


def icon(size):
    im = Image.new('RGBA', (size, size))
    d = ImageDraw.Draw(im)
    stripe = size // 6
    for i in range(7):
        d.rectangle([i * stripe, 0, (i + 1) * stripe, size], fill=(60, 140, 52) if i % 2 else (67, 152, 58))
    for i in range(7):
        x = i * stripe
        d.rectangle([x - size // 200, 0, x + size // 200, size], fill=(240, 240, 240))
    p = colored('burst')
    scale = size * 0.86 / max(p.size)
    p = p.resize((int(p.width * scale), int(p.height * scale)), Image.NEAREST)
    shadow = Image.new('RGBA', im.size)
    sd = ImageDraw.Draw(shadow)
    cx = size // 2
    sd.ellipse([cx - size * 0.3, size * 0.82, cx + size * 0.3, size * 0.92], fill=(0, 0, 0, 80))
    im.alpha_composite(shadow)
    im.alpha_composite(p, (int(cx - p.width / 2), int(size * 0.9 - p.height)))
    return im


if __name__ == '__main__':
    icon(512).save(os.path.join(root, 'icon.png'))
    os.makedirs(os.path.join(root, 'assets/icons'), exist_ok=True)
    icon(1024).convert('RGB').save(os.path.join(root, 'assets/icons/ios_1024.png'))
    print('wrote icon.png and assets/icons/ios_1024.png')
