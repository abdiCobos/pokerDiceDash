"""Pixel-art sprites for the Dice Dash cockfight in the cantina (no external art, no licences).

Cartoon boxing roosters (boxing gloves, no blood), the well-dressed hen who hugs the winner and
gives him a cigar, and the dirt ring. Every frame faces RIGHT; Flutter mirrors them as needed.
Shown with FilterQuality.none, so keep them small.

Written to assets/images/gallos/:
  <rooster>_<frame>.png  48x48   rooster = colorado | giro
      frames: idle0 idle1 walk0 walk1 punch hit ko dizzy celebrate cigar walkc0 walkc1
  hen_<frame>.png        48x48   frames: walk0 walk1 give hug
  ring.png               200x90  the dirt ring
  heart.png, star.png    9x8     hearts for the couple, stars over the K.O.

    python tool/pixelart/gallos.py                 -> every sprite
    python tool/pixelart/gallos.py --preview DIR   -> also a 6x contact sheet in DIR
"""
import math
import os
import sys

from PIL import Image

S = 48  # sprite canvas
OX, OY = 8, 6  # drawing origin inside the canvas (room for the tail and a raised glove)

ROOSTERS = {
    # body shades (dark -> light), hackle (neck feathers), tail, gloves (dark, base, light)
    'colorado': dict(body=[(96, 28, 18), (148, 46, 24), (190, 74, 34), (222, 112, 52)],
                     hackle=[(176, 96, 22), (226, 150, 40), (250, 200, 90)],
                     tail=[(18, 40, 30), (30, 70, 52), (52, 104, 76)],
                     glove=[(120, 14, 20), (200, 30, 36), (250, 96, 90)]),
    'giro': dict(body=[(150, 118, 70), (204, 172, 104), (234, 210, 150), (250, 238, 204)],
                 hackle=[(170, 120, 30), (220, 170, 50), (248, 216, 110)],
                 tail=[(22, 26, 44), (40, 48, 84), (70, 84, 140)],
                 glove=[(20, 52, 130), (36, 98, 210), (110, 168, 250)]),
}
RED = [(150, 20, 24), (210, 40, 40), (246, 92, 80)]       # comb and wattle
BEAK = [(176, 120, 20), (236, 182, 48), (252, 222, 120)]
LEG = [(170, 120, 30), (226, 176, 60)]
OUT = (34, 18, 14)
WHITE = (248, 244, 236)
BLACK = (20, 14, 12)


class Canvas:
    def __init__(self, w=S, h=S):
        self.w, self.h = w, h
        self.px = {}

    def put(self, x, y, c):
        x, y = int(round(x)) + OX, int(round(y)) + OY
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def ellipse(self, cx, cy, rx, ry, shades, light=(0.7, -0.7)):
        """Filled ellipse shaded in bands, lit from the upper right."""
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx, dy = (x - cx) / rx, (y - cy) / ry
                d = dx * dx + dy * dy
                if d <= 1.0:
                    lit = (dx * light[0] + dy * light[1]) * 0.5 + 0.5 - d * 0.25
                    k = max(0, min(len(shades) - 1, int(lit * len(shades))))
                    self.put(x, y, shades[k])

    def line(self, x0, y0, x1, y1, c, w=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(1, n)
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for ox in range(w):
                for oy in range(w):
                    self.put(x + ox - w // 2, y + oy - w // 2, c)

    def outline(self, color=OUT):
        add = {}
        for (x, y) in list(self.px):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)  # canvas coordinates (origin already applied)
                if q not in self.px and 0 <= q[0] < self.w and 0 <= q[1] < self.h:
                    add[q] = color
        self.px.update(add)

    def image(self):
        im = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c + (255,) if len(c) == 3 else c)
        return im


def glove(c, cx, cy, g, r=3.4):
    c.ellipse(cx, cy, r, r * 0.95, g)
    c.put(cx + 1, cy - 2, g[2])
    # white cuff on the wrist side
    for dy in (-1, 0, 1):
        c.put(cx - r, cy + dy, WHITE)


def rooster(kind, frame):
    p = ROOSTERS[kind]
    c = Canvas()
    bob = 1 if frame in ('idle1', 'walk1', 'walkc1') else 0
    lean = {'punch': 2, 'hit': -2, 'celebrate': 0}.get(frame, 0)
    bx, by = 16 + lean, 23 + bob
    hx, hy = 24 + lean + (2 if frame == 'punch' else 0) - (2 if frame == 'hit' else 0), 12 + bob - (1 if frame == 'celebrate' else 0)

    # legs (behind the body)
    step = {'walk0': (-3, 2), 'walk1': (2, -2), 'walkc0': (-3, 2), 'walkc1': (2, -2)}.get(frame, (0, 0))
    for lx, st in ((bx - 2, step[0]), (bx + 3, step[1])):
        c.line(lx, by + 6, lx + st, 37, LEG[0], 1)
        c.line(lx + st, 37, lx + st + 3, 37, LEG[1], 1)
        c.line(lx + st, 37, lx + st - 2, 37, LEG[1], 1)
    # back glove (darker), behind the body
    if frame not in ('celebrate',):
        gx, gy = (bx + 9, by - 2) if frame != 'hit' else (bx + 6, by - 6)
        glove(c, gx, gy, [p['glove'][0], p['glove'][0], p['glove'][1]], 3.0)
    # tail: long sickle feathers rising high behind the body, then arching back down
    for i, (ang, ln, w) in enumerate(((236, 21, 3), (250, 23, 3), (264, 20, 2), (222, 17, 2), (278, 15, 2))):
        a = math.radians(ang)
        x0, y0 = bx - 5, by - 3
        prev = (x0, y0)
        for t in range(1, ln):
            k = t / ln
            x = x0 + math.cos(a) * t - k * k * 11
            y = y0 + math.sin(a) * t + k * k * 8
            c.line(prev[0], prev[1], x, y, p['tail'][(i + (1 if k > 0.6 else 0)) % 3], w if k < 0.8 else 1)
            prev = (x, y)
    # body and wing
    c.ellipse(bx, by, 9, 7.5, p['body'])
    c.ellipse(bx - 1, by + 1, 5.5, 3.6, [p['body'][0], p['body'][1], p['body'][1]])
    # neck (hackle) joining head and body
    for t in range(8):
        k = t / 7
        c.ellipse(bx + 4 + (hx - bx - 4) * k, by - 4 + (hy - by + 4) * k, 4.2 - k, 3.6 - k * 0.6, p['hackle'])
    # head
    c.ellipse(hx, hy, 4.4, 4.2, p['hackle'])
    # comb
    for i, dx in enumerate((-3, -1, 1, 3)):
        top = hy - 6 - (1 if i in (1, 2) else 0)
        c.line(hx + dx, hy - 3, hx + dx, top, RED[1 + (i % 2)], 2)
    # beak and wattle
    for i in range(4):
        c.line(hx + 4, hy - 1 + i * 0.3, hx + 7 - i * 0.5, hy - 0.5 + i * 0.2, BEAK[1 if i < 2 else 0])
    c.put(hx + 5, hy - 1, BEAK[2])
    c.ellipse(hx + 4, hy + 4, 1.4, 2.0, RED)
    # eye
    if frame in ('ko', 'dizzy'):
        for d in (-1, 0, 1):
            c.put(hx + 1 + d, hy - 1 + d, BLACK)
            c.put(hx + 1 + d, hy - 1 - d, BLACK)
    elif frame in ('celebrate', 'cigar', 'walkc0', 'walkc1'):
        c.put(hx, hy - 2, BLACK); c.put(hx + 1, hy - 3, BLACK); c.put(hx + 2, hy - 2, BLACK)  # happy ^
    else:
        c.put(hx + 1, hy - 1, WHITE); c.put(hx + 2, hy - 1, BLACK); c.put(hx + 2, hy - 2, BLACK)
        c.line(hx, hy - 3, hx + 3, hy - 3, BLACK)  # fighting brow
    # cigar in the beak
    if frame in ('cigar', 'walkc0', 'walkc1'):
        c.line(hx + 6, hy + 1, hx + 11, hy + 1, (120, 70, 36), 1)
        c.line(hx + 6, hy + 2, hx + 11, hy + 2, (88, 50, 26), 1)
        c.put(hx + 8, hy + 1, (200, 40, 40))  # band
        c.put(hx + 12, hy + 1, (255, 150, 40)); c.put(hx + 12, hy + 2, (255, 210, 90))
    # front glove
    g = p['glove']
    pos = {'punch': (hx + 9, hy + 4), 'hit': (hx + 2, hy + 6), 'celebrate': (hx - 3, 3),
           'cigar': (hx - 3, 4), 'walkc0': (bx + 8, by - 3), 'walkc1': (bx + 8, by - 2)}.get(frame, (bx + 10, by - 4))
    if frame != 'ko':
        # arm (wing) to the glove
        shoulder = (bx + 1, by - 4) if frame in ('celebrate', 'cigar') else (bx + 4, by - 1)
        c.line(shoulder[0], shoulder[1], pos[0], pos[1] + 2, p['body'][1], 2)
        glove(c, pos[0], pos[1], g)
    c.outline()
    im = c.image()
    if frame == 'ko':
        im = im.rotate(90, resample=Image.NEAREST)  # flat on its back, feet up
        im = im.transform(im.size, Image.AFFINE, (1, 0, 0, 0, 1, -4), resample=Image.NEAREST)
    return im


HEN = dict(body=[(170, 140, 120), (214, 188, 166), (240, 222, 204), (252, 244, 234)],
           dress=[(150, 40, 96), (210, 72, 140), (244, 130, 182)],
           lace=(252, 246, 250), hat=[(70, 30, 110), (110, 52, 160), (160, 100, 210)],
           pearl=(250, 250, 255))


def hen(frame):
    c = Canvas()
    bob = 1 if frame == 'walk1' else 0
    bx, by = 17, 24 + bob
    hx, hy = 24, 13 + bob
    step = {'walk0': (-2, 2), 'walk1': (2, -2)}.get(frame, (0, 0))
    for lx, st in ((bx - 2, step[0]), (bx + 3, step[1])):
        c.line(lx, by + 8, lx + st, 37, LEG[0])
        c.line(lx + st, 37, lx + st + 2, 37, LEG[1])
    # short round tail
    c.ellipse(bx - 8, by - 3, 3, 4, HEN['body'])
    c.ellipse(bx, by, 8, 7, HEN['body'])
    # dress: bell skirt with lace hem, and a bow at the back
    for y in range(by - 1, by + 9):
        half = 7 + (y - by) * 0.7
        for x in range(int(bx - half), int(bx + half) + 1):
            k = 0 if x < bx - half * 0.5 else (2 if x > bx + half * 0.4 else 1)
            c.put(x, y, HEN['dress'][k])
    for x in range(int(bx - 13), int(bx + 13)):
        if (x % 2) == 0:
            c.put(x, by + 9, HEN['lace'])
    c.ellipse(bx - 8, by - 1, 2, 1.6, HEN['dress'])
    # neck and head
    for t in range(6):
        k = t / 5
        c.ellipse(bx + 4 + (hx - bx - 4) * k, by - 4 + (hy - by + 4) * k, 3.6 - k * 0.8, 3.2 - k * 0.5, HEN['body'])
    c.ellipse(hx, hy, 4, 3.8, HEN['body'])
    # pearl necklace
    for i in range(5):
        c.put(hx - 3 + i * 1.4, hy + 4 + (1 if i in (1, 2, 3) else 0), HEN['pearl'])
    # small comb under a wide hat with a flower
    c.line(hx - 1, hy - 4, hx + 2, hy - 4, RED[1], 1)
    c.line(hx - 6, hy - 5, hx + 6, hy - 5, HEN['hat'][0], 1)
    c.ellipse(hx, hy - 7, 3.4, 2.2, HEN['hat'])
    c.ellipse(hx - 3, hy - 8, 1.4, 1.4, [(200, 40, 70), (240, 80, 110), (255, 150, 170)])
    c.put(hx - 3, hy - 8, (255, 230, 120))
    # beak and eye with lashes
    c.line(hx + 4, hy, hx + 6, hy, BEAK[1]); c.put(hx + 4, hy + 1, BEAK[0])
    c.put(hx + 1, hy - 1, BLACK); c.put(hx + 2, hy - 2, BLACK); c.put(hx + 1, hy - 3, BLACK)
    c.put(hx + 3, hy + 1, (240, 120, 130))  # blush
    # wing: down while walking, forward to give the cigar, around the winner to hug
    if frame == 'give':
        c.line(bx + 3, by - 1, bx + 12, by - 4, HEN['body'][1], 2)
        c.line(bx + 12, by - 5, bx + 17, by - 5, (120, 70, 36), 1)
        c.line(bx + 12, by - 4, bx + 17, by - 4, (88, 50, 26), 1)
        c.put(bx + 14, by - 5, (200, 40, 40))
    elif frame == 'hug':
        c.line(bx + 2, by - 2, bx + 12, by - 6, HEN['body'][1], 2)
        c.line(bx + 12, by - 6, bx + 14, by - 2, HEN['body'][1], 2)
    else:
        c.ellipse(bx + 1, by, 4, 2.6, [HEN['body'][0], HEN['body'][1], HEN['body'][1]])
    c.outline()
    return c.image()


def ring():
    """Dirt ring seen from the side, a low wooden fence behind it."""
    w, h = 200, 90
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    for y in range(h):
        for x in range(w):
            dx, dy = (x - w / 2) / (w / 2 - 2), (y - h * 0.62) / (h * 0.36)
            d = dx * dx + dy * dy
            if y < 26 and abs(x - w / 2) < w / 2 - 6:
                # fence planks
                plank = (x // 9) % 2
                col = (96, 58, 30) if plank else (118, 74, 40)
                if y in (8, 9, 20, 21):
                    col = (70, 42, 22)
                px[x, y] = col + (255,)
            elif d <= 1.0:
                base = (168, 120, 70) if d < 0.75 else (140, 96, 54)
                if ((x * 7 + y * 13) % 23) == 0:
                    base = (200, 160, 96)  # straw
                if ((x * 5 + y * 3) % 31) == 0:
                    base = (122, 84, 46)
                px[x, y] = base + (255,)
            elif d <= 1.12:
                px[x, y] = (86, 52, 26, 255)  # ring edge
    return im


HEART = ['.XX.XX.', 'XXXXXXX', 'XXXXXXX', '.XXXXX.', '..XXX..', '...X...']
STAR = ['...X...', '..XXX..', 'XXXXXXX', '.XXXXX.', '.XX.XX.', 'X.....X']


def icon(rows, fill, shine):
    """Tiny outlined icon from a template (hearts over the couple, stars over the K.O.)."""
    w, h = len(rows[0]) + 2, len(rows) + 2
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    cells = {(x + 1, y + 1) for y, r in enumerate(rows) for x, v in enumerate(r) if v == 'X'}
    for (x, y) in cells:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in cells:
                im.putpixel(q, OUT + (255,))
    for (x, y) in cells:
        im.putpixel((x, y), fill + (255,))
    first = min(cells, key=lambda c: (c[1], c[0]))
    im.putpixel((first[0], first[1] + 1), shine + (255,))
    return im


FRAMES = ['idle0', 'idle1', 'walk0', 'walk1', 'punch', 'hit', 'ko', 'dizzy', 'celebrate', 'cigar', 'walkc0', 'walkc1']
HEN_FRAMES = ['walk0', 'walk1', 'give', 'hug']


def main():
    out = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'images', 'gallos'))
    os.makedirs(out, exist_ok=True)
    sheet = []
    for kind in ROOSTERS:
        row = []
        for f in FRAMES:
            im = rooster(kind, f)
            im.save(os.path.join(out, f'{kind}_{f}.png'), optimize=True)
            row.append(im)
        sheet.append(row)
    row = []
    for f in HEN_FRAMES:
        im = hen(f)
        im.save(os.path.join(out, f'hen_{f}.png'), optimize=True)
        row.append(im)
    sheet.append(row)
    ring().save(os.path.join(out, 'ring.png'), optimize=True)
    icon(HEART, (236, 64, 122), (255, 190, 210)).save(os.path.join(out, 'heart.png'), optimize=True)
    icon(STAR, (255, 214, 64), (255, 250, 200)).save(os.path.join(out, 'star.png'), optimize=True)
    print('saved', sum(len(r) for r in sheet) + 1, 'sprites')
    if '--preview' in sys.argv:
        d = sys.argv[sys.argv.index('--preview') + 1]
        os.makedirs(d, exist_ok=True)
        k = 6
        cols = max(len(r) for r in sheet)
        prev = Image.new('RGBA', (cols * S * k, len(sheet) * S * k + 90 * k), (60, 40, 28, 255))
        for r, row in enumerate(sheet):
            for i, im in enumerate(row):
                prev.alpha_composite(im.resize((S * k, S * k), Image.NEAREST), (i * S * k, r * S * k))
        prev.alpha_composite(ring().resize((200 * k, 90 * k), Image.NEAREST), (0, len(sheet) * S * k))
        prev.save(os.path.join(d, 'gallos_preview.png'))


if __name__ == '__main__':
    main()
