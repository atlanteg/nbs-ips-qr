#!/usr/bin/env bash
#
# Serve the app locally for development.
#
# Opening index.html via file:// does not work: the pdf.js worker and the
# library <script src> tags need a real HTTP origin.
#
#     ./serve.sh        # http://localhost:8777
#     ./serve.sh 9000   # custom port
#
set -euo pipefail
cd "$(dirname "$0")"
PORT="${1:-8777}"
echo "http://localhost:$PORT/"
exec python3 -m http.server "$PORT"
