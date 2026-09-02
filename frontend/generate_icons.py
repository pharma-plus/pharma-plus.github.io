import os
from PIL import Image, ImageDraw

ROOT = r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend'

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(3))

C0 = (0x00, 0xE0, 0xC6)
C1 = (0x12, 0xA0, 0x6A)
C2 = (0x0A, 0x3D, 0x2E)
TEAL = (0x00, 0xE0, 0xC6)
WHITE = (255, 255, 255)

def gradient_color(t):
    if t < 0.48:
        return lerp(C0, C1, t/0.48)
    return lerp(C1, C2, (t-0.48)/0.52)

def make_tile(S):
    """Rend une pastille de marque PHARMA+ de taille S (RGBA, coins transparents)."""
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    grad = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    px = grad.load()
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2.0 * (S - 1))
            r, g, b = gradient_color(t)
            px[x, y] = (r, g, b, 255)
    # masque carre arrondi
    mask = Image.new('L', (S, S), 0)
    d = ImageDraw.Draw(mask)
    rad = int(S * 0.22)
    d.rounded_rectangle([0, 0, S-1, S-1], radius=rad, fill=255)
    tile = Image.composite(grad, img, mask)
    # reflet haut
    sheen = Image.new('RGBA', (S, S), (255, 255, 255, 0))
    sd = ImageDraw.Draw(sheen)
    sd.rounded_rectangle([0, 0, S-1, int(S*0.5)], radius=rad, fill=(255, 255, 255, 70))
    tile = Image.alpha_composite(tile, sheen)
    return tile

def add_plus(tile):
    S = tile.size[0]
    d = ImageDraw.Draw(tile)
    cx, cy = S/2, S/2
    bw = S * 0.14
    bh = S * 0.58
    rx = int(bw/2)
    # vertical
    v = [cx-bw/2, cy-bh/2, cx+bw/2, cy+bh/2]
    # horizontal
    hw = S * 0.58
    hh = S * 0.14
    h = [cx-hw/2, cy-hh/2, cx+hw/2, cy+hh/2]
    d.rounded_rectangle(v, radius=rx, fill=WHITE)
    d.rounded_rectangle(h, radius=int(hh/2), fill=WHITE)
    # liseré turquoise
    lw = max(2, int(S*0.02))
    d.rounded_rectangle(v, radius=rx, outline=TEAL, width=lw)
    d.rounded_rectangle(h, radius=int(hh/2), outline=TEAL, width=lw)
    return tile

def add_capsule(tile):
    S = tile.size[0]
    cw, ch = int(S*0.30), int(S*0.115)
    cap = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cap)
    cd.rounded_rectangle([0, 0, cw-1, ch-1], radius=ch//2, fill=WHITE+(255,))
    cd.rounded_rectangle([0, 0, cw//2, ch-1], radius=ch//2, fill=TEAL+(255,))
    cap = cap.rotate(-45, expand=True)
    tile.alpha_composite(cap, (int(S*0.62 - cap.size[0]/2), int(S*0.62 - cap.size[1]/2)))
    return tile

def build_mark(S):
    return add_capsule(add_plus(make_tile(S)))

def save_png(path, img):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, 'PNG')

# --- Web icons ---
import shutil
web = os.path.join(ROOT, 'web')
save_png(os.path.join(web, 'favicon.png'), build_mark(64).resize((64, 64), Image.LANCZOS))
shutil.copyfile(os.path.join(ROOT, 'assets', 'logo', 'pharma_plus_mark.svg'),
                os.path.join(web, 'favicon.svg'))
for sz in (192, 512):
    save_png(os.path.join(web, 'icons', f'Icon-{sz}.png'), build_mark(sz))
    # maskable: marque a 82% centree
    m = build_mark(sz)
    m = m.resize((int(sz*0.82), int(sz*0.82)), Image.LANCZOS)
    canvas = Image.new('RGBA', (sz, sz), (0, 0, 0, 0))
    canvas.alpha_composite(m, (int(sz*0.09), int(sz*0.09)))
    save_png(os.path.join(web, 'icons', f'Icon-maskable-{sz}.png'), canvas)

# --- Windows icon (.ico, multiples tailles) ---
win = os.path.join(ROOT, 'windows', 'runner', 'resources')
os.makedirs(win, exist_ok=True)
sizes = [16, 24, 32, 48, 64, 128, 256]
base = build_mark(256)
base.save(os.path.join(win, 'app_icon.ico'), format='ICO',
          sizes=[(s, s) for s in sizes])

# Verification
from PIL import Image as _Img
with _Img.open(os.path.join(win, 'app_icon.ico')) as verified:
    print('ICO frames:', getattr(verified, 'n_frames', 1), 'size', os.path.getsize(os.path.join(win, 'app_icon.ico')))

print('ICONS GENERATED')
print('favicon', os.path.getsize(os.path.join(web, 'favicon.png')))
print('icon192', os.path.getsize(os.path.join(web, 'icons', 'Icon-192.png')))
print('maskable512', os.path.getsize(os.path.join(web, 'icons', 'Icon-maskable-512.png')))
