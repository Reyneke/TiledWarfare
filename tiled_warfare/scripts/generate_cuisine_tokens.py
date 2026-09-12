"""Generiert Küchen-Token-Varianten (Küchen-Art-Assets, § 9).

Die Basistoken-Grafik ``token_cook_basic.png`` wird pro Küche in einem eigenen
Farbton eingefärbt. Das Ergebnis sind deutlich unterscheidbare
**Platzhalter-Kunst-Assets** – die Dateinamen/Pfade bleiben stabil, sodass
echte Art sie später einfach überschreiben kann.

Verwendung::

    python scripts/generate_cuisine_tokens.py

Die Küchennamen entsprechen ``Cuisine.values`` in ``lib/models/cuisine.dart``;
die Pfadkonvention (``assets/images/token/token_cook_<cuisine>.png``) wird von
``Cuisine.tokenImagePath`` gespiegelt.
"""

from __future__ import annotations

import os

from PIL import Image, ImageEnhance

# Verzeichnis der Token-Assets (relativ zu diesem Skript).
BASE_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "assets", "images", "token")
)
SOURCE = os.path.join(BASE_DIR, "token_cook_basic.png")

# Küche → RGB-Farbe. Die Farben sind bewusst weit auseinander gewählt, damit
# die Varianten klar unterscheidbar bleiben (Platzhalter-Balance).
CUISINES: dict[str, tuple[int, int, int]] = {
    "italian": (67, 160, 71),  # Basilikum-Grün
    "japanese": (229, 57, 53),  # Zinnober-Rot (Sonne)
    "chinese": (253, 216, 53),  # Kaiserlich-Gelb
    "german": (30, 136, 229),  # Stahl-Blau
    "canadian": (239, 108, 0),  # Ahorn-Orange
    "mexican": (216, 27, 96),  # Chili-Magenta
}

# Anteil der Küchenfarbe am Ergebnis (Rest = Original-Grafik → Shading bleibt).
TINT_STRENGTH = 0.55


def tint(base: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    """Färbt ``base`` in ``color`` ein und behält den Alpha-Kanal bei."""
    rgb = base.convert("RGB")
    alpha = base.split()[3]

    color_layer = Image.new("RGB", base.size, color)
    mixed = Image.blend(rgb, color_layer, TINT_STRENGTH)
    mixed = ImageEnhance.Color(mixed).enhance(1.25)

    out = mixed.convert("RGBA")
    out.putalpha(alpha)
    return out



def main() -> int:
    if not os.path.exists(SOURCE):
        print(f"  X Basis-Token nicht gefunden: {SOURCE}")
        return 1

    base = Image.open(SOURCE).convert("RGBA")
    print(f"Basis-Token: {os.path.relpath(SOURCE, os.getcwd())} {base.size}")

    for name, color in CUISINES.items():
        out = tint(base, color)
        target = os.path.join(BASE_DIR, f"token_cook_{name}.png")
        out.save(target, "PNG")
        print(
            "  OK "
            f"{os.path.relpath(target, os.getcwd())} "
            f"({out.size[0]}x{out.size[1]})"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
