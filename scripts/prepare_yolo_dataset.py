#!/usr/bin/env python3
"""Convert COCO annotations to YOLO format for a subset of classes."""

import argparse
import json
import os
from collections import defaultdict


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--annotations", required=True, help="Path to COCO annotations JSON (instances_*.json)")
    parser.add_argument("--images-dir", required=True, help="Directory containing the corresponding images")
    parser.add_argument("--output-dir", required=True, help="Directory where YOLO labels will be written")
    parser.add_argument("--classes", nargs="*", default=None,
                        help="List of class names to keep (case insensitive). If omitted, keep all")
    parser.add_argument("--names-file", default=None,
                        help="Optional path to export the ordered class list (names.txt)")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    os.makedirs(args.output_dir, exist_ok=True)

    with open(args.annotations, "r", encoding="utf-8") as f:
        coco = json.load(f)

    keep = None
    if args.classes:
        keep = {c.lower() for c in args.classes}

    cat_id_to_name = {c["id"]: c["name"].lower() for c in coco.get("categories", [])}

    # Build class index preserving the order in args.classes or discovery order
    class_to_idx = {}
    if args.classes:
        for idx, name in enumerate(args.classes):
            class_to_idx[name.lower()] = idx

    images = {img["id"]: img for img in coco.get("images", [])}
    annos_by_image = defaultdict(list)
    for anno in coco.get("annotations", []):
        cat_name = cat_id_to_name.get(anno.get("category_id"))
        if not cat_name:
            continue
        if keep and cat_name not in keep:
            continue
        annos_by_image[anno["image_id"]].append(anno)
        if cat_name not in class_to_idx:
            class_to_idx[cat_name] = len(class_to_idx)

    for image_id, annos in annos_by_image.items():
        image_info = images.get(image_id)
        if not image_info:
            continue
        width = image_info.get("width")
        height = image_info.get("height")
        if not width or not height:
            continue

        image_file = image_info.get("file_name", "")
        stem, _ = os.path.splitext(image_file)
        label_path = os.path.join(args.output_dir, f"{stem}.txt")

        lines = []
        for anno in annos:
            cat_name = cat_id_to_name.get(anno.get("category_id"))
            if cat_name not in class_to_idx:
                continue
            bbox = anno.get("bbox")  # [x, y, w, h]
            if not bbox or len(bbox) != 4:
                continue
            x, y, w, h = bbox
            x_center = (x + w / 2) / width
            y_center = (y + h / 2) / height
            w_norm = w / width
            h_norm = h / height
            cls_idx = class_to_idx[cat_name]
            lines.append(f"{cls_idx} {x_center:.6f} {y_center:.6f} {w_norm:.6f} {h_norm:.6f}")

        if lines:
            os.makedirs(os.path.dirname(label_path), exist_ok=True)
            with open(label_path, "w", encoding="utf-8") as lf:
                lf.write("\n".join(lines))

    if args.names_file:
        ordered = [None] * len(class_to_idx)
        for name, idx in class_to_idx.items():
            ordered[idx] = name
        with open(args.names_file, "w", encoding="utf-8") as nf:
            nf.write("\n".join(name for name in ordered if name))

    print(f"Processed {len(annos_by_image)} images. Classes: {class_to_idx}")


if __name__ == "__main__":
    main()
