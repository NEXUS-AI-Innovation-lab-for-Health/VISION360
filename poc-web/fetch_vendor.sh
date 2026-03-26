#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$(dirname "$0")/vendor"
cd "$(dirname "$0")/vendor"
echo "Downloading TensorFlow.js and COCO-SSD…"
curl -fsSL -o tf.min.js https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.12.0/dist/tf.min.js
curl -fsSL -o coco-ssd.min.js https://cdn.jsdelivr.net/npm/@tensorflow-models/coco-ssd@2.2.2
echo "Done. Files:" && ls -lh

