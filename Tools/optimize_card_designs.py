import os
import json
import glob
from PIL import Image

DESIGNS = [
    {
        "src": "card/amex/centurion-black.png",
        "id": "amex-centurion-black",
        "name": "Centurion Noir",
        "category": "black",
        "network": "amex"
    },
    {
        "src": "card/amex/kehinde-wiley-centurion.png",
        "id": "amex-centurion-art",
        "name": "Centurion Kehinde Wiley",
        "category": "art",
        "network": "amex"
    },
    {
        "src": "card/apple/black-visa.png",
        "id": "apple-black-visa",
        "name": "Apple Mat",
        "category": "minimal",
        "network": "visa"
    },
    {
        "src": "card/apple/liquid-glass.png",
        "id": "apple-liquid-glass",
        "name": "Liquid Glass",
        "category": "gradient",
        "network": "unknown"
    },
    {
        "src": "card/autres/3AUQeNPlEz.png",
        "id": "silver-titanium",
        "name": "Titane Argent",
        "category": "minimal",
        "network": "unknown"
    },
    {
        "src": "card/autres/g5lm22n1ym.png",
        "id": "stealth-obsidian",
        "name": "Obsidienne Stealth",
        "category": "black",
        "network": "unknown"
    },
    {
        "src": "card/autres/psJG4HTXMX.png",
        "id": "platinum-brushed",
        "name": "Platine Brossé",
        "category": "minimal",
        "network": "unknown"
    },
    {
        "src": "card/autres/rico-mcpato.png",
        "id": "rico-gold",
        "name": "Picsou Or",
        "category": "art",
        "network": "unknown"
    },
    {
        "src": "card/discover/discover-card.png",
        "id": "discover-orange",
        "name": "Discover Flamme",
        "category": "gradient",
        "network": "discover"
    },
    {
        "src": "card/discover/discover.png",
        "id": "discover-dawn",
        "name": "Discover Aurore",
        "category": "gradient",
        "network": "discover"
    },
    {
        "src": "card/discover/it-american-flag.png",
        "id": "discover-flag",
        "name": "Discover USA Flag",
        "category": "art",
        "network": "discover"
    },
    {
        "src": "card/discover/it-cash-back.png",
        "id": "discover-cashback",
        "name": "Discover Chrome",
        "category": "minimal",
        "network": "discover"
    },
    {
        "src": "card/revolut/black.png",
        "id": "revolut-black",
        "name": "Revolut Noir",
        "category": "black",
        "network": "mastercard"
    },
    {
        "src": "card/revolut/revolut.png",
        "id": "revolut-prism",
        "name": "Revolut Prisme",
        "category": "gradient",
        "network": "mastercard"
    },
    {
        "src": "card/visa/coutts-silk.png",
        "id": "visa-coutts-silk",
        "name": "Coutts Silk Soie",
        "category": "luxury",
        "network": "visa"
    },
    {
        "src": "card/visa/credit-agricole-visa-infinite.png",
        "id": "visa-ca-infinite",
        "name": "Crédit Agricole Infinite",
        "category": "luxury",
        "network": "visa"
    },
    {
        "src": "card/visa/lcl-visa-infinite.png",
        "id": "visa-lcl-infinite",
        "name": "LCL Infinite",
        "category": "luxury",
        "network": "visa"
    }
]

def main():
    target_dir = os.path.join("Stash", "Assets.xcassets", "CardDesigns")
    os.makedirs(target_dir, exist_ok=True)

    # Contents.json for CardDesigns folder
    group_contents = {
        "info": {
            "author": "xcode",
            "version": 1
        },
        "properties": {
            "provides-namespace": True
        }
    }
    with open(os.path.join(target_dir, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump(group_contents, f, indent=2)

    total_bytes = 0
    for d in DESIGNS:
        src = d["src"]
        design_id = d["id"]
        im_dir = os.path.join(target_dir, f"{design_id}.imageset")
        os.makedirs(im_dir, exist_ok=True)

        im = Image.open(src)
        # Convert to RGBA to avoid transparency issues
        im_rgba = im.convert("RGBA")
        # Resize to 1024 x 646 (standard credit card ratio at 3x)
        im_resized = im_rgba.resize((1024, 646), Image.Resampling.LANCZOS)

        # Quantize to 256 colors for optimal file size and crisp rendering
        im_opt = im_resized.quantize(colors=256, method=2, dither=1)

        out_filename = f"{design_id}.png"
        out_path = os.path.join(im_dir, out_filename)
        im_opt.save(out_path, "PNG", optimize=True)

        size = os.path.getsize(out_path)
        total_bytes += size
        print(f"Processed {design_id}: {size // 1024} KB")

        item_contents = {
            "images": [
                {
                    "filename": out_filename,
                    "idiom": "universal",
                    "scale": "1x"
                }
            ],
            "info": {
                "author": "xcode",
                "version": 1
            }
        }
        with open(os.path.join(im_dir, "Contents.json"), "w", encoding="utf-8") as f:
            json.dump(item_contents, f, indent=2)

    print(f"\nAll 17 designs optimized into {target_dir}")
    print(f"Total size: {total_bytes / (1024 * 1024):.2f} MB (was ~20.37 MB)")

if __name__ == "__main__":
    main()
