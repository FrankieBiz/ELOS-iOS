"""Generate ELOS PNG icons using PIL — no SVG renderer required."""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import math, struct, zlib, os

OUT = Path(__file__).parent

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(3))

def linear_gradient(size, c1, c2, angle_deg=135):
    """Diagonal linear gradient via numpy-free approach."""
    img = Image.new('RGB', (size, size), c1)
    px = img.load()
    a = math.radians(angle_deg)
    dx, dy = math.cos(a), math.sin(a)
    diag = abs(size*dx) + abs(size*dy)
    for y in range(size):
        for x in range(size):
            t = ((x*dx) + (y*dy)) / diag
            t = max(0.0, min(1.0, t))
            px[x, y] = lerp(c1, c2, t)
    return img

def draw_icon(size, maskable=False):
    bg1 = (10, 10, 10)
    bg2 = (31, 31, 35)
    accent1 = (255, 122, 89)
    accent2 = (255, 77, 122)
    track = (42, 42, 46)
    text = (250, 250, 250)

    # Squircle vs full bleed (maskable)
    img = Image.new('RGBA', (size, size), (0,0,0,0))
    bg = linear_gradient(size, bg1, bg2, 135).convert('RGBA')

    if maskable:
        # Fill the safe zone fully — required for maskable icons.
        img.paste(bg, (0,0))
    else:
        # Squircle / rounded square mask (radius ~22% of side, like iOS)
        mask = Image.new('L', (size, size), 0)
        md = ImageDraw.Draw(mask)
        r = int(size * 0.22)
        md.rounded_rectangle((0, 0, size-1, size-1), radius=r, fill=255)
        img.paste(bg, (0,0), mask=mask)

    draw = ImageDraw.Draw(img)

    # Inset (maskable needs 20% safe area inside the icon)
    inset = int(size * 0.20) if maskable else int(size * 0.18)
    cx = cy = size // 2
    ring_r = (size - inset*2) // 2 - int(size*0.02)
    stroke = max(6, int(size * 0.045))

    # Track ring
    bbox = (cx-ring_r, cy-ring_r, cx+ring_r, cy+ring_r)
    draw.ellipse(bbox, outline=track, width=stroke)

    # Accent arc (top-right ~ from -90° to 90°, gradient approx)
    # PIL doesn't gradient-stroke directly; draw colored segments.
    steps = 90
    start = -90
    sweep = 180
    for i in range(steps):
        t = i / max(1, steps-1)
        col = lerp(accent1, accent2, t)
        a0 = start + (sweep * i / steps)
        a1 = start + (sweep * (i+1) / steps) + 0.5
        draw.arc(bbox, a0, a1, fill=col, width=stroke)

    # Letter "E"
    font_size = int(size * 0.46)
    font = None
    for fname in ('seguisb.ttf','segoeuib.ttf','arialbd.ttf','Arial Bold.ttf','Helvetica.ttc','arial.ttf'):
        try:
            font = ImageFont.truetype(fname, font_size)
            break
        except Exception:
            continue
    if font is None:
        font = ImageFont.load_default()

    txt = 'E'
    bb = draw.textbbox((0,0), txt, font=font)
    tw, th = bb[2]-bb[0], bb[3]-bb[1]
    tx = (size - tw) // 2 - bb[0]
    ty = (size - th) // 2 - bb[1] - int(size*0.01)
    draw.text((tx, ty), txt, font=font, fill=text)

    return img

def to_ico(img, path):
    sizes = [(16,16),(32,32),(48,48)]
    img.save(path, format='ICO', sizes=sizes)

def main():
    OUT.mkdir(exist_ok=True)
    for size in (192, 512):
        i = draw_icon(size, maskable=False)
        i.save(OUT / f'icon-{size}.png', optimize=True)
    # Maskable variant — full bleed, safe area respected
    m = draw_icon(512, maskable=True)
    m.save(OUT / 'icon-maskable.png', optimize=True)
    # Apple touch icon (180x180)
    a = draw_icon(180, maskable=False)
    a.save(OUT / 'apple-touch-icon.png', optimize=True)
    # Favicon (multi-size ICO)
    f = draw_icon(64, maskable=False)
    to_ico(f, OUT / 'favicon.ico')
    # 32px PNG favicon for modern browsers
    f32 = draw_icon(32, maskable=False)
    f32.save(OUT / 'favicon-32.png', optimize=True)
    # Splash backgrounds (one solid colour) — iOS uses the apple-touch-icon for splash
    print('done', sorted(p.name for p in OUT.iterdir()))

if __name__ == '__main__':
    main()
