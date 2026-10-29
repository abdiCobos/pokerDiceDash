"""Pixel-art croupier for the casino roulette (no external art, no licences).

An elegant croupier, always smiling: long wavy chestnut hair with a red rose, gold drop
earrings, a black dress with a gold neckline and a pendant. Bust portrait, 64x64, facing the
viewer. Frames (assets/images/ruleta/crupier_<f>.png):
  smile   eyes open, smiling
  blink   eyes closed (for blinking)
  wink    one eye closed
  spin    right hand raised, flicking the ball
  laugh   happy closed eyes, open smile (a win)
Also writes chip.png (a small casino chip, 12x12) for the betting board.

    python tool/pixelart/crupier.py                 -> every sprite
    python tool/pixelart/crupier.py --preview DIR   -> also an 8x contact sheet
"""
import math
import os
import sys

from PIL import Image

S = 64
OUT = (26, 14, 16)
SKIN = [(176, 110, 88), (214, 148, 118), (236, 180, 148), (248, 208, 178)]
SKIN_D = (160, 98, 78)
BLUSH = (238, 140, 130)
HAIR = [(48, 22, 14), (78, 38, 22), (112, 56, 30), (150, 82, 44), (184, 112, 62)]
LIPS = [(150, 24, 40), (200, 36, 56), (232, 84, 98)]
EYE = (58, 34, 22)
WHITE = (250, 246, 240)
GOLD = [(150, 104, 26), (214, 166, 52), (252, 226, 120)]
DRESS = [(12, 10, 14), (24, 20, 28), (40, 34, 46), (58, 50, 66)]
ROSE = [(130, 14, 28), (190, 30, 46), (236, 72, 86)]
LEAF = [(30, 80, 40), (54, 120, 60)]


class C:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < S and 0 <= y < S:
            self.px[(x, y)] = c

    def get(self, x, y):
        return self.px.get((int(x), int(y)))

    def ellipse(self, cx, cy, rx, ry, shades, light=(-0.5, -0.8)):
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


CX = 32


def hair_back(c):
    """Long wavy hair behind the head, falling over both shoulders (no gap by the neck)."""
    for y in range(14, 56):
        k = (y - 14) / 42
        for side in (-1, 1):
            wave = math.sin(y / 3.4 + (0 if side < 0 else 1.7)) * 1.5
            outer = 13.5 + 4.5 * min(1, k * 1.5) + wave
            for d in range(0, int(outer) + 1):
                x = CX + side * d
                strand = math.sin(d * 0.9 + y * 0.18 + side)
                t = d / outer
                shade = 1 + (1 if strand > 0.2 else 0) + (1 if t > 0.55 and strand > -0.3 else 0)
                if t > 0.9:
                    shade = 1
                c.put(x, y, HAIR[shade])
    c.ellipse(CX, 17, 14.5, 13, HAIR[1:4])


def body(c, frame):
    # shoulders and arms (skin), the dress over them
    for y in range(44, S):
        half = 17 + min(9, (y - 44) * 1.2)
        for x in range(int(CX - half), int(CX + half) + 1):
            t = (x - (CX - half)) / (2 * half)
            c.put(x, y, SKIN[1] if t < 0.15 or t > 0.85 else SKIN[2])
    # neck
    for y in range(34, 46):
        for x in range(CX - 4, CX + 5):
            c.put(x, y, SKIN[1] if x < CX - 1 else SKIN[2])
    for x in range(CX - 3, CX + 4):
        c.put(x, 35, SKIN_D)  # chin shadow
    # dress: black with a gold sweetheart neckline, thin straps
    for y in range(50, S):
        half = 19 + min(7, (y - 50) * 1.1)
        dip = 2 if abs(y - 51) < 1 else 0
        for x in range(int(CX - half), int(CX + half) + 1):
            # sweetheart: two curves meeting in the middle
            top = 50 + int(2.2 * abs(math.sin((x - CX) / 6.5))) + dip
            if y < top:
                continue
            t = (x - (CX - half)) / (2 * half)
            band = 0 if t < 0.12 or t > 0.88 else (1 if t < 0.3 or t > 0.7 else 2)
            c.put(x, y, DRESS[band])
        if y == 50 or y == 51:
            pass
    for x in range(CX - 18, CX + 19):
        top = 50 + int(2.2 * abs(math.sin((x - CX) / 6.5)))
        c.put(x, top, GOLD[1] if (x % 3) else GOLD[2])
    for side in (-1, 1):  # straps
        c.line(CX + side * 12, 50, CX + side * 14, 44, DRESS[2])
    # necklace and pendant
    for i in range(-6, 7):
        c.put(CX + i, 43 + (36 - i * i) // 12 * -1 + 3, GOLD[1] if i % 2 else GOLD[2])
    c.put(CX, 47, GOLD[2]); c.put(CX, 48, (200, 30, 50)); c.put(CX - 1, 47, GOLD[0]); c.put(CX + 1, 47, GOLD[0])
    if frame == 'spin':
        # right arm (viewer's left) raised, hand open flicking the ball, gold bracelet
        c.line(CX - 20, 54, CX - 25, 40, SKIN[1], 4)
        c.line(CX - 25, 40, CX - 24, 31, SKIN[2], 3)
        for y in range(36, 39):
            c.put(CX - 26, y, GOLD[1]); c.put(CX - 23, y, GOLD[2])
        c.ellipse(CX - 24, 28, 3.2, 3.6, SKIN)
        for i, dx in enumerate((-2, 0, 2)):
            c.line(CX - 24 + dx, 26, CX - 24 + dx - 1, 22 - (1 if i == 1 else 0), SKIN[2])
        c.ellipse(CX - 28, 21, 1.3, 1.3, [(220, 220, 228), (250, 250, 255)])  # the ball leaving her fingers


def face(c, frame):
    # oval face with a soft, narrower chin
    for y in range(12, 38):
        for x in range(CX - 12, CX + 13):
            dy = (y - 23) / 12.5
            half = 10.5 * math.sqrt(max(0, 1 - dy * dy)) if dy < 0 else 10.5 * (1 - dy ** 2 * 0.62)
            if abs(x - CX + 0.5) <= half and dy <= 1.0:
                lit = 0.6 - (x - CX) * 0.025 - dy * 0.15
                c.put(x, y, SKIN[3] if lit > 0.72 else (SKIN[2] if lit > 0.42 else SKIN[1]))
    # ears and gold drop earrings
    for side in (-1, 1):
        ex = CX + side * 10.6
        c.ellipse(ex, 24, 1.5, 2.3, SKIN)
        c.put(ex, 27, GOLD[1]); c.put(ex, 28, GOLD[2]); c.put(ex, 29, GOLD[1]); c.put(ex, 30, GOLD[2]); c.put(ex, 31, GOLD[0])
    # fringe: side-swept, framing the face
    for x in range(CX - 11, CX + 12):
        depth = 3 + int(3.5 * math.sin((x - CX + 12) / 7.8))
        for y in range(10, 13 + depth):
            strand = math.sin(x * 0.8 + y * 0.3)
            c.put(x, y, HAIR[3] if strand > 0.4 else HAIR[2])
    for y in range(14, 30):  # locks down the sides of the face
        c.put(CX - 11 + (1 if y > 24 else 0), y, HAIR[2]); c.put(CX - 10, y, HAIR[2] if y < 20 else HAIR[1])
        c.put(CX + 11 - (1 if y > 24 else 0), y, HAIR[2]); c.put(CX + 10, y, HAIR[3] if y < 18 else HAIR[2])
    c.line(CX - 4, 11, CX + 6, 15, HAIR[4])  # shine
    # thin arched brows
    for side in (-1, 1):
        bx = CX + side * 5
        c.put(bx - 2, 18, HAIR[1]); c.put(bx - 1, 17, HAIR[1]); c.put(bx, 17, HAIR[1]); c.put(bx + 1, 17, HAIR[1])
        c.put(bx + 2 * side, 18, HAIR[1])
    # big bright eyes with lashes
    for side in (-1, 1):
        ex = CX + side * 5
        closed = frame in ('blink', 'laugh') or (frame == 'wink' and side > 0)
        if closed:
            if frame == 'laugh' or frame == 'wink':
                for dx, dy in ((-2, 22), (-1, 21), (0, 21), (1, 21), (2, 22)):
                    c.put(ex + dx, dy, OUT)
            else:
                c.line(ex - 2, 22, ex + 2, 22, OUT)
            c.put(ex + 3 * side, 21, OUT)  # outer lash
            continue
        for dx in range(-2, 3):
            for dy in (20, 21, 22):
                c.put(ex + dx, dy, WHITE)
        for dx in (-1, 0, 1):
            for dy in (20, 21, 22):
                c.put(ex + dx, dy, EYE if dy > 20 else (90, 56, 34))
        c.put(ex - 1, 20, WHITE)  # sparkle
        c.put(ex, 22, (30, 18, 12))
        for dx in range(-3, 4):  # upper lash line, flicked up at the outer corner
            c.put(ex + dx, 19, OUT)
        c.put(ex + 4 * side, 18, OUT)
        c.put(ex + 3 * side, 19, OUT)
    # nose
    c.put(CX + 1, 25, SKIN[1]); c.put(CX + 1, 26, SKIN_D); c.put(CX, 27, SKIN_D)
    # blush
    for side in (-1, 1):
        for dx in (6, 7):
            c.put(CX + side * dx, 27, BLUSH)
        c.put(CX + side * 6.5, 28, BLUSH)
    # the smile
    if frame == 'laugh':
        for x in range(CX - 4, CX + 5):
            c.put(x, 30 - (1 if abs(x - CX) == 4 else 0), LIPS[1])
        for x in range(CX - 3, CX + 4):
            c.put(x, 31, WHITE)
        for x in range(CX - 3, CX + 4):
            c.put(x, 32, (150, 40, 50))
        for x in range(CX - 2, CX + 3):
            c.put(x, 33, LIPS[1])
    else:
        # corners lifted, a row of teeth, full lower lip
        for x in range(CX - 4, CX + 5):
            c.put(x, 30 - (1 if abs(x - CX) == 4 else 0), LIPS[1] if abs(x - CX) < 4 else LIPS[0])
        for x in range(CX - 3, CX + 4):
            c.put(x, 31, WHITE)
        for x in range(CX - 2, CX + 3):
            c.put(x, 32, LIPS[2] if x == CX else LIPS[1])


def rose(c):
    rx, ry = CX + 11, 12
    c.ellipse(rx, ry, 3.3, 3.0, ROSE)
    c.put(rx, ry, ROSE[0]); c.put(rx - 1, ry - 1, ROSE[2]); c.put(rx + 1, ry + 1, ROSE[0])
    c.line(rx - 3, ry + 3, rx - 5, ry + 4, LEAF[1]); c.put(rx + 3, ry + 3, LEAF[0])


def crupier(frame):
    c = C()
    hair_back(c)
    body(c, frame)
    face(c, frame)
    rose(c)
    c.outline()
    return c.image()


def chip():
    im = Image.new('RGBA', (12, 12), (0, 0, 0, 0))
    for y in range(12):
        for x in range(12):
            d = math.hypot(x - 5.5, y - 5.5)
            if d <= 5.6:
                col = (200, 30, 40) if d > 3.4 else (240, 230, 220)
                if d > 3.4 and int(math.degrees(math.atan2(y - 5.5, x - 5.5)) // 45) % 2 == 0:
                    col = (250, 246, 240)
                if d > 5.0:
                    col = (110, 14, 20)
                im.putpixel((x, y), col + (255,))
    return im


FRAMES = ['smile', 'blink', 'wink', 'spin', 'laugh']


def main():
    out = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'images', 'ruleta'))
    os.makedirs(out, exist_ok=True)
    tiles = []
    for f in FRAMES:
        im = crupier(f)
        im.save(os.path.join(out, f'crupier_{f}.png'), optimize=True)
        tiles.append(im)
    chip().save(os.path.join(out, 'chip.png'), optimize=True)
    print('saved', len(tiles), 'frames')
    if '--preview' in sys.argv:
        d = sys.argv[sys.argv.index('--preview') + 1]
        os.makedirs(d, exist_ok=True)
        k = 7
        sheet = Image.new('RGBA', (len(tiles) * S * k, S * k), (90, 20, 30, 255))
        for i, im in enumerate(tiles):
            sheet.alpha_composite(im.resize((S * k, S * k), Image.NEAREST), (i * S * k, 0))
        sheet.save(os.path.join(d, 'crupier_preview.png'))


if __name__ == '__main__':
    main()
