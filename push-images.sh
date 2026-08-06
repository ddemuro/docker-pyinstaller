#!/bin/bash
set -e

REGISTRY="dkrhub.takelan.com/ddemuro/pyinstaller"

echo "=== Pushing all 10 images to private registry ==="

# Ubuntu variants (8 imgs)
PUSH_TAGS=(
  py3-amd64-ubuntu20.04-CUSTOM-3.12.9-6.13.0
  py3-amd64-ubuntu20.04-20260805-CUSTOM
  py3-amd64-ubuntu22.04-CUSTOM-3.12.9-6.13.0
  py3-amd64-ubuntu22.04-20260805-CUSTOM
  py3-amd64-ubuntu24.04-CUSTOM-3.12.9-6.13.0
  py3-amd64-ubuntu24.04-20260805-CUSTOM
  py3-amd64-ubuntu26.04-CUSTOM-3.12.9-6.13.0
  py3-amd64-ubuntu26.04-20260805-CUSTOM
)

for tag in "${PUSH_TAGS[@]}"; do
  echo "Pushing $tag..."
  docker push "$REGISTRY:$tag" &
done

# Windows variants (2 imgs)
WIN_TAGS=(
  py3-win32-3.12.9-6.13.0-20260805-CUSTOM
  py3-win64-3.12.9-6.13.0-20260805-CUSTOM
)

for tag in "${WIN_TAGS[@]}"; do
  echo "Pushing $tag..."
  docker push "$REGISTRY:$tag" &
done

wait
echo "=== All pushes complete ==="
