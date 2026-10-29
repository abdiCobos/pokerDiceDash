"""Pixel-art portraits for the garito's police raid (no external art, no licences).

Bust portraits (head and shoulders), facing the viewer, two frames each so they can talk:
  vigia_<f>.png       the lookout: big bald mobster, black shirt, gold chain, a gold tooth
  comandante_<f>.png  police comandante: cap, aviator glasses, moustache, badge
  capo_<f>.png        the boss: fedora, pinstripe suit, cigar; "point" accuses someone
  abogado_<f>.png     Lic. Saul Buenhombre: loud suit, slicked hair, big smile; "wink"
Frames: vigia idle/shout, comandante idle/shout, capo idle/point, abogado idle/wink.
All 48x48, shown with FilterQuality.none (assets/images/redada/).

    python tool/pixelart/redada.py                 -> every portrait
    python tool/pixelart/redada.py --preview DIR   -> also an 8x contact sheet
"""
import math
import os
import sys

from PIL import Image

S = 48
OUT = (22, 14, 12)
SKIN = [(132, 84, 58), (176, 120, 84), (210, 156, 112), (232, 186, 140)]
SKIN_D = [(104, 64, 42), (146, 96, 64), (182, 128, 88), (206, 160, 116)]
WHITE = (246, 242, 234)
BLACK = (18, 14, 14)
GOLD = [(140, 98, 24), (212, 162, 46), (252, 222, 110)]


class C:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < S and 0 <= y < S:
            self.px[(x, y)] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.put(x, y, c)

    def ellipse(self, cx, cy, rx, ry, shades, light=(-0.6, -0.8)):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx, dy = (x - cx) / rx, (y - cy) / ry
                d = dx * dx + dy * dy
                if d <= 1.0:
                    lit = (dx * light[0] + dy * light[1]) * 0.5 + 0.55 - d * 0.2
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

    def shoulders(self, top, half_top, half_bottom, shades, cx=24):
        """Trapezoid torso from y=top to the bottom edge, shaded left to right."""
        for y in range(top, S):
            k = (y - top) / max(1, S - 1 - top)
            half = half_top + (half_bottom - half_top) * min(1, k * 1.8)
            for x in range(int(cx - half), int(cx + half) + 1):
                t = (x - (cx - half)) / max(1, 2 * half)
                band = 0 if t < 0.18 else (len(shades) - 1 if t > 0.82 else (2 if t < 0.4 else 1))
                self.put(x, y, shades[min(band, len(shades) - 1)])

    def outline(self):
        add = {}
        for (x, y) in list(self.px):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in self.px and 0 <= q[0] < S and 0 <= q[1] < S:
                    add[q] = OUT
        self.px.update(add)

    def image(self):
        im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c + (255,))
        return im


def eyes(c, y, cx=24, gap=4, color=BLACK, angry=False):
    for sx in (-1, 1):
        x = cx + sx * gap
        c.put(x, y, WHITE)
        c.put(x + (1 if sx < 0 else -1), y, color)
        if angry:
            c.line(x - 2, y - 2 - (1 if sx < 0 else 0), x + 2, y - 2 - (0 if sx < 0 else 1), BLACK)


def vigia(frame):
    """The lookout: huge, bald, thick neck, black shirt open at the collar, gold chain."""
    c = C()
    shirt = [(10, 10, 12), (24, 24, 28), (40, 40, 46), (58, 58, 66)]
    c.shoulders(31, 12, 23, shirt)
    # open collar showing the chest and a heavy gold chain
    for y in range(31, 40):
        half = max(0, 4 - (y - 31) // 2)
        for x in range(24 - half, 24 + half + 1):
            c.put(x, y, SKIN[1] if x < 24 else SKIN[2])
    for i in range(-7, 8):
        c.put(24 + i, 36 + abs(i) // 3, GOLD[1] if i % 2 else GOLD[2])
    c.put(24, 39, GOLD[2]); c.put(23, 39, GOLD[1]); c.put(25, 39, GOLD[1])
    # thick neck and big bald head
    c.ellipse(24, 29, 7, 4, SKIN)
    c.ellipse(24, 18, 10, 11, SKIN)
    c.put(19, 10, SKIN[3]); c.put(20, 9, SKIN[3]); c.put(21, 9, SKIN[3])  # shine on the scalp
    # ears
    c.ellipse(13.5, 19, 1.8, 2.6, SKIN_D); c.ellipse(34.5, 19, 1.8, 2.6, SKIN_D)
    # heavy brow, small mean eyes, stubble
    c.line(17, 15, 22, 16, BLACK, 1); c.line(26, 16, 31, 15, BLACK, 1)
    eyes(c, 17, gap=4)
    for x in range(17, 32, 2):
        for y in (23, 25, 27):
            if (x + y) % 4 == 0:
                c.put(x, y, SKIN_D[0])
    c.line(23, 19, 24, 21, SKIN_D[1])  # nose
    if frame == 'shout':
        c.rect(20, 23, 29, 27, (90, 20, 20))
        c.rect(21, 23, 28, 24, WHITE)
        c.put(26, 23, GOLD[2]); c.put(25, 23, GOLD[1])  # the gold tooth
        c.rect(21, 26, 28, 27, (150, 50, 50))
    else:
        c.line(20, 24, 28, 24, (90, 30, 26))
        c.put(25, 24, GOLD[2]); c.put(26, 24, GOLD[1])  # gold tooth showing in a smirk
        c.put(28, 23, (90, 30, 26))
    # scar over one eyebrow (old, healed)
    c.line(29, 12, 31, 16, SKIN_D[0])
    c.outline()
    return c.image()


def comandante(frame):
    c = C()
    uniform = [(22, 34, 66), (34, 52, 98), (52, 74, 130), (74, 98, 160)]
    c.shoulders(32, 12, 22, uniform)
    # shirt collar, tie and badge
    c.line(21, 32, 24, 36, (210, 214, 222)); c.line(27, 32, 24, 36, (210, 214, 222))
    c.line(24, 36, 24, 46, (16, 18, 30), 2)
    for (x, y) in ((16, 38), (17, 37), (18, 38), (17, 39), (17, 38)):
        c.put(x, y, GOLD[1])
    c.put(17, 38, GOLD[2])
    # epaulettes
    c.rect(11, 33, 16, 35, GOLD[1]); c.rect(32, 33, 37, 35, GOLD[1])
    c.ellipse(24, 30, 5, 3, SKIN)
    c.ellipse(24, 20, 9, 10, SKIN)
    # cap: crown, band and peak, with a badge
    c.ellipse(24, 10, 11, 5, uniform)
    c.rect(14, 11, 35, 14, (16, 18, 30))
    c.rect(13, 14, 36, 16, BLACK)
    for (x, y) in ((24, 7), (23, 8), (25, 8), (24, 9)):
        c.put(x, y, GOLD[2])
    # aviator glasses
    for sx in (-1, 1):
        c.ellipse(24 + sx * 4.5, 19, 3.2, 2.3, [(20, 26, 36), (40, 54, 74), (90, 120, 150)])
    c.line(21, 18, 27, 18, GOLD[0])
    # big moustache
    for x in range(18, 31):
        y = 25 + (1 if abs(x - 24) > 4 else 0)
        c.put(x, y, (40, 28, 20)); c.put(x, y - 1, (60, 42, 30))
    if frame == 'shout':
        c.rect(21, 27, 28, 30, (90, 20, 20)); c.rect(22, 27, 27, 28, WHITE)
    else:
        c.line(22, 28, 26, 28, (90, 40, 34))
    c.outline()
    return c.image()


def capo(frame):
    c = C()
    suit = [(30, 26, 34), (48, 42, 54), (66, 60, 74), (90, 84, 100)]
    c.shoulders(32, 12, 22, suit)
    for y in range(32, S):  # pinstripes
        for x in range(10, 39, 3):
            if (x, y) in c.px and c.px[(x, y)] in suit:
                c.put(x, y, (120, 114, 128))
    # white shirt, red tie, flower on the lapel
    for y in range(32, 40):
        half = max(0, 3 - (y - 32) // 3)
        for x in range(24 - half, 24 + half + 1):
            c.put(x, y, WHITE)
    c.line(24, 34, 24, 46, (160, 24, 30), 2)
    c.ellipse(17, 36, 1.6, 1.6, [(200, 40, 50), (240, 80, 90), (255, 160, 170)])
    c.ellipse(24, 30, 5, 3, SKIN)
    c.ellipse(24, 20, 9, 10, SKIN)
    # fedora with a band
    c.ellipse(24, 12, 9, 5, [(26, 22, 22), (44, 38, 36), (62, 54, 50)])
    c.rect(11, 13, 38, 15, (26, 22, 22))
    c.rect(15, 11, 34, 13, (120, 20, 24))
    # cold eyes, thin moustache, cigar
    eyes(c, 19, gap=4, angry=True)
    c.line(20, 25, 28, 25, (40, 28, 20))
    c.line(22, 27, 27, 27, (90, 40, 34))
    c.line(27, 27, 33, 26, (120, 70, 36), 1); c.line(27, 28, 33, 27, (88, 50, 26), 1)
    c.put(34, 26, (255, 150, 40)); c.put(34, 27, (255, 210, 90))
    for i, (dx, dy) in enumerate(((35, 24), (36, 22), (35, 20), (36, 18))):  # smoke
        c.put(dx, dy, (170, 166, 160) if i % 2 else (140, 136, 130))
    if frame == 'point':
        # arm and finger pointing at the viewer's right
        c.line(30, 40, 42, 33, suit[2], 3)
        c.ellipse(43, 32, 2.5, 2.2, SKIN)
        c.line(44, 32, 47, 31, SKIN[2], 1)
    c.outline()
    return c.image()


def abogado(frame):
    """Lic. Saul Buenhombre: loud mustard suit, purple shirt, wide tie, slicked combover."""
    c = C()
    suit = [(150, 104, 30), (196, 148, 52), (226, 186, 84), (246, 214, 124)]
    c.shoulders(32, 12, 22, suit)
    for y in range(32, 42):
        half = max(0, 4 - (y - 32) // 3)
        for x in range(24 - half, 24 + half + 1):
            c.put(x, y, (112, 52, 140))
    c.line(24, 34, 24, 46, (230, 60, 60), 3)  # loud tie
    c.line(23, 38, 25, 38, (250, 210, 60)); c.line(23, 42, 25, 42, (250, 210, 60))
    c.ellipse(24, 30, 5, 3, SKIN)
    c.ellipse(24, 20, 9, 10, SKIN)
    # slicked combover
    c.ellipse(24, 12, 10, 5, [(40, 26, 18), (66, 44, 30), (96, 66, 44)])
    c.line(16, 13, 31, 10, (110, 78, 52))
    c.rect(14, 13, 16, 20, (66, 44, 30)); c.rect(33, 13, 35, 20, (66, 44, 30))
    # eyes: one winks
    if frame == 'wink':
        c.put(20, 19, WHITE); c.put(21, 19, BLACK)
        c.line(26, 19, 29, 19, BLACK)
    else:
        eyes(c, 19, gap=4)
    c.line(23, 21, 24, 23, SKIN_D[1])
    # huge salesman smile
    c.rect(19, 25, 30, 28, (90, 20, 20))
    c.rect(20, 25, 29, 26, WHITE)
    c.put(19, 24, (90, 40, 34)); c.put(30, 24, (90, 40, 34))
    c.outline()
    return c.image()


PORTRAITS = {
    'vigia': (vigia, ['idle', 'shout']),
    'comandante': (comandante, ['idle', 'shout']),
    'capo': (capo, ['idle', 'point']),
    'abogado': (abogado, ['idle', 'wink']),
}


def main():
    out = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'images', 'redada'))
    os.makedirs(out, exist_ok=True)
    tiles = []
    for name, (draw, frames) in PORTRAITS.items():
        for f in frames:
            im = draw(f)
            im.save(os.path.join(out, f'{name}_{f}.png'), optimize=True)
            tiles.append(im)
    print('saved', len(tiles), 'portraits')
    if '--preview' in sys.argv:
        d = sys.argv[sys.argv.index('--preview') + 1]
        os.makedirs(d, exist_ok=True)
        k = 8
        sheet = Image.new('RGBA', (len(tiles) * S * k, S * k), (60, 46, 34, 255))
        for i, im in enumerate(tiles):
            sheet.alpha_composite(im.resize((S * k, S * k), Image.NEAREST), (i * S * k, 0))
        sheet.save(os.path.join(d, 'redada_preview.png'))


if __name__ == '__main__':
    main()
