#!/usr/bin/env python3
"""Generate the flat UI textures used by PeaversCommons/src/UI/Theme.lua.

    python3 scripts/generate_media.py            # write src/Media/Textures/*.tga
    python3 scripts/generate_media.py --check    # verify committed files are current
    python3 scripts/generate_media.py --preview  # PNG contact sheet for eyeballing

Every texture is authored as a WHITE master with all shape information in the
alpha channel, then tinted at runtime with Texture:SetVertexColor. SetVertexColor
multiplies, so a white master is an exact identity and one file serves every
colour in the palette; a coloured master could only ever be darkened, and its
antialiased edge would fringe when tinted.

Two format details the WoW client cares about:

  * TGA must be UNCOMPRESSED. Pillow writes image-type 2 by default; never pass
    a `compression` argument, and always convert to RGBA (saving an RGB image
    silently drops to 24-bit with zero alpha bits).
  * The repo's known-good Icon.tga uses a TOP-LEFT origin (descriptor 0x20)
    while Pillow writes BOTTOM-LEFT (0x08). We flip and patch the descriptor to
    match the file that is already proven to load. Shapes here are additionally
    vertically symmetric where possible, so orientation is unobservable anyway.

Pillow's ImageDraw has no antialiasing, so shapes are drawn into an 8x "L" mask
and downsampled with LANCZOS. Note a 1px outline must be drawn at width=SS in
supersampled space; drawing width=1 then downsampling yields a line that vanishes.

Deterministic: same input, byte-identical output, so --check works in CI.
"""

from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:  # pragma: no cover
    sys.exit("Pillow is required: python3 -m pip install Pillow")

OUT = Path(__file__).resolve().parent.parent / "src" / "Media" / "Textures"
SS = 8  # supersampling factor


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #

def _mask_to_rgba(mask: Image.Image) -> Image.Image:
    """White RGB everywhere, shape in alpha only — prevents AA fringing on tint."""
    white = Image.new("L", mask.size, 255)
    return Image.merge("RGBA", (white, white, white, mask))


def _draw_ss(size: int, fn) -> Image.Image:
    """Draw into an 8x 'L' mask via fn(draw, scale), then downsample."""
    big = Image.new("L", (size * SS, size * SS), 0)
    fn(ImageDraw.Draw(big), SS)
    return big.resize((size, size), Image.LANCZOS)


def _save_tga(img: Image.Image, name: str, out_dir: Path) -> Path:
    path = out_dir / name
    # Flip, then stamp descriptor byte 17 = 0x28 (top-left origin | 8 alpha bits)
    # so the on-disk convention matches the repo's known-good Icon.tga.
    img.convert("RGBA").transpose(Image.FLIP_TOP_BOTTOM).save(path, format="TGA")
    with open(path, "r+b") as fh:
        fh.seek(17)
        fh.write(bytes([0x28]))
    return path


# --------------------------------------------------------------------------- #
# textures
# --------------------------------------------------------------------------- #

def make_check(size: int = 16) -> Image.Image:
    """Flat checkmark. Replaces Blizzard's UI-CheckBox-Check, whose baked-in
    bevel and glow go muddy when tinted onto a flat fill."""
    def draw(d, s):
        pts = [(3.0 * s, 8.4 * s), (6.4 * s, 11.8 * s), (13.0 * s, 4.6 * s)]
        d.line(pts, fill=255, width=int(1.9 * s), joint="curve")
        # Round the stroke ends so the mark reads as drawn, not clipped.
        r = 0.95 * s
        for x, y in (pts[0], pts[2]):
            d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return _mask_to_rgba(_draw_ss(size, draw))


def make_circle(size: int = 64) -> Image.Image:
    """Antialiased disc — active dots, pills, status indicators."""
    def draw(d, s):
        d.ellipse([0, 0, size * s - 1, size * s - 1], fill=255)
    return _mask_to_rgba(_draw_ss(size, draw))


def make_rounded_fill(size: int = 32, radius: int = 8) -> Image.Image:
    """Solid rounded rect for 9-slice fills via SetTextureSliceMargins."""
    def draw(d, s):
        d.rounded_rectangle([0, 0, size * s - 1, size * s - 1],
                            radius=radius * s, fill=255)
    return _mask_to_rgba(_draw_ss(size, draw))


def make_rounded_border(size: int = 32, radius: int = 8) -> Image.Image:
    """1px rounded outline, transparent interior — the hairline system."""
    def draw(d, s):
        d.rounded_rectangle([0, 0, size * s - 1, size * s - 1],
                            radius=radius * s, outline=255, width=s)
    return _mask_to_rgba(_draw_ss(size, draw))


def make_shadow(size: int = 64, radius: int = 16, blur: int = 6) -> Image.Image:
    """Soft drop shadow, tinted black at low alpha for lifted surfaces.

    The centre is fully opaque, which is fine only because the surfaces drawn
    over it are opaque. A translucent fill would darken through it.
    """
    inset = blur * 2
    big = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        [inset * SS, inset * SS, (size - inset) * SS - 1, (size - inset) * SS - 1],
        radius=radius * SS, fill=255)
    small = big.resize((size, size), Image.LANCZOS)
    return _mask_to_rgba(small.filter(ImageFilter.GaussianBlur(blur)))


# Small controls (checkboxes, chips) need a tighter radius: slicing the 8px
# master onto an 18px box would make 16 of its 18 pixels corner, rendering a
# near-circle rather than a rounded square.
def make_rounded_fill4() -> Image.Image:
    return make_rounded_fill(size=16, radius=4)


def make_rounded_border4() -> Image.Image:
    return make_rounded_border(size=16, radius=4)


def make_bar_flat(width: int = 32, height: int = 32) -> Image.Image:
    """The collection's default status bar fill: solid, opaque, pure white.

    White matters more here than anywhere else in this file. SetStatusBarColor
    multiplies, so a white master returns exactly the colour an addon asks for -
    a class colour is the class colour, and a health bar at 40% red is the red
    that was specified. Every grey or gradient bar texture in circulation
    silently darkens and desaturates whatever it is given, which is why the same
    class colour looks different in two addons using two textures.

    32x32 rather than 1x1: the client stretches a status bar texture across the
    bar, and a single-pixel master picks up filtering artefacts at the ends on
    some drivers.
    """
    return Image.new("RGBA", (width, height), (255, 255, 255, 255))


def make_bar_matte(width: int = 256, height: int = 64) -> Image.Image:
    """Flat, with a fine grain so the fill reads as a surface rather than a slab.

    Our own, drawn here, rather than copied from any of the matte textures in
    circulation - the look is a mid-grey field with light noise, which is a
    recipe rather than an authored image, and generating it avoids inheriting
    somebody else's licence along with it.

    Two deliberate differences from the textures this imitates:

      * The base is white, not mid-grey. Those sit around 0.63 brightness, so
        they mute every colour put through them by more than a third. Here the
        grain dips below white instead of the whole field sitting below it, so
        the bar has texture without the colour being wrong.
      * The grain is monochrome and applied to RGB, not alpha. In alpha it would
        make the bar faintly see-through in patches, and whatever is behind the
        bar would show through the pattern as it moved.

    Deterministic by construction - a fixed LCG rather than `random` - because
    --check compares bytes and a reseeded generator would make every run differ.
    """
    img = Image.new("RGBA", (width, height))
    px = img.load()

    # Numerical Recipes LCG. Any fixed generator would do; this one is short,
    # has no imports, and gives the same stream on every Python version.
    state = 20260906
    for y in range(height):
        for x in range(width):
            state = (1664525 * state + 1013904223) & 0xFFFFFFFF
            # Top 8 bits are the well-behaved ones in an LCG; the low bits have
            # very short periods and would band visibly.
            grain = (state >> 24) & 0xFF
            value = 255 - (grain * 22 // 255)   # 233..255
            px[x, y] = (value, value, value, 255)

    return img


TEXTURES = {
    "BarFlat.tga": make_bar_flat,
    "BarMatte.tga": make_bar_matte,
    "Check16.tga": make_check,
    "RoundedFill4.tga": make_rounded_fill4,
    "RoundedBorder4.tga": make_rounded_border4,
    "Circle64.tga": make_circle,
    "RoundedFill8.tga": make_rounded_fill,
    "RoundedBorder8.tga": make_rounded_border,
    "Shadow64.tga": make_shadow,
}


# --------------------------------------------------------------------------- #

def generate(out_dir: Path) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    return [_save_tga(fn(), name, out_dir) for name, fn in sorted(TEXTURES.items())]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true",
                    help="fail if committed textures differ from freshly generated")
    ap.add_argument("--preview", action="store_true",
                    help="write scripts/_preview.png (dev only, not shipped)")
    args = ap.parse_args()

    if args.check:
        with tempfile.TemporaryDirectory() as tmp:
            drift = []
            for path in generate(Path(tmp)):
                committed = OUT / path.name
                if not committed.exists():
                    drift.append(f"{path.name}: missing")
                elif committed.read_bytes() != path.read_bytes():
                    drift.append(f"{path.name}: differs")
        if drift:
            print("Textures are out of date:\n  " + "\n  ".join(drift))
            return 1
        print(f"All {len(TEXTURES)} textures up to date.")
        return 0

    paths = generate(OUT)
    for p in paths:
        print(f"  {p.name:<22} {p.stat().st_size:>6} bytes")

    if args.preview:
        # Checkerboard so alpha is visible, with each master tinted indigo.
        cell, pad = 96, 8
        sheet = Image.new("RGBA", (cell * len(paths) + pad * (len(paths) + 1), cell + pad * 2))
        for i in range(sheet.width):
            for j in range(sheet.height):
                v = 40 if ((i // 8) + (j // 8)) % 2 else 60
                sheet.putpixel((i, j), (v, v, v, 255))
        for i, name in enumerate(sorted(TEXTURES)):
            src = Image.open(OUT / name).convert("RGBA").resize((cell, cell), Image.NEAREST)
            tint = Image.new("RGBA", src.size, (129, 140, 248, 255))
            tint.putalpha(src.getchannel("A"))
            sheet.alpha_composite(tint, (pad + i * (cell + pad), pad))
        preview = Path(__file__).resolve().parent / "_preview.png"
        sheet.save(preview)
        print(f"  preview -> {preview}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
