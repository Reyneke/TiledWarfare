"""Generiert Vorschaubilder (preview.png) für die Karten aus den Tileset-Assets.

Liest das Tileset-Bild jeder Karte und erzeugt ein 256x256-Vorschaubild,
das ein repräsentatives Raster von Tiles zeigt (8x8 Tiles à 32px).
"""

import os
from PIL import Image

# Kartenverzeichnis -> Tileset-Datei
MAPS = {
    "map0": "Thespazztikone_tilemaps_005_neu.png",
    "map1": "Thespazztikone_tilemaps_005_neu.png",
}

TILE_SIZE = 32
PREVIEW_SIZE = 256
GRID = PREVIEW_SIZE // TILE_SIZE  # 8x8 Tiles


def generate_preview(tileset_path: str, output_path: str) -> None:
    """Erzeugt ein Vorschaubild aus dem Tileset-Bild."""
    with Image.open(tileset_path) as tileset:
        tileset = tileset.convert("RGBA")

        # Vorschaubild: 8x8 Raster von Tiles aus dem Tileset
        preview = Image.new("RGBA", (PREVIEW_SIZE, PREVIEW_SIZE), (0, 0, 0, 0))

        cols = tileset.width // TILE_SIZE
        rows = tileset.height // TILE_SIZE

        for gy in range(GRID):
            for gx in range(GRID):
                # Tile-Index im Tileset (zeilenweise, mit Wrap-around)
                tile_index = gy * GRID + gx
                src_col = tile_index % cols
                src_row = (tile_index // cols) % rows

                src = tileset.crop(
                    (
                        src_col * TILE_SIZE,
                        src_row * TILE_SIZE,
                        src_col * TILE_SIZE + TILE_SIZE,
                        src_row * TILE_SIZE + TILE_SIZE,
                    )
                )
                preview.paste(src, (gx * TILE_SIZE, gy * TILE_SIZE))

        preview.save(output_path, "PNG")
        print(f"  OK {output_path} ({preview.size[0]}x{preview.size[1]})")


def main() -> None:
    base_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "maps")
    base_dir = os.path.abspath(base_dir)

    for map_dir, tileset_file in MAPS.items():
        tileset_path = os.path.join(base_dir, map_dir, tileset_file)
        output_path = os.path.join(base_dir, map_dir, "preview.png")

        if not os.path.exists(tileset_path):
            print(f"  X Tileset nicht gefunden: {tileset_path}")
            continue

        print(f"Generiere Vorschau fuer {map_dir} ...")
        generate_preview(tileset_path, output_path)


if __name__ == "__main__":
    main()