# =============================================================
# PHARMA+ - Generateur de branding officiel
# Source : logo officiel PHARMA+ (croix verte 3D + feuille + or).
# Genere :
#   - assets/branding/  (variantes full / icon / light / dark / mobile)
#   - web/favicon.png + favicon.svg + icons/Icon-*.png (PWA)
#   - windows/runner/resources/app_icon.ico
# Aucune retouche du logo : uniquement recadrage propre,
# mise a l'echelle proportionnelle et fond transparent.
# =============================================================
import base64
import os
import shutil
from collections import deque

from PIL import Image, ImageDraw

ROOT = r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend'
SRC = r'C:\Users\Merouan\Downloads\ChatGPT Image 5 sept. 2026, 22_17_29.png'
BRANDING = os.path.join(ROOT, 'assets', 'branding')
SOURCE_DIR = os.path.join(BRANDING, 'source')
WEB = os.path.join(ROOT, 'web')

# Palette de marque (theme PHARMA+)
PLATE_TOP = (0x0E, 0x4A, 0x33)   # emeraude profond (medaillon)
PLATE_BOTTOM = (0x04, 0x1F, 0x15)


# -------------------------------------------------------------
# 1. Source officielle -> copie figee dans le projet
# -------------------------------------------------------------
def import_source():
    os.makedirs(SOURCE_DIR, exist_ok=True)
    dst = os.path.join(SOURCE_DIR, 'pharma_plus_official.png')
    shutil.copyfile(SRC, dst)
    return Image.open(dst).convert('RGBA')


# -------------------------------------------------------------
# 2. Fond noir -> transparent (flood fill depuis les bords,
#    preserve les zones sombres interieures du logo)
# -------------------------------------------------------------
def remove_background(img):
    w, h = img.size
    px = img.load()
    visited = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))
    thr = 30  # luminosite max consideree comme fond (noir)
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        i = y * w + x
        if visited[i]:
            continue
        visited[i] = 1
        r, g, b, a = px[x, y]
        if max(r, g, b) > thr:
            continue  # pixel du logo : on ne traverse pas
        px[x, y] = (0, 0, 0, 0)
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return img


def alpha_bounds(img, thr=0):
    alpha = img.getchannel('A')
    if thr > 0:
        alpha = alpha.point(lambda a: 255 if a > thr else 0)
    return alpha.getbbox()


def trim(img, pad=0, thr=0):
    b = alpha_bounds(img, thr)
    if not b:
        return img
    l, t, r, bt = b
    l = max(0, l - pad)
    t = max(0, t - pad)
    r = min(img.size[0], r + pad)
    bt = min(img.size[1], bt + pad)
    return img.crop((l, t, r, bt))

# -------------------------------------------------------------
# 3. Detection des bandes horizontales (symbole / texte / baseline)
# -------------------------------------------------------------
def row_bands(img):
    w, h = img.size
    alpha = img.getchannel('A')
    empty_thr = max(1, int(w * 0.004))
    bands = []
    start = None
    a = alpha.load()
    for y in range(h):
        count = 0
        for x in range(0, w, 2):  # pas de 2 : suffisant et 4x plus rapide
            if a[x, y] > 8:
                count += 1
                if count >= empty_thr:
                    break
        filled = count >= empty_thr
        if filled and start is None:
            start = y
        elif not filled and start is not None:
            bands.append((start, y))
            start = None
    if start is not None:
        bands.append((start, h))
    return bands


def crop_band_bbox(img, y0, y1):
    region = img.crop((0, y0, img.size[0], y1))
    b = alpha_bounds(region)
    if not b:
        return img.crop((0, y0, img.size[0], y1))
    l, t, r, bt = b
    return img.crop((l, y0 + t, r, y0 + bt))


def find_symbol_split(full):
    """Coupe symbole/texte : ligne la plus vide entre 50% et 82% de hauteur."""
    w, h = full.size
    a = full.getchannel('A').load()
    counts = []
    for y in range(h):
        c = 0
        for x in range(0, w, 2):
            if a[x, y] > 8:
                c += 1
        counts.append(c)
    lo, hi = int(h * 0.50), int(h * 0.82)
    window = counts[lo:hi]
    return lo + window.index(min(window))


def keep_largest_component(img):
    """Garde uniquement la composante connexe opaque la plus grande
    (elimine les fragments du texte coupes par la separation)."""
    from PIL import ImageChops
    w, h = img.size
    px = img.load()
    visited = bytearray(w * h)
    q = deque()
    best_seed, best_count = None, 0
    for sy in range(h):
        base = sy * w
        for sx in range(w):
            i0 = base + sx
            if visited[i0] or px[sx, sy][3] <= 8:
                continue
            count = 0
            visited[i0] = 1
            q.append((sx, sy))
            while q:
                x, y = q.popleft()
                count += 1
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not visited[j] and px[nx, ny][3] > 8:
                            visited[j] = 1
                            q.append((nx, ny))
            if count > best_count:
                best_count, best_seed = count, (sx, sy)
    if best_seed is None:
        return img
    mask = Image.new('L', (w, h), 0)
    mp = mask.load()
    q.append(best_seed)
    mp[best_seed[0], best_seed[1]] = 255
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h:
                if mp[nx, ny] == 0 and px[nx, ny][3] > 8:
                    mp[nx, ny] = 255
                    q.append((nx, ny))
    out = img.copy()
    out.putalpha(ImageChops.multiply(img.getchannel('A'), mask))
    return out


def keep_main_components(img, min_ratio=0.03):
    """Supprime les debris isoles : garde les composantes connexes
    d'au moins min_ratio du plus gros bloc (croix + feuille)."""
    w, h = img.size
    px = img.load()
    visited = bytearray(w * h)
    comps = []
    for sy in range(h):
        base = sy * w
        for sx in range(w):
            i0 = base + sx
            if visited[i0] or px[sx, sy][3] <= 8:
                continue
            visited[i0] = 1
            q = deque([(sx, sy)])
            pixels = []
            while q:
                x, y = q.popleft()
                pixels.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not visited[j] and px[nx, ny][3] > 8:
                            visited[j] = 1
                            q.append((nx, ny))
            comps.append(pixels)
    if not comps:
        return img
    biggest = max(len(c) for c in comps)
    thr = biggest * min_ratio
    removed = 0
    for c in comps:
        if len(c) < thr:
            removed += 1
            for x, y in c:
                px[x, y] = (0, 0, 0, 0)
    print('  composantes:', len(comps), '| supprimees:', removed)
    return img


# -------------------------------------------------------------
# 4. Plaques de fond (icone app / favicon)
# -------------------------------------------------------------
def plate(size, rounded=None):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(1, size - 1)
        c = tuple(int(PLATE_TOP[i] + (PLATE_BOTTOM[i] - PLATE_TOP[i]) * t)
                  for i in range(3))
        d.line([(0, y), (size, y)], fill=c + (255,))
    if rounded is not None:
        mask = Image.new('L', (size, size), 0)
        md = ImageDraw.Draw(mask)
        md.rounded_rectangle([0, 0, size - 1, size - 1], radius=rounded, fill=255)
        base = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        img = Image.composite(img, base, mask)
    return img


def on_plate(symbol, size, fill_ratio=0.82, rounded=None):
    canvas = plate(size, rounded=rounded)
    s = int(size * fill_ratio)
    sym = symbol.resize((s, s), Image.LANCZOS)
    off = (size - s) // 2
    canvas.alpha_composite(sym, (off, off))
    return canvas


def square_padded(img, size=1024, fill_ratio=0.94):
    """Centre le symbole dans un carre transparent (sans deformation)."""
    w, h = img.size
    scale = (size * fill_ratio) / max(w, h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    sym = img.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(sym, ((size - nw) // 2, (size - nh) // 2))
    return canvas


def save(img, path, *args, **kw):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, *args, **kw)
    print('  ', os.path.relpath(path, ROOT), img.size, os.path.getsize(path))

def main():
    print('[1/6] Import du logo officiel...')
    src = import_source()
    print('  source', src.size)

    print('[2/6] Transparence du fond + recadrage propre...')
    clean = remove_background(src.copy())
    full = trim(clean)
    print('  full trim', full.size)

    split = find_symbol_split(full)
    print('  separation symbole/texte a y =', split, '/', full.size[1])
    band = full.crop((0, 0, full.size[0], split))
    band = keep_main_components(band)
    # zero les pixels quasi-transparents (halos) puis recadrage strict
    r, g, b, a = band.split()
    a = a.point(lambda v: 0 if v <= 8 else v)
    band = Image.merge('RGBA', (r, g, b, a))
    symbol = trim(band)
    print('  symbole', symbol.size)

    print('[3/6] Variantes assets/branding/ ...')
    f = full
    if f.size[0] > 1400:
        f = f.resize((1400, int(full.size[1] * 1400 / full.size[0])), Image.LANCZOS)
    save(f, os.path.join(BRANDING, 'pharma-logo-full.png'), optimize=True)
    save(f, os.path.join(BRANDING, 'pharma-logo-full.webp'), 'WEBP', quality=92)
    save(f.copy(), os.path.join(BRANDING, 'pharma-logo-dark.png'), optimize=True)

    # Variante "light" : plaque foncee pour fonds clairs
    lw = 1200
    lf = f.resize((lw, int(f.size[1] * lw / f.size[0])), Image.LANCZOS)
    m = 46
    pw_, ph_ = lf.size
    tile = plate(1024).resize((pw_ + 2 * m, ph_ + 2 * m), Image.LANCZOS)
    light = Image.alpha_composite(
        Image.new('RGBA', tile.size, (0, 0, 0, 0)), tile)
    light.alpha_composite(lf, (m, m))
    save(light, os.path.join(BRANDING, 'pharma-logo-light.png'), optimize=True)

    mw = 640
    mfull = full.resize((mw, int(full.size[1] * mw / full.size[0])), Image.LANCZOS)
    save(mfull, os.path.join(BRANDING, 'pharma-logo-mobile.png'), optimize=True)

    icon = square_padded(symbol, 1024)
    save(icon, os.path.join(BRANDING, 'pharma-logo-icon.png'), optimize=True)
    icon512 = square_padded(symbol, 512)
    save(icon512, os.path.join(BRANDING, 'pharma-logo-icon-512.png'), optimize=True)
    save(icon512, os.path.join(BRANDING, 'pharma-logo-icon-512.webp'), 'WEBP', quality=92)

    print('[4/6] Favicons + icones PWA...')
    for s in (16, 32, 48):
        save(on_plate(symbol, s, fill_ratio=0.92),
             os.path.join(BRANDING, f'pharma-favicon-{s}.png'))
    save(on_plate(symbol, 180, fill_ratio=0.84),
         os.path.join(BRANDING, 'pharma-app-icon-180.png'))
    for s in (192, 512):
        save(on_plate(symbol, s, fill_ratio=0.84),
             os.path.join(BRANDING, f'pharma-app-icon-{s}.png'))

    save(on_plate(symbol, 64, fill_ratio=0.92), os.path.join(WEB, 'favicon.png'))
    save(on_plate(symbol, 180, fill_ratio=0.84),
         os.path.join(WEB, 'icons', 'Icon-180.png'))  # apple-touch-icon iOS
    for s in (192, 512):
        save(on_plate(symbol, s, fill_ratio=0.84),
             os.path.join(WEB, 'icons', f'Icon-{s}.png'))
        save(on_plate(symbol, s, fill_ratio=0.70),
             os.path.join(WEB, 'icons', f'Icon-maskable-{s}.png'))

    # favicon.svg : icone 64px embarquee en base64 (aucun logo redessine)
    tmp = os.path.join(ROOT, '.tmp_favicon64.png')
    on_plate(symbol, 64, fill_ratio=0.92).save(tmp)
    b64 = base64.b64encode(open(tmp, 'rb').read()).decode()
    os.remove(tmp)
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">'
           '<defs><clipPath id="r"><rect width="64" height="64" rx="14"/></clipPath></defs>'
           '<g clip-path="url(#r)">'
           f'<image width="64" height="64" href="data:image/png;base64,{b64}"/>'
           '</g></svg>')
    with open(os.path.join(WEB, 'favicon.svg'), 'w', encoding='utf-8') as fh:
        fh.write(svg)
    print('   web/favicon.svg', len(svg), 'octets')

    print('[5/6] Icone Windows (app_icon.ico)...')
    win = os.path.join(ROOT, 'windows', 'runner', 'resources')
    os.makedirs(win, exist_ok=True)
    ico_base = on_plate(symbol, 256, fill_ratio=0.88)
    ico_base.save(os.path.join(win, 'app_icon.ico'), format='ICO',
                  sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    print('   app_icon.ico', os.path.getsize(os.path.join(win, 'app_icon.ico')))

    print('[6/6] OK.')
    fw, fh2 = full.size
    sw, sh = symbol.size
    print(f'ASPECT_FULL={fw / fh2:.4f}')
    print(f'ASPECT_ICON={sw / sh:.4f}')


if __name__ == '__main__':
    main()


