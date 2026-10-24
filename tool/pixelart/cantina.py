"""Pixel-art backgrounds (Mexican cantina, speakeasy garito) (no external art, no licences).

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



# === garito: speakeasy basement under one bare bulb ============================================
BRICK_BANDS = ['brick_dd', 'brick_d', 'brick', 'brick_l', 'brick_h', 'brick_hh']


def light_at(x, y, lamps):
    """0..1 light from (x, y, reach, strength) lamps; bulbs are point lights."""
    best = 0.0
    for lx, ly, reach, k in lamps:
        d = math.hypot((x - lx) * 0.8, (y - ly) * 1.0)
        best = max(best, k * max(0.0, 1 - d / reach))
    return best


def brick_wall(y0, y1, lamps, base=0.08):
    """Old brick with dark mortar; every brick lit in bands by the bulbs, a few odd bricks."""
    for y in range(y0, y1):
        row = (y - y0) // 6
        gy = (y - y0) % 6
        for x in range(W):
            off = 7 if row % 2 else 0
            gx = (x + off) % 14
            brick_id = ((x + off) // 14) * 31 + row * 17
            level = (light_at(x, y, lamps) + base) * (len(BRICK_BANDS) - 1)
            level += ((brick_id * 7) % 5 - 2) * 0.12  # every brick a slightly different tone
            b = int(max(0, min(len(BRICK_BANDS) - 1, level)))
            frac = level - b
            if gy == 5 or gx == 13:
                c = mix('mortar_d', 'mortar_l', min(1.0, max(0.0, level / 5)))
            else:
                c = BRICK_BANDS[b]
                if b + 1 < len(BRICK_BANDS) and frac > 0.75 and dither(x, y, (frac - 0.75) / 0.25):
                    c = BRICK_BANDS[b + 1]
                if gy == 0 and b > 0:
                    c = BRICK_BANDS[min(b + 1, len(BRICK_BANDS) - 1)]  # lit top edge
                if gx == 12 or gy == 4:
                    c = BRICK_BANDS[max(0, b - 1)]  # shadow edge
                if (brick_id % 23) == 0 and gx < 6 and gy < 3:
                    c = mix(c, 'mortar', 0.6)  # chipped corner
            put(x, y, c)


def stains(n, y0, y1):
    """Damp patches running down the wall."""
    for _ in range(n):
        x = random.randrange(W)
        y = random.randrange(y0, y1 - 20)
        length = random.randint(10, 30)
        width = random.randint(3, 7)
        for yy in range(length):
            w = max(1, int(width * (1 - yy / length)))
            for xx in range(-w, w + 1):
                if dither(x + xx, y + yy, 0.45):
                    put(x + xx, y + yy, mix(px[max(0, min(W - 1, x + xx)), min(H - 1, y + yy)], 'void', 0.3))


def concrete_ceiling(ceil):
    rect(0, 0, W, ceil, 'conc_d')
    for y in range(ceil):
        for x in range(W):
            if dither(x * 3, y * 5, 0.12):
                put(x, y, 'conc')
    rect(0, ceil - 1, W, ceil, 'black')


def pipe_h(y, x0, x1, thick=4, flange_every=46):
    tones = ['steel_d', 'steel_l', 'steel_h', 'steel', 'steel_d'][:thick + 1]
    for x in range(x0, x1):
        for i, c in enumerate(tones):
            put(x, y + i, c)
        if (x - x0) % 23 == 11 and random.random() < 0.5:
            put(x, y + thick, 'rust')
    for fx in range(x0 + 10, x1, flange_every):
        rect(fx, y - 1, fx + 4, y + thick + 2, 'steel')
        rect(fx, y - 1, fx + 4, y, 'steel_h')
        put(fx + 1, y + 1, 'steel_h'); put(fx + 2, y + thick, 'steel_d')


def pipe_v(x, y0, y1):
    for y in range(y0, y1):
        for i, c in enumerate(('steel_d', 'steel_l', 'steel_h', 'steel', 'steel_d')):
            put(x + i, y, c)
    for fy in range(y0 + 14, y1, 40):
        rect(x - 1, fy, x + 6, fy + 3, 'steel')
        rect(x - 1, fy, x + 6, fy + 1, 'steel_h')


def valve(cx, cy):
    for y in range(-4, 5):
        for x in range(-4, 5):
            r = math.hypot(x, y)
            if 3 <= r <= 4.4 or (r < 4 and (x == 0 or y == 0)):
                put(cx + x, cy + y, 'red' if x + y < 2 else 'red_d')
    put(cx, cy, 'steel_h')


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


def steel_door(x0, x1, y0, y1):
    rect(x0 - 3, y0 - 3, x1 + 3, y1, 'mortar_d')
    rect(x0, y0, x1, y1, 'steel')
    rect(x0, y0, x0 + 2, y1, 'steel_l')
    rect(x1 - 2, y0, x1, y1, 'steel_d')
    for ry in range(y0 + 4, y1 - 2, 9):  # rivets
        put(x0 + 4, ry, 'steel_h'); put(x1 - 5, ry, 'steel_h')
    rect(x0 + 2, (y0 + y1) // 2, x1 - 2, (y0 + y1) // 2 + 2, 'steel_d')  # cross plate
    # sliding peephole with two eyes looking out
    sy = y0 + 18
    rect(x0 + 8, sy - 3, x1 - 8, sy + 4, 'steel_d')
    rect(x0 + 9, sy - 2, x1 - 9, sy + 3, 'black')
    mid = (x0 + x1) // 2
    put(mid - 3, sy, 'pp_yellow'); put(mid + 2, sy, 'pp_yellow')
    # handle, rust streaks
    rect(x1 - 9, (y0 + y1) // 2 + 6, x1 - 5, (y0 + y1) // 2 + 9, 'steel_h')
    for _ in range(5):
        rx = random.randrange(x0 + 3, x1 - 3)
        for yy in range(random.randrange(y0, y1 - 20), y1 - random.randint(0, 20)):
            if dither(rx, yy, 0.5):
                put(rx, yy, 'rust')


def crate(x0, y0, w, h):
    rect(x0, y0, x0 + w, y0 + h, 'wood')
    for y in range(y0, y0 + h, 4):
        rect(x0, y, x0 + w, y + 1, 'wood_d')
    rect(x0, y0, x0 + w, y0 + 1, 'wood_h')
    rect(x0, y0, x0 + 2, y0 + h, 'wood_l')
    rect(x0 + w - 2, y0, x0 + w, y0 + h, 'wood_d')
    # stencilled XXX
    cx = x0 + w // 2 - 6
    cy = y0 + h // 2 - 2
    for k in range(3):
        for d in range(4):
            put(cx + k * 4 + d, cy + d, 'paper_d'); put(cx + k * 4 + 3 - d, cy + d, 'paper_d')


def barrel(cx, y0, h):
    for y in range(h):
        bulge = math.sin(math.pi * y / (h - 1))
        half = int(7 + 3 * bulge)
        for x in range(-half, half + 1):
            c = 'wood'
            if x < -half + 3:
                c = 'wood_l'
            if x > half - 3:
                c = 'wood_d'
            if (x + 40) % 4 == 0:
                c = mix(c, 'wood_d', 0.4)
            put(cx + x, y0 + y, c)
        if y in (2, 3, h // 2, h // 2 + 1, h - 4, h - 3):
            for x in range(-half, half + 1):
                put(cx + x, y0 + y, 'steel_l' if x < 0 else 'steel_d')
    rect(cx - 6, y0, cx + 7, y0 + 1, 'wood_h')


def safe(x0, y0, w, h):
    rect(x0, y0, x0 + w, y0 + h, 'steel')
    rect(x0, y0, x0 + w, y0 + 2, 'steel_h')
    rect(x0, y0, x0 + 2, y0 + h, 'steel_l')
    rect(x0 + w - 2, y0, x0 + w, y0 + h, 'steel_d')
    rect(x0 + 4, y0 + 5, x0 + w - 4, y0 + h - 4, 'steel_d')
    rect(x0 + 5, y0 + 6, x0 + w - 5, y0 + h - 5, 'steel')
    cx, cy = x0 + w // 2 - 3, y0 + h // 2
    for y in range(-5, 6):  # combination dial
        for x in range(-5, 6):
            r = math.hypot(x, y)
            if r <= 5:
                c = 'gold' if r > 3.5 else ('gold_l' if x + y < 0 else 'steel_d')
                if r <= 1.2:
                    c = 'black'
                put(cx + x, cy + y, c)
    rect(x0 + w - 9, cy - 1, x0 + w - 6, cy + 6, 'gold')  # handle


def cash_stack(x0, y0, n):
    for k in range(n):
        y = y0 - (k + 1) * 2
        rect(x0, y, x0 + 10, y + 2, 'cash')
        rect(x0, y, x0 + 10, y + 1, 'cash_l')
        rect(x0 + 4, y, x0 + 6, y + 2, 'paper_l')  # band
    rect(x0 + 10, y0 - n * 2, x0 + 11, y0, 'cash_d')


def whiskey(x, base):
    bottle(x, base, 'anejo')


def wall_clock(cx, cy, r=7):
    for y in range(-r - 1, r + 2):
        for x in range(-r - 1, r + 2):
            d = math.hypot(x, y)
            if d <= r + 1:
                c = 'wood_d' if d > r else 'paper_l'
                if r - 1 < d <= r:
                    c = 'wood'
                put(cx + x, cy + y, c)
    for k in range(12):
        a = k * math.pi / 6
        put(cx + int(round((r - 2) * math.cos(a))), cy + int(round((r - 2) * math.sin(a))), 'black')
    for i in range(r - 2):  # hands at about midnight: a late game
        put(cx - i // 3, cy - i, 'black')
    for i in range(r - 3):
        put(cx + i, cy, 'black')
    put(cx, cy, 'red')


def poster(x0, y0, w, h):
    """Torn boxing-night poster pinned to the bricks."""
    rect(x0, y0, x0 + w, y0 + h, 'paper')
    rect(x0, y0, x0 + w, y0 + 1, 'paper_l')
    rect(x0 + 2, y0 + 3, x0 + w - 2, y0 + 8, 'red_d')
    for x in range(x0 + 3, x0 + w - 3, 2):
        put(x, y0 + 5, 'paper_l')
    for y in range(y0 + 11, y0 + h - 4, 3):  # lines of text
        rect(x0 + 3, y, x0 + w - 3 - (y % 5), y + 1, 'paper_d')
    for y in range(y0 + h - 5, y0 + h):  # torn corner
        for x in range(x0 + w - (y - (y0 + h - 5)) * 2, x0 + w):
            put(x, y, 'mortar')
    put(x0 + 1, y0 + 1, 'red'); put(x0 + w - 2, y0 + 1, 'red')


def fedora(cx, cy):
    rect(cx - 1, cy - 11, cx + 2, cy - 7, 'wood_d')  # hook
    rect(cx - 10, cy, cx + 11, cy + 2, 'black')
    rect(cx - 10, cy, cx + 11, cy + 1, 'steel_d')
    for y in range(-7, 0):
        half = 6 - (1 if y < -5 else 0)
        for x in range(-half, half + 1):
            put(cx + x, cy + y, 'steel_d' if x > 1 else 'steel')
    rect(cx - 6, cy - 2, cx + 7, cy, 'red_d')
    put(cx, cy - 7, 'black')


def concrete_floor(y0):
    rect(0, y0 - 3, W, y0, 'conc_d')  # baseboard shadow
    for y in range(y0, H):
        depth = (y - y0) / max(1, H - y0)
        for x in range(W):
            c = 'conc' if not dither(x, y, 0.25 + depth * 0.2) else 'conc_l'
            if dither(x * 7, y * 3, 0.05):
                c = 'conc_d'
            put(x, y, c)
    for sx in range(18, W, 58):  # slab joints, leaning outward with depth
        for y in range(y0, H):
            put(int(sx + (sx - W / 2) * (y - y0) / 160), y, 'conc_d')
    for _ in range(4):  # cracks
        x, y = random.randrange(W), random.randrange(y0 + 2, H)
        for _s in range(random.randint(6, 14)):
            put(x, y, 'conc_d')
            x += random.choice((1, 1, 2))
            y += random.choice((-1, 0, 1))


def dark_vignette(strength=0.22, start=0.45):
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - W / 2) / (W * 0.55), (y - H * 0.45) / (H * 0.7))
            t = max(0.0, min(1.0, (d - start) / 0.5))
            if t > 0:
                steps = int(t * 3 + (0.5 if dither(x, y, (t * 3) % 1) else 0))
                if steps:
                    put(x, y, mix(px[x, y], 'void', strength * steps))


def garito_table_scene(width):
    begin(width, 200, 41)
    ceil, flr = 16, 170
    lamp = (W // 2, 30)
    lamps = [(lamp[0], lamp[1], 150, 1.0), (30, 44, 46, 0.55), (R(30), 44, 46, 0.55)]
    concrete_ceiling(ceil)
    brick_wall(ceil, flr - 3, lamps)
    stains(10, ceil + 4, flr - 10)
    pipe_h(4, 0, W)
    pipe_h(10, 0, W, flange_every=60)
    pipe_v(R(64), ceil, flr - 2)
    valve(R(62) + 2, 92)
    # left: steel door with a dim bulb over it, barrel beside it, a poster
    steel_door(10, 50, 66, flr - 3)
    hanging_bulb(30, 50, ceil, shade=False)
    barrel(66, flr - 30, 30)
    poster(62, 38, 18, 26)
    # right: safe with cash and whiskey on top, crates, a fedora on a hook, a clock
    safe(R(44), flr - 40, 36, 37)
    cash_stack(R(40), flr - 40, 4)
    whiskey(R(26), flr - 40)
    rect(R(16), flr - 45, R(12), flr - 40, 'clear_d'); rect(R(15), flr - 44, R(13), flr - 41, 'amber_l')
    crate(R(80), flr - 22, 30, 19)
    crate(R(76), flr - 39, 24, 17)
    hanging_bulb(R(30), 50, ceil, shade=False)
    wall_clock(R(30), 82)
    fedora(R(90), 56)
    # the main lamp over the table, its cone of dusty light and the smoke
    hanging_bulb(lamp[0], lamp[1], ceil)
    smoke(ceil + 4, ceil + 34, lamp[0], W * 0.4, amount=0.5)
    concrete_floor(flr)
    dark_vignette()


def garito_menu_scene():
    begin(200, 444, 43)
    ceil, flr = 18, 420
    lamp = (W // 2, 40)  # above the logo
    lamps = [(lamp[0], lamp[1], 200, 1.0), (24, 300, 60, 0.45), (R(24), 300, 60, 0.45)]
    concrete_ceiling(ceil)
    brick_wall(ceil, flr - 3, lamps)
    stains(14, ceil + 30, flr - 30)
    pipe_h(4, 0, W)
    pipe_h(11, 0, W, flange_every=58)
    pipe_v(8, ceil, flr - 2)
    valve(10, 190)
    poster(R(36), 128, 24, 32)
    wall_clock(28, 140, 8)
    fedora(R(30), 240)
    # bar shelf with whiskey above the counter, the counter with a brass rail
    wall_shelf(20, 92, 316)
    wall_shelf(R(92), R(20), 316)
    top = 356
    rect(0, top, W, top + 4, 'wood_h')
    rect(0, top + 1, W, top + 3, 'wood_l')
    rect(0, top + 4, W, top + 6, 'black')
    rect(0, top + 6, W, flr - 3, 'wood_d')
    for x in range(4, W, 32):
        rect(x, top + 10, x + 28, flr - 10, 'wood')
        rect(x, top + 10, x + 28, top + 11, 'wood_l')
        rect(x + 27, top + 10, x + 28, flr - 10, 'black')
    rect(0, flr - 9, W, flr - 7, 'gold')  # brass foot rail
    rect(0, flr - 9, W, flr - 8, 'gold_l')
    cash_stack(30, top, 3)
    whiskey(R(40), top)
    rect(R(28), top - 5, R(24), top, 'clear_d'); rect(R(27), top - 4, R(25), top - 1, 'amber_l')
    hanging_bulb(lamp[0], lamp[1], ceil)
    smoke(ceil + 6, ceil + 50, lamp[0], 90, amount=0.5)
    concrete_floor(flr)
    dark_vignette(strength=0.2, start=0.55)


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
