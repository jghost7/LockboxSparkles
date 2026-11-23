"""Generate crisp anti-aliased 32-bit RGBA .tga sparkle textures for LockboxSparkles.

    python tools/make_media.py -> LockboxSparkles/Media/*.tga

All textures are white artwork with alpha so WoW can tint them cleanly via SetVertexColor
with ADD blend mode.
"""
import math
import pathlib

from PIL import Image, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "LockboxSparkles" / "Media"


def save_tga(img: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.tga")


def make_sparkle_star(size: int = 64) -> Image.Image:
    """Four-point diamond star glint with sharp tapering rays and luminous core."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    cx = (size - 1) / 2.0
    cy = (size - 1) / 2.0
    r_max = size * 0.48

    for y in range(size):
        dy = (y - cy) / r_max
        ay = abs(dy)
        for x in range(size):
            dx = (x - cx) / r_max
            ax = abs(dx)
            dist = math.hypot(dx, dy)
            if dist >= 1.0:
                continue

            # Soft bright core
            core = math.exp(-(dist * dist) / 0.045)

            # Cardinal 4-point rays (thin bright spikes along X and Y axes)
            ray_h = math.exp(-(ay * ay) / 0.0028) * max(0.0, 1.0 - ax) ** 1.35
            ray_v = math.exp(-(ax * ax) / 0.0028) * max(0.0, 1.0 - ay) ** 1.35

            # Subtle diagonal micro-rays for extra crystalline sparkle
            u = (dx + dy) * 0.70710678
            v = (dx - dy) * 0.70710678
            diag_a = math.exp(-(u * u) / 0.0045) * max(0.0, 1.0 - abs(v) * 1.9) ** 1.8 * 0.38
            diag_b = math.exp(-(v * v) / 0.0045) * max(0.0, 1.0 - abs(u) * 1.9) ** 1.8 * 0.38

            # Smooth circular edge falloff so texture edges are strictly 0
            edge = max(0.0, 1.0 - dist ** 3)
            val = min(1.0, (core * 0.95 + max(ray_h, ray_v) * 0.95 + max(diag_a, diag_b)) * edge)
            alpha = int(round(val * 255))
            if alpha > 0:
                px[x, y] = (255, 255, 255, alpha)

    return img


def make_sparkle_glow(size: int = 64) -> Image.Image:
    """Smooth Gaussian radial glow halo for subtle ambient shimmer behind the lockbox."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    cx = (size - 1) / 2.0
    cy = (size - 1) / 2.0
    r_max = size * 0.48

    for y in range(size):
        dy = (y - cy) / r_max
        for x in range(size):
            dx = (x - cx) / r_max
            dist = math.hypot(dx, dy)
            if dist >= 1.0:
                continue
            falloff = math.exp(-(dist * dist) / 0.19) * (1.0 - dist) ** 1.2
            alpha = int(round(min(1.0, falloff) * 255))
            if alpha > 0:
                px[x, y] = (255, 255, 255, alpha)

    return img


def make_sparkle_dot(size: int = 32) -> Image.Image:
    """Crisp luminous dust mote / micro-glint."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    cx = (size - 1) / 2.0
    cy = (size - 1) / 2.0
    r_max = size * 0.45

    for y in range(size):
        dy = (y - cy) / r_max
        for x in range(size):
            dx = (x - cx) / r_max
            dist = math.hypot(dx, dy)
            if dist >= 1.0:
                continue
            val = math.exp(-(dist * dist) / 0.14) * (1.0 - dist) ** 1.1
            alpha = int(round(min(1.0, val) * 255))
            if alpha > 0:
                px[x, y] = (255, 255, 255, alpha)

    return img.filter(ImageFilter.GaussianBlur(0.3))


def main() -> None:
    save_tga(make_sparkle_star(64), "sparkle_star")
    save_tga(make_sparkle_glow(64), "sparkle_glow")
    save_tga(make_sparkle_dot(32), "sparkle_dot")
    print(f"Generated sparkle textures in {OUT}")


if __name__ == "__main__":
    main()
