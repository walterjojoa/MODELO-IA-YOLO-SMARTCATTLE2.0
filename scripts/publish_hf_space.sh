#!/usr/bin/env bash
# Copies what the Hugging Face Space needs into a local clone of the Space and commits it.
# Usage: scripts/publish_hf_space.sh <path-to-space-clone>   (then: git -C <clone> push)
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
space="${1:?path to the Space clone}"
rm -rf "$space/smartcattle_ai" "$space/models"
mkdir -p "$space/models"
cp "$repo/deploy/huggingface/Dockerfile" "$repo/deploy/huggingface/README.md" "$space/"
cp "$repo/live.py" "$repo/requirements.txt" "$repo/constraints.txt" "$space/"
cp -r "$repo/smartcattle_ai" "$space/smartcattle_ai"
find "$space/smartcattle_ai" -name __pycache__ -type d -prune -exec rm -rf {} +
cp "$repo/models/cattle_coco_yolo11n_best.pt" "$space/models/"
git -C "$space" add -A
git -C "$space" commit -m "Publish $(git -C "$repo" rev-parse --short HEAD) from MODELO-IA-YOLO-SMARTCATTLE2.0" || echo "Nothing changed"
