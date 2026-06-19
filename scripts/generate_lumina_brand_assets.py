#!/usr/bin/env python3
"""Generate Lumina Focus app icon and launch screen assets (rose / lavender feminine palette)."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Hub" / "Assets.xcassets"

# Matches Hub/Design/LuminaTheme.swift
PRIMARY = (196, 92, 138)            # #C45C8A
PRIMARY_DEEP = (168, 72, 120)       # gradient end
PRIMARY_CONTAINER = (232, 164, 196) # #E8A4C4
PRIMARY_LIGHT = (245, 213, 232)     # #F5D5E8
LAVENDER = (184, 152, 216)        # accent glow
SURFACE = (251, 247, 249)           # #FBF7F9
SURFACE_TOP = (255, 245, 248)       # gradient top
ON_SURFACE = (61, 47, 56)          # #3D2F38
ON_SURFACE_VARIANT = (122, 101, 112)  # #7A6570

# iPhone 15 logical size (pt)
LAUNCH_WIDTH = 393
LAUNCH_HEIGHT = 852


def lerp_color(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_vertical_gradient(width: int, height: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", (width, height))
    pixels = img.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        color = lerp_color(top, bottom, t)
        for x in range(width):
            pixels[x, y] = color
    return img


def draw_diagonal_gradient(size: int, c1: tuple[int, int, int], c2: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", (size, size))
    pixels = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * max(size - 1, 1))
            pixels[x, y] = lerp_color(c1, c2, min(1.0, t))
    return img


def add_soft_glow(base: Image.Image, center: tuple[float, float], radius: float, color: tuple[int, int, int, int]) -> Image.Image:
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    for scale, alpha in [(1.5, 14), (1.2, 24), (0.9, 38)]:
        r = radius * scale
        bbox = (center[0] - r, center[1] - r, center[0] + r, center[1] + r)
        gdraw.ellipse(bbox, fill=(color[0], color[1], color[2], alpha))
    return Image.alpha_composite(base.convert("RGBA"), glow)


def create_app_icon(size: int = 1024) -> Image.Image:
    img = draw_diagonal_gradient(size, PRIMARY, PRIMARY_DEEP).convert("RGBA")
    center = (size / 2, size / 2 - size * 0.02)
    base_radius = size * 0.30

    img = add_soft_glow(img, center, base_radius * 0.6, PRIMARY_LIGHT)
    img = add_soft_glow(img, (center[0] + size * 0.08, center[1] - size * 0.06), base_radius * 0.35, LAVENDER)

    draw = ImageDraw.Draw(img)
    for i in range(3):
        opacity = int(255 * (0.94 - i * 0.16))
        radius = base_radius * (1.0 - i * 0.24)
        bbox = (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius)
        draw.ellipse(bbox, outline=(255, 255, 255, opacity), width=int(size * 0.026))

    dot_r = size * 0.052
    dot_bbox = (center[0] - dot_r, center[1] - dot_r, center[0] + dot_r, center[1] + dot_r)
    draw.ellipse(dot_bbox, fill=(255, 255, 255, 255))

    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(highlight)
    hdraw.ellipse(
        (size * 0.08, size * 0.02, size * 0.92, size * 0.55),
        fill=(255, 255, 255, 28),
    )
    img = Image.alpha_composite(img, highlight)
    return img


def apply_icon_mask(img: Image.Image) -> Image.Image:
    size = img.width
    radius = int(size * 0.22)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img.convert("RGBA"), (0, 0), mask)
    return out


def create_app_mark(size: int = 512) -> Image.Image:
    return apply_icon_mask(create_app_icon(size))


def write_square_imageset(folder: Path, base_name: str, image: Image.Image, scales: list[int]) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    entries: list[dict] = []
    for scale in scales:
        suffix = "" if scale == 1 else f"@{scale}x"
        filename = f"{base_name}{suffix}.png"
        side = image.width * scale
        scaled = image.resize((side, side), Image.Resampling.LANCZOS)
        scaled.save(folder / filename, optimize=True)
        entries.append({"filename": filename, "idiom": "universal", "scale": f"{scale}x"})

    contents = {"images": entries, "info": {"author": "xcode", "version": 1}}
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


def create_launch_bitmap(width: int, height: int) -> Image.Image:
    """Full launch screen bitmap: warm gradient + app icon + title (baked in for iOS launch screen)."""
    launch = draw_vertical_gradient(width, height, SURFACE_TOP, SURFACE).convert("RGBA")

    icon_side = int(min(width, height) * 0.32)
    mark = create_app_mark(icon_side)
    lx = (width - mark.width) // 2
    ly = int(height * 0.34)
    launch.paste(mark, (lx, ly), mark)

    draw = ImageDraw.Draw(launch)
    try:
        from PIL import ImageFont
        title_font = ImageFont.truetype("/System/Library/Fonts/SFNSRounded.ttf", max(22, int(height * 0.028)))
        subtitle_font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", max(15, int(height * 0.018)))
    except (OSError, ImportError):
        from PIL import ImageFont
        title_font = ImageFont.load_default()
        subtitle_font = title_font

    title = "Lumina Focus"
    title_bbox = draw.textbbox((0, 0), title, font=title_font)
    title_w = title_bbox[2] - title_bbox[0]
    title_y = ly + mark.height + int(height * 0.032)
    draw.text(((width - title_w) / 2, title_y), title, fill=ON_SURFACE, font=title_font)

    subtitle = "Focus made clear"
    sub_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    sub_w = sub_bbox[2] - sub_bbox[0]
    draw.text(((width - sub_w) / 2, title_y + int(height * 0.042)), subtitle, fill=ON_SURFACE_VARIANT, font=subtitle_font)

    return launch.convert("RGB")


def write_launch_imageset(folder: Path, base_name: str, scales: list[int]) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    entries: list[dict] = []
    for scale in scales:
        suffix = "" if scale == 1 else f"@{scale}x"
        filename = f"{base_name}{suffix}.png"
        w = LAUNCH_WIDTH * scale
        h = LAUNCH_HEIGHT * scale
        create_launch_bitmap(w, h).save(folder / filename, optimize=True)
        entries.append({"filename": filename, "idiom": "universal", "scale": f"{scale}x"})

    contents = {"images": entries, "info": {"author": "xcode", "version": 1}}
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    icon = create_app_icon(1024)
    icon_path = ASSETS / "AppIcon.appiconset" / "icon.png"
    icon.convert("RGB").save(icon_path, optimize=True)

    mark = create_app_mark(192)
    write_square_imageset(ASSETS / "LuminaFocusLaunchMark.imageset", "LuminaFocusLaunchMark", mark, scales=[1, 2, 3])

    print(f"Wrote {icon_path}")
    print(f"Wrote {ASSETS / 'LuminaFocusLaunchMark.imageset'}")


if __name__ == "__main__":
    main()
