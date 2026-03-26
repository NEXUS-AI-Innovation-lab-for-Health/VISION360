#!/usr/bin/env python3
"""Generate a YOLO data.yaml template from the ontology."""

import argparse
import json
from pathlib import Path


def slugify(name: str) -> str:
    return name.lower().strip().replace(" ", "_")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ontology", default="poc-web/ontology.json")
    parser.add_argument("--output", default="datasets/data-template.yaml")
    parser.add_argument("--root", default="C:/datasets/vision360", help="Default dataset root path")
    args = parser.parse_args()

    ont_path = Path(args.ontology)
    data = json.loads(ont_path.read_text(encoding="utf-8"))

    names = []
    seen = set()
    for group in data.values():
        for cls in group.get("classes", []):
            key = slugify(cls)
            if key not in seen:
                seen.add(key)
                names.append(key)

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    with out_path.open("w", encoding="utf-8") as f:
        f.write("# Update train/val paths once your dataset is ready\n")
        f.write(f"path: {args.root}\n")
        f.write("train: images/train\n")
        f.write("val: images/val\n\n")
        f.write("names:\n")
        for idx, name in enumerate(names):
            f.write(f"  {idx}: {name}\n")

    print(f"Wrote template with {len(names)} classes to {out_path}")


if __name__ == "__main__":
    main()
