"""Render the Resona icon, launcher mipmaps, and README banner.

This is a one-shot design tool, not a runtime dependency. It needs Pillow:

    python scripts/generate_brand_assets.py

The mark is a seven-bar resonance waveform: the visual language already used
by the Resona desktop app, re-graded for the Daylight palette. The tiny in-app
mark uses a simplified five-bar cut so it stays crisp at 20-22 px.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
ASSET_ICONS = ROOT / "assets" / "icons"
BRAND_DIR = ROOT / "docs" / "brand"

INK = (11, 13, 16, 255)
INK_TOP = (32, 36, 43, 255)
INK_BOTTOM = (10, 12, 15, 255)
GREEN_TOP = (140, 247, 168)
GREEN_MID = (46, 224, 106)
GREEN_BOTTOM = (11, 158, 69)
RIM = (255, 255, 255, 22)

# Seven-bar resonance waveform, centre bar tallest.
BAR_HEIGHTS = (0.34, 0.50, 0.70, 1.0, 0.70, 0.50, 0.34)


def _vertical_gradient(size: tuple[int, int], stops: list[tuple[float, tuple[int, int, int]]]) -> Image.Image:
    """Return a vertical RGB gradient with the given (position, colour) stops."""
    width, height = size
    column = Image.new("RGB", (1, height))
    pixels = column.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        for index, (position, colour) in enumerate(stops):
            if t <= position or index == len(stops) - 1:
                previous_position, previous_colour = (
                    stops[index - 1] if index else (0.0, colour)
                )
                span = max(position - previous_position, 1e-6)
                local = min(max((t - previous_position) / span, 0.0), 1.0)
                mixed = tuple(
                    round(previous_colour[channel] + (colour[channel] - previous_colour[channel]) * local)
                    for channel in range(3)
                )
                pixels[0, y] = mixed
                break
    return column.resize((width, height), Image.Resampling.BILINEAR)


def _rounded_mask(size: int, box: tuple[int, int, int, int], radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


def _waveform_mask(
    size: int,
    *,
    bar_width: int,
    gap: int,
    height: int,
    heights: tuple[float, ...] = BAR_HEIGHTS,
) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    total = len(heights) * bar_width + (len(heights) - 1) * gap
    x = (size - total) / 2
    centre = size / 2
    for factor in heights:
        bar_height = height * factor
        top = centre - bar_height / 2
        draw.rounded_rectangle(
            (x, top, x + bar_width, top + bar_height),
            radius=bar_width / 2,
            fill=255,
        )
        x += bar_width + gap
    return mask


def _icon_background(size: int, radius: int) -> Image.Image:
    background = _vertical_gradient(
        (size, size),
        [(0.0, INK_TOP), (0.55, (19, 22, 27)), (1.0, INK_BOTTOM)],
    ).convert("RGBA")

    # A soft green pool of light behind the mark keeps the flat icon alive.
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse(
        (
            size * 0.20,
            size * 0.18,
            size * 0.80,
            size * 0.86,
        ),
        fill=(30, 215, 96, 46),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.16))
    background = Image.alpha_composite(background, glow)

    # A 1 px cool rim reads as a machined edge on light and dark launchers.
    rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle(
        (0.5, 0.5, size - 1.5, size - 1.5),
        radius=radius,
        outline=RIM,
        width=max(2, size // 512),
    )
    background = Image.alpha_composite(background, rim)

    mask = _rounded_mask(size, (0, 0, size - 1, size - 1), radius)
    background.putalpha(mask)
    return background


def _icon(size: int = 1024) -> Image.Image:
    radius = round(size * 0.226)
    background = _icon_background(size, radius)

    bar_width = round(size * 0.0566)
    gap = round(size * 0.0332)
    mark_height = round(size * 0.508)
    bars = _waveform_mask(
        size,
        bar_width=bar_width,
        gap=gap,
        height=mark_height,
    )

    # Barely-there green bleed under the bars.
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow.paste((35, 226, 110, 120), (0, 0, size, size), bars)
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.035))
    background = Image.alpha_composite(background, glow)

    gradient = _vertical_gradient(
        (size, size),
        [(0.24, GREEN_TOP), (0.52, GREEN_MID), (0.80, GREEN_BOTTOM)],
    ).convert("RGBA")
    bars_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bars_layer.paste(gradient, (0, 0), bars)
    background = Image.alpha_composite(background, bars_layer)

    return background


def _foreground(size: int = 1024) -> Image.Image:
    """Transparent adaptive-icon foreground: just the resonance bars."""
    bar_width = round(size * 0.0566)
    gap = round(size * 0.0332)
    mark_height = round(size * 0.508)
    bars = _waveform_mask(size, bar_width=bar_width, gap=gap, height=mark_height)

    # Keep the mark inside the adaptive-icon safe circle (66% of the canvas).
    # The seven-bar mark is widest at the centre, so 94% leaves the roundest
    # launcher masks a little breathing room without shrinking it to a dot.
    safe_scale = 0.94
    scaled = bars.resize(
        (round(size * safe_scale), round(size * safe_scale)),
        Image.Resampling.LANCZOS,
    )
    bars = Image.new("L", (size, size), 0)
    bars.paste(scaled, ((size - scaled.width) // 2, (size - scaled.height) // 2))

    gradient = _vertical_gradient(
        (size, size),
        [(0.24, GREEN_TOP), (0.52, GREEN_MID), (0.80, GREEN_BOTTOM)],
    ).convert("RGBA")
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    layer.paste(gradient, (0, 0), bars)
    return layer


def _monochrome(size: int = 1024) -> Image.Image:
    bars = _waveform_mask(
        size,
        bar_width=round(size * 0.0566),
        gap=round(size * 0.0332),
        height=round(size * 0.508),
    )
    layer = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    layer.putalpha(bars)
    return layer


def _round_icon(size: int = 1024) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    square = _icon(size)
    square.putalpha(mask)
    return square


def _write_png(image: Image.Image, path: Path, size: int | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    target = image if size is None else image.resize((size, size), Image.Resampling.LANCZOS)
    target.save(path, "PNG", optimize=True)


def _android_mipmaps() -> None:
    legacy_sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    adaptive_sizes = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

    for density, size in legacy_sizes.items():
        _write_png(_icon(size), ANDROID_RES / f"mipmap-{density}" / "ic_launcher.png")
        _write_png(_round_icon(size), ANDROID_RES / f"mipmap-{density}" / "ic_launcher_round.png")

    for density, size in adaptive_sizes.items():
        _write_png(_foreground(size), ANDROID_RES / f"mipmap-{density}" / "ic_launcher_adaptive_fore.png")
        _write_png(_foreground(size), ANDROID_RES / f"drawable-{density}" / "ic_launcher_foreground.png")
        _write_png(_monochrome(size), ANDROID_RES / f"drawable-{density}" / "ic_launcher_monochrome.png")

    # The Linux installer wants a single app icon.
    _write_png(_icon(256), ASSET_ICONS / "ic_launcher.png")
    _write_png(_icon(256), ASSET_ICONS / "resona_icon.png")
    _write_png(_icon(1024), BRAND_DIR / "resona-icon-1024.png")


def _windows_icons() -> None:
    target = ROOT / "windows" / "runner" / "resources"
    # The desktop CI check requires app_icon.png to match the packaged
    # notification icon byte-for-byte, so keep both at the xxxhdpi size.
    _write_png(_icon(192), target / "app_icon.png")
    _icon(256).save(
        target / "app_icon.ico",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


def _fastlane_icons() -> None:
    _write_png(
        _icon(512),
        ROOT / "fastlane" / "metadata" / "android" / "en-US" / "images" / "icon.png",
    )


def _banner() -> None:
    width, height = 1600, 520
    canvas = Image.new("RGBA", (width, height), (11, 13, 16, 255))

    # Layered green glow on the left, then a faint grid of vertical rules.
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse((-220, -180, 900, 760), fill=(30, 215, 96, 54))
    glow = glow.filter(ImageFilter.GaussianBlur(150))
    canvas = Image.alpha_composite(canvas, glow)

    grid = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    grid_draw = ImageDraw.Draw(grid)
    for x in range(0, width, 80):
        grid_draw.line((x, 0, x, height), fill=(255, 255, 255, 6))
    canvas = Image.alpha_composite(canvas, grid)

    icon = _icon(240)
    canvas.alpha_composite(icon, (120, 140))

    display = ImageFont.truetype(
        str(ROOT / "assets" / "fonts" / "daylight" / "BricolageGrotesque-700.ttf"),
        150,
    )
    tagline_font = ImageFont.truetype(
        str(ROOT / "assets" / "fonts" / "daylight" / "Inter-400.ttf"),
        36,
    )
    meta_font = ImageFont.truetype(
        str(ROOT / "assets" / "fonts" / "daylight" / "Inter-500.ttf"),
        24,
    )
    draw = ImageDraw.Draw(canvas)

    draw.text((420, 120), "Resona", font=display, fill=(247, 249, 252, 255))
    draw.text(
        (426, 314),
        "Daylight for your music.",
        font=tagline_font,
        fill=(168, 176, 190, 255),
    )

    meta = "OPEN SOURCE  ·  GPL-3.0  ·  NO ADS"
    meta_width = draw.textlength(meta, font=meta_font)
    draw.rounded_rectangle(
        (426, 382, 426 + meta_width + 46, 430),
        radius=24,
        outline=(46, 224, 106, 130),
        width=2,
    )
    draw.text((449, 394), meta, font=meta_font, fill=(94, 235, 139, 255))

    draw.rectangle((120, 436, 1480, 438), fill=(32, 224, 105, 110))

    BRAND_DIR.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(BRAND_DIR / "resona-banner.png", "PNG", optimize=True)


def main() -> None:
    _android_mipmaps()
    _windows_icons()
    _fastlane_icons()
    _banner()
    print("Rendered Resona icons, launcher mipmaps, Windows ICO, and banner.")


if __name__ == "__main__":
    main()
