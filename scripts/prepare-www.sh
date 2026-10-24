#!/usr/bin/env bash
# Bouwt de www/ map voor Capacitor uit de master bestanden in de repo-root.
# index.html blijft de enige bron: hier wordt alleen gekopieerd, nooit gewijzigd.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -f index.html ]; then
  echo "FOUT: index.html niet gevonden in $ROOT" >&2
  exit 1
fi

rm -rf www
mkdir -p www

cp index.html www/index.html
cp sw.js      www/sw.js
cp icon.png   www/icon.png
cp gps-icon.png www/gps-icon.png

echo "www/ gebouwd uit index.html ($(wc -c < index.html) bytes)"
