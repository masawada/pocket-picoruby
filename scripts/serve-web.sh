#!/bin/sh
# Serve the repository so the browser runner can load scripts from ruby/.
#   open http://localhost:8000/web/?script=../ruby/examples/draw.rb
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-8000}"
echo "http://localhost:${PORT}/web/?script=../ruby/examples/draw.rb"
cd "${ROOT}" && exec python3 -m http.server "${PORT}"
