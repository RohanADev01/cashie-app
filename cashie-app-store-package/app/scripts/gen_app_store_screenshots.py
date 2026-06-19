#!/usr/bin/env python3
"""Generate App Store marketing screenshots for Cashie.

Composites the REAL in-app captures (screenshots/app/*.png) onto branded,
"selling" marketing frames: a feature headline up top, a subheading, and the
real screenshot with rounded corners + soft shadow on a Cashie-cream background
with a soft green accent glow.

Outputs the Apple baseline device classes (Apple auto-scales down):
  - iPhone 6.9 inch : 1320 x 2868  (covers 6.9 + 6.5 + smaller)
  - iPad 13 inch    : 2064 x 2752

Saved as 24-bit PNG, no transparency, well under 8 MB each.

Usage:  python3 scripts/gen_app_store_screenshots.py
Requires Pillow:  pip3 install --user Pillow
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
# Fresh in-app captures, per device class. iPhone shots come from the iPhone 15
# Pro sim; iPad shots are REAL captures from the iPad Pro 13-inch sim (same slide
# filenames in each folder) so the iPad frames show true iPad UI, not a phone.
SRC_DIRS = {
    "iphone_6.9_inch": ROOT / "screenshots" / "landing_2026-06-09",
    "ipad_13_inch": ROOT / "screenshots" / "ipad_2026-06-09",
}
OUT_ROOT = ROOT / "app_store_submission" / "screenshots"

# Brand palette (from Cashie/DesignSystem/Theme.swift)
CREAM = (244, 245, 247)
INK = (17, 17, 17)
INK_SOFT = (92, 95, 99)
GREEN = (4, 186, 116)
AMBER = (241, 189, 58)

# Device targets: (label, width, height)
DEVICES = [
    ("iphone_6.9_inch", 1320, 2868),
    ("ipad_13_inch", 2064, 2752),
]

# Slides: real screen + selling copy. Headline lines are token lists:
# (text, accent?) where accent=True renders in brand green.
SLIDES = [
    {
        "out": "01_today",
        "src": "today.png",
        "head": [[("Know what's", False)], [("safe to spend", True)]],
        "sub": "Cashie does the math, so today always has a number you trust.",
    },
    {
        "out": "02_rank",
        "src": "rank_legendary.png",
        "head": [[("Climb to", False)], [("Legendary", True)]],
        "sub": "Earn XP on every log and rank up from Bronze all the way to Legendary.",
    },
    {
        "out": "03_badges",
        "src": "badges.png",
        "head": [[("Collect every", False)], [("badge", True)]],
        "sub": "49 badges to unlock. Budgeting that actually feels like a game.",
    },
    {
        "out": "04_goals",
        "src": "goals.png",
        "head": [[("Save for what", False)], [("actually matters", True)]],
        "sub": "Turn the things you want into real, funded goals.",
    },
    {
        "out": "05_reveal",
        "src": "reveal.png",
        "head": [[("Meet your money", False)], [("personality", True)]],
        "sub": "A 60-second quiz builds a plan that fits how you really spend.",
    },
    {
        "out": "06_quicklog",
        "src": "trylive.png",
        "head": [[("Log a spend", False)], [("in one tap", True)]],
        "sub": "Open Quick Log, tap the amount, done. The fastest entry in any money app.",
    },
    {
        "out": "07_log_ways",
        "src": "backtap.png",
        "head": [[("Log in", False)], [("2 seconds", True)]],
        "sub": "Double-tap the back of your phone and the spend is logged. No typing, no opening the app.",
    },
]

SF = "/System/Library/Fonts/SFNS.ttf"
ARIAL = {
    "black": "/System/Library/Fonts/Supplemental/Arial Black.ttf",
    "bold": "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "regular": "/System/Library/Fonts/Supplemental/Arial.ttf",
}
SF_NAME = {"black": "Black", "heavy": "Heavy", "bold": "Bold",
           "semibold": "Semibold", "medium": "Medium", "regular": "Regular"}


def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont:
    size = int(size)
    if Path(SF).exists():
        try:
            f = ImageFont.truetype(SF, size)
            try:
                f.set_variation_by_name(SF_NAME.get(weight, "Regular"))
            except Exception:
                pass
            return f
        except Exception:
            pass
    key = "black" if weight in ("black", "heavy") else ("bold" if weight in ("bold", "semibold") else "regular")
    return ImageFont.truetype(ARIAL[key], size)


def text_w(draw, s, f, tracking=0):
    if tracking == 0:
        return draw.textlength(s, font=f)
    return sum(draw.textlength(ch, font=f) for ch in s) + tracking * max(0, len(s) - 1)


def draw_tracked(draw, xy, s, f, fill, tracking):
    x, y = xy
    for ch in s:
        draw.text((x, y), ch, font=f, fill=fill)
        x += draw.textlength(ch, font=f) + tracking


def rounded_mask(size, radius) -> Image.Image:
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def soft_blob(canvas_size, center, radius, color, alpha, blur):
    layer = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = center
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=color + (alpha,))
    return layer.filter(ImageFilter.GaussianBlur(blur))


def wrap(draw, s, f, max_w):
    words, lines, cur = s.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=f) <= max_w:
            cur = t
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def render(slide, src_dir, w, h, out_path):
    img = Image.new("RGB", (w, h), CREAM)
    # Brand accent glows.
    g1 = soft_blob((w, h), (int(w * 0.92), int(h * 0.10)), int(w * 0.42), GREEN, 46, int(w * 0.10))
    g2 = soft_blob((w, h), (int(w * 0.05), int(h * 0.93)), int(w * 0.36), AMBER, 30, int(w * 0.10))
    base = img.convert("RGBA")
    base.alpha_composite(g1)
    base.alpha_composite(g2)
    img = base.convert("RGB")
    draw = ImageDraw.Draw(img)

    side = w * 0.08
    y = h * 0.052

    # Wordmark
    wm_f = font(w * 0.030, "bold")
    wm = "CASHIE"
    tracking = w * 0.012
    wm_w = text_w(draw, wm, wm_f, tracking)
    draw_tracked(draw, ((w - wm_w) / 2, y), wm, wm_f, GREEN, tracking)
    y += w * 0.030 * 1.2 + h * 0.022

    # Headline
    head_f = font(w * 0.080, "black")
    line_h = w * 0.080 * 1.06
    for line in slide["head"]:
        total = sum(text_w(draw, tok, head_f) for tok, _ in line)
        x = (w - total) / 2
        for tok, accent in line:
            draw.text((x, y), tok, font=head_f, fill=(GREEN if accent else INK))
            x += text_w(draw, tok, head_f)
        y += line_h
    y += h * 0.010

    # Subheading
    sub_f = font(w * 0.0325, "medium")
    for ln in wrap(draw, slide["sub"], sub_f, w - 2 * side):
        lw = draw.textlength(ln, font=sub_f)
        draw.text(((w - lw) / 2, y), ln, font=sub_f, fill=INK_SOFT)
        y += w * 0.0325 * 1.32
    y += h * 0.022

    # Screenshot with rounded corners + shadow
    src = Image.open(src_dir / slide["src"]).convert("RGB")
    sw, sh = src.size
    max_w = w * 0.80
    bottom = h * 0.055
    avail_h = (h - bottom) - y
    shot_w = max_w
    shot_h = shot_w * sh / sw
    if shot_h > avail_h:
        shot_h = avail_h
        shot_w = shot_h * sw / sh
    shot_w, shot_h = int(shot_w), int(shot_h)
    shot = src.resize((shot_w, shot_h), Image.LANCZOS)

    radius = int(shot_w * 0.085)
    mask = rounded_mask((shot_w, shot_h), radius)
    shot_rgba = shot.convert("RGBA")
    shot_rgba.putalpha(mask)

    px = int((w - shot_w) / 2)
    py = int(y + (avail_h - shot_h) / 2)

    # Shadow
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    pad = int(shot_w * 0.02)
    sd.rounded_rectangle([px - pad, py - pad + int(shot_w * 0.02),
                          px + shot_w + pad, py + shot_h + pad + int(shot_w * 0.02)],
                         radius=radius + pad, fill=(17, 17, 17, 80))
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(shot_w * 0.05)))
    img_rgba = img.convert("RGBA")
    img_rgba.alpha_composite(shadow)
    img_rgba.alpha_composite(shot_rgba, (px, py))
    img = img_rgba.convert("RGB")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, "PNG", optimize=True)
    return out_path


def main():
    made = 0
    for label, w, h in DEVICES:
        src_dir = SRC_DIRS[label]
        # Clear stale frames so a changed lineup never leaves old files behind.
        out_dir = OUT_ROOT / label
        if out_dir.exists():
            for old in out_dir.glob("*.png"):
                old.unlink()
        for slide in SLIDES:
            if not (src_dir / slide["src"]).exists():
                print(f"  skip (missing {label} source): {slide['src']}")
                continue
            out = out_dir / f"{slide['out']}.png"
            render(slide, src_dir, w, h, out)
            made += 1
            print(f"  wrote {out.relative_to(ROOT)}")
    print(f"Done. {made} screenshots in {OUT_ROOT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
