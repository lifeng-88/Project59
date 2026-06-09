#!/usr/bin/env bash
# 将 Rahmi B 面 UI 位图同步到 Hub/Assets.xcassets（不覆盖 Lumina AppIcon / LaunchScreen）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/../Rahmi/Rahmi/Assets.xcassets}"
DST="$ROOT/Hub/Assets.xcassets"

if [[ ! -d "$SRC" ]]; then
  SRC="$ROOT/Hub/RahmiAssets.xcassets"
fi

for name in AppCoinGold.imageset UploadTipsGood.imageset UploadTipsBad.imageset; do
  if [[ -d "$SRC/$name" ]]; then
    rm -rf "$DST/$name"
    cp -R "$SRC/$name" "$DST/"
    echo "synced $name"
  fi
done

echo "Done → $DST (Lumina AppIcon/LaunchScreen 请用 scripts/generate_lumina_brand_assets.py 生成)"
