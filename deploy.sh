#!/usr/bin/env bash
#
# Deploy the static app to one or more hosts over SSH.
#
# The app is plain static files, so deploying is just copying this directory
# to the web root of each host. No build step is involved.
#
# Configuration lives OUTSIDE this repository (the repo intentionally contains
# no hostnames, IPs or credentials). Provide it either as environment variables
# or in a local, untracked `deploy.env` next to this script:
#
#     # deploy.env
#     NBSQR_HOSTS="user@host-a user@host-b"
#     NBSQR_REMOTE_DIR="/var/www/qrpay"
#
# Usage:
#     ./deploy.sh              # deploy to every host in NBSQR_HOSTS
#     ./deploy.sh user@host    # deploy to the given host(s) instead
#
set -euo pipefail

cd "$(dirname "$0")"

[ -f deploy.env ] && . ./deploy.env

REMOTE_DIR="${NBSQR_REMOTE_DIR:-/var/www/qrpay}"

if [ "$#" -gt 0 ]; then
  HOSTS="$*"
else
  HOSTS="${NBSQR_HOSTS:-}"
fi

if [ -z "$HOSTS" ]; then
  echo "error: no hosts. Set NBSQR_HOSTS in deploy.env or pass hosts as arguments." >&2
  exit 1
fi

# The files that make up the app. Everything else (docs, scripts, git) stays local.
FILES=(index.html qrcode.min.js pdf.min.js pdf.worker.min.js)

for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "error: missing $f" >&2; exit 1; }
done

LOCAL_SUM="$(shasum -a 256 index.html | cut -d' ' -f1)"
echo "index.html sha256: $LOCAL_SUM"

for host in $HOSTS; do
  echo "==> $host:$REMOTE_DIR"

  # Stage in a temp dir first, then move into place with sudo, so we never need
  # the web root to be writable by the SSH user.
  ssh "$host" "rm -rf /tmp/qrpay-deploy && mkdir -p /tmp/qrpay-deploy"
  scp -q "${FILES[@]}" "$host:/tmp/qrpay-deploy/"
  ssh "$host" "sudo mkdir -p '$REMOTE_DIR' \
    && sudo cp /tmp/qrpay-deploy/* '$REMOTE_DIR/' \
    && sudo chmod 644 '$REMOTE_DIR'/* \
    && rm -rf /tmp/qrpay-deploy"

  # Verify what the node actually has on disk matches what we just sent.
  REMOTE_SUM="$(ssh "$host" "sha256sum '$REMOTE_DIR/index.html' | cut -d' ' -f1")"
  if [ "$REMOTE_SUM" = "$LOCAL_SUM" ]; then
    echo "    ok — checksum matches"
  else
    echo "    MISMATCH — remote $REMOTE_SUM" >&2
    exit 1
  fi
done

echo "done."
