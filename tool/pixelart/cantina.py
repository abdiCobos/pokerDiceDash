"""Pixel-art backgrounds (Mexican cantina, back room of a mob house) (no external art, no licences).

Drawn pixel by pixel at low resolution with a fixed palette, then shown by Flutter with
nearest-neighbour scaling (FilterQuality.none) so they stay crisp on any screen.

Scenes (all written to assets/images/cantina/):
  cantina_bg.png        444x200  tables on phones (~20:9)
  cantina_bg_16x9.png   356x200  tables on PC / tablets (16:9)
  cantina_menu.png      200x444  main menu on phones (portrait)

The table oval covers the centre (about x 10-90 %, y 20-85 %), so the table scenes keep the
detail on the ceiling band, both sides and the floor. The menu keeps the centre column calm
(logo and buttons) and frames it with the ceiling at the top and the bar at the bottom.

    python tool/pixelart/cantina.py                 -> every scene
    python tool/pixelart/cantina.py --preview DIR   -> also 4x previews in DIR
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

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
    # garito (speakeasy basement)
    'brick_dd': (26, 13, 12), 'brick_d': (46, 22, 19), 'brick': (72, 34, 27), 'brick_l': (102, 50, 36),
    'brick_h': (140, 74, 50), 'brick_hh': (182, 112, 72),
    'mortar_d': (20, 16, 15), 'mortar': (38, 32, 29), 'mortar_l': (70, 60, 52),
    'steel_d': (28, 32, 36), 'steel': (52, 58, 64), 'steel_l': (86, 94, 100), 'steel_h': (140, 148, 150),
    'rust': (108, 50, 24), 'rust_l': (150, 78, 36),
    'conc_d': (26, 25, 24), 'conc': (44, 42, 39), 'conc_l': (66, 62, 57), 'conc_h': (92, 86, 78),
    'shade_d': (22, 44, 30), 'shade': (38, 74, 50), 'shade_l': (64, 112, 76),
    'bulb': (255, 238, 176), 'bulb_c': (255, 252, 230),
    'cash_d': (44, 78, 40), 'cash': (82, 126, 66), 'cash_l': (138, 176, 106),
    'paper_d': (128, 108, 74), 'paper': (186, 166, 120), 'paper_l': (222, 206, 160),
    'smoke': (150, 140, 128),
    'gold': (212, 175, 55), 'gold_l': (250, 214, 110),
}
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
COLORS = ['pp_pink', 'pp_orange', 'pp_yellow', 'pp_green', 'pp_blue', 'pp_purple']

# Current canvas (set by begin()).
W = H = 0
img = px = None


def begin(w, h, seed):
    global W, H, img, px
    W, H = w, h
    img = Image.new('RGB', (W, H), P['void'])
    px = img.load()
    random.seed(seed)


def R(x):
    """x measured from the right edge."""
    return W - x


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


# --- building blocks -------------------------------------------------------------------------
def ceiling(ceil):
    """Dark boards and round beams."""
    for y in range(ceil):
        for x in range(W):
            put(x, y, 'board_l' if (x // 6 + y // 3) % 7 == 0 else 'board')
    for bx in range(-4, W, 30):
        for y in range(0, ceil + 3):
            for i, c in enumerate(('beam_d', 'beam', 'beam_l', 'beam_h', 'beam_l', 'beam', 'beam', 'beam_d')):
                put(bx + i, y, c)
        for i in range(8):  # rounded beam end catching the light
            put(bx + i, ceil + 3, 'beam_d' if i in (0, 7) else 'beam')
    rect(0, ceil, W, ceil + 1, 'black')


BANDS = ['wall_d', 'wall', 'wall_l', 'wall_h', 'wall_hh']


def wall(y0, y1, lamps, reach=82, base=0.18, fall=0.25):
    """Plastered adobe lit by the lamps in clean bands (dithered only at the band edges)."""
    for y in range(y0, y1):
        for x in range(W):
            light = 0.0
            for lx, ly in lamps:
                d = math.hypot((x - lx) * 0.7, (y - ly) * 1.0)
                light = max(light, 1 - d / reach)
            light = max(0.0, light) + base - fall * (y - y0) / max(1, (y1 - y0))
            level = light * (len(BANDS) - 1)
            b = int(max(0, min(len(BANDS) - 1, level)))
            frac = level - b
            c = BANDS[b]
            if b + 1 < len(BANDS) and frac > 0.7 and dither(x, y, (frac - 0.7) / 0.3):
                c = BANDS[b + 1]
            put(x, y, c)


def plaster_chips(n, y0, y1):
    """A few chipped spots showing the adobe brick underneath."""
    for _ in range(n):
        x, y = random.randrange(W), random.randrange(y0, y1)
        w, h = random.randint(4, 9), random.randint(2, 4)
        for yy in range(h):
            for xx in range(w):
                if random.random() < 0.8:
                    put(x + xx, y + yy, mix(px[min(W - 1, x + xx), min(H - 1, y + yy)], 'wall_dd', 0.45))
        rect(x, y + h, x + w, y + h + 1, mix('wall_dd', 'void', 0.2))


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


def bottle_row(x0, x1, base):
    x = x0
    while x < x1 - 5:
        bottle(x, base, random.choice(['tequila', 'mezcal', 'anejo', 'vino', 'tequila', 'jarro']))
        x += random.choice((6, 7, 7, 8))


def shelf_unit(x0, x1, rows):
    rect(x0 - 3, rows[0] - 22, x1 + 3, rows[-1] + 5, 'wood_d')
    rect(x0 - 2, rows[0] - 21, x1 + 2, rows[-1] + 4, mix('wood_d', 'void', 0.35))
    for ry in rows:
        rect(x0 - 3, ry, x1 + 3, ry + 3, 'wood')
        rect(x0 - 3, ry, x1 + 3, ry + 1, 'wood_h')
        rect(x0 - 3, ry + 3, x1 + 3, ry + 4, 'black')
        bottle_row(x0, x1, ry)


def wall_shelf(x0, x1, y):
    """A single floating shelf with bottles (no cabinet)."""
    bottle_row(x0 + 1, x1, y)
    rect(x0, y, x1, y + 3, 'wood')
    rect(x0, y, x1, y + 1, 'wood_h')
    rect(x0 + 1, y + 3, x1 - 1, y + 5, mix('wall_dd', 'void', 0.3))  # shadow on the wall
    for bx in (x0 + 3, x1 - 5):  # brackets
        rect(bx, y + 3, bx + 2, y + 7, 'wood_d')


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


def tin_lamp(lx, ly, ceil):
    """Punched-tin star lamp hanging from the ceiling."""
    for y in range(ceil, ly - 7):
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


def sombrero(sx, sy):
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


def wainscot(y0, y1):
    rect(0, y0, W, y1, 'wood')
    rect(0, y0 - 2, W, y0, 'wood_h')
    rect(0, y0, W, y0 + 1, 'wood_d')
    for x in range(-4, W, 24):
        rect(x + 2, y0 + 5, x + 22, y1 - 4, 'wood_d')
        rect(x + 3, y0 + 6, x + 21, y1 - 5, 'wood')
        rect(x + 3, y0 + 6, x + 21, y0 + 7, 'wood_l')
        for y in range(y0 + 8, y1 - 5):
            for xx in range(x + 4, x + 20):
                if (xx * 7 + y * 3 + (xx // 5) * 11) % 17 == 0:
                    put(xx, y, 'wood_l')  # grain
    rect(0, y1 - 3, W, y1, 'wood_d')
    rect(0, y1 - 4, W, y1 - 3, 'wood_h')


def floor(y0):
    """Talavera border + terracotta tiles in straight rows (taller toward the viewer)."""
    for y in range(y0, H):
        depth = (y - y0) / max(1, (H - y0))
        th = 4 + int(depth * 4)
        row = 0
        acc = y0 + 6
        while acc + th <= y:
            acc += th
            row += 1
        for x in range(W):
            if y < y0 + 6:  # talavera strip
                k = (x // 6) % 2
                gx = x % 6
                c = 'talav_w'
                if y in (y0, y0 + 5):
                    c = 'talav_b'
                elif gx == 0:
                    c = 'talav_bl'
                elif gx in (2, 3) and y in (y0 + 2, y0 + 3):
                    c = 'talav_y' if k else 'talav_b'
                put(x, y, c)
                continue
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


def nopal_pot(px0, py0):
    """Nopal with tunas in a Talavera pot; (px0, py0) is the pot rim centre."""
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


def guitar(gx, gy):
    """Guitar standing on its base; (gx, gy) is the top of the body."""
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


def bar_counter(top, bottom):
    """Front view of the wooden bar: thick top with a highlight, carved front panels."""
    rect(0, top, W, top + 5, 'wood_h')
    rect(0, top + 1, W, top + 4, 'wood_l')
    rect(0, top + 5, W, top + 7, 'black')
    rect(0, top + 7, W, bottom, 'wood')
    for x in range(2, W, 28):
        rect(x, top + 11, x + 24, bottom - 5, 'wood_d')
        rect(x + 1, top + 12, x + 23, bottom - 6, 'wood')
        rect(x + 1, top + 12, x + 23, top + 13, 'wood_l')
        # talavera tile in the middle of every panel
        cx, cy = x + 12, (top + 12 + bottom - 6) // 2
        for yy in range(-4, 5):
            for xx in range(-4, 5):
                c = 'talav_w'
                if abs(xx) == 4 or abs(yy) == 4:
                    c = 'talav_b'
                elif abs(xx) + abs(yy) <= 2:
                    c = 'talav_y' if (xx + yy) % 2 == 0 else 'talav_b'
                elif abs(xx) == abs(yy):
                    c = 'talav_bl'
                put(cx + xx, cy + yy, c)
    rect(0, bottom - 3, W, bottom, 'wood_d')


def vignette(cy_frac=0.5, rx=0.6, ry=0.72, start=0.62):
    """Edges darker in three clean steps (no noise)."""
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - W / 2) / (W * rx), (y - H * cy_frac) / (H * ry))
            t = max(0.0, min(1.0, (d - start) / 0.45))
            if t > 0:
                steps = int(t * 3 + (0.5 if dither(x, y, (t * 3) % 1) else 0))
                if steps:
                    put(x, y, mix(px[x, y], 'void', 0.18 * steps))


# --- scenes ----------------------------------------------------------------------------------
def table_scene(width):
    """Behind the table oval: detail on the ceiling band, both sides and the floor."""
    begin(width, 200, 11)
    ceil, wain, flr = 18, 136, 166
    lamps = [(84, 36), (W // 2, 32), (R(84), 36)]
    ceiling(ceil)
    wall(ceil + 1, wain, lamps)
    plaster_chips(22, ceil + 8, wain - 8)
    shelf_unit(6, 46, [72, 98, 124])
    shelf_unit(R(46), R(6), [72, 98, 124])
    garland(-6, W // 2 + 10, ceil + 2, 14, 0)
    garland(W // 2 - 10, W + 6, ceil + 2, 14, 3)
    for lx, ly in lamps:
        tin_lamp(lx, ly, ceil)
    plate(16, 42, 7, 'talav_y')
    plate(33, 44, 5, 'talav_bl')
    sombrero(R(26), 46)
    wainscot(wain, flr)
    floor(flr)
    nopal_pot(22, 168)
    guitar(R(22), 132)
    vignette()


def menu_scene():
    """Portrait menu: ceiling, papel picado and lamps at the top, a calm wall in the middle
    for the logo and the buttons, the bar with bottles at the bottom."""
    begin(200, 444, 23)
    ceil = 20
    bar_top = 372
    flr = 426
    lamps = [(40, 62), (W // 2, 46), (R(40), 62)]
    ceiling(ceil)
    wall(ceil + 1, bar_top, lamps, reach=96, base=0.2, fall=0.32)
    plaster_chips(16, ceil + 60, bar_top - 20)
    # back-bar shelves on the wall just above the counter (behind the lower buttons)
    wall_shelf(8, 92, 338)
    wall_shelf(R(92), R(8), 338)
    wall_shelf(20, 80, 304)
    wall_shelf(R(80), R(20), 304)
    # side decoration at mid height (beside the logo and the mode buttons)
    plate(14, 150, 7, 'talav_y')
    plate(14, 168, 5, 'talav_bl')
    plate(R(14), 158, 6, 'talav_y')
    # three rows of papel picado crossing the ceiling
    garland(-6, W + 6, ceil + 2, 10, 0)
    garland(-6, W // 2 + 8, ceil + 22, 12, 2)
    garland(W // 2 - 8, W + 6, ceil + 22, 12, 4)
    for lx, ly in lamps:
        tin_lamp(lx, ly, ceil)
    sombrero(R(24), 112)
    # the bar, with bottles, a jug and two glasses on top, then the floor
    bar_counter(bar_top, flr)
    for x, kind in ((22, 'tequila'), (30, 'jarro'), (R(44), 'mezcal'), (R(36), 'anejo')):
        bottle(x, bar_top, kind)
    for gx in (50, R(56)):  # caballito glasses
        rect(gx, bar_top - 5, gx + 4, bar_top, 'clear_d')
        rect(gx + 1, bar_top - 4, gx + 3, bar_top - 1, 'amber_l')
    floor(flr)
    # (no nopal / guitar here: on phones the bottom buttons sit right on the bar)
    vignette(cy_frac=0.45, rx=0.75, ry=0.62, start=0.7)



# === garito: a back room in a run-down house where the mob plays for dirty money ===============
P.update({
    'wp_dd': (30, 27, 16), 'wp_d': (52, 47, 27), 'wp': (80, 72, 40), 'wp_l': (110, 99, 55),
    'wp_h': (142, 128, 72), 'wp_hh': (176, 160, 94),
    'plas_d': (62, 56, 46), 'plas': (104, 96, 80), 'plas_l': (146, 136, 114), 'plas_h': (184, 174, 148),
    'ceil_d': (28, 25, 21), 'ceil': (44, 40, 33), 'ceil_l': (62, 57, 47),
    'water': (74, 56, 30),
    'stain': (44, 12, 12), 'stain_l': (66, 20, 18),
    'night': (8, 10, 22), 'cop_r': (226, 44, 44), 'cop_b': (54, 96, 236),
    'floor_d': (30, 17, 11), 'floor': (52, 30, 18), 'floor_l': (76, 45, 26), 'floor_h': (100, 62, 36),
})
WP_BANDS = ['wp_dd', 'wp_d', 'wp', 'wp_l', 'wp_h', 'wp_hh']
PLAS_BANDS = ['plas_d', 'plas_d', 'plas', 'plas_l', 'plas_h', 'plas_h']
FLOOR_BANDS = ['floor_d', 'floor', 'floor_l', 'floor_h']


def light_at(x, y, lamps):
    """0..1 light from (x, y, reach, strength) lamps; bulbs are point lights."""
    best = 0.0
    for lx, ly, reach, k in lamps:
        d = math.hypot((x - lx) * 0.8, (y - ly) * 1.0)
        best = max(best, k * max(0.0, 1 - d / reach))
    return best


def banded(bands, level, x, y):
    """Pick a band for a 0..1 light level, dithering only near the band edge."""
    level = max(0.0, min(0.999, level)) * (len(bands) - 1)
    b = int(level)
    frac = level - b
    if b + 1 < len(bands) and frac > 0.72 and dither(x, y, (frac - 0.72) / 0.28):
        b += 1
    return bands[b]


def blob(cx, cy, rx, ry, seed):
    """Irregular patch: returns a test function (x, y) -> inside."""
    rnd = random.Random(seed)
    k = [rnd.uniform(0.75, 1.15) for _ in range(8)]

    def inside(x, y):
        a = math.atan2((y - cy) / ry, (x - cx) / rx)
        i = int((a + math.pi) / (2 * math.pi) * 8) % 8
        j = (i + 1) % 8
        t = ((a + math.pi) / (2 * math.pi) * 8) % 1
        r = k[i] * (1 - t) + k[j] * t
        return math.hypot((x - cx) / rx, (y - cy) / ry) <= r
    return inside


def tear(x0, y0, w, h, seed, side=1):
    """A strip of wallpaper torn away from a seam: wide at the top, ragged, tapering down."""
    rnd = random.Random(seed)
    jag, j = [], 0.0
    for _ in range(h + 2):  # ragged edge: a random walk, not a straight cut
        j = max(-4.0, min(4.0, j + rnd.uniform(-1.6, 1.6)))
        jag.append(int(j))

    def inside(x, y):
        t = (y - y0) / h
        if not 0 <= t <= 1:
            return False
        reach = w * (1 - t * t) ** 0.7 * (0.3 if t > 0.85 else 1) + jag[y - y0]
        return 0 <= (x - x0) * side <= reach
    return inside


def wallpaper_wall(y0, y1, lamps, peels, base=0.05):
    """Faded damask wallpaper, torn off in places down to the plaster and the lath behind it."""
    for y in range(y0, y1):
        for x in range(W):
            lit = light_at(x, y, lamps) + base - 0.12 * (y - y0) / max(1, y1 - y0)
            hole = next((p for p in peels if p[0](x, y)), None)
            if hole is not None:
                if hole[1] and hole[1](x, y):  # plaster fell too: wooden lath strips
                    c = banded(['black', 'wood_d', 'wood', 'wood_l'], lit * 0.9, x, y) if (y % 4) != 3 else 'black'
                else:
                    c = banded(PLAS_BANDS, lit * 0.85, x, y)
                    if dither(x * 5, y * 3, 0.08):
                        c = mix(c, 'void', 0.3)
                put(x, y, c)
                continue
            gx, gy = x % 12, (y - y0) % 14
            pattern = gx in (0, 1)  # stripe
            dx, dy = abs(gx - 6), abs(gy - 7)
            if dx + dy == 3 or (dx == 0 and dy == 0):  # damask diamond with a dot
                pattern = True
            c = banded(WP_BANDS, lit - (0.14 if pattern else 0), x, y)
            put(x, y, c)
    # the paper curls at the edge of every tear
    for p in peels:
        test = p[0]
        for y in range(y0, y1):
            for x in range(W):
                if not test(x, y) and (test(x + 1, y) or test(x, y + 1)):
                    put(x, y, mix(px[x, y], 'wp_hh', 0.35))
                elif test(x, y) and not test(x, y - 1):
                    put(x, y, mix(px[x, y], 'void', 0.45))


def water_stains(spots):
    """Brown rings where the roof leaks, dripping down the paper."""
    for cx, cy, r in spots:
        for y in range(cy - r, cy + r * 3):
            for x in range(cx - r, cx + r + 1):
                d = math.hypot(x - cx, (y - cy) * (1.0 if y < cy else 0.35))
                if d <= r and 0 <= x < W and 0 <= y < H:
                    if dither(x, y, 0.45 * (1 - d / r) + 0.1):
                        put(x, y, mix(px[x, y], 'water', 0.3))


def plaster_ceiling(ceil, lamps):
    for y in range(ceil):
        for x in range(W):
            lit = light_at(x, y + 10, lamps)
            put(x, y, banded(['ceil_d', 'ceil', 'ceil_l'], lit * 0.8 + 0.1, x, y))
    for _ in range(3):  # cracks
        x, y = random.randrange(W), random.randrange(ceil)
        for _s in range(random.randint(10, 24)):
            put(x, y, 'void')
            x += random.choice((1, 1, 2, -1))
            y = max(0, min(ceil - 2, y + random.choice((-1, 0, 1))))
    rect(0, ceil - 1, W, ceil, 'black')
    rect(0, ceil, W, ceil + 2, 'wood_d')  # crown moulding
    rect(0, ceil, W, ceil + 1, 'wood')


def bullet_holes(holes):
    for hx, hy in holes:
        for dx, dy in ((1, -1), (-2, 1), (2, 2), (-1, -2), (3, 0)):
            for s in range(1, 3 + random.randint(0, 2)):
                if random.random() < 0.8:
                    put(hx + dx * s // 2, hy + dy * s // 2, mix(px[max(0, min(W - 1, hx)), max(0, min(H - 1, hy))], 'void', 0.6))
        rect(hx - 1, hy - 2, hx + 3, hy + 3, 'plas')
        rect(hx - 2, hy - 1, hx + 4, hy + 2, 'plas')
        rect(hx - 1, hy - 1, hx + 3, hy + 2, 'plas_d')
        rect(hx, hy - 1, hx + 2, hy + 2, 'black')
        rect(hx - 1, hy, hx + 3, hy + 1, 'black')
        put(hx - 1, hy - 2, 'plas_h')


def mugshot(x0, y0, crossed, tilt=0):
    """A photo pinned to the wall; the crossed ones are already dealt with."""
    for y in range(11):
        sx = (y * tilt) // 6
        for x in range(9):
            c = 'paper_l' if x in (0, 8) or y in (0, 10) else 'paper_d'
            put(x0 + x + sx, y0 + y, c)
    for y in range(2, 10):  # head and shoulders
        sx = (y * tilt) // 6
        for x in range(1, 8):
            if (y < 6 and abs(x - 4) <= 1 + (y in (3, 4))) or (y >= 7 and abs(x - 4) <= y - 5):
                put(x0 + x + sx, y0 + y, 'steel_d')
    if crossed:
        for i in range(9):
            sx = (min(10, i) * tilt) // 6
            put(x0 + i + sx, y0 + 1 + i, 'red'); put(x0 + 8 - i + sx, y0 + 1 + i, 'red')
    put(x0 + 4, y0, 'red_l')  # pin


def crooked_frame(x0, y0, w, h, tilt):
    """An old picture hanging crooked; a dark painting nobody looks at."""
    for y in range(h):
        sx = (y * tilt) // max(1, h)
        for x in range(w):
            edge = x < 2 or x >= w - 2 or y < 2 or y >= h - 2
            c = ('gold' if (x + y) % 5 else 'gold_l') if edge else ('wood_d' if y > h * 0.6 else 'shade_d')
            if not edge and y > h * 0.5 and (x - w // 2) ** 2 < (y - h * 0.5) * 3:
                c = 'shade'
            put(x0 + x + sx, y0 + y, c)
    put(x0 + w // 2, y0 - 3, 'black'); put(x0 + w // 2 - 1, y0 - 2, 'black'); put(x0 + w // 2 + 1, y0 - 2, 'black')


def boarded_window(x0, y0, w, h):
    """Window nailed shut; red and blue lights from the street leak through the gaps."""
    rect(x0 - 3, y0 - 3, x0 + w + 3, y0 + h + 4, 'wood_d')
    rect(x0 - 3, y0 + h + 1, x0 + w + 3, y0 + h + 3, 'wood_l')  # sill
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            t = (x - x0) / w
            c = 'night'
            if dither(x, y, 0.5 * (1 - t)):
                c = mix('night', 'cop_r', 0.55)
            if dither(x + 2, y + 1, 0.5 * t):
                c = mix('night', 'cop_b', 0.55)
            put(x, y, c)
    rect(x0 + w // 2, y0, x0 + w // 2 + 1, y0 + h, 'wood_d')  # window bars
    boards = [(y0 + 2, 6, 1), (y0 + h // 2 - 4, 7, -1), (y0 + h - 9, 6, 1)]
    for by, bh, slope in boards:
        for x in range(x0 - 4, x0 + w + 4):
            yy = by + slope * (x - x0) // 9
            for i in range(bh):
                c = 'wood_l' if i == 0 else ('wood_d' if i == bh - 1 else 'wood')
                if (x * 7 + i * 3) % 11 == 0:
                    c = 'wood_d'
                put(x, yy + i, c)
        for nx in (x0 - 2, x0 + w + 1):
            put(nx, by + slope * (nx - x0) // 9 + 2, 'steel_h')


def light_spill(cx, cy, r, color, amount=0.18):
    for y in range(cy - r, cy + r):
        for x in range(cx - r, cx + r):
            d = math.hypot(x - cx, y - cy) / r
            if d < 1 and 0 <= x < W and 0 <= y < H and dither(x, y, (1 - d) * 0.6):
                put(x, y, mix(px[x, y], color, amount))


def bolted_door(x0, x1, y0, y1, feet=True):
    """Beaten wooden door with a chain, three deadbolts and someone standing behind it."""
    rect(x0 - 3, y0 - 3, x1 + 3, y1, 'wood_d')
    rect(x0 - 3, y0 - 3, x1 + 3, y0 - 2, 'wood_l')
    rect(x0, y0, x1, y1, 'wood')
    rect(x0, y0, x0 + 1, y1, 'wood_l')
    rect(x1 - 1, y0, x1, y1, 'floor_d')
    for py0, py1 in ((y0 + 5, y0 + (y1 - y0) // 2 - 3), (y0 + (y1 - y0) // 2 + 3, y1 - 6)):
        rect(x0 + 4, py0, x1 - 4, py1, 'wood_d')
        rect(x0 + 5, py0 + 1, x1 - 5, py1 - 1, 'wood')
        rect(x0 + 5, py0 + 1, x1 - 5, py0 + 2, 'wood_l')
    # kicked-in crack on the lower panel
    x, y = x0 + 7, y1 - 12
    for _ in range(9):
        put(x, y, 'black')
        x += 1
        y += random.choice((-1, 0, 1))
    # three deadbolts, a chain lock and the knob
    lx = x1 - 6
    for k in range(3):
        by = y0 + 10 + k * 9
        rect(lx - 1, by, lx + 3, by + 3, 'gold')
        put(lx, by, 'gold_l')
    cy = y0 + 13
    for i in range(7):
        put(lx - 3 - i, cy + (i * i) // 10, 'steel_h' if i % 2 else 'steel_l')
    rect(lx - 11, cy - 1, lx - 8, cy + 2, 'steel')
    rect(lx - 1, (y0 + y1) // 2 + 2, lx + 3, (y0 + y1) // 2 + 5, 'gold_l')
    put((x0 + x1) // 2, y0 + 12, 'black')  # peephole
    # light under the door, broken by two feet
    rect(x0, y1 - 1, x1, y1, 'bulb')
    if feet:
        mid = (x0 + x1) // 2
        rect(mid - 7, y1 - 1, mid - 3, y1, 'black')
        rect(mid + 2, y1 - 1, mid + 6, y1, 'black')


def wainscot_panels(y0, y1, lamps):
    """Dark wood panelling under a chair rail, scuffed and kicked in."""
    for y in range(y0, y1):
        for x in range(W):
            lit = light_at(x, y, lamps) * 0.7
            c = banded(['wood_d', 'wood_d', 'wood', 'wood_l'], lit, x, y)
            gx = x % 22
            if gx in (0, 21) or y in (y0 + 4, y1 - 3):
                c = 'black' if gx == 21 or y == y1 - 3 else c
            put(x, y, c)
    rect(0, y0, W, y0 + 2, 'wood_l')
    rect(0, y0 + 2, W, y0 + 3, 'black')


def wood_floor(y0, lamps):
    rect(0, y0 - 2, W, y0, 'black')  # baseboard shadow
    row_h = 3
    y = y0
    row = 0
    while y < H:
        for yy in range(y, min(H, y + row_h)):
            for x in range(W):
                off = (row * 37) % 50
                seam = (x + off) % 50 == 0
                lit = light_at(x, yy - 40, lamps) * 0.85 + 0.24
                c = banded(FLOOR_BANDS, lit, x, yy)
                if yy == y + row_h - 1 or seam:
                    c = 'floor_d' if c != 'floor_d' else 'black'
                if dither(x * 3 + row, yy * 7, 0.06):
                    c = mix(c, 'void', 0.3)
                put(x, yy, c)
        y += row_h
        row_h += 1
        row += 1


def blood_stain(cx, cy, rx, ry, seed):
    inside = blob(cx, cy, rx, ry, seed)
    for y in range(cy - ry * 2, cy + ry * 2):
        for x in range(cx - rx * 2, cx + rx * 2):
            if 0 <= x < W and 0 <= y < H and inside(x, y):
                put(x, y, mix(px[x, y], 'stain_l', 0.8 if dither(x, y, 0.7) else 0.6))


def shell_casings(n, x0, x1, y0, y1):
    for _ in range(n):
        x, y = random.randrange(x0, x1), random.randrange(y0, y1)
        put(x, y, 'gold_l'); put(x + 1, y, 'gold')


def line(x0, y0, x1, y1, c, thick=1):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        x = round(x0 + (x1 - x0) * i / n)
        y = round(y0 + (y1 - y0) * i / n)
        for t in range(thick):
            put(x + t, y, c)


def shotgun(xb, yb, xt, yt):
    """Leaning on the wall: wooden stock at the bottom, barrels up."""
    mx = xb + (xt - xb) * 0.38
    my = yb + (yt - yb) * 0.38
    line(xb, yb, int(mx), int(my), 'wood', 3)
    line(xb, yb, int(mx), int(my), 'wood_l', 1)
    line(int(mx), int(my), xt, yt, 'steel', 2)
    line(int(mx) + 1, int(my), xt + 1, yt, 'steel_h', 1)
    rect(int(mx) - 1, int(my) - 1, int(mx) + 3, int(my) + 3, 'steel_d')  # action


def revolver(x0, y0):
    rect(x0, y0, x0 + 9, y0 + 2, 'steel_l')  # barrel
    rect(x0, y0, x0 + 9, y0 + 1, 'steel_h')
    rect(x0 + 7, y0 - 1, x0 + 12, y0 + 3, 'steel')  # cylinder
    rect(x0 + 8, y0, x0 + 11, y0 + 1, 'steel_h')
    rect(x0 + 11, y0 + 1, x0 + 15, y0 + 4, 'wood')  # grip
    rect(x0 + 12, y0 + 3, x0 + 16, y0 + 5, 'wood_d')
    put(x0 + 9, y0 + 3, 'steel_d')  # trigger


def ashtray(cx, y):
    rect(cx - 4, y - 2, cx + 5, y, 'clear_d')
    rect(cx - 3, y - 3, cx + 4, y - 2, 'clear')
    put(cx - 1, y - 4, 'paper_l'); put(cx, y - 4, 'paper_l'); put(cx + 1, y - 5, 'red_l')
    put(cx + 2, y - 3, 'paper_l'); put(cx + 3, y - 4, 'paper_d')
    for k in range(6):  # thin smoke
        put(cx + 1 + (k % 2), y - 6 - k * 2, 'smoke')


def side_table(x0, x1, top, bottom):
    rect(x0, top, x1, top + 3, 'wood_l')
    rect(x0, top, x1, top + 1, 'wood_h')
    rect(x0, top + 3, x1, top + 4, 'black')
    rect(x0 + 1, top + 4, x1 - 1, top + 10, 'wood')  # drawer
    rect(x0 + 1, top + 4, x1 - 1, top + 5, 'wood_l')
    rect(x0 + 1, top + 9, x1 - 1, top + 10, 'black')
    rect((x0 + x1) // 2 - 1, top + 6, (x0 + x1) // 2 + 2, top + 8, 'gold')
    for lx in (x0 + 1, x1 - 3):
        rect(lx, top + 10, lx + 2, bottom, 'wood')
        rect(lx, top + 10, lx + 1, bottom, 'wood_l')


def cash_duffel(x0, y0, w, h):
    """Open sports bag stuffed with bills."""
    for y in range(h):
        for x in range(w):
            r = ((x - w / 2) / (w / 2)) ** 2 + ((y - h) / h) ** 2
            if r <= 1:
                put(x0 + x, y0 + y, 'steel_d' if x > w * 0.6 else 'steel')
    for k in range(5):  # bundles sticking out
        bx = x0 + 3 + k * (w - 8) // 4
        rect(bx, y0 - 2 + (k % 2), bx + 5, y0 + 2, 'cash')
        rect(bx, y0 - 2 + (k % 2), bx + 5, y0 - 1 + (k % 2), 'cash_l')
        rect(bx + 2, y0 - 2 + (k % 2), bx + 3, y0 + 2, 'paper_l')
    rect(x0 + 2, y0 + 2, x0 + w - 2, y0 + 3, 'black')  # zipper mouth
    rect(x0 + w // 2 - 6, y0 - 4, x0 + w // 2 + 6, y0 - 3, 'black')  # strap


def bottle_floor(x, base, kind='anejo', lying=False):
    if not lying:
        bottle(x, base, kind)
        return
    rect(x, base - 4, x + 10, base, P['amber_d'])
    rect(x, base - 4, x + 10, base - 3, P['amber_l'])
    rect(x + 10, base - 3, x + 14, base - 1, P['amber'])


def hanging_bulb(lx, ly, ceil, shade=True):
    """Bare bulb, optionally under a green enamel cone shade, on a cord."""
    for y in range(ceil, ly - (6 if shade else 2)):
        put(lx, y, 'black')
    if shade:
        for y in range(0, 7):
            half = 2 + int(y * 1.6)
            for x in range(-half, half + 1):
                c = 'shade'
                if x < -half + 2:
                    c = 'shade_l'
                if x > half - 2:
                    c = 'shade_d'
                put(lx + x, ly - 6 + y, c)
        rect(lx - 12, ly + 1, lx + 13, ly + 2, 'shade_d')
        for x in range(-4, 5):  # glowing bulb under the rim
            for y in range(1, 5):
                if x * x + (y - 2) ** 2 <= 8:
                    put(lx + x, ly + y, 'bulb_c' if abs(x) < 2 and y < 4 else 'bulb')
    else:
        for x in range(-2, 3):
            for y in range(-2, 4):
                if x * x + (y - 1) ** 2 <= 6:
                    put(lx + x, ly + y, 'bulb_c' if abs(x) < 1 else 'bulb')
        rect(lx - 1, ly - 3, lx + 2, ly - 1, 'steel')


def light_cone(lx, ly, length, spread, strength=0.22):
    """Dusty light falling from a shaded bulb (dithered, brightens what is behind it)."""
    for y in range(ly + 2, min(H, ly + length)):
        t = (y - ly) / length
        half = 8 + spread * t
        for x in range(int(lx - half), int(lx + half) + 1):
            edge = 1 - abs(x - lx) / half
            a = strength * edge * (1 - t)
            if a > 0 and dither(x, y, a * 2.2):
                put(x, y, mix(px[max(0, min(W - 1, x)), y], 'bulb', 0.18))


def smoke(y0, y1, cx, width, amount=0.35):
    """Lazy cigarette smoke curls hanging under the ceiling."""
    for k in range(5):
        base_y = y0 + k * (y1 - y0) // 5
        phase = random.random() * 6
        for x in range(int(cx - width), int(cx + width)):
            yy = base_y + int(3 * math.sin(x / 9 + phase))
            fall = 1 - abs(x - cx) / width
            for d in range(-1, 2):
                if dither(x, yy + d, amount * fall * (0.6 if d else 1)):
                    put(x, yy + d, mix(px[max(0, min(W - 1, x)), max(0, min(H - 1, yy + d))], 'smoke', 0.35))


def cash_stack(x0, y0, n):
    for k in range(n):
        y = y0 - (k + 1) * 2
        rect(x0, y, x0 + 10, y + 2, 'cash')
        rect(x0, y, x0 + 10, y + 1, 'cash_l')
        rect(x0 + 4, y, x0 + 6, y + 2, 'paper_l')  # band
    rect(x0 + 10, y0 - n * 2, x0 + 11, y0, 'cash_d')


def dark_vignette(strength=0.22, start=0.45):
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - W / 2) / (W * 0.55), (y - H * 0.45) / (H * 0.7))
            t = max(0.0, min(1.0, (d - start) / 0.5))
            if t > 0:
                steps = int(t * 3 + (0.5 if dither(x, y, (t * 3) % 1) else 0))
                if steps:
                    put(x, y, mix(px[x, y], 'void', strength * steps))


def grime(n, y0, y1):
    """Dirty streaks running down the paper and smoke-yellowed patches."""
    for _ in range(n):
        x = random.randrange(W)
        y = random.randrange(y0, max(y0 + 1, y1 - 24))
        length = random.randint(12, 34)
        w = random.randint(1, 3)
        for yy in range(length):
            for xx in range(-w, w + 1):
                if dither(x + xx, y + yy, 0.5 * (1 - yy / length)):
                    put(x + xx, y + yy, mix(px[max(0, min(W - 1, x + xx)), min(H - 1, y + yy)], 'void', 0.28))


def garito_table_scene(width):
    begin(width, 200, 41)
    ceil, rail, flr = 14, 140, 170
    lamp = (W // 2, 30)
    lamps = [(lamp[0], lamp[1], 170, 1.0), (22, 44, 80, 0.62), (R(26), 66, 70, 0.5)]
    plaster_ceiling(ceil, lamps)
    peels = [
        (tear(58, ceil + 2, 16, 34, 1), tear(60, ceil + 2, 6, 14, 2)),
        (tear(R(64), ceil + 2, 14, 30, 3, side=-1), None),
        (tear(44, rail - 40, 10, 38, 4), tear(45, rail - 38, 4, 16, 5)),
        (tear(R(48), rail - 36, 10, 34, 6, side=-1), None),
    ]
    wallpaper_wall(ceil + 2, rail, lamps, peels)
    grime(14, ceil + 4, rail)
    water_stains([(W // 2 - 70, ceil + 4, 6), (R(100), ceil + 5, 8)])
    wainscot_panels(rail, flr - 2, lamps)
    # left: the bolted door with someone outside, a bare bulb over it, a shotgun beside it
    bolted_door(6, 38, 52, flr - 2)
    hanging_bulb(22, 40, ceil, shade=False)
    shotgun(46, flr - 3, 58, 90)
    # top band: the hit list, a crooked painting, bullet holes
    hx = int(W * 0.2)  # kept off the middle, where the dealer sits in Blackjack
    # everything here ends above y 31, where Blackjack prints its rules on the wall
    mugshot(hx, 18, True, 1)
    mugshot(hx + 12, 19, True, 0)
    mugshot(hx + 24, 18, False, -1)
    line(hx + 5, 19, hx + 29, 19, 'red_d')  # string between the targets
    mugshot(R(int(W * 0.2) + 10), 18, True, 0)
    crooked_frame(R(int(W * 0.3) + 22), 19, 20, 11, 3)
    bullet_holes([(60, 24), (67, 28), (56, 27), (R(84), 24), (R(90), 28), (W // 2 + 30, 22)])
    # right: boarded window with police lights, a side table with the gun and the cash
    boarded_window(R(42), 44, 34, 44)
    light_spill(R(25), 66, 44, 'cop_r', 0.14)
    light_spill(R(10), 72, 34, 'cop_b', 0.14)
    side_table(R(46), R(6), flr - 26, flr - 1)
    revolver(R(44), flr - 31)
    cash_stack(R(26), flr - 26, 3)
    ashtray(R(12), flr - 26)
    # the main lamp and its smoke
    hanging_bulb(lamp[0], lamp[1], ceil)
    smoke(ceil + 4, ceil + 34, lamp[0], W * 0.4, amount=0.5)
    wood_floor(flr, lamps)
    blood_stain(34, flr + 14, 18, 5, 9)
    shell_casings(7, 40, 90, flr + 4, H - 4)
    shell_casings(5, R(90), R(40), flr + 4, H - 4)
    cash_duffel(R(64), flr + 8, 26, 12)
    bottle_floor(66, flr + 18, lying=True)
    dark_vignette(strength=0.16, start=0.6)


def garito_menu_scene():
    begin(200, 444, 43)
    ceil, rail, flr = 16, 360, 400
    lamp = (W // 2, 40)  # above the logo
    lamps = [(lamp[0], lamp[1], 200, 1.0), (R(22), 118, 60, 0.45), (W // 2, 470, 120, 0.55)]
    plaster_ceiling(ceil, lamps)
    peels = [
        (tear(0, 60, 26, 60, 11), tear(0, 64, 10, 24, 12)),
        (tear(W, 210, 22, 50, 13, side=-1), None),
        (tear(26, 268, 14, 44, 14), tear(27, 270, 5, 18, 15)),
        (tear(R(60), ceil + 2, 18, 22, 16, side=-1), None),
    ]
    wallpaper_wall(ceil + 2, rail, lamps, peels, base=0.16)
    grime(20, ceil + 4, rail)
    water_stains([(46, ceil + 4, 8), (R(50), ceil + 5, 10)])
    wainscot_panels(rail, flr - 2, lamps)
    # beside the logo: the hit list on the left, the boarded window on the right
    mugshot(6, 130, True, 1)
    mugshot(18, 138, False, 0)
    mugshot(8, 152, True, -1)
    line(10, 131, 22, 139, 'red_d')
    boarded_window(R(36), 92, 30, 50)
    light_spill(R(20), 116, 40, 'cop_r', 0.14)
    light_spill(R(8), 124, 34, 'cop_b', 0.14)
    bullet_holes([(R(26), 158), (R(18), 166), (R(30), 172), (42, 44), (154, 58)])
    shotgun(12, flr - 3, 24, 300)
    hanging_bulb(lamp[0], lamp[1], ceil)
    smoke(ceil + 6, ceil + 50, lamp[0], 90, amount=0.5)
    wood_floor(flr, lamps)
    blood_stain(134, flr + 22, 24, 7, 17)
    cash_duffel(26, flr + 16, 32, 14)
    revolver(R(62), flr + 30)
    shell_casings(9, 70, 190, flr + 6, H - 6)
    bottle_floor(R(36), flr + 14, lying=True)
    dark_vignette(strength=0.16, start=0.62)


SCENES = {
    'cantina_bg.png': lambda: table_scene(444),
    'cantina_bg_16x9.png': lambda: table_scene(356),
    'cantina_menu.png': menu_scene,
    'garito_bg.png': lambda: garito_table_scene(444),
    'garito_bg_16x9.png': lambda: garito_table_scene(356),
    'garito_menu.png': garito_menu_scene,
}


def main():
    out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'images', 'cantina'))
    os.makedirs(out_dir, exist_ok=True)
    preview = sys.argv[sys.argv.index('--preview') + 1] if '--preview' in sys.argv else None
    for name, draw in SCENES.items():
        draw()
        img.save(os.path.join(out_dir, name), optimize=True)
        print('saved', name, img.size)
        if preview:
            os.makedirs(preview, exist_ok=True)
            img.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(preview, name.replace('.png', '_x4.png')))


if __name__ == '__main__':
    main()
