"""Pixel-art Mexican cantina background for the game tables (no external art, no licences).

Drawn pixel by pixel at low resolution with a fixed palette, then shown by Flutter with
nearest-neighbour scaling (FilterQuality.none) so it stays crisp on any screen.

The table oval covers the centre (about x 10-90 %, y 20-85 %), so the detail lives where it
is seen: the ceiling band (beams, papel picado, tin lamps), both sides (bottle shelves, a
nopal in a clay pot, a guitar and a sombrero) and the floor at the bottom.

    python tool/pixelart/cantina.py                  -> assets/images/cantina/cantina_bg.png
    python tool/pixelart/cantina.py --preview FILE   -> also a 4x preview
    python tool/pixelart/cantina.py --mask FILE      -> preview with the table oval drawn on top
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

# Two widths, same drawing: phones are about 20:9, PCs and tablets 16:9. Right-hand objects
# are placed from the right edge (R(x) = W - x), so nothing is cropped in either proportion.
VARIANTS = {'cantina_bg.png': 444, 'cantina_bg_16x9.png': 356}
H = 200
_name = next((a.split('=', 1)[1] for a in sys.argv if a.startswith('--variant=')), 'cantina_bg.png')
W = VARIANTS[_name]
random.seed(11)


def R(x):
    """x measured from the right edge."""
    return W - x

P = {
    'void': (16, 9, 10),
    'beam_d': (40, 22, 15), 'beam': (66, 37, 23), 'beam_l': (96, 57, 33), 'beam_h': (130, 82, 47),
    'board': (30, 17, 12), 'board_l': (46, 26, 17),
    'wall_dd': (70, 32, 24), 'wall_d': (98, 46, 32), 'wall': (128, 62, 41), 'wall_l': (156, 82, 52),
    'wall_h': (188, 108, 64), 'wall_hh': (222, 146, 86),
    'wood_d': (42, 22, 14), 'wood': (72, 40, 23), 'wood_l': (104, 61, 34), 'wood_h': (140, 88, 48),
    'tile_d': (88, 40, 28), 'tile': (130, 62, 40), 'tile_l': (160, 86, 54), 'grout': (52, 26, 19),
    'talav_w': (234, 224, 198), 'talav_b': (36, 76, 156), 'talav_bl': (82, 128, 204), 'talav_y': (224, 172, 56),
    'green_d': (20, 64, 34), 'green': (38, 106, 54), 'green_l': (76, 152, 76), 'green_h': (140, 200, 108),
    'amber_d': (112, 54, 12), 'amber': (176, 98, 24), 'amber_l': (226, 158, 54), 'amber_h': (250, 206, 120),
    'clear_d': (112, 128, 134), 'clear': (170, 190, 192), 'clear_l': (226, 238, 234),
    'red_d': (104, 20, 26), 'red': (166, 36, 40), 'red_l': (214, 78, 66),
    'clay_d': (108, 44, 25), 'clay': (162, 76, 40), 'clay_l': (204, 112, 60), 'clay_h': (234, 154, 94),
    'straw_d': (140, 98, 38), 'straw': (200, 152, 68), 'straw_l': (236, 200, 112), 'straw_h': (250, 230, 168),
    'tin_d': (90, 86, 78), 'tin': (156, 150, 136), 'tin_l': (212, 206, 188),
    'glow1': (255, 206, 120), 'glow2': (255, 240, 196),
    'pp_pink': (232, 62, 136), 'pp_orange': (244, 128, 36), 'pp_yellow': (246, 206, 52),
    'pp_green': (54, 178, 94), 'pp_blue': (54, 134, 224), 'pp_purple': (144, 76, 198),
    'string': (34, 20, 16), 'black': (24, 14, 12),
}

img = Image.new('RGB', (W, H), P['void'])
px = img.load()
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = c if isinstance(c, tuple) else P[c]


def rect(x0, y0, x1, y1, c):
    for y in range(max(0, y0), min(H, y1)):
        for x in range(max(0, x0), min(W, x1)):
            put(x, y, c)


def dither(x, y, t):
    return t * 16 > BAYER[y % 4][x % 4] + 0.5


def mix(a, b, t):
    a = P[a] if isinstance(a, str) else a
    b = P[b] if isinstance(b, str) else b
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


CEIL = 18          # ceiling boards + beams
WAIN = 136         # wood wainscot starts
FLOOR = 166        # floor starts
LAMPS = [(84, 36), (W // 2, 32), (R(84), 36)]

# --- 1. ceiling: dark boards and round beams ------------------------------------------------
for y in range(CEIL):
    for x in range(W):
        put(x, y, 'board_l' if (x // 6 + y // 3) % 7 == 0 else 'board')
for bx in range(-4, W, 30):
    for y in range(0, CEIL + 3):
        for i, c in enumerate(('beam_d', 'beam', 'beam_l', 'beam_h', 'beam_l', 'beam', 'beam', 'beam_d')):
            put(bx + i, y, c)
    for i in range(8):  # rounded beam end catching the light
        put(bx + i, CEIL + 3, 'beam_d' if i in (0, 7) else 'beam')
rect(0, CEIL, W, CEIL + 1, 'black')

# --- 2. plastered adobe wall with banded lamp light ------------------------------------------
BANDS = ['wall_d', 'wall', 'wall_l', 'wall_h', 'wall_hh']
for y in range(CEIL + 1, WAIN):
    for x in range(W):
        light = 0.0
        for lx, ly in LAMPS:
            d = math.hypot((x - lx) * 0.7, (y - ly) * 1.0)
            light = max(light, 1 - d / 82)
        light = max(0.0, light) + 0.18 - 0.25 * (y - CEIL) / (WAIN - CEIL)
        level = light * (len(BANDS) - 1)
        base = int(max(0, min(len(BANDS) - 1, level)))
        frac = level - base
        c = BANDS[base]
        # dither only along the band edge (pixel-art style), not all over the wall
        if base + 1 < len(BANDS) and frac > 0.7 and dither(x, y, (frac - 0.7) / 0.3):
            c = BANDS[base + 1]
        put(x, y, c)
# plaster texture: a few chipped spots showing the adobe brick underneath
for _ in range(22):
    x, y = random.randrange(W), random.randrange(CEIL + 8, WAIN - 8)
    w, h = random.randint(4, 9), random.randint(2, 4)
    for yy in range(h):
        for xx in range(w):
            if random.random() < 0.8:
                put(x + xx, y + yy, mix(px[min(W - 1, x + xx), min(H - 1, y + yy)], 'wall_dd', 0.45))
    rect(x, y + h, x + w, y + h + 1, mix('wall_dd', 'void', 0.2))

# --- 3. side shelving with bottles --------------------------------------------------------------
KINDS = {
    'tequila': ('clear_d', 'clear', 'clear_l', 12, 'red'),
    'mezcal': ('green_d', 'green', 'green_l', 14, 'straw_d'),
    'anejo': ('amber_d', 'amber', 'amber_l', 11, 'black'),
    'vino': ('red_d', 'red', 'red_l', 13, 'straw_d'),
    'jarro': ('clay_d', 'clay', 'clay_l', 8, None),
}


def bottle(x, base, kind):
    d, m, l, h, cap = KINDS[kind]
    top = base - h
    if kind == 'jarro':  # clay jug
        for y in range(top, base):
            half = 3 if y > top + 2 else 2
            for i in range(-half, half + 1):
                put(x + 2 + i, y, l if i == -half + 1 else (d if i == half else m))
        put(x + 5, top + 3, 'clay_d'); put(x + 6, top + 4, 'clay_d')
        return
    for y in range(top + 4, base):
        for i in range(5):
            put(x + i, y, d if i == 4 else (l if i == 1 else m))
    for y in range(top, top + 4):
        put(x + 1, y, l); put(x + 2, y, m); put(x + 3, y, d)
    if cap:
        put(x + 2, top - 1, cap); put(x + 1, top - 1, cap)
    for y in range(top + 6, top + 9):
        for i in range(1, 4):
            put(x + i, y, 'straw_h' if kind != 'anejo' else 'talav_w')
    put(x + 1, top + 5, 'clear_l')  # glint


def shelf_unit(x0, x1, rows):
    rect(x0 - 3, rows[0] - 22, x1 + 3, rows[-1] + 5, 'wood_d')
    rect(x0 - 2, rows[0] - 21, x1 + 2, rows[-1] + 4, mix('wood_d', 'void', 0.35))
    for ry in rows:
        rect(x0 - 3, ry, x1 + 3, ry + 3, 'wood')
        rect(x0 - 3, ry, x1 + 3, ry + 1, 'wood_h')
        rect(x0 - 3, ry + 3, x1 + 3, ry + 4, 'black')
        x = x0
        while x < x1 - 5:
            bottle(x, ry, random.choice(['tequila', 'mezcal', 'anejo', 'vino', 'tequila', 'jarro']))
            x += random.choice((6, 7, 7, 8))


shelf_unit(6, 46, [72, 98, 124])
shelf_unit(R(46), R(6), [72, 98, 124])

# --- 4. talavera plates on the wall (top corners, between garlands and shelves) ---------------
def plate(cx, cy, r, accent):
    for y in range(-r, r + 1):
        for x in range(-r, r + 1):
            d = math.hypot(x, y)
            if d <= r:
                c = 'talav_w'
                if d > r - 1.2:
                    c = 'talav_b'
                elif abs(d - r * 0.55) < 0.8:
                    c = accent
                elif d < 1.6:
                    c = 'talav_b'
                elif (abs(x) == abs(y)) and d < r * 0.5:
                    c = 'talav_bl'
                put(cx + x, cy + y, c)
    put(cx - r // 2, cy - r // 2, 'clear_l')



# --- 5. papel picado ---------------------------------------------------------------------------
COLORS = ['pp_pink', 'pp_orange', 'pp_yellow', 'pp_green', 'pp_blue', 'pp_purple']


def flag(x, top, color, sway):
    dark = mix(color, 'void', 0.32)
    light = mix(color, 'glow2', 0.25)
    for yy in range(0, 13):
        for xx in range(0, 10):
            if yy >= 10 and (xx % 3) != 1 and yy == 12:
                continue
            if yy >= 10 and (xx + yy) % 2 == 1:
                continue
            # punched motif: a flower in the middle and a row of diamonds
            if (yy, xx) in ((3, 4), (3, 5), (4, 3), (4, 6), (5, 3), (5, 6), (6, 4), (6, 5), (8, 2), (8, 5), (8, 8)):
                continue
            c = color
            if xx == 9:
                c = dark
            elif xx == 0 or yy == 1:
                c = light
            put(x + xx + (sway if yy > 7 else 0), top + yy, c)


def garland(x0, x1, y0, sag, phase, step=13):
    pts = {}
    for x in range(x0, x1 + 1):
        t = (x - x0) / (x1 - x0)
        pts[x] = int(round(y0 + sag * math.sin(math.pi * t)))
        put(x, pts[x], 'string')
    k = 0
    for cx in range(x0 + 5, x1 - 10, step):
        flag(cx, pts[cx] + 1, COLORS[(k + phase) % len(COLORS)], (k + phase) % 3 - 1)
        k += 1


garland(-6, W // 2 + 10, CEIL + 2, 14, 0)
garland(W // 2 - 10, W + 6, CEIL + 2, 14, 3)

# --- 6. punched-tin star lamps (drawn over the garlands) ------------------------------------
for lx, ly in LAMPS:
    for y in range(CEIL, ly - 7):
        put(lx, y, 'string')
    for y in range(-8, 9):
        for x in range(-8, 9):
            r = math.hypot(x, y)
            ang = math.atan2(y, x)
            star_r = 4.6 + 3.0 * abs(math.cos(2.5 * ang + 0.3))
            if r <= star_r:
                c = 'tin' if x + y < 0 else 'tin_d'
                if r < 3.2:
                    c = 'glow2'
                elif r < 4.6:
                    c = 'glow1'
                elif (x * 3 + y * 5) % 6 == 0:
                    c = 'glow1'  # punched holes
                put(lx + x, ly + y, c)
            elif r <= star_r + 1 and (x * 2 + y) % 3 == 0:
                put(lx + x, ly + y, 'tin_d')
    put(lx - 3, ly - 4, 'tin_l'); put(lx - 4, ly - 3, 'tin_l')

# --- 6b. things in front of the garlands: plates and a sombrero on top of the shelves
plate(16, 42, 7, 'talav_y')
plate(33, 44, 5, 'talav_bl')
sx, sy = R(26), 46
for x in range(-19, 20):  # brim
    for y in range(-3, 4):
        if (x / 19) ** 2 + (y / 3.2) ** 2 <= 1:
            c = 'straw' if y < 0 else 'straw_d'
            if y == -2:
                c = 'straw_l'
            put(sx + x, sy + y, c)
for y in range(-15, -1):  # crown
    half = int(8 - (y + 15) * 0.18)
    for x in range(-half, half + 1):
        c = 'straw_l' if x < -2 else ('straw' if x < 4 else 'straw_d')
        if y == -15:
            c = 'straw_h'
        put(sx + x, sy + y, c)
rect(sx - 8, sy - 5, sx + 9, sy - 2, 'red')
for x in range(-7, 9, 3):
    put(sx + x, sy - 4, 'pp_yellow')
for x in range(-17, 18, 4):
    put(sx + x, sy + 2, 'red_l')
rect(sx - 1, sy - 19, sx + 2, sy - 15, 'wood_d')  # peg


# --- 7. wood wainscot --------------------------------------------------------------------------
rect(0, WAIN, W, FLOOR, 'wood')
rect(0, WAIN - 2, W, WAIN, 'wood_h')
rect(0, WAIN, W, WAIN + 1, 'wood_d')
for x in range(-4, W, 24):
    rect(x + 2, WAIN + 5, x + 22, FLOOR - 4, 'wood_d')
    rect(x + 3, WAIN + 6, x + 21, FLOOR - 5, 'wood')
    rect(x + 3, WAIN + 6, x + 21, WAIN + 7, 'wood_l')
    for y in range(WAIN + 8, FLOOR - 5):
        for xx in range(x + 4, x + 20):
            if (xx * 7 + y * 3 + (xx // 5) * 11) % 17 == 0:
                put(xx, y, 'wood_l')  # grain
rect(0, FLOOR - 3, W, FLOOR, 'wood_d')
rect(0, FLOOR - 4, W, FLOOR - 3, 'wood_h')

# --- 8. floor: talavera border + terracotta tiles in perspective ------------------------------
for y in range(FLOOR, H):
    depth = (y - FLOOR) / (H - FLOOR)
    th = 4 + int(depth * 4)
    row = 0
    acc = FLOOR + 6
    while acc + th <= y:
        acc += th
        row += 1
    for x in range(W):
        if y < FLOOR + 6:  # talavera strip
            k = (x // 6) % 2
            gx = x % 6
            c = 'talav_w'
            if y in (FLOOR, FLOOR + 5):
                c = 'talav_b'
            elif gx == 0:
                c = 'talav_bl'
            elif (gx in (2, 3) and y in (FLOOR + 2, FLOOR + 3)):
                c = 'talav_y' if k else 'talav_b'
            put(x, y, c)
            continue
        # straight rows, joints offset every other row; rows get taller toward the viewer
        tw = 14 + int(depth * 6)
        gx = (x + (row % 2) * (tw // 2)) % tw
        gy = y - acc
        if gy == 0 or gx == 0:
            c = 'grout'
        else:
            c = 'tile'
            if gy == 1 or gx == 1:
                c = 'tile_l'
            if gx == tw - 1:
                c = 'tile_d'
            if ((x + (row % 2) * (tw // 2)) // tw * 7 + row * 3) % 5 == 0:
                c = mix(c, 'tile_d', 0.4)
        put(x, y, c)

# --- 9. left corner: nopal in a talavera pot -------------------------------------------------
def pad(cx, cy, rx, ry, tilt=0.0):
    for y in range(-ry, ry + 1):
        for x in range(-rx, rx + 1):
            xr = x * math.cos(tilt) + y * math.sin(tilt)
            yr = -x * math.sin(tilt) + y * math.cos(tilt)
            if (xr / rx) ** 2 + (yr / ry) ** 2 <= 1:
                c = 'green'
                if xr < -rx * 0.35:
                    c = 'green_l'
                if xr > rx * 0.45 or yr > ry * 0.55:
                    c = 'green_d'
                if (x * 5 + y * 7) % 11 == 0:
                    c = 'green_h'
                put(cx + x, cy + y, c)


px0, py0 = 22, 168
for y in range(0, 28):
    half = int(10 + 4 * math.sin(math.pi * min(1, y / 22)))
    for x in range(-half, half + 1):
        c = 'clay'
        if x < -half + 3:
            c = 'clay_l'
        if x > half - 4:
            c = 'clay_d'
        if 6 <= y <= 10:
            c = 'talav_w'
            if y in (6, 10) or (x % 4 == 0 and y == 8):
                c = 'talav_b'
        put(px0 + x, py0 + y, c)
rect(px0 - 12, py0 - 2, px0 + 13, py0 + 1, 'clay_h')
rect(px0 - 12, py0 + 1, px0 + 13, py0 + 2, 'clay_d')
pad(px0, py0 - 14, 7, 12)
pad(px0 - 11, py0 - 30, 6, 9, -0.4)
pad(px0 + 9, py0 - 32, 6, 10, 0.35)
pad(px0 - 3, py0 - 48, 5, 8, -0.15)
for fx, fy in ((px0 + 12, py0 - 43), (px0 - 15, py0 - 39), (px0 - 2, py0 - 57)):
    rect(fx - 1, fy - 1, fx + 2, fy + 2, 'pp_pink')
    put(fx, fy - 1, 'red_l')

# --- 10. right corner: guitar leaning on the wainscot + sombrero on a peg ---------------------
gx, gy = R(22), 132
for y in range(0, 40):  # body (figure-eight)
    t = y / 39
    half = 9 * (0.72 + 0.28 * math.cos(2 * math.pi * (t - 0.75))) if t > 0.3 else 7 * (0.6 + 0.4 * math.sin(math.pi * t / 0.3))
    half = int(half)
    for x in range(-half, half + 1):
        c = 'amber'
        if x < -half + 3:
            c = 'amber_l'
        if x > half - 3:
            c = 'amber_d'
        put(gx + x, gy + y, c)
    put(gx - half - 1, gy + y, 'wood_d'); put(gx + half + 1, gy + y, 'wood_d')
for yy in range(-3, 4):
    for xx in range(-3, 4):
        if xx * xx + yy * yy <= 9:
            put(gx + xx, gy + 22 + yy, 'black')
for xx in range(-3, 4):
    put(gx + xx, gy + 31, 'wood_d')
for y in range(-34, 18):  # neck
    put(gx - 1, gy + y, 'wood'); put(gx, gy + y, 'wood_l'); put(gx + 1, gy + y, 'wood_d')
    if y % 4 == 0 and y < 10:
        put(gx, gy + y, 'tin_l')
rect(gx - 3, gy - 42, gx + 4, gy - 34, 'wood_d')
for k in range(3):
    put(gx - 4, gy - 40 + k * 2, 'tin_l'); put(gx + 4, gy - 40 + k * 2, 'tin_l')

# --- 11. gentle vignette (edges darker, no noise) --------------------------------------------
for y in range(H):
    for x in range(W):
        d = math.hypot((x - W / 2) / (W * 0.6), (y - H * 0.5) / (H * 0.72))
        t = max(0.0, min(1.0, (d - 0.62) / 0.45))
        if t > 0:
            steps = int(t * 3 + (0.5 if dither(x, y, (t * 3) % 1) else 0))
            if steps:
                put(x, y, mix(px[x, y], 'void', 0.18 * steps))

out_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'images', 'cantina')
os.makedirs(out_dir, exist_ok=True)
out = os.path.abspath(os.path.join(out_dir, _name))
img.save(out, optimize=True)
print('saved', out, img.size)
if '--preview' in sys.argv:
    img.resize((W * 4, H * 4), Image.NEAREST).save(sys.argv[sys.argv.index('--preview') + 1])
if '--mask' in sys.argv:
    m = img.resize((W * 4, H * 4), Image.NEAREST)
    d = ImageDraw.Draw(m)
    d.ellipse((int(W * 4 * 0.10), int(H * 4 * 0.20), int(W * 4 * 0.90), int(H * 4 * 0.85)), fill=(18, 110, 60), outline=(70, 38, 22), width=24)
    m.save(sys.argv[sys.argv.index('--mask') + 1])
