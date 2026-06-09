#!/usr/bin/env python3
"""Generate Lumina Focus app icon and launch mark assets."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Hub" / "Assets.xcassets"

PRIMARY = (0, 93, 167)       # #005DA7
PRIMARY_CONTAINER = (41, 118, 199)  # #2976C7
PRIMARY_LIGHT = (164, 201, 255)     # #A4C9FF
SURFACE = (248, 249, 250)           # #F8F9FA
ON_SURFACE = (25, 28, 29)           # #191C1D


def lerp_color(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_vertical_gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", (size, size))
    pixels = img.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        color = lerp_color(top, bottom, t)
        for x in range(size):
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


def draw_focus_rings(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    base_radius: float,
    ring_color: tuple[int, int, int, int],
    ring_width: float,
    ring_count: int = 3,
    gap: float = 0.22,
) -> None:
    for i in range(ring_count):
        radius = base_radius * (1.0 - i * gap)
        bbox = (
            center[0] - radius,
            center[1] - radius,
            center[0] + radius,
            center[1] + radius,
        )
        draw.ellipse(bbox, outline=ring_color, width=int(max(1, ring_width * (1.0 - i * 0.08))))


def add_soft_glow(base: Image.Image, center: tuple[float, float], radius: float, color: tuple[int, int, int, int]) -> Image.Image:
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    for scale, alpha in [(1.4, 18), (1.1, 28), (0.85, 40)]:
        r = radius * scale
        bbox = (center[0] - r, center[1] - r, center[0] + r, center[1] + r)
        gdraw.ellipse(bbox, fill=(color[0], color[1], color[2], alpha))
    return Image.alpha_composite(base.convert("RGBA"), glow)


def create_app_icon(size: int = 1024) -> Image.Image:
    img = draw_diagonal_gradient(size, PRIMARY, PRIMARY_CONTAINER).convert("RGBA")
    center = (size / 2, size / 2 - size * 0.02)
    base_radius = size * 0.30

    img = add_soft_glow(img, center, base_radius * 0.55, (212, 227, 255))

    draw = ImageDraw.Draw(img)
    for i in range(3):
        opacity = int(255 * (0.92 - i * 0.18))
        draw_focus_rings(
            draw,
            center,
            base_radius,
            (255, 255, 255, opacity),
            ring_width=size * 0.028,
            ring_count=1,
            gap=0.24 * (i + 1),
        )
        radius = base_radius * (1.0 - i * 0.24)
        bbox = (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius)
        draw.ellipse(bbox, outline=(255, 255, 255, opacity), width=int(size * 0.028))

    dot_r = size * 0.055
    dot_bbox = (center[0] - dot_r, center[1] - dot_r, center[0] + dot_r, center[1] + dot_r)
    draw.ellipse(dot_bbox, fill=(255, 255, 255, 255))

    # Subtle top highlight
    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(highlight)
    hdraw.ellipse(
        (size * 0.08, size * 0.02, size * 0.92, size * 0.55),
        fill=(255, 255, 255, 22),
    )
    img = Image.alpha_composite(img, highlight)
    return img


def create_app_mark(size: int = 512, for_light_bg: bool = True) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    center = (size / 2, size / 2)
    base_radius = size * 0.34

    if for_light_bg:
        ring_rgb = PRIMARY
        dot_rgb = PRIMARY
        glow_rgb = PRIMARY_LIGHT
    else:
        ring_rgb = (255, 255, 255)
        dot_rgb = (255, 255, 255)
        glow_rgb = (212, 227, 255)

    img = add_soft_glow(img, center, base_radius * 0.5, glow_rgb)

    draw = ImageDraw.Draw(img)
    for i in range(3):
        opacity = int(255 * (0.95 - i * 0.15))
        radius = base_radius * (1.0 - i * 0.24)
        bbox = (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius)
        draw.ellipse(
            bbox,
            outline=(ring_rgb[0], ring_rgb[1], ring_rgb[2], opacity),
            width=int(max(2, size * 0.032)),
        )

    dot_r = size * 0.058
    dot_bbox = (center[0] - dot_r, center[1] - dot_r, center[0] + dot_r, center[1] + dot_r)
    draw.ellipse(dot_bbox, fill=(dot_rgb[0], dot_rgb[1], dot_rgb[2], 255))
    return img


def write_imageset(folder: Path, base_name: str, image: Image.Image, scales: list[int]) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    entries: list[dict] = []
    for scale in scales:
        suffix = "" if scale == 1 else f"@{scale}x"
        filename = f"{base_name}{suffix}.png"
        scaled = image.resize((image.width * scale, image.height * scale), Image.Resampling.LANCZOS)
        if scaled.mode == "RGBA":
            scaled.save(folder / filename, optimize=True)
        else:
            scaled.convert("RGB").save(folder / filename, optimize=True)
        entries.append(
            {
                "filename": filename,
                "idiom": "universal",
                "scale": f"{scale}x",
            }
        )

    import json

    contents = {"images": entries, "info": {"author": "xcode", "version": 1}}
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    icon = create_app_icon(1024)
    icon_path = ASSETS / "AppIcon.appiconset" / "icon.png"
    icon.convert("RGB").save(icon_path, optimize=True)

    mark = create_app_mark(128)
    write_imageset(ASSETS / "LuminaAppMark.imageset", "LuminaAppMark", mark, scales=[1, 2, 3])

    # Legacy Rahmi launch image — replace with Lumina splash still for any storyboard fallbacks
    launch = Image.new("RGB", (1170, 2532), SURFACE)
    mark_large = create_app_mark(220)
    lx = (launch.width - mark_large.width) // 2
    ly = int(launch.height * 0.38)
    launch.paste(mark_large, (lx, ly), mark_large)

    title_draw = ImageDraw.Draw(launch)
    title = "Lumina Focus"
    font_size = 42
    # Pillow default font — approximate centering via textbbox
    bbox = title_draw.textbbox((0, 0), title)
    tw = bbox[2] - bbox[0]
    title_draw.text(
        ((launch.width - tw) / 2, ly + mark_large.height + 36),
        title,
        fill=ON_SURFACE,
    )

    launch_path = ASSETS / "LaunchScreen.imageset" / "LaunchScreen.png"
    launch.save(launch_path, optimize=True)

    print(f"Wrote {icon_path}")
    print(f"Wrote {ASSETS / 'LuminaAppMark.imageset'}")
    print(f"Wrote {launch_path}")


if __name__ == "__main__":
    main()
