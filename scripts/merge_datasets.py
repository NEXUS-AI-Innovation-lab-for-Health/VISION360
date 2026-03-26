#!/usr/bin/env python3
"""Merge multiple YOLO-format datasets into one (images/labels/train|val)."""

import argparse
import shutil
from pathlib import Path


def parse_args():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--datasets", nargs="+", required=True,
                   help="Paths to datasets in YOLO format (containing images/ and labels/)")
    p.add_argument("--output", default="merged-dataset",
                   help="Output directory (created if missing)")
    p.add_argument("--split", default="train", choices=["train", "val", "test"],
                   help="Which split to merge (expects images/<split> and labels/<split>)")
    return p.parse_args()


def copy_tree(src: Path, dst: Path) -> int:
    dst.mkdir(parents=True, exist_ok=True)
    count = 0
    for file in src.glob("*"):
        if file.is_dir():
            continue
        target = dst / file.name
        # Avoid collisions by prefixing if needed
        if target.exists():
            target = dst / f"{file.stem}_{count}{file.suffix}"
        shutil.copy2(file, target)
        count += 1
    return count


def main() -> None:
    args = parse_args()
    out = Path(args.output)
    (out / f"images/{args.split}").mkdir(parents=True, exist_ok=True)
    (out / f"labels/{args.split}").mkdir(parents=True, exist_ok=True)

    images_total = 0
    labels_total = 0
    for dataset in args.datasets:
        base = Path(dataset)
        img_dir = base / "images" / args.split
        lbl_dir = base / "labels" / args.split
        if not img_dir.exists() or not lbl_dir.exists():
            print(f"[WARN] split '{args.split}' not found in {base}")
            continue
        images_total += copy_tree(img_dir, out / "images" / args.split)
        labels_total += copy_tree(lbl_dir, out / "labels" / args.split)
        print(f"Merged {base}")

    print(f"Done. Copied {images_total} images, {labels_total} labels into {out}")


if __name__ == "__main__":
    main()
