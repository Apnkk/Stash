#!/usr/bin/env python3
"""Genere le logo/AppIcon de Stash en PNG 1024x1024 avec Pillow.

Le logo : un fond arrondi avec degrade diagonal (bleu -> violet), sur lequel
se superpose une pile de trois cartes stylisees decalees, evoquant un "stash"
(reserve de cartes). La carte du dessus porte une puce EMV doree et une bande.
Rendu en supersampling x4 puis reduit pour un anti-aliasing propre.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

# --- Parametres ---
SIZE = 1024          # taille finale du PNG (px)
SS = 4               # facteur de supersampling pour l'anti-aliasing
W = SIZE * SS        # taille de travail

OUT_DIR = Path(__file__).resolve().parent.parent / "Stash" / "Assets.xcassets" / "AppIcon.appiconset"
OUT_FILE = OUT_DIR / "AppIcon-1024.png"


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def lerp_color(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        round(lerp(c1[0], c2[0], t)),
        round(lerp(c1[1], c2[1], t)),
        round(lerp(c1[2], c2[2], t)),
    )


def diagonal_gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    """Cree un degrade diagonal (coin haut-gauche -> coin bas-droit)."""
    grad = Image.new("RGB", (size, size))
    px = grad.load()
    max_d = (size - 1) * 2
    for y in range(size):
        for x in range(size):
            t = (x + y) / max_d
            px[x, y] = lerp_color(top, bottom, t)
    return grad


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def rotate_points(points, cx, cy, angle_deg):
    a = math.radians(angle_deg)
    ca, sa = math.cos(a), math.sin(a)
    out = []
    for x, y in points:
        dx, dy = x - cx, y - cy
        out.append((cx + dx * ca - dy * sa, cy + dx * sa + dy * ca))
    return out


def make_card(w: int, h: int, radius: int, colors: tuple[tuple[int, int, int], tuple[int, int, int]],
              with_chip: bool) -> Image.Image:
    """Cree une carte (RGBA) avec degrade vertical, coins arrondis et ombre douce."""
    pad = radius  # marge pour l'ombre
    card = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))

    # degrade vertical du corps de la carte
    body = Image.new("RGB", (w, h))
    bpx = body.load()
    for y in range(h):
        t = y / max(1, h - 1)
        col = lerp_color(colors[0], colors[1], t)
        for x in range(w):
            bpx[x, y] = col

    body_mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(body_mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)

    card.paste(body, (pad, pad), body_mask)

    draw = ImageDraw.Draw(card)

    if with_chip:
        # puce EMV doree
        chip_w = int(w * 0.16)
        chip_h = int(chip_w * 0.78)
        chip_x = pad + int(w * 0.10)
        chip_y = pad + int(h * 0.30)
        gold_top = (247, 224, 138)
        gold_bot = (196, 154, 61)
        chip = Image.new("RGB", (chip_w, chip_h))
        cpx = chip.load()
        for y in range(chip_h):
            t = y / max(1, chip_h - 1)
            col = lerp_color(gold_top, gold_bot, t)
            for x in range(chip_w):
                cpx[x, y] = col
        chip_mask = Image.new("L", (chip_w, chip_h), 0)
        ImageDraw.Draw(chip_mask).rounded_rectangle(
            [0, 0, chip_w - 1, chip_h - 1], radius=int(chip_h * 0.18), fill=255
        )
        card.paste(chip, (chip_x, chip_y), chip_mask)
        # contacts de la puce
        line_col = (150, 116, 40)
        cd = ImageDraw.Draw(card)
        lw = max(1, int(chip_w * 0.03))
        cd.line([chip_x, chip_y + chip_h // 2, chip_x + chip_w, chip_y + chip_h // 2], fill=line_col, width=lw)
        cd.line([chip_x + chip_w // 3, chip_y, chip_x + chip_w // 3, chip_y + chip_h], fill=line_col, width=lw)
        cd.line([chip_x + 2 * chip_w // 3, chip_y, chip_x + 2 * chip_w // 3, chip_y + chip_h], fill=line_col, width=lw)

        # deux "lignes" evoquant le numero
        num_y = pad + int(h * 0.62)
        num_x = pad + int(w * 0.10)
        num_col = (255, 255, 255, 200)
        for i in range(4):
            bx = num_x + i * int(w * 0.20)
            draw.rounded_rectangle(
                [bx, num_y, bx + int(w * 0.15), num_y + int(h * 0.06)],
                radius=int(h * 0.03), fill=num_col,
            )

    return card


def main() -> None:
    # degrade de fond : rouge profond -> noir
    top = (200, 24, 40)
    bottom = (16, 16, 18)

    bg = diagonal_gradient(W, top, bottom).convert("RGBA")

    # cartes de la pile (de l'arriere vers l'avant)
    cw = int(W * 0.52)
    ch = int(cw * 0.63)
    radius = int(ch * 0.14)

    cx = W // 2
    cy = W // 2

    stack = [
        # (dx, dy, angle, couleurs, puce)
        (int(W * 0.02), int(W * 0.10), -18, ((60, 60, 64), (30, 30, 34)), False),
        (int(W * -0.02), int(W * 0.00), -18, ((214, 40, 54), (150, 20, 30)), False),
        (int(W * -0.06), int(W * -0.10), -18, ((28, 28, 32), (12, 12, 14)), True),
    ]

    for dx, dy, angle, colors, chip in stack:
        card = make_card(cw, ch, radius, colors, chip)
        card = card.rotate(angle, expand=True, resample=Image.BICUBIC)
        px = cx - card.width // 2 + dx
        py = cy - card.height // 2 + dy
        bg.alpha_composite(card, (px, py))

    # masque arrondi facon AppIcon iOS (superellipse approx via rayon large)
    mask = rounded_mask(W, int(W * 0.2237))
    bg.putalpha(mask)

    # reduction (anti-aliasing)
    final = bg.resize((SIZE, SIZE), Image.LANCZOS)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    final.save(OUT_FILE, "PNG")
    print(f"Logo genere : {OUT_FILE} ({final.size[0]}x{final.size[1]})")


if __name__ == "__main__":
    main()
