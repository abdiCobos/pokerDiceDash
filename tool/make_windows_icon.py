"""Builds windows/runner/resources/app_icon.ico from tool/icon/icon_full.png.

Windows picks a different size for the title bar (16-24 px), taskbar (24-48 px),
Explorer and the .exe (up to 256 px); a single 256 px image looks blurry when
shrunk, so every size is resampled from the 1024 px artwork.

    flutter test tool/render_app_icon_test.dart   # redraw the artwork first
    python tool/make_windows_icon.py
"""
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parent.parent
src = Image.open(root / 'tool' / 'icon' / 'icon_full.png').convert('RGBA')
sizes = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]
out = root / 'windows' / 'runner' / 'resources' / 'app_icon.ico'
src.save(out, format='ICO', sizes=[(s, s) for s in sizes])
print(f'{out} ({", ".join(map(str, sizes))} px)')
